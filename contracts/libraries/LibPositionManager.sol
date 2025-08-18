// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibAppStorage} from "./LibAppStorage.sol";
import "../models/Error.sol";

library LibPositionManager {
    function _createPositionFor(LibAppStorage.StorageLayout storage s, address _user) internal returns (uint256) {
        if (_userAddressExists(s, _user)) revert ADDRESS_EXISTS(_user);
        uint256 _positionId = s._nextPositionId + 1;
        s._nextPositionId += 1;

        s._positionOwner[_positionId] = _user;
        s._ownerPosition[_user] = _positionId;

        return _positionId;
    }

    function _userAddressExists(LibAppStorage.StorageLayout storage s, address _user) internal view returns (bool) {
        if (s._ownerPosition[_user] == 0) {
            return false;
        }
        return true;
    }
}
