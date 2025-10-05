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
        if (!LibAppStorage.appStorage().s_supportedCollateralTokens[_token]) revert TOKEN_NOT_SUPPORTED(_token);
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
        uint256 _healthFactor = _getHealthFactor(s, _positionId, 0);

        uint256 _borrowValue = _getPositionBorrowedValue(s, _positionId);
        if (_borrowValue > 0) {
            if (_healthFactor < Constants.MIN_HEALTH_FACTOR) revert HEALTH_FACTOR_TOO_LOW(_healthFactor);
        }

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

        (, uint256 _currentBorrowValue) = s._getTokenValueInUSD(_token, _amount);
        uint256 _healthFactor = _getHealthFactor(s, _positionId, _currentBorrowValue);

        if (_healthFactor < Constants.MIN_HEALTH_FACTOR) revert HEALTH_FACTOR_TOO_LOW(_healthFactor);

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
        return s.s_positionBorrowed[_positionId][_token];
    }

    function _repay(LibAppStorage.StorageLayout storage s, address _token, uint256 _amount)
        internal
        returns (uint256)
    {
        uint256 _positionId = _positionIdCheck(s);

        uint256 _debt = s.s_positionBorrowed[_positionId][_token];
        if (_debt == 0) revert NO_OUTSTANDING_DEBT(_positionId, _token);

        _allowanceAndBalanceCheck(_token, _amount);

        if (_amount > _debt) {
            _amount = _debt;
        }

        RepayStateChangeParams memory _params =
            RepayStateChangeParams({positionId: _positionId, token: _token, amount: _amount});
        _repayStateChanges(s, _params);
        s._updateVaultRepays(address(_token), _amount);

        bool _success = ERC20(_token).transferFrom(msg.sender, address(s.i_tokenVault[_token]), _amount);
        if (!_success) revert TRANSFER_FAILED();

        emit Repay(_positionId, _token, _amount);
        return _calculateUserDebt(s, _positionId, _token, 0);
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

    function _getPositionCollateralTokenValue(
        LibAppStorage.StorageLayout storage s,
        uint256 _positionId,
        address _token
    ) internal view returns (uint256) {
        uint256 _amount = s.s_positionCollateral[_positionId][_token];
        (, uint256 _usdValue) = s._getTokenValueInUSD(_token, _amount);
        return _usdValue;
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
            uint256 _amount = _calculateUserDebt(s, _positionId, _token, 0);
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
