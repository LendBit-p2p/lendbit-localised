// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../models/Protocol.sol";


library LibAppStorage {
    struct StorageLayout {
        uint256 _nextPositionId;
        address _securityCouncil;

        mapping(uint256 => address) _positionOwner; // PositionID -> Owner Address
        mapping(address => uint256) _ownerPosition;   // Owner Address -> PositionID
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("contracts.storage.LibAppStorage");

    function appStorage() internal pure returns (StorageLayout storage ds) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            ds.slot := slot
        }
    }
}