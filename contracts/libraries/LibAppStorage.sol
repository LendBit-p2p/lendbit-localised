// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IFunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsRouter.sol";
import "../models/Protocol.sol";

library LibAppStorage {
    struct StorageLayout {
        IFunctionsRouter i_router;
        uint256 s_nextPositionId;
        mapping(uint256 => address) s_positionOwner; // PositionID -> Owner Address
        mapping(address => uint256) s_ownerPosition; // Owner Address -> PositionID
        // Chainlink functions variables
        uint32 s_gasLimit;
        bytes32 s_donID;
        bytes32 s_lastRequestId;
        bytes s_lastResponse;
        bytes s_lastError;
        string s_source;
        address s_router;
        mapping(bytes32 _requestId => FunctionResponse) s_functionResponse;
    }
    // JavaScript source code
    // Fetch character name from the Star Wars API.
    // Documentation: https://swapi.info/people
    // string s_source = "const characterId = args[0];" "const apiResponse = await Functions.makeHttpRequest({"
    //     "url: `https://swapi.info/api/people/${characterId}/`" "});" "if (apiResponse.error) {"
    //     "throw Error('Request failed');" "}" "const { data } = apiResponse;" "return Functions.encodeString(data.name);";

    bytes32 internal constant STORAGE_SLOT = keccak256("contracts.storage.LibAppStorage");

    function appStorage() internal pure returns (StorageLayout storage ds) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            ds.slot := slot
        }
    }
}
