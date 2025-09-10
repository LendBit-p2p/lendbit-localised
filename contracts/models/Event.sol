// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

event PositionIdCreated(uint256 indexed positionId, address indexed user);

event PositionIdTransferred(uint256 indexed positionId, address indexed oldAddress, address indexed newAddress);

event SecurityCouncilSet(address _newCouncil);

event TokenAdded(address indexed asset, address indexed assetVault);

event TokenSupportChanged(address indexed asset, bool isSupported);

// Vault Events
event Deposit(uint256 indexed positionId, address indexed asset, uint256 amount);
event Withdrawal(uint256 indexed positionId, address indexed asset, uint256 amount);

event CollateralDeposited(uint256 indexed positionId, address indexed token, uint256 amount);
event CollateralWithdrawn(uint256 indexed positionId, address indexed token, uint256 amount);

event CollateralTokenAdded(address indexed token);
event CollateralTokenRemoved(address indexed token);

// Chainlink functions events
event RequestSent(bytes32 indexed id);

event RequestFulfilled(bytes32 indexed id);

event Response(bytes32 indexed requestId, uint256 priceData, bytes response, bytes err);

event FunctionsRouterChanged(address indexed securityCouncil, bytes32 donId, address router);

event FunctionsSourceChanged(address indexed securityCouncil, bytes source);
