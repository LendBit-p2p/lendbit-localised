// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibVaultManager} from "../libraries/LibVaultManager.sol";

import {VaultConfiguration} from "../models/Protocol.sol";
import "../models/Error.sol";

contract VaultManagerFacet {
    using LibVaultManager for LibAppStorage.StorageLayout;

    function deposit(address _token, uint256 _amount) external returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._deposit(msg.sender, _token, _amount);
    }

    function withdraw(address _token, uint256 _amount) external {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._withdraw(msg.sender, _token, _amount);
    }

    function deployVault(
        address _token,
        address _pricefeed,
        string calldata _name,
        string calldata _symbol,
        VaultConfiguration calldata _config
    ) external onlySecurityCouncil returns (address) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._deployVault(_token, _pricefeed, _name, _symbol, _config);
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

    function getVaultTotalAssets(address asset) external view returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._getVaultTotalAssets(asset);
    }

    modifier onlySecurityCouncil() {
        if (msg.sender != LibDiamond.contractOwner()) revert ONLY_SECURITY_COUNCIL();
        _;
    }
}
