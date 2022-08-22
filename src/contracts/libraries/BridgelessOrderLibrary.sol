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

    // struct BridgelessOrder {
    //     // order signatory
    //     address signer;
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
    //     // flags and info for all optional parameters
    //     bytes optionalParameters;
    // }
    /// @notice The EIP-712 typehash for the `ORDER_TYPEHASH` order struct used by the contract
    bytes32 public constant ORDER_TYPEHASH = keccak256(
        "BridgelessOrder(address tokenIn,uint256 amountIn, address tokenOut,uint256 amountOutMin,uint256 deadline,bytes optionalParameters)");

    /**
     * @notice Simple getter function to calculate the `orderHash` for a `BridgelessOrder`
     * @param order A `BridgelessOrder`-type order
     */
    function calculateBridgelessOrderHash(BridgelessOrder calldata order) public pure returns (bytes32) {
        return(
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    order.signer,
                    order.tokenIn,
                    order.amountIn,
                    order.tokenOut,
                    order.amountOutMin,
                    order.deadline,
                    order.optionalParameters
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
    ) public pure returns (bytes memory optionalParameters)
    {
        // add a single bit at the front, used for flags
        optionalParameters = abi.encodePacked(bytes1(0));
        if (usingOTC) {
            // concatenate the `executor` address in a 32-byte slot
            optionalParameters = abi.encodePacked(optionalParameters, executor);
            // OTC flag is first bit being 1 -- set this bit!
            assembly {
                mstore(
                    add(optionalParameters, 32),
                    or(mload(add(optionalParameters, 32)), 0x1000000000000000000000000000000000000000000000000000000000000000)
                )
            }
        }
        if (usingNonce) {
            // concatenate the `nonce` value in a 32-byte slot
            optionalParameters = abi.encodePacked(optionalParameters, nonce);
            // nonce flag is second bit being 1 -- set this bit!
            assembly {
                mstore(
                    add(optionalParameters, 32),
                    or(mload(add(optionalParameters, 32)), 0x2000000000000000000000000000000000000000000000000000000000000000)
                )
            }
        }
        return optionalParameters;
    }

    /**
     * Experimental `optionalParameters` format is:
     * (optional) bytes1: flags to indicate order types -- do not need to include (but can include) for "simple" orders
     * bytes32[numberOfPositiveFlags]: for each flag that is a '1', 32 bytes of additional calldata should be attached, encoding information relevant to that flag
     */
    function unpackOptionalParameters(bytes memory optionalParameters) public returns (bool usingOTC, bool usingNonce, address executor, uint256 nonce) {
        if (optionalParameters.length <= 1) {
            emit log("no optional parameters encoded");
        }
        // account for the 32 bytes of data that encode length
        uint256 additionalOffset = 32;
        assembly {
            // OTC flag is first bit being 1
            usingOTC := eq(
                and(
                    mload(add(optionalParameters, additionalOffset)),
                    0x1000000000000000000000000000000000000000000000000000000000000000
                ),
                    0x1000000000000000000000000000000000000000000000000000000000000000
            )
            // nonce flag is second bit being 1
            usingNonce := eq(
                and(
                    mload(add(optionalParameters, additionalOffset)),
                    0x2000000000000000000000000000000000000000000000000000000000000000
                ),
                    0x2000000000000000000000000000000000000000000000000000000000000000
            )
                // add to additionalOffset to account for the 1 byte of data that was read
                additionalOffset := add(additionalOffset, 1)
        }
        // run OTC check if necessary
        if (usingOTC) {
            assembly {
                // read executor address -- address is 160 bits so we right-shift by (256-160) = 96
                executor := shr(96,
                    mload(add(optionalParameters, additionalOffset))
                )
                // add to additionalOffset to account for the 20 bytes of data that was read
                additionalOffset := add(additionalOffset, 20)                    
            }          
        }
        // run nonce check if necessary
        if (usingNonce) {
            assembly {
                nonce := mload(add(optionalParameters, additionalOffset))
                // add to additionalOffset to account for the 32 bytes of data that was read
                additionalOffset := add(additionalOffset, 32)
            }
        }
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
