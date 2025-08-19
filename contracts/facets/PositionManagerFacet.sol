// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibPositionManager} from "../libraries/LibPositionManager.sol";

import "../models/Error.sol";

contract PositionManagerFacet {
    function createPositionFor(address _user) external returns (uint256) {
        return LibPositionManager._createPositionFor(LibAppStorage.appStorage(), _user);
    }

    function transferPositionOwnership(address _newAddress) external returns (uint256 _positionId) {
        _positionId = LibPositionManager._transferPositionId(LibAppStorage.appStorage(), msg.sender, _newAddress);
    }

    // Getter functions

    function getNextPositionId() external view returns (uint256) {
        return LibPositionManager._getNextPositionId(LibAppStorage.appStorage());
    }

    function getPositionIdForUser(address _user) external view returns (uint256) {
        return LibPositionManager._getPositionIdForUser(LibAppStorage.appStorage(), _user);
    }

    function getUserForPositionId(uint256 _positionId) external view returns (address) {
        return LibPositionManager._getUserForPositionId(LibAppStorage.appStorage(), _positionId);
    }
}
