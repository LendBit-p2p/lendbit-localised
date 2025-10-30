// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

struct VaultConfiguration {
    uint16 reserveFactor; // in basis points
    uint16 optimalUtilization; // in basis points
    uint16 baseRate; // in basis points
    uint16 slopeRate; // in basis points
    uint16 liquidationBonus; // in basis points
    uint256 totalDeposits;
    uint256 totalBorrows;
    uint256 lastUpdated; // timestamp
}

enum RequestStatus {
    NONE,
    PENDING,
    FULFILLED,
    REJECTED,
    REPAID,
    LIQUIDATED
}

struct FunctionResponse {
    bool exists;
    bytes32 requestId;
    bytes responses;
    bytes err;
    uint256 priceData;
}
