// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

/// @title IBlockpostServiceManager
/// @notice AVS allowing users to request a message to be stored on-chain
interface IBlockpostServiceManager {
    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new request to store a message is made by a users
    /// @param id The unique ID of the message to be stored
    /// @param req Struct to encapsulate the request to store a new message
    event MessageRequestCreated(uint32 indexed id, Request req);

    /// @notice Emitted when a message request is validated by the operators
    /// @param id The unique ID where the message is stored
    /// @param req Struct to encapsulate the request to store the message
    /// @param operator The address of the EigenLayer operator that validated the request
    event MessageStored(uint32 indexed id, Request req, address operator);

    /*//////////////////////////////////////////////////////////////////////////
                                    ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an operator does not have the minimum stake weight
    error OperatorDoesntHaveMinimumWeight();

    /// @notice Thrown when an operator tries to resolve an unexistent request
    error InvalidRequest();

    /// @notice Thrown when an operator tries to resolve an already resolved request
    error RequestAlreadyResolved();

    /// @notice Thrown when the operator signature is not valid
    error InvalidOperatorSignature();

    /*//////////////////////////////////////////////////////////////////////////
                                CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Retrieves the hash of the message storage request
    /// @param id The unique ID of the message requested to be stored
    function requestHashes(uint32 id) external view returns (bytes32 hash);

    /// @notice Retrieves the stored message with the `id` id
    /// @param id The unique ID of the message to be retrieved
    function messages(uint32 id) external view returns (string memory message);

    /// @notice Struct encapsulating the request to store a message
    /// @param message The content of the message
    /// @param blockNumber The number of the block when the request was created
    struct Request {
        string message;
        uint32 blocknumber;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Creates a new request to store the `message` message
    /// @param message The message to be stored
    function createNewRequest(string memory message) external;

    /// @notice Responds to a message storage request
    ///
    /// Notes:
    /// - called by operators to respond to a request and validate a message storage request
    ///
    /// @param req Struct encapsulating the message storage request being validated
    /// @param messageId The unique ID of the message that is to be stored
    /// @param signature The
    function respondToRequest(Request calldata req, uint32 messageId, bytes calldata signature) external;
}
