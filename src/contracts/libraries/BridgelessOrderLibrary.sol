// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../BridgelessStructs.sol";

import "forge-std/Test.sol";

abstract contract BridgelessOrderLibrary is
    BridgelessStructs
    // ,DSTest
{
    /// @notice The EIP-712 typehash for the contract's domain
    // bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract");
    bytes32 public constant DOMAIN_TYPEHASH = 0x4e2c4bf03f58b0b9d87019acd26e490aca9f5097fac5fd3eed5cccf6342a8d85;

    /// @notice The EIP-712 typehash for the `ORDER_TYPEHASH` order struct used by the contract
    bytes32 public constant ORDER_TYPEHASH = keccak256(
        "BridgelessOrder(address tokenIn,uint256 amountIn, address tokenOut,uint256 amountOutMin,uint256 deadline,uint256 noncebytes optionalParameters)");

    // BIT MASKS
    uint256 internal constant FIRST_BIT_MASK = 0x1000000000000000000000000000000000000000000000000000000000000000;
    uint256 internal constant SECOND_BIT_MASK = 0x2000000000000000000000000000000000000000000000000000000000000000;
    uint256 internal constant THIRD_BIT_MASK = 0x4000000000000000000000000000000000000000000000000000000000000000;

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
                    order.nonce,
                    order.optionalParameters
                )
            )
        );
    }

    /**
     * @dev The `optionalParameters` format is:
     * (optional) bytes1: 8-bit map of flags to indicate presence of optional parameters -- do not need to include (but can include) for "simple" orders
     * abi.encodePacked(additional args): for each flag that is a '1', additional calldata should be attached, encoding information relevant to that flag
     */
    function packOptionalParameters(
        bool usingExecutor,
        bool usingValidAfter,
        bool usingPartialFill,
        address executor,
        uint32 validAfter
    ) public pure returns (bytes memory optionalParameters)
    {
        // add a single bit at the front, used for flags
        optionalParameters = abi.encodePacked(bytes1(0));
        if (usingExecutor) {
            // concatenate the `executor` address in a 20-byte slot
            optionalParameters = abi.encodePacked(optionalParameters, executor);
            // executor flag is first bit being 1 -- set this bit!
            assembly {
                mstore(
                    add(optionalParameters, 32),
                    or(mload(add(optionalParameters, 32)), FIRST_BIT_MASK)
                )
            }
        }
        if (usingValidAfter) {
            // concatenate the `validAfter` value in a 4-byte slot
            optionalParameters = abi.encodePacked(optionalParameters, validAfter);
            // validAfter flag is second bit being 1 -- set this bit!
            assembly {
                mstore(
                    add(optionalParameters, 32),
                    or(mload(add(optionalParameters, 32)), SECOND_BIT_MASK)
                )
            }
        }
        if (usingPartialFill) {
            // partialFill flag is third bit being 1 -- set this bit!
            assembly {
                mstore(
                    add(optionalParameters, 32),
                    or(mload(add(optionalParameters, 32)), THIRD_BIT_MASK)
                )
            }
        }
        return optionalParameters;
    }

    /**
     * @dev The `optionalParameters` format is:
     * (optional) bytes1: 8-bit map of flags to indicate presence of optional parameters -- do not need to include (but can include) for "simple" orders
     * abi.encodePacked(additional args): for each flag that is a '1', additional calldata should be attached, encoding information relevant to that flag
     */
    function unpackOptionalParameters(
        bytes memory optionalParameters
    )
        public pure returns (bool usingExecutor, bool usingValidAfter, bool usingPartialFill, address executor, uint32 validAfter) {
        // account for the 32 bytes of data that encode length
        uint256 additionalOffset = 32;
        assembly {
            // Executor flag is first bit being 1
            usingExecutor := eq(
                and(
                    mload(add(optionalParameters, additionalOffset)),
                    FIRST_BIT_MASK
                ),
                    FIRST_BIT_MASK
            )
            // validAfter flag is second bit being 1 -- check for this flag
            usingValidAfter := eq(
                and(
                    // offset of 32 is used to start reading from `optionalParameters` starting after the 32 bytes that encode length
                    mload(add(optionalParameters, additionalOffset)),
                    SECOND_BIT_MASK
                ),
                    SECOND_BIT_MASK
            )
            // partialFill flag is third bit being 1 -- check for this flag
            usingPartialFill := eq(
                and(
                    // offset of 32 is used to start reading from `optionalParameters` starting after the 32 bytes that encode length
                    mload(add(optionalParameters, additionalOffset)),
                    THIRD_BIT_MASK
                ),
                    THIRD_BIT_MASK
            )
            // add to additionalOffset to account for the 1 byte of data that was read
            additionalOffset := add(additionalOffset, 1)
        }
        if (usingExecutor) {
            assembly {
                // read executor address -- address is 160 bits so we right-shift by (256-160) = 96
                executor := shr(96,
                    mload(add(optionalParameters, additionalOffset))
                )
                // add to additionalOffset to account for the 20 bytes of data that was read
                additionalOffset := add(additionalOffset, 20)                    
            }          
        }
        if (usingValidAfter) {
            assembly {
                // read validAfter timestamp -- timestamp is enocoded as 32 bits so we right-shift by (256-32) = 224
                validAfter := shr(224,
                    mload(add(optionalParameters, additionalOffset))
                )
                // add to additionalOffset to account for the 4 bytes of data that was read
                additionalOffset := add(additionalOffset, 4)                    
            }
        }
    }

    function _checkOrderSignature(address signer, bytes32 orderHash, PackedSignature calldata signature) internal pure {
        require(
            signer == ECDSA.recover(
                orderHash,
                signature.r,
                signature.vs
            ),
            "Bridgeless._checkOrderSignature: signer != recoveredAddress"
        );
    }

    function _checkOrderDeadline(uint256 deadline) internal view {
        require(
            block.timestamp <= deadline,
            "Bridgeless._checkOrderDeadline: block.timestamp > deadline"
        );
    }
}
