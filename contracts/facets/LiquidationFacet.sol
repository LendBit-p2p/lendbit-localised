// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibLiquidation} from "../libraries/LibLiquidation.sol";

contract LiquidationFacet {
    using LibLiquidation for LibAppStorage.StorageLayout;

    function isLiquidatable(uint256 _positionId) external view returns (bool) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        return s._isLiquidatable(_positionId);
    }

    function liquidatePosition(uint256 _positionId, uint256 _amount, address _token, address _collateralToken)
        external
    {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._liquidatePosition(_positionId, _amount, _token, _collateralToken);
    }
}
