// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "../Bridgeless.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

// Simple 'AccessControlEnumerable' version of the 'Bridgeless' contract. Different applications may desire different access controls.
// Contract is for demo purposes and is not kept fully up-to-date with the base implementation. *Please* do not use this in production.

contract Bridgeless_AccessControlEnumerable is
    Bridgeless,
    AccessControlEnumerable
{
    // gives "DEFAULT_ADMIN_ROLE" to `msg.sender`
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function fulfillOrder(
        IBridgelessCallee swapper,
        BridgelessOrder calldata order,
        PackedSignature calldata signature,
        bytes calldata extraCalldata
    )   
        public override
        // function is restricted to callers holding the "DEFAULT_ADMIN_ROLE"
        onlyRole(DEFAULT_ADMIN_ROLE)
        // @dev Modifier to verify that order is still valid
        checkOrderDeadline(order.deadline)
        // @dev Modifier to verify correct order execution
        checkOrderFulfillment(order.signer, order.tokenOut, order.amountOutMin)
        // @dev nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        super.fulfillOrder(
            swapper,
            order,
            signature,
            extraCalldata
        );
    }

    function fulfillOrders(
        IBridgelessCallee swapper,
        BridgelessOrder[] calldata orders,
        PackedSignature[] calldata signatures,
        bytes calldata extraCalldata
    )
        public override
        // function is restricted to callers holding the "DEFAULT_ADMIN_ROLE"
        onlyRole(DEFAULT_ADMIN_ROLE)
        // @dev nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        super.fulfillOrders(
            swapper,
            orders,
            signatures,
            extraCalldata
        );
    }
}
