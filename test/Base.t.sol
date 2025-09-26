// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20Mock} from "@chainlink/contracts/src/v0.8/shared/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/PriceOracleFacet.sol";
import "../contracts/facets/ProtocolFacet.sol";
import "../contracts/facets/PositionManagerFacet.sol";
import "../contracts/facets/VaultManagerFacet.sol";
import "../contracts/Diamond.sol";

import {Test} from "forge-std/Test.sol";

contract Base is Test, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ProtocolFacet protocolF;
    PositionManagerFacet positionManagerF;
    VaultManagerFacet vaultManagerF;
    PriceOracleFacet priceOracleF;

    // Test tokens
    ERC20Mock token1;
    ERC20Mock token2;
    ERC20Mock token3;
    ERC20Mock token4;
    address pricefeed1;
    address pricefeed2;
    address pricefeed3;
    address pricefeed4;

    // Test addresses
    address user1 = mkaddr("user1");
    address user2 = mkaddr("user2");
    address nonAdmin = mkaddr("nonAdmin");

    VaultConfiguration defaultConfig = VaultConfiguration({
        totalDeposits: 0,
        totalBorrows: 0,
        baseRate: 500,
        slopeRate: 1500,
        reserveFactor: 2000,
        optimalUtilization: 7500,
        lastUpdated: block.timestamp
    });

    function setUp() public virtual {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        protocolF = new ProtocolFacet();
        positionManagerF = new PositionManagerFacet();
        vaultManagerF = new VaultManagerFacet();
        priceOracleF = new PriceOracleFacet();

        //upgrade diamond with facets
        //build cut struct
        FacetCut[] memory cut = new FacetCut[](6);

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
                facetAddress: address(protocolF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ProtocolFacet")
            })
        );

        cut[3] = (
            FacetCut({
                facetAddress: address(positionManagerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("PositionManagerFacet")
            })
        );

        cut[4] = (
            FacetCut({
                facetAddress: address(vaultManagerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("VaultManagerFacet")
            })
        );

        cut[5] = (
            FacetCut({
                facetAddress: address(priceOracleF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("PriceOracleFacet")
            })
        );

        protocolF = ProtocolFacet(address(diamond));
        positionManagerF = PositionManagerFacet(address(diamond));
        vaultManagerF = VaultManagerFacet(address(diamond));
        priceOracleF = PriceOracleFacet(address(diamond));

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        // Deploy test tokens
        (address _token1, address _pricefeed1) = deployERC20ContractAndAddPriceFeed("token1", 18, 1500);
        (address _token2, address _pricefeed2) = deployERC20ContractAndAddPriceFeed("token2", 18, 300);
        (address _token3, address _pricefeed3) = deployERC20ContractAndAddPriceFeed("token3", 6, 1);

        token1 = ERC20Mock(_token1);
        token2 = ERC20Mock(_token2);
        token3 = ERC20Mock(_token3);

        pricefeed1 = _pricefeed1;
        pricefeed2 = _pricefeed2;
        pricefeed3 = _pricefeed3;

        // Setup initial collateral tokens
        _setupInitialCollateralTokens();
    }

    function _setupInitialCollateralTokens() internal {
        protocolF.addCollateralToken(address(token1), pricefeed1);
        protocolF.addCollateralToken(address(token2), pricefeed2);
    }

    function deployERC20ContractAndAddPriceFeed(string memory _name, uint8 _decimals, int256 _initialAnswer)
        internal
        returns (address, address)
    {
        ERC20Mock _erc20 = new ERC20Mock(_decimals);
        MockV3Aggregator priceFeed = new MockV3Aggregator(8, _initialAnswer * 1e8);
        vm.label(address(priceFeed), "Price Feed");
        vm.label(address(_erc20), _name);
        return (address(_erc20), address(priceFeed));
    }

    function mkaddr(string memory name) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))));
        vm.label(addr, name);
        return addr;
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
