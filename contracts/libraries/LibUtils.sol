// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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

    function _getTokenDecimals(address _token) internal view returns (uint8) {
        return ERC20(_token).decimals();
    }
}
