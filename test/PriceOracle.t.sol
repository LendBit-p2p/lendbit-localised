// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/PriceOracleFacet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

import "../contracts/models/Error.sol";
import "../contracts/models/Event.sol";

contract PriceOracleTest is Test, IDiamondCut {
    uint256 baseMainnetFork;
    uint256 baseSepoliaFork;

    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    PriceOracleFacet priceOracleF;

    address baseRouter = 0xf9B8fc078197181C841c296C876945aaa425B278;
    bytes32 baseDonId = 0x66756e2d626173652d6d61696e6e65742d310000000000000000000000000000;
    string source = "const url = `https://swapi.dev/api/people/1/`;\n"
        "const response = await Functions.makeHttpRequest({ url });\n" "if (!response.ok) {\n"
        "  throw Error(`Error fetching character: ${response.status} ${response.statusText}`);\n" "}\n"
        "const character = response.data.name;\n" "console.log(`Character: ${character}`);\n" "return character;";

    function setUp() public {
        baseMainnetFork = vm.createFork(vm.envString("BASE_MAINNET_URL"));
        baseSepoliaFork = vm.createFork(vm.envString("BASE_SEPOLIA_URL"));
        vm.selectFork(baseMainnetFork);
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

        priceOracleF.setupRouter(baseDonId, baseRouter);
        priceOracleF.setupSource(source);
    }

    function testSetupSource() public {
        string memory _source = "const characterId = args[0];"
            "const apiResponse = await Functions.makeHttpRequest({"
            "url: `https://swapi.info/api/people/${characterId}/`" "});" "if (apiResponse.error) {"
            "throw Error('Request failed');" "}" "const { data } = apiResponse;"
            "return Functions.encodeString(data.name);";
        vm.expectEmit(true, true, true, true);
        emit FunctionsSourceChanged(address(this), abi.encode(_source));
        priceOracleF.setupSource(_source);
    }

    function testRequestCharacter() public {
        string[] memory args = new string[](1);
        args[0] = "1";
        //request character info
        bytes32 reqId = priceOracleF.sendRequest(1, args);
        assertTrue(reqId != 0);
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
