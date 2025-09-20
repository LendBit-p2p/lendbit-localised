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
error TOKEN_ALREADY_SUPPORTED_AS_COLLATERAL(address _asset);
error TOKEN_NOT_SUPPORTED_AS_COLLATERAL(address _asset);

error AMOUNT_ZERO();
error TRANSFER_FAILED();
error INSUFFICIENT_ALLOWANCE();
error INSUFFICIENT_BALANCE();

error EMPTY_STRING();
error CURRENCY_ALREADY_SUPPORTED(string _currency);
error CURRENCY_NOT_SUPPORTED(string _currency);

error STALE_PRICE_FEED(address _priceFeed);
error INVALID_PRICE_FEED(address _priceFeed);

// chainlink functions error
error OnlyRouterCanFulfill();
error UnexpectedRequestID(bytes32 requestId);
