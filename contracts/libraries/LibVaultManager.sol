// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibAppStorage} from "./LibAppStorage.sol";
import {LibDiamond} from "./LibDiamond.sol";
import "../models/Error.sol";
import "../models/Event.sol";

import {TokenVault} from "../TokenVault.sol";

library LibVaultManager {
    function _deployVault(
        LibAppStorage.StorageLayout storage s,
        address _token,
        string memory _name,
        string memory _symbol
    ) internal returns (address) {
        if (_token == address(0)) revert ADDRESS_ZERO();
        if (address(s.i_tokenVault[_token]) != address(0)) {
            revert TOKEN_ALREADY_SUPPORTED(_token, address(s.i_tokenVault[_token]));
        }

        TokenVault _tokenVault = new TokenVault(_token, _name, _symbol, address(this));
        s.s_supportedToken[_token] = true;
        s.i_tokenVault[_token] = _tokenVault;

        emit TokenAdded(_token, address(_tokenVault));
        emit TokenSupportChanged(_token, true);
        return address(_tokenVault);
    }

    function _pauseTokenSupport(LibAppStorage.StorageLayout storage s, address _token) internal {
        if (_token == address(0)) revert ADDRESS_ZERO();
        if (!s.s_supportedToken[_token]) revert TOKEN_NOT_SUPPORTED(_token);
        s.s_supportedToken[_token] = false;
        emit TokenSupportChanged(_token, false);
    }

    function _resumeTokenSupport(LibAppStorage.StorageLayout storage s, address _token) internal {
        if (_token == address(0)) revert ADDRESS_ZERO();
        if (address(s.i_tokenVault[_token]) == address(0)) revert TOKEN_NOT_SUPPORTED(_token);
        if (s.s_supportedToken[_token]) return;
        s.s_supportedToken[_token] = true;
        emit TokenSupportChanged(_token, true);
    }

    function _tokenIsSupported(LibAppStorage.StorageLayout storage s, address _token) internal view returns (bool) {
        return s.s_supportedToken[_token];
    }

    function _getTokenVault(LibAppStorage.StorageLayout storage s, address _token) internal view returns (address) {
        return address(s.i_tokenVault[_token]);
    }
}
