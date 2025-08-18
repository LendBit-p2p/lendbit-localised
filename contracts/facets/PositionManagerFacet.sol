// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibPositionManager} from "../libraries/LibPositionManager.sol";

contract PositionManagerFacet {
    function createPositionFor(address _user) external returns (uint256) {
        return LibPositionManager._createPositionFor(LibAppStorage.appStorage(), _user);
    }
}