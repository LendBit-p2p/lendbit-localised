pragma solidity ^0.8.9;
import {LibLenbitVaultManager} from "../libraries/LibLendbitVaultManager.sol";
import (LibAppStorage) from "../libraries/LibAppStorage";

 

// this contract is to hold
contract LendbitVault {
    using LibLenbitVaultManager for  LibAppStorage.Layout;

    // This is a placeholder contract for the LendbitVault.
    // The actual implementation would go here.

    function depositCollateral(address _tokenCollateralAddress,
        uint256 _amountOfCollateral, _user)external {
         LibLenbitVaultManager._deposit(LibAppStorage.appStorage(),msg.sender, _tokenCollateralAddress, _amountOfCollateral);
    }

    function withdrawnCollateral(address _to, address _token, uint256 _amount) external {
            LibLenbitVaultManager._withdraw(LibAppStorage.appStorage(),_to, _token, _amount);
    }



}


