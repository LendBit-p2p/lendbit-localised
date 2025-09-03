// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

error ADDRESS_ZERO();
error ADDRESS_EXISTS(address _address);
error NO_POSITION_ID(address _address);
error NO_ACCESS_TO_POSITION_ID(address _caller);
error ONLY_SECURITY_COUNCIL();
error SUBSCRIPTION_ID_NOT_SET();

error TOKEN_NOT_SUPPORTED(address _asset);
error TOKEN_ALREADY_SUPPORTED(address _asset, address _assetVault);

// chainlink functions error
error OnlyRouterCanFulfill();
error UnexpectedRequestID(bytes32 requestId);
