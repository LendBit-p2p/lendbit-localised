// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IFunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsRouter.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import {TokenVault} from "../TokenVault.sol";

import "../models/Protocol.sol";

library LibAppStorage {
    struct StorageLayout {
        IFunctionsRouter i_router;
        LinkTokenInterface i_linkToken;
        uint256 s_nextPositionId;
        uint256 s_nextBorrowId;
        mapping(uint256 => address) s_positionOwner; // PositionID -> Owner Address
        mapping(address => uint256) s_ownerPosition; // Owner Address -> PositionID
        mapping(bytes32 => uint256) s_requestIdToBorrowId; // Chainlink RequestID -> BorrowID
        mapping(uint256 => BorrowDetails) s_borrowDetails; // BorrowID -> BorrowDetails

        // borrowable token related storage
        address[] s_allSupportedTokens;
        mapping(string => bool) s_supportedLocalCurrencies;
        mapping(address => bool) s_supportedToken;
        mapping(string => address) s_localCurrencyToToken; // currency string -> token address
        mapping(address => address) s_tokenPriceFeed; // token address -> price feed address
        mapping(address => TokenVault) i_tokenVault;
        mapping(address => VaultConfiguration) s_tokenVaultConfig; // token address -> vault config

        // collateral tracking
        mapping(uint256 => mapping(address => uint256)) s_positionCollateral; // PositionID -> (Token Address -> Amount)
        mapping(uint256 => mapping(address => uint256)) s_positionLockedCollateral; // PositionID -> (Token Address -> Amount)
        mapping(uint256 => mapping(address => uint256)) s_borrowLockedCollateral; // BorrowID -> (Token Address -> Amount)
        mapping(address => bool) s_supportedCollateralTokens;
        address[] s_allCollateralTokens; // list of all collateral tokens

        // borrow tracking
        mapping(uint256 => mapping(address => uint256)) s_positionBorrowed; // PositionID -> (token address -> Amount)
        mapping(uint256 => mapping(address => uint256)) s_positionBorrowedLastUpdate; // PositionID -> (token address -> timestamp)
    

        // Chainlink functions variables
        uint32 s_gasLimit;
        uint64 s_subscriptionId;
        bytes32 s_donID;
        bytes32 s_lastRequestId;
        bytes s_lastResponse;
        bytes s_lastError;
        string s_source;
        address s_router;
        mapping(bytes32 _requestId => FunctionResponse) s_functionResponse;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("contracts.storage.LibAppStorage");

    function appStorage() internal pure returns (StorageLayout storage ds) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            ds.slot := slot
        }
    }
}
