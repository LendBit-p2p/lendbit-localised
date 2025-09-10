// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibProtocol} from "../libraries/LibProtocol.sol";

import "../models/Error.sol";

contract ProtocolFacet {
    using LibProtocol for LibAppStorage.StorageLayout;

    /**
     * @notice Deposit collateral tokens to a position
     * @param _token The collateral token address
     * @param _amount The amount to deposit
     */
    function depositCollateral(address _token, uint256 _amount) external {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._depositCollateral(_token, _amount);
    }

    /**
     * @notice Withdraw collateral tokens from a position
     * @param _token The collateral token address
     * @param _amount The amount to withdraw
     */
    function withdrawCollateral(address _token, uint256 _amount) external {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._withdrawCollateral(_token, _amount);
    }

    /**
     * @notice Add a token as accepted collateral (only security council)
     * @param _token The token address to add as collateral
     */
    function addCollateralToken(address _token) external onlySecurityCouncil {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._addCollateralToken(_token);
    }

    /**
     * @notice Remove a token from accepted collateral (only security council)
     * @param _token The token address to remove from collateral
     */
    function removeCollateralToken(address _token) external onlySecurityCouncil {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._removeCollateralToken(_token);
    }

    /**
     * @notice Check if a token is supported as collateral
     * @param _token The token address to check
     * @return bool True if token is supported as collateral
     */
    function isCollateralTokenSupported(address _token) external view returns (bool) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s.s_supportedCollateralTokens[_token];
    }

    /**
     * @notice Get all supported collateral tokens
     * @return address[] Array of all supported collateral token addresses
     */
    function getAllCollateralTokens() external view returns (address[] memory) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s.s_allCollateralTokens;
    }

    /**
     * @notice Get collateral balance for a position and token
     * @param _positionId The position ID
     * @param _token The collateral token address
     * @return uint256 The collateral amount
     */
    function getPositionCollateral(uint256 _positionId, address _token) external view returns (uint256) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s.s_positionCollateral[_positionId][_token];
    }

    // Modifiers
    modifier onlySecurityCouncil() {
        if (msg.sender != LibDiamond.contractOwner()) revert ONLY_SECURITY_COUNCIL();
        _;
    }
}
