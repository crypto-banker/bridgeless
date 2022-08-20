// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "../BridgelessStructs.sol";

interface IBridgelessCallee is
    BridgelessStructs
{
    function bridgelessCall(address swapDestination, BridgelessOrder_Simple calldata order, bytes calldata extraCalldata) external;
    function bridgelessCalls(address[] calldata swapDestinations, BridgelessOrder_Simple[] calldata orders, bytes calldata extraCalldata) external;
}
