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

    function _processOrderSignature(BridgelessOrder calldata order, Signature calldata signature) internal {
        // calculate the orderHash and mark it as spent
        bytes32 orderHash = calculateBridgelessOrderHash(order);
        _markOrderHashAsSpent(orderHash);
        // verify the order signature
        _checkOrderSignature(order.signer, orderHash, signature);
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
    function processOptionalParameters(address signer, bytes memory optionalParameters) public {
        // no optionalParams -- do nothing and return early
        if (optionalParameters.length == 0) {
            return;
        }
        bool usingOTC;
        bool usingNonce;
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
        // run nonce check if necessary
        if (usingNonce) {
            uint256 nonce;
            assembly {
                nonce := mload(add(optionalParameters, additionalOffset))
                // add to additionalOffset to account for the 32 bytes of data that was read
                additionalOffset := add(additionalOffset, 32)
            }
            // check nonce validity
            if (nonceIsSpent[signer][nonce]) {
                revert("Bridgeless._checkOptionalParameters: nonce is already spent");
            }
            // mark nonce as spent
            nonceIsSpent[signer][nonce] = true;
        }
        return;
    }
}
