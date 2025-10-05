// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {LibAppStorage} from "./LibAppStorage.sol";
import {LibInterestRateModel} from "./LibInterestRateModel.sol";
import {LibPositionManager} from "./LibPositionManager.sol";
import {LibPriceOracle} from "./LibPriceOracle.sol";
import {LibUtils} from "./LibUtils.sol";
import {LibVaultManager} from "./LibVaultManager.sol";

import {Constants} from "../models/Constant.sol";
import "../models/Error.sol";
import "../models/Event.sol";
import "../models/Protocol.sol";
import {RepayStateChangeParams} from "../models/FunctionParams.sol";

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

    // TODO: fix withdraw to check health factor before allowing withdraw
    function _withdrawCollateral(LibAppStorage.StorageLayout storage s, address _token, uint256 _amount) internal {
        uint256 _positionId = _positionIdCheck(s);
        if (s.s_positionCollateral[_positionId][_token] < _amount) revert INSUFFICIENT_BALANCE();

        s.s_positionCollateral[_positionId][_token] -= _amount;
        bool _success = ERC20(_token).transfer(msg.sender, _amount);
        if (!_success) revert TRANSFER_FAILED();
        emit CollateralWithdrawn(_positionId, _token, _amount);
    }

    //TODO: remove data types not needed for lquidity pools
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

        // Calculate the amount of collateral to lock based on the loan value
        uint256 _collateralToLock = _calculateCollateralToLock(_currentBorrowValue);

        // For each collateral token, lock an appropriate amount based on its USD value
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

        uint256 _tokenBorrow = s.s_positionBorrowed[_positionId][_token];
        if (_tokenBorrow == 0) {
            s.s_positionBorrowed[_positionId][_token] += _amount;
        } else {
            s.s_positionBorrowed[_positionId][_token] = _calculateUserDebt(s, _positionId, _token, _amount);
        }

        s.s_positionBorrowedLastUpdate[_positionId][_token] = block.timestamp;

        s._updateVaultBorrows(_token, _amount);

        TokenVault _vault = s.i_tokenVault[_token];
        _vault.borrow(msg.sender, _amount);

        emit BorrowComplete(_positionId, _token, _amount);
        return _borrowId;
    }

    function _repay(LibAppStorage.StorageLayout storage s, uint256 _borrowId, uint256 _amount)
        internal
        returns (uint256)
    {
        if (_borrowId > s.s_nextBorrowId) revert INVALID_BORROW_ID(_borrowId);
        uint256 _positionId = _positionIdCheck(s);

        BorrowDetails storage _borrowDetails = s.s_borrowDetails[_borrowId];
        if (_positionId != _borrowDetails.positionId) revert NOT_BORROW_OWNER();

        ERC20 _token = ERC20(_borrowDetails.token);
        if (_token.allowance(msg.sender, address(this)) < _amount) revert INSUFFICIENT_ALLOWANCE();
        if (_token.balanceOf(msg.sender) < _amount) revert INSUFFICIENT_BALANCE();

        uint256 _totalDebt = _calculateUserDebt(s, _positionId, address(_token), 0);

        if (_amount >= _totalDebt) {
            _amount = _totalDebt;
            _borrowDetails.status = RequestStatus.REPAID;
        }

        s.s_positionBorrowed[_positionId][_borrowDetails.token] = _totalDebt - _amount;
        s.s_positionBorrowedLastUpdate[_positionId][_borrowDetails.token] = block.timestamp;

        _borrowDetails.totalRepayment += _amount;

        (, uint256 _amountValue) = s._getTokenValueInUSD(_borrowDetails.token, _amount);

        if (_amount == _totalDebt) {
            // Unlock all collateral if the loan is fully repaid
            _unlockCollateral(s, _positionId, _borrowId, _getBorrowIdLockedCollateralValue(s, _borrowId));
            _borrowDetails.status = RequestStatus.REPAID;
        } else {
            _unlockCollateral(s, _positionId, _borrowId, _amountValue);
        }
        s._updateVaultRepays(address(_token), _amount);

        bool _success = _token.transferFrom(msg.sender, address(s.i_tokenVault[address(_token)]), _amount);
        if (!_success) revert TRANSFER_FAILED();

        emit Repay(_positionId, address(_token), _amount);
        return _calculateUserDebt(s, _positionId, address(_token), 0);
    }

    function _repayStateChanges(LibAppStorage.StorageLayout storage s, RepayStateChangeParams memory _params)
        internal
    {
        uint256 _totalDebt = _calculateUserDebt(s, _params.positionId, _params.token, 0);
        s.s_positionBorrowed[_params.positionId][_params.token] = _totalDebt - _params.amount;
        s.s_positionBorrowedLastUpdate[_params.positionId][_params.token] = block.timestamp;
        s._updateVaultRepays(_params.token, _params.amount);
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

    function _lockCollateral(
        LibAppStorage.StorageLayout storage s,
        uint256 _positionId,
        uint256 _borrowId,
        uint256 _collateralToLock
    ) internal {
        for (uint256 i = 0; i < s.s_allCollateralTokens.length; i++) {
            address _token = s.s_allCollateralTokens[i];
            uint256 _userLockedCollateral = s.s_positionCollateral[_positionId][_token];

            // Get price per token (not total USD value)
            (uint256 _pricePerToken, uint256 _userLockedCollateralUSD) =
                s._getTokenValueInUSD(_token, _userLockedCollateral);
            uint8 _pricefeedDecimals = s._getPriceDecimals(_token);

            uint256 _amountToUnlockUSD;
            if (_userLockedCollateralUSD >= _collateralToLock) {
                _amountToUnlockUSD = _collateralToLock;
                _collateralToLock = 0;
            } else {
                _amountToUnlockUSD = _userLockedCollateralUSD;
                _collateralToLock -= _userLockedCollateralUSD;
            }

            // Convert USD amount to token amount
            uint256 _amountToLock =
                LibUtils._convertUSDToTokenAmount(_token, _amountToUnlockUSD, _pricePerToken, _pricefeedDecimals);

            // Store the locked amount for each collateral token
            s.s_borrowLockedCollateral[_borrowId][_token] += _amountToLock;
            s.s_positionLockedCollateral[_positionId][_token] += _amountToLock;
            s.s_positionCollateral[_positionId][_token] = _userLockedCollateral - _amountToLock;

            if (_collateralToLock == 0) break;
        }
    }

    function _unlockCollateral(
        LibAppStorage.StorageLayout storage s,
        uint256 _positionId,
        uint256 _borrowId,
        uint256 _collateralToUnlock
    ) internal {
        // uint256 _collateralToLockUSD = _collateralToUnlock;
        for (uint256 i = 0; i < s.s_allCollateralTokens.length; i++) {
            address _token = s.s_allCollateralTokens[i];
            uint256 _userLockedCollateral = s.s_borrowLockedCollateral[_borrowId][_token];

            if (_userLockedCollateral == 0) continue;

            uint8 _decimalToken = LibUtils._getTokenDecimals(_token);

            // Get price per token (not total USD value)
            (uint256 _pricePerToken, uint256 _userLockedCollateralUSD) =
                s._getTokenValueInUSD(_token, _userLockedCollateral);
            uint8 _pricefeedDecimals = s._getPriceDecimals(_token);

            uint256 _amountToUnlockUSD;
            if (_collateralToUnlock <= _userLockedCollateralUSD) {
                _amountToUnlockUSD = _userLockedCollateralUSD;
                _collateralToUnlock = 0;
            } else {
                _amountToUnlockUSD = _userLockedCollateralUSD;
                _collateralToUnlock -= _userLockedCollateralUSD;
            }

            // Convert USD amount to token amount
            uint256 _amountToUnlock = _amountToUnlockUSD * (10 ** _decimalToken)
                / LibUtils._noramlizeToNDecimals(_pricePerToken, _pricefeedDecimals, Constants.PRECISION_SCALE);

            // Store the locked amount for each collateral token
            s.s_borrowLockedCollateral[_borrowId][_token] -= _amountToUnlock;
            s.s_positionLockedCollateral[_positionId][_token] -= _amountToUnlock;
            s.s_positionCollateral[_positionId][_token] = _userLockedCollateral + _amountToUnlock;

            if (_collateralToUnlock == 0) break;
        }
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
            _amount += s.s_positionLockedCollateral[_positionId][_token];
            (, uint256 _usdValue) = s._getTokenValueInUSD(_token, _amount);
            _totalValue += _usdValue;
        }
        return _totalValue;
    }

    function _getPositionCollateralTokenValue(
        LibAppStorage.StorageLayout storage s,
        uint256 _positionId,
        address _token
    ) internal view returns (uint256) {
        uint256 _amount = s.s_positionCollateral[_positionId][_token];
        (, uint256 _usdValue) = s._getTokenValueInUSD(_token, _amount);
        return _usdValue;
    }

    function _getPositionLockedCollateralValue(LibAppStorage.StorageLayout storage s, uint256 _positionId)
        internal
        view
        returns (uint256)
    {
        uint256 _totalValue = 0;
        address[] memory _tokens = s.s_allCollateralTokens;
        for (uint256 i = 0; i < _tokens.length; i++) {
            address _token = _tokens[i];
            uint256 _amount = s.s_positionLockedCollateral[_positionId][_token];
            (, uint256 _usdValue) = s._getTokenValueInUSD(_token, _amount);
            _totalValue += _usdValue;
        }
        return _totalValue;
    }

    function _getBorrowIdLockedCollateralValue(LibAppStorage.StorageLayout storage s, uint256 _borrowId)
        internal
        view
        returns (uint256)
    {
        uint256 _totalValue = 0;
        address[] memory _tokens = s.s_allCollateralTokens;
        for (uint256 i = 0; i < _tokens.length; i++) {
            address _token = _tokens[i];
            uint256 _amount = s.s_borrowLockedCollateral[_borrowId][_token];
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

    /**
     * @notice Calculates the current debt for a specific user including accrued interest
     * @param _positionId The positionId of the user
     * @param _token The token the debt is debt is owed
     * @param _amount The current amount to be borrowed
     * @return debt The current debt amount including interest
     */
    function _calculateUserDebt(
        LibAppStorage.StorageLayout storage s,
        uint256 _positionId,
        address _token,
        uint256 _amount
    ) internal view returns (uint256 debt) {
        uint256 _tokenBorrows = s.s_positionBorrowed[_positionId][_token];

        VaultConfiguration memory _config = s.s_tokenVaultConfig[_token];
        uint256 _from = s.s_positionBorrowedLastUpdate[_positionId][_token];

        uint256 timeElapsed = block.timestamp - _from;
        uint256 utilization = LibInterestRateModel.calculateUtilization(_config.totalBorrows, _config.totalDeposits);
        uint256 interestRate = LibInterestRateModel.calculateInterestRate(_config, utilization);
        uint256 factor = ((interestRate * timeElapsed) * 1e18) / (10000 * 365 days);
        debt = _amount + _tokenBorrows + ((_tokenBorrows * factor) / 1e18);

        return debt;
    }
}
