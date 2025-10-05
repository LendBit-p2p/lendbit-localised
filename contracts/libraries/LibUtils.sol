// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Constants} from "../models/Constant.sol";

library LibUtils {
    function _normalizeTokenAmount(address _token, uint256 _amount) internal view returns (uint256) {
        uint8 _decimals = LibUtils._getTokenDecimals(_token);
        return _noramlizeToNDecimals(_amount, _decimals, 18);
    }

    function _noramlizeToNDecimals(uint256 _amount, uint8 _amountDecimal, uint8 _newDecimal)
        internal
        pure
        returns (uint256)
    {
        if (_amountDecimal <= _newDecimal) {
            return _amount * (10 ** (_newDecimal - _amountDecimal));
        } else {
            return _amount / (10 ** (_amountDecimal - _newDecimal));
        }
    }

    function _convertUSDToTokenAmount(
        address _token,
        uint256 _amountInUSD,
        uint256 _pricePerToken,
        uint8 _pricefeedDecimals
    ) internal view returns (uint256) {
        uint8 _decimals = _getTokenDecimals(_token);
        return _amountInUSD * (10 ** _decimals)
            / LibUtils._noramlizeToNDecimals(_pricePerToken, _pricefeedDecimals, Constants.PRECISION_SCALE);
    }

    function _getTokenDecimals(address _token) internal view returns (uint8) {
        return ERC20(_token).decimals();
    }
}
