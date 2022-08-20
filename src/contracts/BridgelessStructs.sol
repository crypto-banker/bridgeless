// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

interface BridgelessStructs {
    struct BridgelessOrder_Base {
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
    }

    struct BridgelessOrder_Simple {
        BridgelessOrder_Base orderBase;
    }

    struct BridgelessOrder_WithNonce {
        BridgelessOrder_Base orderBase;
        /** 
         * @dev Only one order signed by a given address with a specfic `nonce` value can ever be executed.
         *      This allows users to sign a set of multiple orders with the same nonce – e.g. orders at different prices,
         *      and *guarantee* that at max only one of their set of orders will ever be fulfilled.
         */ 
        uint256 nonce;
    }

    struct BridgelessOrder_Simple_OTC {
        BridgelessOrder_Base orderBase;
        // @dev In fulfilling an "OTC"-type order, the specified `executor` address *must be* the `msg.sender` to Bridgeless.
        address executor;
    }

    struct BridgelessOrder_WithNonce_OTC {
        BridgelessOrder_Base orderBase;
        /** 
         * @dev Only one order signed by a given address with a specfic `nonce` value can ever be executed.
         *      This allows users to sign a set of multiple orders with the same nonce – e.g. orders at different prices,
         *      and *guarantee* that at max only one of their set of orders will ever be fulfilled.
         */ 
        uint256 nonce;
        // @dev In fulfilling an "OTC"-type order, the specified `executor` address *must be* the `msg.sender` to Bridgeless.
        address executor;
    }

    // @notice ECDSA signature parameters
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

}
