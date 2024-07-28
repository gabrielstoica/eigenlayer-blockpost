// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import { BytesLib } from "@eigenlayer/contracts/libraries/BytesLib.sol";
import { ECDSAServiceManagerBase } from "@eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";
import { ECDSAStakeRegistry } from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import { ECDSAUpgradeable } from "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import { Pausable } from "@eigenlayer/contracts/permissions/Pausable.sol";
import { IBlockpostServiceManager } from "./IBlockpostServiceManager.sol";

/// @title BlockpostServiceManager
/// @notice See the documentation in {IBlockpostServiceManager}
contract BlockpostServiceManager is ECDSAServiceManagerBase, IBlockpostServiceManager, Pausable {
    using BytesLib for bytes;
    using ECDSAUpgradeable for bytes32;

    /*//////////////////////////////////////////////////////////////////////////
                                PUBLIC STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBlockpostServiceManager
    mapping(uint32 => bytes32) public override requestHashes;

    /// @inheritdoc IBlockpostServiceManager
    mapping(uint32 => string) public override messages;

    /*//////////////////////////////////////////////////////////////////////////
                                PRIVATE STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Counter to get unique IDs for stored messages
    uint32 private _messageIndex;

    /*//////////////////////////////////////////////////////////////////////////
                                  CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(
        address _avsDirectory,
        address _stakeRegistry,
        address _delegationManager
    ) ECDSAServiceManagerBase(_avsDirectory, _stakeRegistry, address(0), _delegationManager) { }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Checks if `msg.sender` is a registered AVS operator
    modifier onlyOperator() {
        require(ECDSAStakeRegistry(stakeRegistry).operatorRegistered(msg.sender) == true, "Operator must be the caller");
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                USER-FACING METHODS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBlockpostServiceManager
    function createNewRequest(string memory message) external {
        // Create a new request struct
        Request memory newReq;
        newReq.message = message;
        newReq.blocknumber = uint32(block.number);

        // Store the hash of the request on-chain to allow validators to pick it up
        requestHashes[_messageIndex] = keccak256(abi.encode(newReq));

        // Log the message storage request
        emit MessageRequestCreated({ id: _messageIndex, req: newReq });

        // Use unchecked to save on gas costs
        // This is safe because the `_messageIndex` cannot realistically overflow
        unchecked {
            _messageIndex++;
        }
    }

    /// @inheritdoc IBlockpostServiceManager
    function respondToRequest(Request calldata req, uint32 messageId, bytes calldata signature) external onlyOperator {
        // Checks: the operator has the minimum weight
        if (!operatorHasMinimumWeight(msg.sender)) {
            revert OperatorDoesntHaveMinimumWeight();
        }

        // Checks: the request is valid
        if (keccak256(abi.encode(req)) != requestHashes[messageId]) {
            revert InvalidRequest();
        }

        // Checks: the request hasn't been resolved yet
        if (bytes(messages[messageId]).length != 0) {
            revert RequestAlreadyResolved();
        }

        // Recover the signer of the operator who responded to this request
        bytes32 messageHash = keccak256(abi.encodePacked(req.message));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        // Recover the signer address from the signature
        address signer = ethSignedMessageHash.recover(signature);

        // Checks: the message was signed by the actual operator
        if (signer != msg.sender) revert InvalidOperatorSignature();

        // Effects: store the message mapped by its unique ID
        messages[messageId] = req.message;

        // Log the successful storage of the message
        emit MessageStored({ id: messageId, req: req, operator: msg.sender });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Checks if the `operator` operator has the minimum stake weight required by the AVS
    function operatorHasMinimumWeight(address operator) public view returns (bool) {
        return ECDSAStakeRegistry(stakeRegistry).getOperatorWeight(operator)
            >= ECDSAStakeRegistry(stakeRegistry).minimumWeight();
    }
}
