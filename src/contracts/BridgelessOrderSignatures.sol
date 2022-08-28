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

    /**
     *  signer => nonce => whether or not the nonce has been spent already
     *  Implementation of BitMaps in this contract is inspired by OpenZeppelin's and Uniswap's code.
     *  Using bitmaps saves gas, since SSTOREs are cheaper once the slot is already nonzero!
     *  A Single BitMap entry can be read by using the `nonceIsSpent(signer, nonce)` function.
     */
    mapping(address => mapping(uint256 => uint256)) public nonceBitmaps;

    function nonceIsSpent(address signer, uint256 nonce) public view returns (bool) {
        uint256 index = (nonce >> 128);
        uint256 mask = (1 << (nonce & 0xffffffffffffffff));
        return ((nonceBitmaps[signer][index] & mask) != 0);
    }

    // set immutable variables
    constructor()
    {
        // initialize the immutable DOMAIN_SEPARATOR for signatures
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(DOMAIN_TYPEHASH, bytes("Bridgeless"), block.chainid, address(this))
        );
    }

    function _processOrderSignature(BridgelessOrder calldata order, PackedSignature calldata signature) internal {
        // calculate the orderHash
        bytes32 orderHash = calculateBridgelessOrderHash(order);
        // verify the order signature
        _checkOrderSignature(order.signer, orderHash, signature);
        // check nonce validity
        uint256 index = (order.nonce >> 128);
        uint256 mask = (1 << (order.nonce & 0xffffffffffffffff));
        // this means the nonce is already spent
        if (nonceBitmaps[order.signer][index] & mask != 0) {
            revert("Bridgeless._processOrderSignature: nonce is already spent");
        }
        // mark nonce as spent
        nonceBitmaps[order.signer][index] = (nonceBitmaps[order.signer][index] | mask);
    }

    /**
     * @notice Looks at the provided flags in `optionalParameters`, then processes each included optional parameter
     * @dev Currently there are two flags, `usingExecutor` and `usingValidAfter`
     * @param optionalParameters A set of flags and 
     * @dev The `optionalParameters` format is:
     * (optional) bytes1: 8-bit map of flags to indicate presence of optional parameters -- do not need to include (but can include) for "simple" orders
     * abi.encodePacked(additional args): for each flag that is a '1', additional calldata should be attached, encoding information relevant to that flag
     * @ return Whether or not the `partialFill` flag is set
     */
    function processOptionalParameters(bytes memory optionalParameters) public view returns (bool) {
        // no optionalParams -- do nothing and return early
        if (optionalParameters.length == 0) {
            return false;
        }
        bool flag;
        // executor flag is first bit being 1 -- check for this flag
        assembly {
            flag := eq(
                and(
                    // offset of 32 is used to start reading from `optionalParameters` starting after the 32 bytes that encode length
                    mload(add(optionalParameters, 32)),
                    FIRST_BIT_MASK
                ),
                    FIRST_BIT_MASK
            )
        }
        // account for the 32 bytes of data that encode length and the 1 byte that has already been read
        uint256 additionalOffset = 33;
        // run executor check if flag was set
        if (flag) {
            address executor;
            assembly {
                // read executor address -- address is 160 bits so we right-shift by (256-160) = 96
                executor := shr(96,
                    mload(add(optionalParameters, additionalOffset))
                )
                // add to additionalOffset to account for the 20 bytes of data that was read
                additionalOffset := add(additionalOffset, 20)                    
            }
            require(
                executor == msg.sender,
                "Bridgeless._checkOptionalParameters: executor != msg.sender"
            );
        }
        // validAfter flag is second bit being 1 -- check for this flag
        assembly {
            flag := eq(
                and(
                    // offset of 32 is used to start reading from `optionalParameters` starting after the 32 bytes that encode length
                    mload(add(optionalParameters, 32)),
                    SECOND_BIT_MASK
                ),
                    SECOND_BIT_MASK
            )
        }
        // run validAfter check if flag was set
        if (flag) {
            uint32 validAfter;
            assembly {
                // read validAfter timestamp -- timestamp is enocoded as 32 bits so we right-shift by (256-32) = 224
                validAfter := shr(224,
                    mload(add(optionalParameters, additionalOffset))
                )
                // add to additionalOffset to account for the 4 bytes of data that was read
                additionalOffset := add(additionalOffset, 4)                    
            }
            require(
                block.timestamp > validAfter,
                "Bridgeless._checkOptionalParameters: block.timestamp <= validAfter"
            );
        }
        // partialFill flag is third bit being 1 -- check for this flag
        assembly {
            flag := eq(
                and(
                    // offset of 32 is used to start reading from `optionalParameters` starting after the 32 bytes that encode length
                    mload(add(optionalParameters, 32)),
                    THIRD_BIT_MASK
                ),
                    THIRD_BIT_MASK
            )
        }
        return flag;
    }
}
