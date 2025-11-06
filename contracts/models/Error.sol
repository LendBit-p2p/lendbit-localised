// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

error ADDRESS_ZERO();
error ADDRESS_EXISTS(address userAddress);
error NO_POSITION_ID(address userAddress);
error NO_ACCESS_TO_POSITION_ID(address caller);
error POSITION_ID_MISMATCH(uint256 expected, uint256 given);
error ONLY_SECURITY_COUNCIL();
error SUBSCRIPTION_ID_NOT_SET();

error TOKEN_NOT_SUPPORTED(address asset);
error TOKEN_ALREADY_SUPPORTED(address asset, address assetVault);
error TOKEN_ALREADY_SUPPORTED_AS_COLLATERAL(address asset);
error TOKEN_NOT_SUPPORTED_AS_COLLATERAL(address asset);

error AMOUNT_ZERO();
error AMOUNT_MISMATCH(uint256 amount1, uint256 amount2);
error TRANSFER_FAILED();
error INSUFFICIENT_ALLOWANCE();
error INSUFFICIENT_BALANCE();
error HEALTH_FACTOR_TOO_LOW(uint256 healthFactor);
error NOT_LIQUIDATABLE();
error NO_ACTIVE_BORROW_FOR_TOKEN(uint256 positionId, address token);
error NO_COLLATERAL_FOR_TOKEN(uint256 positionId, address token);

error LTV_BELOW_TEN_PERCENT();
error TOKEN_OVERUTILIZATION();
error NO_OUTSTANDING_DEBT(uint256 positionId, address token);
error INACTIVE_LOAN();

error EMPTY_STRING();
error CURRENCY_ALREADY_SUPPORTED(string currency);
error CURRENCY_NOT_SUPPORTED(string currency);

error STALE_PRICE_FEED(address priceFeed);
error INVALID_PRICE_FEED(address priceFeed);

// chainlink functions error
error OnlyRouterCanFulfill();
error UnexpectedRequestID(bytes32 requestId);
