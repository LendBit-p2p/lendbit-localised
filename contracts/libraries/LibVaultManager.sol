// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LibAppStorage} from "./LibAppStorage.sol";
import {LibDiamond} from "./LibDiamond.sol";
import "../models/Error.sol";
import "../models/Event.sol";

import {LibPositionManager} from "./LibPositionManager.sol";

import {TokenVault} from "../TokenVault.sol";

library LibVaultManager {
    using LibPositionManager for LibAppStorage.StorageLayout;

    // function _deposit(LibAppStorage.StorageLayout storage s, address _from, address _token, uint256 _amount) internal {
    //     if (_token == address(0)) revert ADDRESS_ZERO();
    //     if (_amount == 0) revert AMOUNT_ZERO();
    //     if (!s.s_supportedToken[_token]) revert TOKEN_NOT_SUPPORTED(_token);
    //     uint256 _positionId = s._getPositionIdForUser(_from);
    //     if (_positionId == 0) {
    //         _positionId = s._createPositionFor(_from);
    //     }
    //     TokenVault _tokenVault = s.i_tokenVault[_token];
    //     if (address(_tokenVault) == address(0)) revert TOKEN_NOT_SUPPORTED(_token);

    //     IERC20(_token).transferFrom(_from, address(this), _amount);

    //     _tokenVault.protocolDeposit(_amount, _from);

    //     emit Deposit(_positionId, _token, _amount);
    // }

    // function _withdraw(LibAppStorage.StorageLayout storage s, address _to, address _token, uint256 _amount) internal {
    //     if (_token == address(0)) revert ADDRESS_ZERO();
    //     if (_amount == 0) revert AMOUNT_ZERO();
    //     if (!s.s_supportedToken[_token]) revert TOKEN_NOT_SUPPORTED(_token);
        
    //     uint256 _positionId = s._getPositionIdForUser(_to);
    //     if (_positionId == 0) revert NO_POSITION_ID(_to);
    
    //     TokenVault _tokenVault = s.i_tokenVault[_token];
    //     if (address(_tokenVault) == address(0)) revert TOKEN_NOT_SUPPORTED(_token);

    //     _tokenVault.withdraw(_amount, _to, msg.sender);
    //     bool success = IERC20(_token).transfer(_to, _amount);
        
    //     if (!success) revert TRANSFER_FAILED();

    //     emit Withdrawal(_positionId, _token, _amount);
    // }

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
        s.s_allSupportedTokens.push(_token);
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

    function _getVaultTotalAssets(LibAppStorage.StorageLayout storage s, address asset) internal view returns (uint256) {
        TokenVault _tokenVault = s.i_tokenVault[asset];
        if (address(_tokenVault) == address(0)) revert TOKEN_NOT_SUPPORTED(asset);
        return IERC20(asset).balanceOf(address(this));
    }
}
