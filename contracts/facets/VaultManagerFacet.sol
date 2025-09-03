// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibVaultManager} from "../libraries/LibVaultManager.sol";

import "../models/Error.sol";

contract VaultManagerFacet {
    using LibVaultManager for LibAppStorage.StorageLayout;

    function deployVault(address _token, string calldata _name, string calldata _symbol)
        external
        onlySecurityCouncil
        returns (address)
    {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._deployVault(_token, _name, _symbol);
    }

    function pauseTokenSupport(address _token) external onlySecurityCouncil {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._pauseTokenSupport(_token);
    }

    function resumeTokenSupport(address _token) external onlySecurityCouncil {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._resumeTokenSupport(_token);
    }

    function tokenIsSupported(address _token) external view returns (bool) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._tokenIsSupported(_token);
    }

    function getTokenVault(address _token) external view returns (address) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._getTokenVault(_token);
    }

    modifier onlySecurityCouncil() {
        if (msg.sender != LibDiamond.contractOwner()) revert ONLY_SECURITY_COUNCIL();
        _;
    }
}
