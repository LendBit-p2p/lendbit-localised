// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @notice Interface for Vault Manager
 */
interface IVaultManager {
    function notifyVaultDeposit(address asset, uint256 amount, address depositor, bool transferAssets) external;
    function notifyVaultWithdrawal(address asset, uint256 amount, address receiver, bool transferAssets) external;
    function notifyVaultTransfer(address asset, uint256 amount, address sender, address receiver)
        external
        returns (bool);
    function getVaultExchangeRate(address asset) external view returns (uint256);
    function getVaultTotalAssets(address asset) external view returns (uint256);
}
