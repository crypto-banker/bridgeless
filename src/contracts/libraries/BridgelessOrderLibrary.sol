// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../BridgelessStructs.sol";

import "forge-std/Test.sol";

abstract contract BridgelessOrderLibrary is
    BridgelessStructs
    ,DSTest
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

    /**
     * Experimental `optionalParameters` format is:
     * (optional) bytes1: flags to indicate order types -- do not need to include (but can include) for "simple" orders
     * abi.encodePacked(additional args): for each flag that is a '1', additional calldata should be attached, encoding information relevant to that flag
     */
    function packOptionalParameters(
        bool usingOTC,
        bool usingNonce,
        address executor,
        uint256 nonce
    ) public returns (bytes memory optionalParameters)
    {
        emit log_named_bytes("optionalParameters", optionalParameters);
        // add a single bit at the front, used for flags
        optionalParameters = abi.encodePacked(bytes1(0));
        emit log_named_bytes("optionalParameters", optionalParameters);
        if (usingOTC) {
            // concatenate the `executor` address in a 32-byte slot
            optionalParameters = abi.encodePacked(optionalParameters, executor);
            emit log_named_bytes("optionalParameters", optionalParameters);
            // OTC flag is first bit being 1 -- set this bit!
            assembly {
                mstore(
                    add(optionalParameters, 32),
                    or(mload(add(optionalParameters, 32)), 0x1000000000000000000000000000000000000000000000000000000000000000)
                )
            }
            emit log_named_bytes("optionalParameters", optionalParameters);
        }
        if (usingNonce) {
            // concatenate the `nonce` value in a 32-byte slot
            optionalParameters = abi.encodePacked(optionalParameters, nonce);
            emit log_named_bytes("optionalParameters", optionalParameters);
            // nonce flag is second bit being 1 -- set this bit!
            assembly {
                mstore(
                    add(optionalParameters, 32),
                    or(mload(add(optionalParameters, 32)), 0x2000000000000000000000000000000000000000000000000000000000000000)
                )
            }
            emit log_named_bytes("optionalParameters", optionalParameters);
        }
        return optionalParameters;
    }

    /**
     * Experimental `optionalParameters` format is:
     * (optional) bytes1: flags to indicate order types -- do not need to include (but can include) for "simple" orders
     * bytes32[numberOfPositiveFlags]: for each flag that is a '1', 32 bytes of additional calldata should be attached, encoding information relevant to that flag
     */
    function unpackOptionalParameters(bytes calldata optionalParameters) public {
        if (optionalParameters.length <= 1) {
            emit log("no optional parameters encoded");
        }
        bool usingOTC;
        bool usingNonce;
        uint256 additionalOffset = 1;
        // TODO: make sure using optionalParameters.offset is correct here -- verify that we aren't just reading the length, for instance
        assembly {
            // OTC flag is first bit being 1
            usingOTC := and(calldataload(optionalParameters.offset), 0x1000000000000000000000000000000000000000000000000000000000000000)
            // nonce flag is second bit being 1
            usingNonce := and(calldataload(optionalParameters.offset), 0x2000000000000000000000000000000000000000000000000000000000000000)
        }
        // run OTC check if necessary
        if (usingOTC) {
            emit log("usingOTC is true!");
            emit log_named_uint("additionalOffset", additionalOffset);
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
            emit log_named_address("executor", executor);
            emit log_named_uint("additionalOffset", additionalOffset);
        }
        // run nonce check if necessary
        if (usingNonce) {
            emit log("usingNonce is true!");
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
            emit log_named_uint("nonce", nonce);
            emit log_named_uint("additionalOffset", additionalOffset);
        }
        return;
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
