// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibPositionManager} from "../libraries/LibPositionManager.sol";

contract PositionManagerFacet {
    function createPositionFor(address _user) external returns (uint256) {
        return LibPositionManager._createPositionFor(LibAppStorage.appStorage(), _user);
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
