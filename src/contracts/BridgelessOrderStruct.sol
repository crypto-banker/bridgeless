// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

interface BridgelessOrderStruct {
    struct BridgelessOrder {
        // ERC20 token to trade
        address tokenIn;
        // amount of token to trade
        uint256 amountIn;
        // minimum amount of native token to receive
        uint256 amountOutMin;
        // signature expiration
        uint256 deadline;
    }
}
