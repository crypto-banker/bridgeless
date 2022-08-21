// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../BridgelessStructs.sol";

abstract contract BridgelessOrderLibrary is
    BridgelessStructs
{
    /// @notice The EIP-712 typehash for the contract's domain
    // bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract");
    bytes32 public constant DOMAIN_TYPEHASH = 0x4e2c4bf03f58b0b9d87019acd26e490aca9f5097fac5fd3eed5cccf6342a8d85;

    // struct BridgelessOrder_Base {
    //     // ERC20 token to trade
    //     address tokenIn;
    //     // amount of token to trade
    //     uint256 amountIn;
    //     // desired token to trade into
    //     address tokenOut;
    //     // minimum amount of native token to receive
    //     uint256 amountOutMin;
    //     // signature expiration
    //     uint256 deadline;
    // }
    /// @notice The EIP-712 typehash for the `ORDER_TYPEHASH_Base` order struct used by the contract
    bytes32 public constant ORDER_TYPEHASH_Base = keccak256(
        "BridgelessOrder_Base(address tokenIn,uint256 amountIn, address tokenOut,uint256 amountOutMin,uint256 deadline)");

    // struct BridgelessOrder_Simple {
    //     BridgelessOrder_Base orderBase;
    // }
    /// @notice The EIP-712 typehash for the `ORDER_TYPEHASH_Simple` order struct used by the contract
    bytes32 public constant ORDER_TYPEHASH_Simple = keccak256(
        "BridgelessOrder_Simple(BridgelessOrder_Base orderBase)");

    /// @notice The EIP-712 typehash for the `ORDER_TYPEHASH_Simple_OTC` order struct used by the contract
    bytes32 public constant ORDER_TYPEHASH_Simple_OTC = keccak256(
        "BridgelessOrder_Simple_OTC(BridgelessOrder_Base orderBase,address executor)");

    /// @notice The EIP-712 typehash for the `ORDER_TYPEHASH_WithNonce` order struct used by the contract
    bytes32 public constant ORDER_TYPEHASH_WithNonce = keccak256(
        "BridgelessOrder_WithNonce(BridgelessOrder_Base orderBase,uint256 nonce)");

    /// @notice The EIP-712 typehash for the `ORDER_TYPEHASH_WithNonce_OTC` order struct used by the contract
    bytes32 public constant ORDER_TYPEHASH_WithNonce_OTC = keccak256(
        "ORDER_TYPEHASH_WithNonce_OTC(BridgelessOrder_Base orderBase,uint256 nonce,address executor)");

    /**
     * @notice Simple getter function to calculate the `orderHash` for a `BridgelessOrder_Simple`
     * @param order A `BridgelessOrder_Simple`-type order
     */
    function calculateBridgelessOrderHash_Simple(BridgelessOrder_Simple calldata order) public pure returns (bytes32) {
        return(
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH_Simple,
                    calculateBridgelessOrderHash_Base(order.orderBase)
                )
            )
        );
    }

    /**
     * @notice Simple getter function to calculate the `orderHash` for a `BridgelessOrder_Base`
     * @param orderBase A `BridgelessOrder_Base` ojbect
     */
    function calculateBridgelessOrderHash_Base(BridgelessOrder_Base calldata orderBase) public pure returns (bytes32) {
        return(
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH_Base,
                    orderBase.signer,
                    orderBase.tokenIn,
                    orderBase.amountIn,
                    orderBase.tokenOut,
                    orderBase.amountOutMin,
                    orderBase.deadline
                )
            )
        );
    }

    /**
     * @notice Simple getter function to calculate the `orderHash` for a `BridgelessOrder_Simple_OTC`
     * @param order A `BridgelessOrder_Simple_OTC`-type order
     */
    function calculateBridgelessOrderHash_Simple_OTC(BridgelessOrder_Simple_OTC calldata order) public pure returns (bytes32) {
        return(
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH_Simple_OTC,
                    calculateBridgelessOrderHash_Base(order.orderBase),
                    order.executor
                )
            )
        );
    }

    /**
     * @notice Simple getter function to calculate the `orderHash` for a `BridgelessOrder_WithNonce`
     * @param order A `BridgelessOrder_WithNonce`-type order
     */
    function calculateBridgelessOrderHash_WithNonce(BridgelessOrder_WithNonce calldata order) public pure returns (bytes32) {
        return(
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH_WithNonce,
                    calculateBridgelessOrderHash_Base(order.orderBase),
                    order.nonce
                )
            )
        );
    }

    /**
     * @notice Simple getter function to calculate the `orderHash` for a `BridgelessOrder_WithNonce_OTC`
     * @param order A `BridgelessOrder_WithNonce_OTC`-type order
     */
    function calculateBridgelessOrderHash_WithNonce_OTC(BridgelessOrder_WithNonce_OTC calldata order) public pure returns (bytes32) {
        return(
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH_WithNonce_OTC,
                    calculateBridgelessOrderHash_Base(order.orderBase),
                    order.nonce,
                    order.executor
                )
            )
        );
    }

    function _checkOrderDeadline(uint256 deadline) internal view {
        require(
            block.timestamp <= deadline,
            "Bridgeless._checkOrderDeadline: block.timestamp > deadline"
        );
    }

    function _checkOrderSignature(address signer, bytes32 orderHash, Signature calldata signature) internal pure {
        require(
            signer == ECDSA.recover(
                orderHash,
                signature.v,
                signature.r,
                signature.s
            ),
            "Bridgeless._checkOrderSignature: signer != recoveredAddress"
        );
    }
}
