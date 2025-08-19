// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

event PositionIdCreated(uint256 indexed positionId, address indexed user);
event PositionIdTransferred(uint256 indexed positionId, address indexed oldAddress, address indexed newAddress);
event SecurityCouncilSet(address _newCouncil);