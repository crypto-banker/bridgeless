// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./BridgelessStructs.sol";

import "forge-std/Test.sol";

abstract contract BridgelessOrderSignatures is
    BridgelessStructs
    ,DSTest
{
    using SafeERC20 for IERC20;
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

    /// @notice The EIP-712 typehash for the `ORDER_TYPEHASH_Simple_OTC` order struct used by the contract
    bytes32 public constant ORDER_TYPEHASH_Simple_OTC = keccak256(
        "BridgelessOrder_Simple_OTC(BridgelessOrder_Base orderBase,address executor)");

    /// @notice The EIP-712 typehash for the `ORDER_TYPEHASH_Base` order struct used by the contract
    bytes32 public constant ORDER_TYPEHASH_WithNonce = keccak256(
        "BridgelessOrder_WithNonce(BridgelessOrder_Base orderBase,uint256 nonce)");

    /// @notice EIP-712 Domain separator
    bytes32 public immutable DOMAIN_SEPARATOR;

    // signer => nonce => whether or not the nonce has been spent already
    mapping(address => mapping(uint256 => bool)) public nonceIsSpent;

    // set immutable variables
    constructor()
    {
        // initialize the immutable DOMAIN_SEPARATOR for signatures
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(DOMAIN_TYPEHASH, bytes("Bridgeless"), block.chainid, address(this))
        );

    }

    /**
     * @notice Simple getter function to calculate the `orderHash` for a `BridgelessOrder_Simple`
     * @param order A `BridgelessOrder_Simple`-type order
     */
    function calculateBridgelessOrderHash_Simple(BridgelessOrder_Simple calldata order) public pure returns (bytes32) {
        return calculateBridgelessOrderHash_Base(order.orderBase);
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

    function _checkOrderSignature_Simple(address signer, BridgelessOrder_Simple calldata order, Signature calldata signature) internal pure {
        // verify the order signature
        require(
            signer == ECDSA.recover(
                // calculate the orderHash
                calculateBridgelessOrderHash_Simple(order),
                signature.v,
                signature.r,
                signature.s
            ),
            "Bridgeless._checkOrderSignature_Simple: signer != recoveredAddress"
        );
    }

    function _checkOrderSignature_Simple_OTC(address signer, BridgelessOrder_Simple_OTC calldata order, Signature calldata signature) internal pure {
        // verify the order signature
        require(
            signer == ECDSA.recover(
                // calculate the orderHash
                calculateBridgelessOrderHash_Simple_OTC(order),
                signature.v,
                signature.r,
                signature.s
            ),
            "Bridgeless._checkOrderSignature_WithNonce: signer != recoveredAddress"
        );
    }

    function _checkOrderSignature_WithNonce(address signer, BridgelessOrder_WithNonce calldata order, Signature calldata signature) internal {
        // check nonce validity
        if (nonceIsSpent[signer][order.nonce]) {
            revert("Bridgeless._checkOrderSignature_WithNonce: nonce is already spent");
        }
        // mark nonce as spent
        nonceIsSpent[signer][order.nonce] = true;
        // verify the order signature
        require(
            signer == ECDSA.recover(
                // calculate the orderHash
                calculateBridgelessOrderHash_WithNonce(order),
                signature.v,
                signature.r,
                signature.s
            ),
            "Bridgeless._checkOrderSignature_WithNonce: signer != recoveredAddress"
        );
    }

    function _checkOrderDeadline(uint256 deadline) internal view {
        require(
            block.timestamp <= deadline,
            "Bridgeless._checkOrderDeadline: block.timestamp > deadline"
        );
    }
}
