// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/VaultManagerFacet.sol";
import "../contracts/Diamond.sol";
import {Base} from "./Base.t.sol";

import "../contracts/models/Protocol.sol";
import "../contracts/models/Error.sol";
import "../contracts/models/Event.sol";

import {TokenVault} from "../contracts/TokenVault.sol";
import {Helpers} from "./Helpers.sol";

contract PositionManagerTest is Base, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    VaultManagerFacet vaultManagerF;

    address linkHolder = 0x4281eCF07378Ee595C564a59048801330f3084eE; //sepolia

    //some test tokens
    ERC20Mock token1;
    ERC20Mock token2;

    TokenVault tokenVault1;
    TokenVault tokenVault2;

    address user1 = mkaddr("user1");
    address user2 = mkaddr("user2");

    VaultConfiguration defaultConfig = VaultConfiguration({
        totalDeposits: 0,
        totalBorrows: 0,
        baseRate: 500,
        slopeRate: 1500,
        reserveFactor: 2000,
        optimalUtilization: 7500,
        lastUpdated: block.timestamp
    });

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        vaultManagerF = new VaultManagerFacet();

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](3);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(vaultManagerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("VaultManagerFacet")
            })
        );

        vaultManagerF = VaultManagerFacet(address(diamond));

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        _deployErc20Tokens();
        _deployVaults();
    }

    function testDeposit() public {
        address _token = address(token1);
        uint256 _amount = 1000 ether;

        token1.mint(address(this), _amount);
        token1.approve(address(diamond), _amount);

        TokenVault tokenVault = TokenVault(payable(vaultManagerF.getTokenVault(_token)));

        vm.expectEmit(true, true, true, true);
        emit Deposit(1, _token, _amount);
        vaultManagerF.deposit(_token, _amount);

        assertEq(token1.balanceOf(user1), 0);
        assertEq(token1.balanceOf(address(tokenVault)), _amount);
        assertEq(ERC20Mock(vaultManagerF.getTokenVault(_token)).balanceOf(address(this)), _amount);
    }

    function testVaultDeposit() public {
        address _token = address(token1);
        uint256 _amount = 1000 ether;

        token1.mint(user1, _amount);
        vm.startPrank(user1);
        token1.approve(address(tokenVault1), _amount);

        tokenVault1.deposit(_amount, user1);

        assertEq(token1.balanceOf(user1), 0);
        assertEq(token1.balanceOf(address(tokenVault1)), _amount);
        assertEq(ERC20Mock(vaultManagerF.getTokenVault(_token)).balanceOf(user1), _amount);

        vm.stopPrank();
    }

    function testWithdraw() public {
        address _token = address(token1);
        uint256 _amount = 1000 ether;
        uint256 _halfAmount = _amount / 2;

        token1.mint(address(this), _amount);
        token1.approve(address(diamond), _amount);
        vaultManagerF.deposit(_token, _amount);

        tokenVault1.approve(address(diamond), _halfAmount);

        vm.expectEmit(true, true, true, true);
        emit Withdrawal(1, _token, _halfAmount);
        vaultManagerF.withdraw(_token, _halfAmount);

        assertEq(token1.balanceOf(address(this)), _halfAmount);
        assertEq(token1.balanceOf(address(tokenVault1)), _halfAmount);
        assertEq(tokenVault1.balanceOf(address(this)), _halfAmount);
    }

    function testDeployVault() public {
        address _token = address(0x123);
        address _tokenVault = vaultManagerF.deployVault(_token, address(0xdead), "Test token", "TesT", defaultConfig);
        assertTrue(vaultManagerF.tokenIsSupported(_token));
        assertEq(_tokenVault, vaultManagerF.getTokenVault(_token));
    }

    function testDeploVaultEmitTokenAdded() public {
        address _token = address(0x123);
        vm.expectEmit(true, false, true, true);
        emit TokenAdded(_token, address(0));
        vaultManagerF.deployVault(_token, address(0xdead), "Test token", "TesT", defaultConfig);
    }

    function testOnlyContractOwnerCanDeployVault() public {
        address _token = address(0x123);
        vm.startPrank(linkHolder);
        vm.expectRevert(abi.encodeWithSelector(ONLY_SECURITY_COUNCIL.selector));
        vaultManagerF.deployVault(_token, address(0xdead), "Test token", "TesT", defaultConfig);
    }

    function testPauseTokenSupport() public {
        address _token = address(0x123);
        vaultManagerF.deployVault(_token, address(0xdead), "Test token", "TesT", defaultConfig);

        vaultManagerF.pauseTokenSupport(_token);
        assertFalse(vaultManagerF.tokenIsSupported(_token));
    }

    function testOnlyContractOwnerCanPauseTokenSupport() public {
        address _token = address(0x123);
        vaultManagerF.deployVault(_token, address(0xdead), "Test token", "TesT", defaultConfig);

        vm.startPrank(linkHolder);
        vm.expectRevert(abi.encodeWithSelector(ONLY_SECURITY_COUNCIL.selector));
        vaultManagerF.pauseTokenSupport(_token);
    }

    function testResumeTokenSupport() public {
        address _token = address(0x123);
        vaultManagerF.deployVault(_token, address(0xdead), "Test token", "TesT", defaultConfig);
        vaultManagerF.pauseTokenSupport(_token);

        vaultManagerF.resumeTokenSupport(_token);
        assertTrue(vaultManagerF.tokenIsSupported(_token));
    }

    function testOnlyContractOwnerCanResumeTokenSupport() public {
        address _token = address(0x123);
        vaultManagerF.deployVault(_token, address(0xdead), "Test token", "TesT", defaultConfig);
        vaultManagerF.pauseTokenSupport(_token);

        vm.startPrank(linkHolder);
        vm.expectRevert(abi.encodeWithSelector(ONLY_SECURITY_COUNCIL.selector));
        vaultManagerF.resumeTokenSupport(_token);
    }

    function testCannotPauseOrResumeTokenSupportForTokenThatIsNotSupported() public {
        address _token = address(0x123);
        vm.expectRevert(abi.encodeWithSelector(TOKEN_NOT_SUPPORTED.selector, _token));
        vaultManagerF.pauseTokenSupport(_token);

        vm.expectRevert(abi.encodeWithSelector(TOKEN_NOT_SUPPORTED.selector, _token));
        vaultManagerF.resumeTokenSupport(_token);
    }

    function testCannotAddAddressZeroAsSupportedToken() public {
        address _token = address(0);
        vm.expectRevert(abi.encodeWithSelector(ADDRESS_ZERO.selector));
        vaultManagerF.deployVault(_token, address(0xdead), "Test token", "TesT", defaultConfig);
    }

    function testCannotPauseAddressZeroAsSupportedToken() public {
        address _token = address(0);
        vm.expectRevert(abi.encodeWithSelector(ADDRESS_ZERO.selector));
        vaultManagerF.pauseTokenSupport(_token);
    }

    function testCannotResumeAddressZeroAsSupportedToken() public {
        address _token = address(0);
        vm.expectRevert(abi.encodeWithSelector(ADDRESS_ZERO.selector));
        vaultManagerF.resumeTokenSupport(_token);
    }

    function testCannotDeployVaultMultipleTimesForSameToken() public {
        address _token = address(0x123);
        address _vaultToken = vaultManagerF.deployVault(_token, address(0xdead), "Test token", "TesT", defaultConfig);

        vm.expectRevert(abi.encodeWithSelector(TOKEN_ALREADY_SUPPORTED.selector, _token, _vaultToken));
        vaultManagerF.deployVault(_token, address(0xdead), "Diff name", "Diff", defaultConfig);
    }

    function testCannotDeployVaultForTokensWithPausedSupport() public {
        address _token = address(0x123);
        address _vaultToken = vaultManagerF.deployVault(_token, address(0xdead), "Test token", "TesT", defaultConfig);
        vaultManagerF.pauseTokenSupport(_token);

        vm.expectRevert(abi.encodeWithSelector(TOKEN_ALREADY_SUPPORTED.selector, _token, _vaultToken));
        vaultManagerF.deployVault(_token, address(0xdead), "Diff name", "Diff", defaultConfig);
    }

    function _deployVaults() internal {
        tokenVault1 = TokenVault(payable(vaultManagerF.deployVault(address(token1), address(0xdead), "Hodl Dai", "HDAI", defaultConfig)));
        tokenVault2 = TokenVault(payable(vaultManagerF.deployVault(address(token2), address(0xdead), "Hodl Xai", "HXAI", defaultConfig)));
    }

    function _deployErc20Tokens() internal {
        token1 = new ERC20Mock();
        token2 = new ERC20Mock();
    }

    function generateSelectors(string memory _facetName) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {}
}
