// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

interface BridgelessStructs {
    struct BridgelessOrder {
        // order signatory
        address signer;
        // ERC20 token to trade
        address tokenIn;
        // amount of token to trade
        uint256 amountIn;
        // desired token to trade into
        address tokenOut;
        // minimum amount of native token to receive
        uint256 amountOutMin;
        // signature expiration
        uint256 deadline;
        // flags and info for all optional parameters
        bytes optionalParameters;
    }

    // @notice ECDSA signature parameters
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

}
