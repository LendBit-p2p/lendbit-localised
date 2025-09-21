// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

struct UserDetails {
    uint256 positionId;
    address walletAddress;
    KYCTier kycTier;
}

enum KYCTier {
    NONE,
    TIER_1,
    TIER_2,
    TIER_3
}

struct VaultConfiguration {
    uint256 totalDeposits;
    uint256 totalBorrows;
    uint256 interestRate; // in basis points
    uint256 utilizationRate; // in basis points
    uint256 lastUpdated; // timestamp
}

enum RequestStatus {
    NONE,
    PENDING,
    FULFILLED,
    REJECTED,
    REPAID
}

struct BorrowDetails {
    uint256 positionId;
    string currency;
    uint256 amount;
    uint256 startTime; // timestamp
    RequestStatus status;
}

struct FunctionResponse {
    bool exists;
    bytes32 requestId;
    bytes responses;
    bytes err;
    uint256 priceData;
}
