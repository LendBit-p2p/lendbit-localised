// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibPriceOracle} from "../libraries/LibPriceOracle.sol";
import {LibProtocol} from "../libraries/LibProtocol.sol";
import {LibUtils} from "../libraries/LibUtils.sol";

import {Constants} from "../models/Constant.sol";
import "../models/Error.sol";
import "../models/Event.sol";
import "../models/Protocol.sol";
import {RepayStateChangeParams} from "../models/FunctionParams.sol";

library LibLiquidation {
    using LibPriceOracle for LibAppStorage.StorageLayout;
    using LibProtocol for LibAppStorage.StorageLayout;

    function _isLiquidatable(LibAppStorage.StorageLayout storage s, uint256 _positionId) internal view returns (bool) {
        uint256 _healthFactor = s._getHealthFactor(_positionId, 0);
        return _healthFactor < 1e18;
    }

    function _liquidatePosition(
        LibAppStorage.StorageLayout storage s,
        uint256 _positionId,
        uint256 _amount,
        address _token,
        address _collateralToken
    ) internal {
        if (!_isLiquidatable(s, _positionId)) revert NOT_LIQUIDATABLE();
        if (s.s_positionBorrowed[_positionId][_token] == 0) revert NO_ACTIVE_BORROW_FOR_TOKEN(_positionId, _token);

        uint256 _collateralAmount = s.s_positionCollateral[_positionId][_collateralToken];
        if (_collateralAmount == 0) revert NO_COLLATERAL_FOR_TOKEN(_positionId, _collateralToken);

        ERC20 _tokenI = ERC20(_token);
        LibProtocol._allowanceAndBalanceCheck(_token, _amount);

        (uint256 _collateralPricePerToken, uint256 _collateralValue) =
            s._getTokenValueInUSD(_collateralToken, _collateralAmount);
        (uint256 _liquidationTokenprice, uint256 _amountValue) = s._getTokenValueInUSD(_token, _amount);

        if (_collateralValue < _amountValue) {
            _amountValue = _collateralValue;
            _amount = LibUtils._convertUSDToTokenAmount(
                _token, _amountValue, _liquidationTokenprice, s._getPriceDecimals(_token)
            );
        }

        uint8 _pricefeedDecimals = s._getPriceDecimals(_collateralToken);
        uint256 _amountToLiquidate = LibUtils._convertUSDToTokenAmount(
            _collateralToken, _collateralValue, _collateralPricePerToken, _pricefeedDecimals
        );

        s.s_positionCollateral[_positionId][_collateralToken] -= _amountToLiquidate;

        RepayStateChangeParams memory _params = RepayStateChangeParams({
            positionId: _positionId,
            token: _token,
            amount: (
                _amount
                    * (
                        (Constants.BASIS_POINTS_SCALE - s.s_tokenVaultConfig[_token].liquidationBonus)
                            / Constants.BASIS_POINTS_SCALE
                    )
            )
        });
        s._repayStateChanges(_params);

        bool _success = _tokenI.transferFrom(msg.sender, address(s.i_tokenVault[_token]), _amount);
        if (!_success) revert TRANSFER_FAILED();

        LibProtocol._transferToken(_collateralToken, msg.sender, _amountToLiquidate);
        // _success = ERC20(_collateralToken).transfer(msg.sender, _amountToLiquidate);
        // if (!_success) revert TRANSFER_FAILED();

        emit PositionLiquidated(_positionId, msg.sender, _collateralToken, _amountToLiquidate);
        emit Repay(_positionId, _token, _amount);
    }
}
