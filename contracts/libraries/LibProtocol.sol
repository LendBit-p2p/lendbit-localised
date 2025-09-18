// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LibAppStorage} from "./LibAppStorage.sol";
import {LibPositionManager} from "./LibPositionManager.sol";
import {LibPriceOracle} from "./LibPriceOracle.sol";

import "../models/Error.sol";
import "../models/Event.sol";
import "../models/Protocol.sol";

library LibProtocol {
    using LibPositionManager for LibAppStorage.StorageLayout;
    using LibPriceOracle for LibAppStorage.StorageLayout;

    function _depositCollateral(LibAppStorage.StorageLayout storage s, address _token, uint256 _amount) internal {
        uint256 _positionId = s._getPositionIdForUser(msg.sender);

        if (_positionId == 0) {
            _positionId = s._createPositionFor(msg.sender);
        }
        _allowanceAndBalanceCheck(_token, _amount);

        s.s_positionCollateral[_positionId][_token] += _amount;
        bool _success = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        if (!_success) revert TRANSFER_FAILED();
        emit CollateralDeposited(_positionId, _token, _amount);
    }

    function _withdrawCollateral(LibAppStorage.StorageLayout storage s, address _token, uint256 _amount) internal {
        uint256 _positionId = _positionIdCheck(s);
        if (s.s_positionCollateral[_positionId][_token] < _amount) revert INSUFFICIENT_BALANCE();

        s.s_positionCollateral[_positionId][_token] -= _amount;
        bool _success = IERC20(_token).transfer(msg.sender, _amount);
        if (!_success) revert TRANSFER_FAILED();
        emit CollateralWithdrawn(_positionId, _token, _amount);
    }

    function _borrowCurrency(LibAppStorage.StorageLayout storage s, string calldata _currency, uint256 _amount) internal {
        uint256 _positionId = _positionIdCheck(s);
        if (!s.s_supportedLocalCurrencies[_currency]) revert CURRENCY_NOT_SUPPORTED(_currency);

        s.s_nextBorrowId++;
        uint256 _borrowId = s.s_nextBorrowId;

        // borrowing logic to be implemented
        BorrowDetails memory borrowDetails = BorrowDetails({
            positionId: _positionId,
            currency: _currency,
            amount: _amount,
            startTime: block.timestamp,
            status: RequestStatus.NONE
        });

        s.s_borrowDetails[_borrowId] = borrowDetails;

    }

    function _allowanceAndBalanceCheck(address _token, uint256 _amount) internal view {
        if (_token == address(0)) revert ADDRESS_ZERO();
        if (_amount == 0) revert AMOUNT_ZERO();
        if (!LibAppStorage.appStorage().s_supportedCollateralTokens[_token]) revert TOKEN_NOT_SUPPORTED(_token);
        if (IERC20(_token).allowance(msg.sender, address(this)) < _amount) revert INSUFFICIENT_ALLOWANCE();
        if (IERC20(_token).balanceOf(msg.sender) < _amount) revert INSUFFICIENT_BALANCE();
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
        if (keccak256(abi.encode(_currency)) == keccak256("")) revert EMPTY_STRING();
        if (s.s_supportedLocalCurrencies[_currency]) revert CURRENCY_ALREADY_SUPPORTED(_currency);

        s.s_supportedLocalCurrencies[_currency] = true;

        emit LocalCurrencyAdded(_currency);
    }

    function _removeLocalCurrencySupport(LibAppStorage.StorageLayout storage s, string calldata _currency) internal {
        if (keccak256(abi.encode(_currency)) == keccak256("")) revert EMPTY_STRING();
        if (!s.s_supportedLocalCurrencies[_currency]) revert CURRENCY_NOT_SUPPORTED(_currency);

        s.s_supportedLocalCurrencies[_currency] = false;

        emit LocalCurrencyRemoved(_currency);
    }
}
