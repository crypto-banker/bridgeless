// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/BridgelessOrderLibrary.sol";

// import "forge-std/Test.sol";

abstract contract BridgelessOrderSignatures is
    BridgelessOrderLibrary
    // ,DSTest
{
    using SafeERC20 for IERC20;
    /// @notice EIP-712 Domain separator
    bytes32 public immutable DOMAIN_SEPARATOR;

    // signer => nonce => whether or not the nonce has been spent already
    mapping(address => mapping(uint256 => bool)) public nonceIsSpent;

    mapping(bytes32 => bool) public orderHashIsSpent;

    // set immutable variables
    constructor()
    {
        // initialize the immutable DOMAIN_SEPARATOR for signatures
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(DOMAIN_TYPEHASH, bytes("Bridgeless"), block.chainid, address(this))
        );

    }

    function _processOrderSignature_Simple(BridgelessOrder_Simple calldata order, Signature calldata signature) internal {
        // calculate the orderHash and mark it as spent
        bytes32 orderHash = calculateBridgelessOrderHash_Simple(order);
        _markOrderHashAsSpent(orderHash);
        // verify the order signature
        _checkOrderSignature(order.orderBase.signer, orderHash, signature);
    }

    function _processOrderSignature_Simple_OTC(BridgelessOrder_Simple_OTC calldata order, Signature calldata signature) internal {
        // verify that `executor` is correct
        require(
            order.executor == msg.sender,
            "Bridgeless._processOrderSignature_Simple_OTC: order.executor != msg.sender"
        );
        // calculate the orderHash and mark it as spent
        bytes32 orderHash = calculateBridgelessOrderHash_Simple_OTC(order);
        _markOrderHashAsSpent(orderHash);
        // verify the order signature
        _checkOrderSignature(order.orderBase.signer, orderHash, signature);
    }

    function _processOrderSignature_WithNonce(BridgelessOrder_WithNonce calldata order, Signature calldata signature) internal {
        // check nonce validity
        if (nonceIsSpent[order.orderBase.signer][order.nonce]) {
            revert("Bridgeless._processOrderSignature_WithNonce: nonce is already spent");
        }
        // mark nonce as spent
        nonceIsSpent[order.orderBase.signer][order.nonce] = true;
        // calculate the orderHash and mark it as spent
        bytes32 orderHash = calculateBridgelessOrderHash_WithNonce(order);
        _markOrderHashAsSpent(orderHash);
        // verify the order signature
        _checkOrderSignature(order.orderBase.signer, orderHash, signature);
    }

    function _processOrderSignature_WithNonce_OTC(BridgelessOrder_WithNonce_OTC calldata order, Signature calldata signature) internal {
        // verify that `executor` is correct
        require(
            order.executor == msg.sender,
            "Bridgeless._processOrderSignature_WithNonce_OTC: order.executor != msg.sender"
        );
        // check nonce validity
        if (nonceIsSpent[order.orderBase.signer][order.nonce]) {
            revert("Bridgeless._processOrderSignature_WithNonce_OTC: nonce is already spent");
        }
        // mark nonce as spent
        nonceIsSpent[order.orderBase.signer][order.nonce] = true;
        // calculate the orderHash and mark it as spent
        bytes32 orderHash = calculateBridgelessOrderHash_WithNonce_OTC(order);
        _markOrderHashAsSpent(orderHash);
        // verify the order signature
        _checkOrderSignature(order.orderBase.signer, orderHash, signature);
    }

    function _processOrderSignature_OptionalParameters(BridgelessOrder_OptionalParameters calldata order, Signature calldata signature) internal {
        // calculate the orderHash and mark it as spent
        bytes32 orderHash = calculateBridgelessOrderHash_OptionalParameters(order);
        _markOrderHashAsSpent(orderHash);
        // verify the order signature
        _checkOrderSignature(order.orderBase.signer, orderHash, signature);
    }

    function _markOrderHashAsSpent(bytes32 orderHash) internal {
        // verify that the orderHash has not already been spent
        require(
            !orderHashIsSpent[orderHash],
            "Bridgeless._markOrderHashAsSpent: orderHash has already been spent"
        );
        // mark orderHash as spent
        orderHashIsSpent[orderHash] = true;
    }

    /**
     * Experimental `optionalParameters` format is:
     * (optional) bytes1: flags to indicate order types -- do not need to include (but can include) for "simple" orders
     * bytes32[numberOfPositiveFlags]: for each flag that is a '1', 32 bytes of additional calldata should be attached, encoding information relevant to that flag
     */
    function processOptionalParameters(BridgelessOrder_Base calldata orderBase, bytes calldata optionalParameters) public {
        uint256 paramsLength = optionalParameters.length / 32;
        // no optionalParams -- do nothing and return early
        if (paramsLength == 0) {
            return;
        }
        bool usingOTC;
        bool usingNonce;
        uint256 additionalOffset = 1;
        // TODO: make sure using optionalParameters.offset is correct here -- verify that we aren't just reading the length, for instance
        assembly {
            // OTC flag is first bit being 1
            usingOTC := and(calldataload(optionalParameters.offset), 1)
            // nonce flag is second bit being 1
            usingNonce := and(calldataload(optionalParameters.offset), 2)
        }
        // run OTC check if necessary
        if (usingOTC) {
            address executor;
            assembly {
                // read executor address -- address is 160 bits so we right-shift by (256-160) = 96
                executor := shr(96,
                    calldataload(
                        add(
                            optionalParameters.offset,
                            additionalOffset
                        )
                    )
                )
                // add to additionalOffset to account for the 20 bytes of data that was read
                additionalOffset := add(additionalOffset, 20)                    
            }
            require(
                executor == msg.sender,
                "Bridgeless._checkOptionalParameters: executor != msg.sender"
            );            
        }
        // run nonce check if necessary
        if (usingNonce) {
            uint256 nonce;
            assembly {
                nonce := 
                    calldataload(
                        add(
                            optionalParameters.offset,
                            additionalOffset
                        )
                    )
                // add to additionalOffset to account for the 32 bytes of data that was read
                additionalOffset := add(additionalOffset, 32)                    
            }
            // check nonce validity
            if (nonceIsSpent[orderBase.signer][nonce]) {
                revert("Bridgeless._checkOptionalParameters: nonce is already spent");
            }
            // mark nonce as spent
            nonceIsSpent[orderBase.signer][nonce] = true;
        }
        return;
    }

// unused alternate draft of function
/*
    // struct BridgelessOrder_OptionalParameters {
    //     BridgelessOrder_Base orderBase;
    //     bytes optionalParameters;
    // }
    function _processOptionalParameters(BridgelessOrder_OptionalParameters calldata order) internal {
        uint256 paramsLength = order.optionalParameters.length / 32;
        // no optionalParams -- do nothing and return early
        if (paramsLength == 0) {
            return;
        }
        bool OTC;
        bool nonce;
        bytes memory params = order.optionalParameters;
        // TODO: make sure using order.optionalParameters.offset is correct here -- verify we aren't just reading the length, for instance
    }
*/

}
