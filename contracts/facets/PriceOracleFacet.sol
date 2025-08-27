// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibPriceOracle} from "../libraries/LibPriceOracle.sol";

contract PriceOracleFacet {
    using FunctionsRequest for FunctionsRequest.Request;
    using LibPriceOracle for LibAppStorage.StorageLayout;

    /**
     * @notice setup the Chainlink router address and sets the DON ID
     * @param _donID The ID of the Decentralized Oracle Network (DON)
     * @param _router The address of the Chainlink Functions router contract
     */
    function setupRouter(bytes32 _donID, address _router) external {
        LibDiamond.enforceIsContractOwner();
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._setupRouter(_donID, _router);
    }

    function setupSource(string calldata _source) external {
        LibDiamond.enforceIsContractOwner();
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._setupSource(_source);
    }

    /**
     * @notice Sends an HTTP request for character information
     * @param subscriptionId The ID for the Chainlink subscription
     * @param args The arguments to pass to the HTTP request
     * @return requestId The ID of the request
     */
    function sendRequest(uint64 subscriptionId, string[] calldata args) external returns (bytes32 requestId) {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s.s_source); // Initialize the request with JS code
        if (args.length > 0) req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        bytes32 s_lastRequestId = s._sendRequest(req.encodeCBOR(), subscriptionId, s.s_gasLimit, s.s_donID);

        return s_lastRequestId;
    }

    /**
     * @notice Callback function for fulfilling a request
     * @param _requestId The ID of the request to fulfill
     * @param _response The HTTP response data
     * @param _err Any errors from the Functions request
     */
    function handleOracleFulfillment(bytes32 _requestId, bytes memory _response, bytes memory _err) internal {
        LibAppStorage.StorageLayout storage s = LibAppStorage.appStorage();
        s._handleOracleFulfillment(_requestId, _response, _err);
    }
}
