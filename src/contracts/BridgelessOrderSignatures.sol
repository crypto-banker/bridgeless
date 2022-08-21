// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/BridgelessOrderLibrary.sol";

import "forge-std/Test.sol";

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
        // calculate the orderHash
        bytes32 orderHash = calculateBridgelessOrderHash_Simple(order);
        _markOrderHashAsSpent(orderHash);
        // verify the order signature
        _checkOrderSignature(order.orderBase.signer, orderHash, signature);
    }

    function _processOrderSignature_Simple_OTC(BridgelessOrder_Simple_OTC calldata order, Signature calldata signature) internal {
        // calculate the orderHash
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
        // calculate the orderHash
        bytes32 orderHash = calculateBridgelessOrderHash_WithNonce(order);
        _markOrderHashAsSpent(orderHash);
        // verify the order signature
        _checkOrderSignature(order.orderBase.signer, orderHash, signature);
    }

    function _processOrderSignature_WithNonce_OTC(BridgelessOrder_WithNonce_OTC calldata order, Signature calldata signature) internal {
        // check nonce validity
        if (nonceIsSpent[order.orderBase.signer][order.nonce]) {
            revert("Bridgeless._processOrderSignature_WithNonce_OTC: nonce is already spent");
        }
        // mark nonce as spent
        nonceIsSpent[order.orderBase.signer][order.nonce] = true;
        // calculate the orderHash
        bytes32 orderHash = calculateBridgelessOrderHash_WithNonce_OTC(order);
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
}
