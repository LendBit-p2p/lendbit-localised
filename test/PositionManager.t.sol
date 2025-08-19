// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/PositionManagerFacet.sol";
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
    PositionManagerFacet positionManagerF;

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        positionManagerF = new PositionManagerFacet();

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
                facetAddress: address(positionManagerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("PositionManagerFacet")
            })
        );

        positionManagerF = PositionManagerFacet(address(diamond));

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    function testCreatePositionFor() public {
        uint256 _positionIdA = positionManagerF.createPositionFor(address(0xa));
        uint256 _positionIdB = positionManagerF.createPositionFor(address(0xb));
        assertEq(_positionIdA, 1);
        assertEq(_positionIdB, 2);
    }

    function testCreatePositionForFailsWithDulplicateAddress() public {
        address _user = address(0xa);
        positionManagerF.createPositionFor(_user);

        vm.expectRevert(abi.encodeWithSelector(ADDRESS_EXISTS.selector, _user));
        positionManagerF.createPositionFor(_user);
    }

    function testCreatePositionForEmitPositionCreatedEvent() public {
        address _user = address(0xa);
        vm.expectEmit(true, true, true, true);
        emit PositionIdCreated(1, _user);
        positionManagerF.createPositionFor(_user);
    }

    function testTransferPositionOwnership() public {
        address _user = address(0xdead);
        address _newAddress = address(0xacc);

        uint256 _positionId = positionManagerF.createPositionFor(_user);

        vm.startPrank(_user);
        uint256 _retainedPositionId = positionManagerF.transferPositionOwnership(_newAddress);

        assertEq(_retainedPositionId, _positionId);
        assertEq(positionManagerF.getPositionIdForUser(_newAddress), _positionId);
        assertEq(positionManagerF.getPositionIdForUser(_user), 0);
    }

    function testTransferPositionOwnershipFailsWhenUserIsNotRegistered() public {
        address _user = address(0xdead);
        address _newAddress = address(0xacc);

        vm.startPrank(_user);
        vm.expectRevert(abi.encodeWithSelector(NO_POSITION_ID.selector, _user));
        positionManagerF.transferPositionOwnership(_newAddress);
    }

    function testTransferPositionOwnershipEmitsEvent() public {
        address _user = address(0xdead);
        address _newAddress = address(0xacc);

        uint256 _positionId = positionManagerF.createPositionFor(_user);

        vm.startPrank(_user);
        vm.expectEmit(true, true, true, true);
        emit PositionIdTransferred(_positionId, _user, _newAddress);
        positionManagerF.transferPositionOwnership(_newAddress);
    }

    // Getters Tests
    function testGetNextPositionId() public {
        for (uint160 i = 1; i < 10; i++) {
            positionManagerF.createPositionFor(address(i));
        }

        uint256 _nextPositionId = positionManagerF.getNextPositionId();
        assertEq(_nextPositionId, 10);
    }

    function testGetPositionIdForUser() public {
        for (uint160 i = 1; i < 10; i++) {
            positionManagerF.createPositionFor(address(i));
        }

        uint256 _positionId3 = positionManagerF.getPositionIdForUser(address(3));
        uint256 _positionId5 = positionManagerF.getPositionIdForUser(address(5));
        uint256 _positionId10 = positionManagerF.getPositionIdForUser(address(10));

        assertEq(_positionId3, 3);
        assertEq(_positionId5, 5);
        assertEq(_positionId10, 0);
    }

    function testGetUserForPositionId() public {
        for (uint160 i = 1; i < 10; i++) {
            positionManagerF.createPositionFor(address(i));
        }

        address _user3 = positionManagerF.getUserForPositionId(3);
        address _user5 = positionManagerF.getUserForPositionId(5);
        address _user10 = positionManagerF.getUserForPositionId(10);

        assertTrue(_user3 == address(3));
        assertTrue(_user5 == address(5));
        assertTrue(_user10 == address(0));
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
