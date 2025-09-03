// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/VaultManagerFacet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

import "../contracts/models/Error.sol";
import "../contracts/models/Event.sol";

contract PositionManagerTest is Test, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    VaultManagerFacet vaultManagerF;

    address linkHolder = 0x4281eCF07378Ee595C564a59048801330f3084eE; //sepolia

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
    }

    function testDeploVault() public {
        address _token = address(0x123);
        address _tokenVault = vaultManagerF.deployVault(_token, "Test token", "TesT");
        assertTrue(vaultManagerF.tokenIsSupported(_token));
        assertEq(_tokenVault, vaultManagerF.getTokenVault(_token));
    }

    function testDeploVaultEmitTokenAdded() public {
        address _token = address(0x123);
        vm.expectEmit(true, false, true, true);
        emit TokenAdded(_token, address(0));
        vaultManagerF.deployVault(_token, "Test token", "TesT");
    }

    function testOnlyContractOwnerCanDeployVault() public {
        address _token = address(0x123);
        vm.startPrank(linkHolder);
        vm.expectRevert(abi.encodeWithSelector(ONLY_SECURITY_COUNCIL.selector));
        vaultManagerF.deployVault(_token, "Test token", "TesT");
    }

    function testPauseTokenSupport() public {
        address _token = address(0x123);
        vaultManagerF.deployVault(_token, "Test token", "TesT");

        vaultManagerF.pauseTokenSupport(_token);
        assertFalse(vaultManagerF.tokenIsSupported(_token));
    }

    function testOnlyContractOwnerCanPauseTokenSupport() public {
        address _token = address(0x123);
        vaultManagerF.deployVault(_token, "Test token", "TesT");

        vm.startPrank(linkHolder);
        vm.expectRevert(abi.encodeWithSelector(ONLY_SECURITY_COUNCIL.selector));
        vaultManagerF.pauseTokenSupport(_token);
    }

    function testResumeTokenSupport() public {
        address _token = address(0x123);
        vaultManagerF.deployVault(_token, "Test token", "TesT");
        vaultManagerF.pauseTokenSupport(_token);

        vaultManagerF.resumeTokenSupport(_token);
        assertTrue(vaultManagerF.tokenIsSupported(_token));
    }

    function testOnlyContractOwnerCanResumeTokenSupport() public {
        address _token = address(0x123);
        vaultManagerF.deployVault(_token, "Test token", "TesT");
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
        vaultManagerF.deployVault(_token, "Test token", "TesT");
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
        address _vaultToken = vaultManagerF.deployVault(_token, "Test token", "TesT");

        vm.expectRevert(abi.encodeWithSelector(TOKEN_ALREADY_SUPPORTED.selector, _token, _vaultToken));
        vaultManagerF.deployVault(_token, "Diff name", "Diff");
    }

    function testCannotDeployVaultForTokensWithPausedSupport() public {
        address _token = address(0x123);
        address _vaultToken = vaultManagerF.deployVault(_token, "Test token", "TesT");
        vaultManagerF.pauseTokenSupport(_token);

        vm.expectRevert(abi.encodeWithSelector(TOKEN_ALREADY_SUPPORTED.selector, _token, _vaultToken));
        vaultManagerF.deployVault(_token, "Diff name", "Diff");
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
