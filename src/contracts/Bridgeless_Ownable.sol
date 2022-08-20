// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "./Bridgeless.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Bridgeless_Ownable is
    Bridgeless,
    Ownable
{
    function fulfillOrder(
        IBridgelessCallee swapper,
        address tokenOwner,
        BridgelessOrder_Simple calldata order,
        Signature calldata signature,
        bytes calldata extraCalldata
    )
        // nonReentrant since we hand over control of execution to an arbitrary contract later in this function
        public override nonReentrant onlyOwner
    {
        super.fulfillOrder(
            swapper,
            tokenOwner,
            order,
            signature,
            extraCalldata
        );
    }

    function fulfillOrders(
        IBridgelessCallee swapper,
        address[] calldata tokenOwners,
        BridgelessOrder_Simple[] calldata orders,
        Signature[] calldata signatures,
        bytes calldata extraCalldata
    )
        // nonReentrant since we hand over control of execution to an arbitrary contract later in this function
        public override nonReentrant onlyOwner
    {
        super.fulfillOrders(
            swapper,
            tokenOwners,
            orders,
            signatures,
            extraCalldata
        );
    }
}
