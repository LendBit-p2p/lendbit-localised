// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibProtocol} from "../libraries/LibProtocol.sol";

import "../models/Error.sol";

contract ProtocolFacet {
    using LibProtocol for LibAppStorage.StorageLayout;

    /**
     * @notice Deposit collateral tokens to a position
     * @param _token The collateral token address
     * @param _amount The amount to deposit
     */
    function depositCollateral(address _token, uint256 _amount) external payable {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._depositCollateral(_token, _amount);
    }

    /**
     * @notice Withdraw collateral tokens from a position
     * @param _token The collateral token address
     * @param _amount The amount to withdraw
     */
    function withdrawCollateral(address _token, uint256 _amount) external {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._withdrawCollateral(_token, _amount);
    }

    function borrow(address _token, uint256 _amount) external returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._borrow(_token, _amount);
    }

    function repay(address _token, uint256 _amount) external returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._repay(_token, _amount);
    }

    function takeLoan(address _token, uint256 _principal, uint256 _tenureSeconds) external returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._takeLoan(_token, _principal, _tenureSeconds);
    }

    function repayLoanFor(uint256 positionId, uint256 loanId, uint256 _amount) external returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._repayLoanFor(positionId, loanId, _amount);
    }

    function repayLoan(uint256 loanId, uint256 _amount) external returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._repayLoan(loanId, _amount);
    }

    // function borrowCurrency(string calldata _currency, uint256 _amount) external {
    //     LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
    //     s._borrowCurrency(_currency, _amount);
    // }

    /**
     * @notice Add a token as accepted collateral (only security council)
     * @param _token The token address to add as collateral
     */
    function addCollateralToken(address _token, address _pricefeed, uint16 _tokenLTV) external onlySecurityCouncil {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._addCollateralToken(_token, _pricefeed, _tokenLTV);
    }

    /**
     * @notice Remove a token from accepted collateral (only security council)
     * @param _token The token address to remove from collateral
     */
    function removeCollateralToken(address _token) external onlySecurityCouncil {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._removeCollateralToken(_token);
    }

    function setInterestRate(uint16 _newInterestRate, uint16 _newPenaltyRate) external onlySecurityCouncil {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._setInterestRate(_newInterestRate, _newPenaltyRate);
    }

    function setCollateralTokenLtv(address _token, uint16 _tokenNewLTV) external onlySecurityCouncil {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._setCollateralTokenLtv(_token, _tokenNewLTV);
    }

    /**
     * @notice Add a local currency to supported list (only security council)
     * @param _currency The currency string to add (e.g., "NGN", "UGX", "KES", etc.)
     */
    function addLocalCurrency(string calldata _currency) external onlySecurityCouncil {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._addLocalCurrencySupport(_currency);
    }

    /**
     * @notice Remove a local currency from supported list (only security council)
     * @param _currency The currency string to remove
     */
    function removeLocalCurrency(string calldata _currency) external onlySecurityCouncil {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._removeLocalCurrencySupport(_currency);
    }

    /**
     * @notice Check if a token is supported as collateral
     * @param _token The token address to check
     * @return bool True if token is supported as collateral
     */
    function isCollateralTokenSupported(address _token) external view returns (bool) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s.s_supportedCollateralTokens[_token];
    }

    /**
     * @notice Get all supported collateral tokens
     * @return address[] Array of all supported collateral token addresses
     */
    function getAllCollateralTokens() external view returns (address[] memory) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s.s_allCollateralTokens;
    }

    /**
     * @notice Get collateral balance for a position and token
     * @param _positionId The position ID
     * @param _token The collateral token address
     * @return uint256 The collateral amount
     */
    function getPositionCollateral(uint256 _positionId, address _token) external view returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s.s_positionCollateral[_positionId][_token];
    }

    function getPositionCollateralValue(uint256 _positionId) external view returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._getPositionCollateralValue(_positionId);
    }

    /**
     * @notice Get borrowable collateral value for a position based on the LTV of each collateral token
     * @param _positionId The position ID
     * @return uint256 The borrowable collateral value in USD
     */
    function getPositionBorrowableCollateralValue(uint256 _positionId) external view returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._getPositionBorrowableCollateralValue(_positionId);
    }

    function getPositionBorrowedValue(uint256 _positionId) external view returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._getPositionBorrowedValue(_positionId);
    }

    function getHealthFactor(uint256 _positionId, uint256 _currentBorrowValue) external view returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._getHealthFactor(_positionId, _currentBorrowValue);
    }

    function getBorrowDetails(uint256 _positionId, address _token) external view returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._calculateUserDebt(_positionId, _token, 0);
    }

    function getCollateralTokenLTV(address _token) external view returns (uint16) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s.s_collateralTokenLTV[_token];
    }

    function getInterestRate() external view returns (uint16, uint16) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return (s.s_interestRate, s.s_penaltyRate);
    }

    /// @notice Get the total debt for active tenured loans for a position
    /// @dev This function calculates the total outstanding debt for all active loans associated with a given position ID.
    /// It iterates through each active loan, computes the outstanding balance using the `_outstandingBalance` function from the `LibProtocol` library,
    /// and sums them up to return the total debt.
    /// @param _positionId The ID of the position for which to calculate the total active debt
    /// @return uint256 The total outstanding debt for all active loans of the position
    function getTotalActiveDebt(uint256 _positionId) external view returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._totalActiveDebt(_positionId);
    }

    function getOutstandingDebtForLoan(uint256 _loanId) external view returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._outstandingBalance(_loanId, block.timestamp);
    }

    // Modifiers
    modifier onlySecurityCouncil() {
        _onlySecurityCouncil();
        _;
    }

    function _onlySecurityCouncil() internal view {
        if (msg.sender != LibDiamond.contractOwner()) revert ONLY_SECURITY_COUNCIL();
    }
}
