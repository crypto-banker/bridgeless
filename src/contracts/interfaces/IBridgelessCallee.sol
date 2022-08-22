// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "../BridgelessStructs.sol";

interface IBridgelessCallee is
    BridgelessStructs
{
    function bridgelessCall(BridgelessOrder calldata order, bytes calldata extraCalldata) external;
    function bridgelessCalls(BridgelessOrder[] calldata orders, bytes calldata extraCalldata) external;
}
