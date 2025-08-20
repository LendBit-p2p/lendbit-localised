// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibAppStorage} from "./LibAppStorage.sol";
import {LibDiamond} from "./LibDiamond.sol";
import "../models/Error.sol";
import "../models/Event.sol";

library LibPositionManager {
    function _createPositionFor(LibAppStorage.StorageLayout storage s, address _user) internal returns (uint256) {
        if (_userAddressExists(s, _user)) revert ADDRESS_EXISTS(_user);
        uint256 _positionId = s._nextPositionId + 1;
        s._nextPositionId += 1;

        s._positionOwner[_positionId] = _user;
        s._ownerPosition[_user] = _positionId;

        emit PositionIdCreated(_positionId, _user);
        return _positionId;
    }

    function _transferPositionId(LibAppStorage.StorageLayout storage s, address _oldAddress, address _newAddress)
        internal
        returns (uint256 _positionId)
    {
        _positionId = _validateUserExists(s, _oldAddress);

        s._ownerPosition[_newAddress] = _positionId;
        s._positionOwner[_positionId] = _newAddress;

        delete s._ownerPosition[_oldAddress];

        emit PositionIdTransferred(_positionId, _oldAddress, _newAddress);
    }

    function _userAddressExists(LibAppStorage.StorageLayout storage s, address _user) internal view returns (bool) {
        if (s._ownerPosition[_user] == 0) {
            return false;
        }
        return true;
    }

    function _getNextPositionId(LibAppStorage.StorageLayout storage s) internal view returns (uint256) {
        return s._nextPositionId + 1;
    }

    function _getPositionIdForUser(LibAppStorage.StorageLayout storage s, address _user)
        internal
        view
        returns (uint256)
    {
        return s._ownerPosition[_user];
    }

    function _getUserForPositionId(LibAppStorage.StorageLayout storage s, uint256 _positionId)
        internal
        view
        returns (address)
    {
        return s._positionOwner[_positionId];
    }

    // Validators
    function _validateUserExists(LibAppStorage.StorageLayout storage s, address _user)
        internal
        view
        returns (uint256 _positionId)
    {
        _positionId = _getPositionIdForUser(s, _user);
        if (_positionId == 0) {
            revert NO_POSITION_ID(_user);
        }
    }
}
