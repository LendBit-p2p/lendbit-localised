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

struct FunctionResponse {
    bool exists;
    bytes32 requestId;
    bytes responses;
    bytes err;
    string character;
}
