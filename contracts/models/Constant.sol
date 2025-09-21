// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @dev Holds all the constant for our protocol
library Constants {
    uint256 constant PRECISION = 1E18;
    uint256 constant LIQUIDATION_THRESHOLD = 8000;
    uint256 constant MIN_HEALTH_FACTOR = 1;
    uint256 constant COLLATERALIZATION_RATIO = 8000;
    uint256 constant MAX_UTILIZATION = 8000;
    address constant NATIVE_TOKEN = address(1);

    // Constants to avoid magic numbers
    uint256 constant BASIS_POINTS_SCALE = 1E4; // 100% = 10000 basis points
    uint256 constant PRECISION_SCALE = 18; // High precision for calculations
    uint256 constant MAX_APR_BASIS_POINTS = 1E6; // Maximum 10000% APR
    uint256 constant DEFAULT_COMPOUNDING_PERIODS = 12; // Monthly compounding
    uint256 constant ZERO = 0;
}