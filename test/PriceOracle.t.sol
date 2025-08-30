// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/PriceOracleFacet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

import "../contracts/models/Error.sol";
import "../contracts/models/Event.sol";

import {IFunctionsSubscriptions} from
    "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsSubscriptions.sol";

contract PriceOracleTest is Test, IDiamondCut {
    uint256 baseMainnetFork;
    uint256 baseSepoliaFork;

    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    PriceOracleFacet priceOracleF;

    uint64 subscriptionId = 438;
    address subOwner = 0xb159588fc04378B8334BA49593aAa3966663ACe1;
    // address linkHolder = 0x72bE417AFB0aBEa66913141C605D313BB389b59C; //mainnet
    address linkHolder = 0x4281eCF07378Ee595C564a59048801330f3084eE; //sepolia

    // address linkToken = 0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196; //mainnet
    address linkToken = 0xE4aB69C077896252FAFBD49EFD26B5D171A32410; //sepolia
    address baseRouter = 0xf9B8fc078197181C841c296C876945aaa425B278;
    // bytes32 baseDonId = 0x66756e2d626173652d6d61696e6e65742d310000000000000000000000000000;
    bytes32 baseDonId = 0x66756e2d626173652d7365706f6c69612d310000000000000000000000000000;
    string source = "const stableCoin = args[0]" "const localCurrency = args[1]"
        "const apiResponse = await Functions.makeHttpRequest({"
        "url: `https://api.paycrest.io/v1/rates/${stableCoin}/100/${localCurrency}`,"
        "headers: {'API-Key': secrets.apiKey}" "})" "if (apiResponse.error) {" "console.error(apiResponse.error)"
        "throw Error('Request failed')" "}" "const { data } = apiResponse;" "return Functions.encodeString(data.data)";

    function setUp() public {
        baseMainnetFork = vm.createFork(vm.envString("BASE_MAINNET_URL"));
        baseSepoliaFork = vm.createFork(vm.envString("BASE_SEPOLIA_URL"));
        vm.selectFork(baseSepoliaFork);

        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        priceOracleF = new PriceOracleFacet();

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
                facetAddress: address(priceOracleF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("PriceOracleFacet")
            })
        );

        priceOracleF = PriceOracleFacet(address(diamond));

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        priceOracleF.initializePriceOracle(baseDonId, baseRouter, linkToken, 300000, subscriptionId);
        priceOracleF.setupSource(source);
        addContractAsConsumer();
    }

    function testInitialization() public view {
        uint64 _subId = priceOracleF.getSubscriptionId();
        (address _router, bytes32 _donId) = priceOracleF.getRouterInfo();
        assertEq(_subId, subscriptionId);
        assertEq(_router, baseRouter);
        assertEq(_donId, baseDonId);
    }

    function testSetupSource() public {
        string memory _source = "const stableCoin = args[0]" "const localCurrency = args[1]"
            "const apiResponse = await Functions.makeHttpRequest({"
            "url: `https://api.paycrest.io/v1/rates/${stableCoin}/100/${localCurrency}`,"
            "headers: {'API-Key': secrets.apiKey}" "})" "if (apiResponse.error) {" "console.error(apiResponse.error)"
            "throw Error('Request failed')" "}" "const { data } = apiResponse;"
            "return Functions.encodeString(data.data)";
        vm.expectEmit(true, true, true, true);
        emit FunctionsSourceChanged(address(this), abi.encode(_source));
        priceOracleF.setupSource(_source);

        string memory returnedSource = priceOracleF.getSource();
        assertEq(returnedSource, _source);
    }

    function testRequestPrice() public {
        string[] memory args = new string[](2);
        args[0] = "USDT";
        args[1] = "NGN";
        //request character info
        bytes32 reqId = priceOracleF.sendRequest(subscriptionId, args);
        assertTrue(reqId != 0);
    }

    function addContractAsConsumer() internal {
        vm.startPrank(subOwner);
        IFunctionsSubscriptions(baseRouter).addConsumer(subscriptionId, address(diamond));
        vm.stopPrank();
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
