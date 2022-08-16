// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "./BridgelessOrderStruct.sol";

interface IBridgelessCallee is
    BridgelessOrderStruct
{
    function bridgelessCall(address swapDestination, BridgelessOrder calldata order) external;
}
