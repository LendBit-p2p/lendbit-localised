// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {LibAppStorage} from "./LibAppStorage.sol";
import {LibPositionManager} from "./LibPositionManager.sol";
import {LibPriceOracle} from "./LibPriceOracle.sol";
import {LibUtils} from "./LibUtils.sol";
import {LibVaultManager} from "./LibVaultManager.sol";

import {Constants} from "../models/Constant.sol";
import "../models/Error.sol";
import "../models/Event.sol";
import "../models/Protocol.sol";

import {TokenVault} from "../TokenVault.sol";

library LibProtocol {
    using LibPositionManager for LibAppStorage.StorageLayout;
    using LibPriceOracle for LibAppStorage.StorageLayout;
    using LibVaultManager for LibAppStorage.StorageLayout;

    function _depositCollateral(LibAppStorage.StorageLayout storage s, address _token, uint256 _amount) internal {
        uint256 _positionId = s._getPositionIdForUser(msg.sender);

        if (_positionId == 0) {
            _positionId = s._createPositionFor(msg.sender);
        }
        _allowanceAndBalanceCheck(_token, _amount);

        s.s_positionCollateral[_positionId][_token] += _amount;
        bool _success = ERC20(_token).transferFrom(msg.sender, address(this), _amount);
        if (!_success) revert TRANSFER_FAILED();
        emit CollateralDeposited(_positionId, _token, _amount);
    }

    function _withdrawCollateral(LibAppStorage.StorageLayout storage s, address _token, uint256 _amount) internal {
        uint256 _positionId = _positionIdCheck(s);
        if (s.s_positionCollateral[_positionId][_token] < _amount) revert INSUFFICIENT_BALANCE();

        s.s_positionCollateral[_positionId][_token] -= _amount;
        bool _success = ERC20(_token).transfer(msg.sender, _amount);
        if (!_success) revert TRANSFER_FAILED();
        emit CollateralWithdrawn(_positionId, _token, _amount);
    }

    function _borrow(LibAppStorage.StorageLayout storage s, address _token, uint256 _amount)
        internal
        returns (uint256)
    {
        uint256 _positionId = _positionIdCheck(s);
        if (!s.s_supportedToken[_token]) revert TOKEN_NOT_SUPPORTED(_token);
        if (!s._validateVaultUtlization(_token, _amount)) revert TOKEN_OVERUTILIZATION();

        s.s_nextBorrowId++;
        uint256 _borrowId = s.s_nextBorrowId;

        (, uint256 _currentBorrowValue) = s._getTokenValueInUSD(_token, _amount);
        uint256 _healthFactor = _getHealthFactor(s, _positionId, _currentBorrowValue);

        if (_healthFactor < Constants.MIN_HEALTH_FACTOR) revert HEALTH_FACTOR_TOO_LOW(_healthFactor);

        //  // Calculate the amount of collateral to lock based on the loan value
        uint256 _collateralToLock = _calculateCollateralToLock(_currentBorrowValue);
        // // For each collateral token, lock an appropriate amount based on its USD value
        _lockCollateral(s, _positionId, _borrowId, _collateralToLock);

        // borrowing logic to be implemented
        BorrowDetails memory borrowDetails = BorrowDetails({
            positionId: _positionId,
            token: _token,
            amount: _amount,
            totalRepayment: 0,
            startTime: block.timestamp,
            status: RequestStatus.FULFILLED
        });
        s.s_borrowDetails[_borrowId] = borrowDetails;

        TokenVault _vault = s.i_tokenVault[_token];
        _vault.borrow(msg.sender, _amount);

        emit BorrowComplete(_positionId, _token, _amount);
        return _borrowId;
    }

    function _allowanceAndBalanceCheck(address _token, uint256 _amount) internal view {
        if (_token == address(0)) revert ADDRESS_ZERO();
        if (_amount == 0) revert AMOUNT_ZERO();
        if (!LibAppStorage.appStorage().s_supportedCollateralTokens[_token]) revert TOKEN_NOT_SUPPORTED(_token);
        if (ERC20(_token).allowance(msg.sender, address(this)) < _amount) revert INSUFFICIENT_ALLOWANCE();
        if (ERC20(_token).balanceOf(msg.sender) < _amount) revert INSUFFICIENT_BALANCE();
    }

    function _positionIdCheck(LibAppStorage.StorageLayout storage s) internal view returns (uint256) {
        uint256 _positionId = s._getPositionIdForUser(msg.sender);
        if (_positionId == 0) revert NO_POSITION_ID(msg.sender);
        return _positionId;
    }

    function _addCollateralToken(LibAppStorage.StorageLayout storage s, address _token, address _pricefeed) internal {
        if (_token == address(0)) revert ADDRESS_ZERO();
        if (_pricefeed == address(0)) revert ADDRESS_ZERO();
        if (s.s_supportedCollateralTokens[_token]) revert TOKEN_ALREADY_SUPPORTED_AS_COLLATERAL(_token);

        s.s_supportedCollateralTokens[_token] = true;
        s.s_allCollateralTokens.push(_token);
        s.s_tokenPriceFeed[_token] = _pricefeed;

        emit CollateralTokenAdded(_token);
    }

    function _removeCollateralToken(LibAppStorage.StorageLayout storage s, address _token) internal {
        if (_token == address(0)) revert ADDRESS_ZERO();
        if (!s.s_supportedCollateralTokens[_token]) revert TOKEN_NOT_SUPPORTED_AS_COLLATERAL(_token);

        s.s_supportedCollateralTokens[_token] = false;
        // delete s.s_tokenPriceFeed[_token];

        // remove from array
        uint256 length = s.s_allCollateralTokens.length;
        for (uint256 i = 0; i < length; i++) {
            if (s.s_allCollateralTokens[i] == _token) {
                s.s_allCollateralTokens[i] = s.s_allCollateralTokens[length - 1];
                s.s_allCollateralTokens.pop();
                break;
            }
        }

        emit CollateralTokenRemoved(_token);
    }

    function _addLocalCurrencySupport(LibAppStorage.StorageLayout storage s, string calldata _currency) internal {
        if (keccak256(abi.encode(_currency)) == keccak256(abi.encode(""))) revert EMPTY_STRING();
        if (s.s_supportedLocalCurrencies[_currency]) revert CURRENCY_ALREADY_SUPPORTED(_currency);

        s.s_supportedLocalCurrencies[_currency] = true;

        emit LocalCurrencyAdded(_currency);
    }

    function _removeLocalCurrencySupport(LibAppStorage.StorageLayout storage s, string calldata _currency) internal {
        if (keccak256(abi.encode(_currency)) == keccak256(abi.encode(""))) revert EMPTY_STRING();
        if (!s.s_supportedLocalCurrencies[_currency]) revert CURRENCY_NOT_SUPPORTED(_currency);

        s.s_supportedLocalCurrencies[_currency] = false;

        emit LocalCurrencyRemoved(_currency);
    }

    function _getPositionCollateralValue(LibAppStorage.StorageLayout storage s, uint256 _positionId)
        internal
        view
        returns (uint256)
    {
        uint256 _totalValue = 0;
        address[] memory _tokens = s.s_allCollateralTokens;
        for (uint256 i = 0; i < _tokens.length; i++) {
            address _token = _tokens[i];
            uint256 _amount = s.s_positionCollateral[_positionId][_token];
            (, uint256 _usdValue) = s._getTokenValueInUSD(_token, _amount);
            _totalValue += _usdValue;
        }
        return _totalValue;
    }

    function _getPositionBorrowedValue(LibAppStorage.StorageLayout storage s, uint256 _positionId)
        internal
        view
        returns (uint256)
    {
        uint256 _totalValue = 0;
        address[] memory _tokens = s.s_allSupportedTokens;
        for (uint256 i = 0; i < _tokens.length; i++) {
            address _token = _tokens[i];
            uint256 _amount = s.s_positionBorrowed[_positionId][_token];
            (, uint256 _usdValue) = s._getTokenValueInUSD(_token, _amount);
            _totalValue += _usdValue;
        }
        return _totalValue;
    }

    function _getHealthFactor(LibAppStorage.StorageLayout storage s, uint256 _positionId, uint256 _currentBorrowValue)
        internal
        view
        returns (uint256)
    {
        uint256 _collateralValue = _getPositionCollateralValue(s, _positionId);
        uint256 _borrowedValue = _getPositionBorrowedValue(s, _positionId);
        uint256 _collateralAdjustedValue =
            (_collateralValue * Constants.LIQUIDATION_THRESHOLD) / Constants.BASIS_POINTS_SCALE;

        _borrowedValue += _currentBorrowValue;

        if (_borrowedValue == 0) return (_collateralAdjustedValue * Constants.PRECISION); // No debt means max health factor

        return _collateralAdjustedValue * Constants.PRECISION / _borrowedValue; // Health factor with 18 decimals
    }

    function _calculateCollateralToLock(uint256 _loanUSDValue) internal pure returns (uint256) {
        return _loanUSDValue * Constants.BASIS_POINTS_SCALE / Constants.COLLATERALIZATION_RATIO; // 125% of the amount being borrowed
    }

    event Amount(uint256 amount, uint256 amount2);

    function _lockCollateral(
        LibAppStorage.StorageLayout storage s,
        uint256 _positionId,
        uint256 _borrowId,
        uint256 _collateralToLock
    ) internal {
        // uint256 _collateralToLockUSD = _collateralToLock;
        for (uint256 i = 0; i < s.s_allCollateralTokens.length; i++) {
            address _token = s.s_allCollateralTokens[i];
            uint256 _userCollateral = s.s_positionCollateral[_positionId][_token];
            uint8 _decimalToken = LibUtils._getTokenDecimals(_token);

            // Get price per token (not total USD value)

            (uint256 _pricePerToken, uint256 _userCollateralUSD) = s._getTokenValueInUSD(_token, _userCollateral);

            // emit Amount(_userCollateralUSD, _collateralToLock);

            uint256 _amountToLockUSD;
            if (_userCollateralUSD >= _collateralToLock) {
                _amountToLockUSD = _collateralToLock;
                _collateralToLock = 0;
                // emit Amount(_amountToLockUSD, _collateralToLock);
            } else {
                _amountToLockUSD = _userCollateralUSD;
                _collateralToLock -= _userCollateralUSD;
            }

            // Convert USD amount to token amount
            uint256 _amountToLock = _amountToLockUSD * (10 ** _decimalToken) / LibUtils._noramlizeToNDecimals(_pricePerToken, 8, 18); //Constants.PRECISION;

            emit Amount(_amountToLock, _amountToLockUSD);

            // Store the locked amount for each collateral token
            s.s_borrowLockedCollateral[_borrowId][_token] += _amountToLock;
            s.s_positionCollateral[_positionId][_token] = _userCollateral - _amountToLock;

            if (_collateralToLock == 0) break;
        }
    }
}
