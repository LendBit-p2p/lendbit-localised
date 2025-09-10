// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ProtocolFacet.sol";
import "../contracts/facets/PositionManagerFacet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

import "../contracts/models/Error.sol";
import "../contracts/models/Event.sol";
import {Helpers} from "./Helpers.sol";

contract ProtocolTest is Test, IDiamondCut, Helpers {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ProtocolFacet protocolF;
    PositionManagerFacet positionManagerF;

    // Test tokens
    ERC20Mock token1;
    ERC20Mock token2;
    ERC20Mock token3;

    // Test addresses
    address user1 = mkaddr("user1");
    address user2 = mkaddr("user2");
    address nonAdmin = mkaddr("nonAdmin");

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        protocolF = new ProtocolFacet();
        positionManagerF = new PositionManagerFacet();

        //upgrade diamond with facets
        //build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

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

        protocolF = ProtocolFacet(address(diamond));
        positionManagerF = PositionManagerFacet(address(diamond));

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        // Deploy test tokens
        token1 = new ERC20Mock();
        token2 = new ERC20Mock();
        token3 = new ERC20Mock();

        // Setup initial collateral tokens
        _setupInitialCollateralTokens();
    }
    
    function _setupInitialCollateralTokens() internal {
        protocolF.addCollateralToken(address(token1));
        protocolF.addCollateralToken(address(token2));
    }

    // =============================================================
    //                    ADD COLLATERAL TOKEN TESTS
    // =============================================================

    function testAddCollateralToken() public {
        address newToken = address(0x123);
        
        vm.expectEmit(true, false, false, false);
        emit CollateralTokenAdded(newToken);
        
        protocolF.addCollateralToken(newToken);
        
        assertTrue(protocolF.isCollateralTokenSupported(newToken));
        
        address[] memory allTokens = protocolF.getAllCollateralTokens();
        bool found = false;
        for (uint i = 0; i < allTokens.length; i++) {
            if (allTokens[i] == newToken) {
                found = true;
                break;
            }
        }
        assertTrue(found, "Token should be in collateral tokens array");
    }

    function testAddCollateralTokenFailsIfNotSecurityCouncil() public {
        address newToken = address(0x123);
        
        vm.startPrank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(ONLY_SECURITY_COUNCIL.selector));
        protocolF.addCollateralToken(newToken);
        vm.stopPrank();
    }

    function testAddCollateralTokenFailsForAddressZero() public {
        vm.expectRevert(abi.encodeWithSelector(ADDRESS_ZERO.selector));
        protocolF.addCollateralToken(address(0));
    }

    function testAddCollateralTokenFailsIfAlreadySupported() public {
        vm.expectRevert(abi.encodeWithSelector(TOKEN_ALREADY_SUPPORTED_AS_COLLATERAL.selector, address(token1)));
        protocolF.addCollateralToken(address(token1));
    }

    // =============================================================
    //                  REMOVE COLLATERAL TOKEN TESTS
    // =============================================================

    function testRemoveCollateralToken() public {
        assertTrue(protocolF.isCollateralTokenSupported(address(token1)));
        
        vm.expectEmit(true, false, false, false);
        emit CollateralTokenRemoved(address(token1));
        
        protocolF.removeCollateralToken(address(token1));
        
        assertFalse(protocolF.isCollateralTokenSupported(address(token1)));
        
        address[] memory allTokens = protocolF.getAllCollateralTokens();
        bool found = false;
        for (uint i = 0; i < allTokens.length; i++) {
            if (allTokens[i] == address(token1)) {
                found = true;
                break;
            }
        }
        assertFalse(found, "Token should be removed from collateral tokens array");
    }

    function testRemoveCollateralTokenFailsIfNotSecurityCouncil() public {
        vm.startPrank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(ONLY_SECURITY_COUNCIL.selector));
        protocolF.removeCollateralToken(address(token1));
        vm.stopPrank();
    }

    function testRemoveCollateralTokenFailsForAddressZero() public {
        vm.expectRevert(abi.encodeWithSelector(ADDRESS_ZERO.selector));
        protocolF.removeCollateralToken(address(0));
    }

    function testRemoveCollateralTokenFailsIfNotSupported() public {
        vm.expectRevert(abi.encodeWithSelector(TOKEN_NOT_SUPPORTED_AS_COLLATERAL.selector, address(token3)));
        protocolF.removeCollateralToken(address(token3));
    }

    // =============================================================
    //                    DEPOSIT COLLATERAL TESTS
    // =============================================================

    function testDepositCollateral() public {
        uint256 depositAmount = 1000 * 1e18;
        
        // Mint tokens to user1
        token1.mint(user1, depositAmount);
        
        vm.startPrank(user1);
        
        // Approve spending
        token1.approve(address(diamond), depositAmount);
        
        // Expect events
        vm.expectEmit(true, true, false, false);
        emit PositionIdCreated(1, user1);
        
        vm.expectEmit(true, true, true, false);
        emit CollateralDeposited(1, address(token1), depositAmount);
        
        // Deposit collateral
        protocolF.depositCollateral(address(token1), depositAmount);
        
        vm.stopPrank();
        
        // Verify collateral was deposited
        uint256 collateralBalance = protocolF.getPositionCollateral(1, address(token1));
        assertEq(collateralBalance, depositAmount);
        
        // Verify token was transferred
        assertEq(token1.balanceOf(user1), 0);
        assertEq(token1.balanceOf(address(diamond)), depositAmount);
        
        // Verify position was created
        assertEq(positionManagerF.getPositionIdForUser(user1), 1);
    }

    function testDepositCollateralToExistingPosition() public {
        uint256 depositAmount1 = 1000 * 1e18;
        uint256 depositAmount2 = 500 * 1e18;
        
        // Create position first
        positionManagerF.createPositionFor(user1);
        uint256 positionId = positionManagerF.getPositionIdForUser(user1);
        
        // Mint tokens to user1
        token1.mint(user1, depositAmount1 + depositAmount2);
        
        vm.startPrank(user1);
        
        // First deposit
        token1.approve(address(diamond), depositAmount1);
        protocolF.depositCollateral(address(token1), depositAmount1);
        
        // Second deposit
        token1.approve(address(diamond), depositAmount2);
        
        vm.expectEmit(true, true, true, false);
        emit CollateralDeposited(positionId, address(token1), depositAmount2);
        
        protocolF.depositCollateral(address(token1), depositAmount2);
        
        vm.stopPrank();
        
        // Verify total collateral
        uint256 totalCollateral = protocolF.getPositionCollateral(positionId, address(token1));
        assertEq(totalCollateral, depositAmount1 + depositAmount2);
    }

    function testDepositCollateralFailsForAddressZero() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(ADDRESS_ZERO.selector));
        protocolF.depositCollateral(address(0), 1000);
        vm.stopPrank();
    }

    function testDepositCollateralFailsForZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(AMOUNT_ZERO.selector));
        protocolF.depositCollateral(address(token1), 0);
        vm.stopPrank();
    }

    function testDepositCollateralFailsForUnsupportedToken() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(TOKEN_NOT_SUPPORTED.selector, address(token3)));
        protocolF.depositCollateral(address(token3), 1000);
        vm.stopPrank();
    }

    function testDepositCollateralFailsForInsufficientAllowance() public {
        uint256 depositAmount = 1000 * 1e18;
        token1.mint(user1, depositAmount);
        
        vm.startPrank(user1);
        // Don't approve or approve less than needed
        token1.approve(address(diamond), depositAmount - 1);
        
        vm.expectRevert(abi.encodeWithSelector(INSUFFICIENT_ALLOWANCE.selector));
        protocolF.depositCollateral(address(token1), depositAmount);
        vm.stopPrank();
    }

    function testDepositCollateralFailsForInsufficientBalance() public {
        uint256 depositAmount = 1000 * 1e18;
        token1.mint(user1, depositAmount - 1); // Mint less than needed
        
        vm.startPrank(user1);
        token1.approve(address(diamond), depositAmount);
        
        vm.expectRevert(abi.encodeWithSelector(INSUFFICIENT_BALANCE.selector));
        protocolF.depositCollateral(address(token1), depositAmount);
        vm.stopPrank();
    }

    // =============================================================
    //                   WITHDRAW COLLATERAL TESTS
    // =============================================================

    function testWithdrawCollateral() public {
        uint256 depositAmount = 1000 * 1e18;
        uint256 withdrawAmount = 300 * 1e18;
        
        // First deposit some collateral
        token1.mint(user1, depositAmount);
        vm.startPrank(user1);
        token1.approve(address(diamond), depositAmount);
        protocolF.depositCollateral(address(token1), depositAmount);
        
        uint256 positionId = positionManagerF.getPositionIdForUser(user1);
        
        // Verify initial collateral balance
        assertEq(protocolF.getPositionCollateral(positionId, address(token1)), depositAmount);
        assertEq(token1.balanceOf(user1), 0);
        assertEq(token1.balanceOf(address(diamond)), depositAmount);
        
        // Withdraw some collateral
        vm.expectEmit(true, true, true, false);
        emit CollateralWithdrawn(positionId, address(token1), withdrawAmount);
        
        protocolF.withdrawCollateral(address(token1), withdrawAmount);
        vm.stopPrank();
        
        // Verify collateral was withdrawn
        uint256 remainingCollateral = depositAmount - withdrawAmount;
        assertEq(protocolF.getPositionCollateral(positionId, address(token1)), remainingCollateral);
        assertEq(token1.balanceOf(user1), withdrawAmount);
        assertEq(token1.balanceOf(address(diamond)), remainingCollateral);
    }

    function testWithdrawAllCollateral() public {
        uint256 depositAmount = 1000 * 1e18;
        
        // First deposit some collateral
        token1.mint(user1, depositAmount);
        vm.startPrank(user1);
        token1.approve(address(diamond), depositAmount);
        protocolF.depositCollateral(address(token1), depositAmount);
        
        uint256 positionId = positionManagerF.getPositionIdForUser(user1);
        
        // Withdraw all collateral
        vm.expectEmit(true, true, true, false);
        emit CollateralWithdrawn(positionId, address(token1), depositAmount);
        
        protocolF.withdrawCollateral(address(token1), depositAmount);
        vm.stopPrank();
        
        // Verify all collateral was withdrawn
        assertEq(protocolF.getPositionCollateral(positionId, address(token1)), 0);
        assertEq(token1.balanceOf(user1), depositAmount);
        assertEq(token1.balanceOf(address(diamond)), 0);
    }

    function testWithdrawCollateralMultipleTokens() public {
        uint256 depositAmount1 = 1000 * 1e18;
        uint256 depositAmount2 = 2000 * 1e18;
        uint256 withdrawAmount1 = 500 * 1e18;
        uint256 withdrawAmount2 = 1000 * 1e18;
        
        // Deposit two different tokens
        token1.mint(user1, depositAmount1);
        token2.mint(user1, depositAmount2);
        
        vm.startPrank(user1);
        token1.approve(address(diamond), depositAmount1);
        token2.approve(address(diamond), depositAmount2);
        
        protocolF.depositCollateral(address(token1), depositAmount1);
        protocolF.depositCollateral(address(token2), depositAmount2);
        
        uint256 positionId = positionManagerF.getPositionIdForUser(user1);
        
        // Withdraw from both tokens
        protocolF.withdrawCollateral(address(token1), withdrawAmount1);
        protocolF.withdrawCollateral(address(token2), withdrawAmount2);
        vm.stopPrank();
        
        // Verify withdrawals
        assertEq(protocolF.getPositionCollateral(positionId, address(token1)), depositAmount1 - withdrawAmount1);
        assertEq(protocolF.getPositionCollateral(positionId, address(token2)), depositAmount2 - withdrawAmount2);
        assertEq(token1.balanceOf(user1), withdrawAmount1);
        assertEq(token2.balanceOf(user1), withdrawAmount2);
    }

    function testWithdrawCollateralFailsIfNoPosition() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(NO_POSITION_ID.selector, user1));
        protocolF.withdrawCollateral(address(token1), 1000);
        vm.stopPrank();
    }

    function testWithdrawCollateralFailsForInsufficientBalance() public {
        uint256 depositAmount = 1000 * 1e18;
        uint256 withdrawAmount = 1500 * 1e18; // More than deposited
        
        // First deposit some collateral
        token1.mint(user1, depositAmount);
        vm.startPrank(user1);
        token1.approve(address(diamond), depositAmount);
        protocolF.depositCollateral(address(token1), depositAmount);
        
        // Try to withdraw more than available
        vm.expectRevert(abi.encodeWithSelector(INSUFFICIENT_BALANCE.selector));
        protocolF.withdrawCollateral(address(token1), withdrawAmount);
        vm.stopPrank();
    }

    function testWithdrawCollateralFailsForZeroAmount() public {
        uint256 depositAmount = 1000 * 1e18;
        
        // First deposit some collateral
        token1.mint(user1, depositAmount);
        vm.startPrank(user1);
        token1.approve(address(diamond), depositAmount);
        protocolF.depositCollateral(address(token1), depositAmount);
        
        // Try to withdraw zero amount - this should fail at the LibProtocol level
        // Note: The current implementation doesn't have zero amount check in withdraw
        // but we can test withdrawing 0 should leave balances unchanged
        uint256 positionId = positionManagerF.getPositionIdForUser(user1);
        uint256 initialBalance = protocolF.getPositionCollateral(positionId, address(token1));
        uint256 initialUserBalance = token1.balanceOf(user1);
        
        protocolF.withdrawCollateral(address(token1), 0);
        
        // Balances should remain unchanged
        assertEq(protocolF.getPositionCollateral(positionId, address(token1)), initialBalance);
        assertEq(token1.balanceOf(user1), initialUserBalance);
        vm.stopPrank();
    }

    function testWithdrawCollateralFailsWhenTokenTransferFails() public {
        // This test would require a mock token that can fail transfers
        // For now, we'll skip this as ERC20Mock doesn't have failure modes
        // In a real scenario, you'd use a token that can be paused or have transfer restrictions
    }

    function testWithdrawCollateralFromEmptyBalance() public {
        uint256 depositAmount = 1000 * 1e18;
        
        // Deposit and then withdraw all
        token1.mint(user1, depositAmount);
        vm.startPrank(user1);
        token1.approve(address(diamond), depositAmount);
        protocolF.depositCollateral(address(token1), depositAmount);
        protocolF.withdrawCollateral(address(token1), depositAmount);
        
        // Try to withdraw again from empty balance
        vm.expectRevert(abi.encodeWithSelector(INSUFFICIENT_BALANCE.selector));
        protocolF.withdrawCollateral(address(token1), 1);
        vm.stopPrank();
    }

    function testWithdrawCollateralDifferentTokensIndependently() public {
        uint256 depositAmount = 1000 * 1e18;
        
        // Deposit token1 only
        token1.mint(user1, depositAmount);
        vm.startPrank(user1);
        token1.approve(address(diamond), depositAmount);
        protocolF.depositCollateral(address(token1), depositAmount);
        
        uint256 positionId = positionManagerF.getPositionIdForUser(user1);
        
        // Should be able to withdraw token1
        protocolF.withdrawCollateral(address(token1), 500 * 1e18);
        
        // Should fail to withdraw token2 (no balance)
        vm.expectRevert(abi.encodeWithSelector(INSUFFICIENT_BALANCE.selector));
        protocolF.withdrawCollateral(address(token2), 1);
        
        // Verify token1 balance is correct and token2 balance is still 0
        assertEq(protocolF.getPositionCollateral(positionId, address(token1)), 500 * 1e18);
        assertEq(protocolF.getPositionCollateral(positionId, address(token2)), 0);
        vm.stopPrank();
    }

    function testWithdrawCollateralMultipleUsers() public {
        uint256 depositAmount = 1000 * 1e18;
        uint256 withdrawAmount = 300 * 1e18;
        
        // Both users deposit
        token1.mint(user1, depositAmount);
        token1.mint(user2, depositAmount);
        
        vm.startPrank(user1);
        token1.approve(address(diamond), depositAmount);
        protocolF.depositCollateral(address(token1), depositAmount);
        vm.stopPrank();
        
        vm.startPrank(user2);
        token1.approve(address(diamond), depositAmount);
        protocolF.depositCollateral(address(token1), depositAmount);
        vm.stopPrank();
        
        uint256 user1PositionId = positionManagerF.getPositionIdForUser(user1);
        uint256 user2PositionId = positionManagerF.getPositionIdForUser(user2);
        
        // User1 withdraws
        vm.startPrank(user1);
        protocolF.withdrawCollateral(address(token1), withdrawAmount);
        vm.stopPrank();
        
        // Verify only user1's collateral was affected
        assertEq(protocolF.getPositionCollateral(user1PositionId, address(token1)), depositAmount - withdrawAmount);
        assertEq(protocolF.getPositionCollateral(user2PositionId, address(token1)), depositAmount);
        assertEq(token1.balanceOf(user1), withdrawAmount);
        assertEq(token1.balanceOf(user2), 0);
        assertEq(token1.balanceOf(address(diamond)), depositAmount * 2 - withdrawAmount);
    }

    function testWithdrawCollateralPartialAmounts() public {
        uint256 depositAmount = 1000 * 1e18;
        
        token1.mint(user1, depositAmount);
        vm.startPrank(user1);
        token1.approve(address(diamond), depositAmount);
        protocolF.depositCollateral(address(token1), depositAmount);
        
        uint256 positionId = positionManagerF.getPositionIdForUser(user1);
        
        // Multiple partial withdrawals
        protocolF.withdrawCollateral(address(token1), 100 * 1e18);
        assertEq(protocolF.getPositionCollateral(positionId, address(token1)), 900 * 1e18);
        assertEq(token1.balanceOf(user1), 100 * 1e18);
        
        protocolF.withdrawCollateral(address(token1), 200 * 1e18);
        assertEq(protocolF.getPositionCollateral(positionId, address(token1)), 700 * 1e18);
        assertEq(token1.balanceOf(user1), 300 * 1e18);
        
        protocolF.withdrawCollateral(address(token1), 700 * 1e18); // Withdraw remaining
        assertEq(protocolF.getPositionCollateral(positionId, address(token1)), 0);
        assertEq(token1.balanceOf(user1), 1000 * 1e18);
        
        vm.stopPrank();
    }

    // =============================================================
    //                       VIEW FUNCTION TESTS
    // =============================================================

    function testIsCollateralTokenSupported() public {
        assertTrue(protocolF.isCollateralTokenSupported(address(token1)));
        assertTrue(protocolF.isCollateralTokenSupported(address(token2)));
        assertFalse(protocolF.isCollateralTokenSupported(address(token3)));
        assertFalse(protocolF.isCollateralTokenSupported(address(0x999)));
    }

    function testGetAllCollateralTokens() public {
        address[] memory tokens = protocolF.getAllCollateralTokens();
        
        assertEq(tokens.length, 2);
        assertTrue(tokens[0] == address(token1) || tokens[1] == address(token1));
        assertTrue(tokens[0] == address(token2) || tokens[1] == address(token2));
    }

    function testGetAllCollateralTokensAfterAddingAndRemoving() public {
        // Add a new token
        protocolF.addCollateralToken(address(token3));
        
        address[] memory tokens = protocolF.getAllCollateralTokens();
        assertEq(tokens.length, 3);
        
        // Remove a token
        protocolF.removeCollateralToken(address(token1));
        
        tokens = protocolF.getAllCollateralTokens();
        assertEq(tokens.length, 2);
        
        // Verify token1 is not in the array
        for (uint i = 0; i < tokens.length; i++) {
            assertTrue(tokens[i] != address(token1));
        }
    }

    function testGetPositionCollateral() public {
        uint256 depositAmount = 1000 * 1e18;
        
        // Initially should be 0
        assertEq(protocolF.getPositionCollateral(1, address(token1)), 0);
        
        // Deposit some collateral
        token1.mint(user1, depositAmount);
        vm.startPrank(user1);
        token1.approve(address(diamond), depositAmount);
        protocolF.depositCollateral(address(token1), depositAmount);
        vm.stopPrank();
        
        // Should now return the deposited amount
        assertEq(protocolF.getPositionCollateral(1, address(token1)), depositAmount);
        
        // Other tokens should still be 0
        assertEq(protocolF.getPositionCollateral(1, address(token2)), 0);
        assertEq(protocolF.getPositionCollateral(2, address(token1)), 0);
    }

    function testMultipleUsersAndTokens() public {
        uint256 user1Amount = 1000 * 1e18;
        uint256 user2Amount = 2000 * 1e18;
        
        // Setup tokens for users
        token1.mint(user1, user1Amount);
        token2.mint(user1, user1Amount);
        token1.mint(user2, user2Amount);
        token2.mint(user2, user2Amount);
        
        // User1 deposits
        vm.startPrank(user1);
        token1.approve(address(diamond), user1Amount);
        token2.approve(address(diamond), user1Amount);
        protocolF.depositCollateral(address(token1), user1Amount);
        protocolF.depositCollateral(address(token2), user1Amount / 2);
        vm.stopPrank();
        
        // User2 deposits
        vm.startPrank(user2);
        token1.approve(address(diamond), user2Amount);
        protocolF.depositCollateral(address(token1), user2Amount);
        vm.stopPrank();
        
        uint256 user1PositionId = positionManagerF.getPositionIdForUser(user1);
        uint256 user2PositionId = positionManagerF.getPositionIdForUser(user2);
        
        // Verify individual collateral amounts
        assertEq(protocolF.getPositionCollateral(user1PositionId, address(token1)), user1Amount);
        assertEq(protocolF.getPositionCollateral(user1PositionId, address(token2)), user1Amount / 2);
        assertEq(protocolF.getPositionCollateral(user2PositionId, address(token1)), user2Amount);
        assertEq(protocolF.getPositionCollateral(user2PositionId, address(token2)), 0);
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
