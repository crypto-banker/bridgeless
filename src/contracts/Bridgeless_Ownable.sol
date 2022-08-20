// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "./Bridgeless.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Bridgeless_Ownable is
    Bridgeless,
    Ownable
{
    /**
     * @notice Fulfills a single `BridgelessOrder`, swapping `order.amountIn` of the ERC20 token `order.tokenIn` for *at least* `order.amountOutMin` of `order.TokenOut`.
     * @notice Note that an input of `order.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from `tokenOwner` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCall(tokenOwner, order, extraCalldata)`.
     * @param tokenOwner Address of the user whose order is being fulfilled.
     * @param order A valid `BridgelessOrder` created by `tokenOwner`, specifying their desired order parameters.
     * @param signature A valid ECDSA signature of `order` provided by `tokenOwner`. This signature is verified
     *        by checking against calculateBridgelessOrderHash(tokenOwner, order)
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     */
    function fulfillOrder(
        IBridgelessCallee swapper,
        address tokenOwner,
        BridgelessOrder calldata order,
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

    /**
     * @notice Fulfills any arbitrary number of `BridgelessOrder`s, swapping `order.amountIn`
     *         of the ERC20 token `orders[i].tokenIn` for *at least* `orders[i].amountOutMin` of `orders[i].TokenOut`.
     * @notice Note that an input of `order.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from each of the `tokenOwners` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCalls(tokenOwners, orders, extraCalldata)`
     * @param tokenOwners Addresses of the users whose orders are being fulfilled.
     * @param orders A valid set of `BridgelessOrder`s created by `tokenOwners`, specifying their desired order parameters.
     * @param signatures A valid set of ECDSA signatures of `orders` provided by `tokenOwners`. Thess signature are verified
     *        by checking against `calculateBridgelessOrderHash(tokenOwners[i], orders[i])`
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     */
    function fulfillOrders(
        IBridgelessCallee swapper,
        address[] calldata tokenOwners,
        BridgelessOrder[] calldata orders,
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
