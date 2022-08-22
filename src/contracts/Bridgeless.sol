// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./BridgelessOrderSignatures.sol";
import "./interfaces/IBridgelessCallee.sol";

import "forge-std/Test.sol";

contract Bridgeless is
    BridgelessOrderSignatures,
    ReentrancyGuard
    // ,DSTest
{
    // Vm cheats = Vm(HEVM_ADDRESS);
    using SafeERC20 for IERC20;

    // verify that the `tokenOwner` receives *at least* `amountOutMin in `tokenOut` from the swap
    modifier checkOrderFulfillment(
        address tokenOwner,
        address tokenOut,
        uint256 amountOutMin
    ) {
        // get the `tokenOwner`'s balance of the `tokenOut`, *prior* to running the function
        uint256 ownerBalanceBefore = _getUserBalance(tokenOwner, tokenOut);
        
        // run the function
        _;

        // verify that the `tokenOwner` received *at least* `amountOutMin` in `tokenOut` *after* function has run
        require(
            _getUserBalance(tokenOwner, tokenOut) - ownerBalanceBefore >= amountOutMin,
            "Bridgeless.checkOrderFulfillment: amountOutMin not met!"
        );
    }

    // Check an order deadline. Orders must be executed at or before the UTC timestamp specified by their `deadline`.
    modifier checkOrderDeadline(uint256 deadline) {
        require(
            block.timestamp <= deadline,
            "Bridgeless.checkOrderDeadline: block.timestamp > deadline"
        );
        _;
    }

    /**
     * @notice Fulfills a single `BridgelessOrder`, swapping `order.amountIn` of the ERC20 token `order.tokenIn` for
     *          *at least* `order.amountOutMin` of `order.TokenOut`.
     * @notice Note that an input of `order.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from `order.signer` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCall(order, extraCalldata)`.
     * @param order A valid `BridgelessOrder` created by `order.signer`, specifying their desired order parameters.
     * @param signature A valid ECDSA signature of `order` provided by `order.signer`. This signature is verified
     *        by checking against `calculateBridgelessOrderHash(order)`
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     * @dev This function assumes that allowance of at least `order.amountIn` of `order.tokenIn` has already been provided
     *       by `order.signer` to **this contract**.
     * @dev Allowance can be be provided by first calling `permit` on an ERC2612 token (either in a prior transaction or within the same transaction).
     */
    function fulfillOrder(
        IBridgelessCallee swapper,
        BridgelessOrder calldata order,
        Signature calldata signature,
        bytes calldata extraCalldata
    )   
        external virtual
        // @dev Modifier to verify that order is still valid
        checkOrderDeadline(order.deadline)
        // @dev Modifier to verify correct order execution
        checkOrderFulfillment(order.signer, order.tokenOut, order.amountOutMin)
        // @dev nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        // @dev Verify that `order.signer` did indeed sign `order` and that it is still valid, then mark the orderHash as spent
        _processOrderSignature(order, signature);

        processOptionalParameters(abi.encode(order));
        // @dev Fulfill the `order`
        _fulfillOrder(
            swapper,
            order,
            extraCalldata
        );
    }


    /**
     * @notice Fulfills a single `BridgelessOrder_Simple`, swapping `order.orderBase.amountIn` of the ERC20 token `order.orderBase.tokenIn` for
     *          *at least* `order.orderBase.amountOutMin` of `order.orderBase.TokenOut`.
     * @notice Note that an input of `order.orderBase.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from `order.orderBase.signer` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCall(order, extraCalldata)`.
     * @param order A valid `BridgelessOrder_Simple` created by `order.orderBase.signer`, specifying their desired order parameters.
     * @param signature A valid ECDSA signature of `order` provided by `order.orderBase.signer`. This signature is verified
     *        by checking against `calculateBridgelessOrderHash_Simple(order)`
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     * @dev This function assumes that allowance of at least `order.orderBase.amountIn` of `order.orderBase.tokenIn` has already been provided
     *       by `order.orderBase.signer` to **this contract**.
     * @dev Allowance can be be provided by first calling `permit` on an ERC2612 token (either in a prior transaction or within the same transaction).
     */
    function fulfillOrder_Simple(
        IBridgelessCallee swapper,
        BridgelessOrder_Simple calldata order,
        Signature calldata signature,
        bytes calldata extraCalldata
    )   
        public virtual
        // @dev Modifier to verify that order is still valid
        checkOrderDeadline(order.orderBase.deadline)
        // @dev Modifier to verify correct order execution
        checkOrderFulfillment(order.orderBase.signer, order.orderBase.tokenOut, order.orderBase.amountOutMin)
        // @dev nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        // @dev Verify that `order.orderBase.signer` did indeed sign `order` and that it is still valid, then mark the orderHash as spent
        _processOrderSignature_Simple(order, signature);
        // @dev Fulfill the `order`
        _fulfillOrder_Base(
            swapper,
            order.orderBase,
            extraCalldata
        );
    }

    /**
     * @notice Fulfills a single `BridgelessOrder_Simple_OTC`, swapping `order.orderBase.amountIn` of the ERC20 token `order.orderBase.tokenIn` for
     *          *at least* `order.orderBase.amountOutMin` of `order.orderBase.TokenOut`.
     * @notice Note that an input of `order.orderBase.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from `order.orderBase.signer` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCall(order, extraCalldata)`.
     * @param order A valid `BridgelessOrder_Simple_OTC` created by `order.orderBase.signer`, specifying their desired order parameters.
     * @param signature A valid ECDSA signature of `order` provided by `order.orderBase.signer`. This signature is verified
     *        by checking against `calculateBridgelessOrderHash_Simple_OTC(order)`
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     * @dev This function assumes that allowance of at least `order.orderBase.amountIn` of `order.orderBase.tokenIn` has already been provided
     *       by `order.orderBase.signer` to **this contract**.
     * @dev Allowance can be be provided by first calling `permit` on an ERC2612 token (either in a prior transaction or within the same transaction).
     */
    function fulfillOrder_Simple_OTC(
        IBridgelessCallee swapper,
        BridgelessOrder_Simple_OTC calldata order,
        Signature calldata signature,
        bytes calldata extraCalldata
    )   
        external virtual
        // @dev Modifier to verify that order is still valid
        checkOrderDeadline(order.orderBase.deadline)
        // @dev Modifier to verify correct order execution
        checkOrderFulfillment(order.orderBase.signer, order.orderBase.tokenOut, order.orderBase.amountOutMin)
        // @dev nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        // @dev Verify that `order.orderBase.signer` did indeed sign `order` and that it is still valid, then mark the orderHash as spent
        _processOrderSignature_Simple_OTC(order, signature);
        // @dev Fulfill the `order`
        _fulfillOrder_Base(
            swapper,
            order.orderBase,
            extraCalldata
        );
    }

    /**
     * @notice Fulfills a single `BridgelessOrder_WithNonce`, swapping `order.orderBase.amountIn` of the ERC20 token `order.orderBase.tokenIn` for
     *          *at least* `order.orderBase.amountOutMin` of `order.orderBase.TokenOut`.
     * @notice Note that an input of `order.orderBase.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from `order.orderBase.signer` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCall(order, extraCalldata)`.
     * @param order A valid `BridgelessOrder_WithNonce` created by `order.orderBase.signer`, specifying their desired order parameters.
     * @param signature A valid ECDSA signature of `order` provided by `order.orderBase.signer`. This signature is verified
     *        by checking against `calculateBridgelessOrderHash_WithNonce(order)`
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     * @dev This function assumes that allowance of at least `order.orderBase.amountIn` of `order.orderBase.tokenIn` has already been provided
     *       by `order.orderBase.signer` to **this contract**.
     * @dev Allowance can be be provided by first calling `permit` on an ERC2612 token (either in a prior transaction or within the same transaction).
     */
    function fulfillOrder_WithNonce(
        IBridgelessCallee swapper,
        BridgelessOrder_WithNonce calldata order,
        Signature calldata signature,
        bytes calldata extraCalldata
    )   
        external virtual
        // @dev Modifier to verify that order is still valid
        checkOrderDeadline(order.orderBase.deadline)
        // @dev Modifier to verify correct order execution
        checkOrderFulfillment(order.orderBase.signer, order.orderBase.tokenOut, order.orderBase.amountOutMin)
        // @dev nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        // @dev Verify that `order.orderBase.signer` did indeed sign `order` and that it is still valid, then mark the orderHash as spent
        _processOrderSignature_WithNonce(order, signature);
        // @dev Fulfill the `order`
        _fulfillOrder_Base(
            swapper,
            order.orderBase,
            extraCalldata
        );
    }

    /**
     * @notice Fulfills a single `BridgelessOrder_WithNonce_OTC`, swapping `order.orderBase.amountIn` of the ERC20 token `order.orderBase.tokenIn` for
     *          *at least* `order.orderBase.amountOutMin` of `order.orderBase.TokenOut`.
     * @notice Note that an input of `order.orderBase.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from `order.orderBase.signer` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCall(order, extraCalldata)`.
     * @param order.orderBase.signer Address of the user whose order is being fulfilled.
     * @param order A valid `BridgelessOrder_WithNonce_OTC` created by `order.orderBase.signer`, specifying their desired order parameters.
     * @param signature A valid ECDSA signature of `order` provided by `order.orderBase.signer`. This signature is verified
     *        by checking against `calculateBridgelessOrderHash_WithNonce(order)`
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     * @dev This function assumes that allowance of at least `order.orderBase.amountIn` of `order.orderBase.tokenIn` has already been provided
     *       by `order.orderBase.signer` to **this contract**.
     * @dev Allowance can be be provided by first calling `permit` on an ERC2612 token (either in a prior transaction or within the same transaction).
     */
    function fulfillOrder_WithNonce_OTC(
        IBridgelessCallee swapper,
        BridgelessOrder_WithNonce_OTC calldata order,
        Signature calldata signature,
        bytes calldata extraCalldata
    )   
        external virtual
        // @dev Modifier to verify that order is still valid
        checkOrderDeadline(order.orderBase.deadline)
        // @dev Modifier to verify correct order execution
        checkOrderFulfillment(order.orderBase.signer, order.orderBase.tokenOut, order.orderBase.amountOutMin)
        // @dev nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        // @dev Verify that `order.orderBase.signer` did indeed sign `order` and that it is still valid, then mark the orderHash as spent
        _processOrderSignature_WithNonce_OTC(order, signature);
        // @dev Fulfill the `order`
        _fulfillOrder_Base(
            swapper,
            order.orderBase,
            extraCalldata
        );
    }


    /**
     * @notice Fulfills a single `BridgelessOrder_OptionalParameters`, swapping `order.orderBase.amountIn` of the ERC20 token `order.orderBase.tokenIn` for
     *          *at least* `order.orderBase.amountOutMin` of `order.orderBase.TokenOut`.
     * @notice Note that an input of `order.orderBase.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from `order.orderBase.signer` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCall(order, extraCalldata)`.
     * @param order A valid `BridgelessOrder_OptionalParameters` created by `order.orderBase.signer`, specifying their desired order parameters.
     * @param signature A valid ECDSA signature of `order` provided by `order.orderBase.signer`. This signature is verified
     *        by checking against `calculateBridgelessOrderHash_OptionalParameters(order)`
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     * @dev This function assumes that allowance of at least `order.orderBase.amountIn` of `order.orderBase.tokenIn` has already been provided
     *       by `order.orderBase.signer` to **this contract**.
     * @dev Allowance can be be provided by first calling `permit` on an ERC2612 token (either in a prior transaction or within the same transaction).
     */
    function fulfillOrder_OptionalParameters(
        IBridgelessCallee swapper,
        BridgelessOrder_OptionalParameters calldata order,
        Signature calldata signature,
        bytes calldata extraCalldata
    )   
        external virtual
        // @dev Modifier to verify that order is still valid
        checkOrderDeadline(order.orderBase.deadline)
        // @dev Modifier to verify correct order execution
        checkOrderFulfillment(order.orderBase.signer, order.orderBase.tokenOut, order.orderBase.amountOutMin)
        // @dev nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        // @dev Verify that `order.orderBase.signer` did indeed sign `order` and that it is still valid, then mark the orderHash as spent
        _processOrderSignature_OptionalParameters(order, signature);

        processOptionalParameters(order.orderBase, order.optionalParameters);
        // @dev Fulfill the `order`
        _fulfillOrder_Base(
            swapper,
            order.orderBase,
            extraCalldata
        );
    }



    /**
     * @notice Fulfills any arbitrary number of `BridgelessOrder_Simple`s, swapping `order.orderBase.amountIn`
     *         of the ERC20 token `orders[i].orderBase.tokenIn` for *at least* `orders[i].orderBase.amountOutMin` of `orders[i].orderBase.TokenOut`.
     * @notice Note that an input of `order.orderBase.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from each of the `order.signer`s to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCalls(orders, extraCalldata)`
     * @param orders A valid set of `BridgelessOrder_Simple`s created by `order.signer`s, specifying their desired order parameters.
     * @param signatures A valid set of ECDSA signatures of `orders` provided by `order.signer`s. These signature are verified
     *        by checking against `calculateBridgelessOrderHash_Simple(orders[i])`
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     * @dev This function assumes that allowance of at least `order.orderBase.amountIn` of `order.orderBase.tokenIn` has already been provided
     *       by `order.orderBase.signer` to **this contract**.
     * @dev Allowance can be be provided by first calling `permit` on an ERC2612 token (either in a prior transaction or within the same transaction).
     */

    function fulfillOrders_Simple(
        IBridgelessCallee swapper,
        BridgelessOrder_Simple[] calldata orders,
        Signature[] calldata signatures,
        bytes calldata extraCalldata
    )
        public virtual
        // nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        // cache array length in memory
        uint256 ordersLength = orders.length;
        // @dev Sanity check on input lengths.
        {
            require(
                ordersLength == signatures.length,
                "Bridgeless.fulfillOrders: orders.length != signatures.length"
            );
        }

        // @dev Verify that the `orders` are all still valid.
        {
            for (uint256 i; i < ordersLength;) {
                _checkOrderDeadline(orders[i].orderBase.deadline);
                unchecked {
                    ++i;
                }
            }
        }

        // @dev Verify that the `order.signer`s did indeed sign the `orders`.
        {
            for (uint256 i; i < ordersLength;) {
                _processOrderSignature_Simple(orders[i], signatures[i]);
                unchecked {
                    ++i;
                }
            }
        }

        // @dev Get the `order.signer`'s balances of the `tokenOut`s and cache them in memory, prior to any swap.
        uint256[] memory ownerBalancesBefore = new uint256[](ordersLength);
        // scoped block used here to 'avoid stack too deep' errors
        {
            for (uint256 i; i < ordersLength;) {
                ownerBalancesBefore[i] = _getUserBalance(orders[i].orderBase.signer, orders[i].orderBase.tokenOut);
                unchecked {
                    ++i;
                }
            }
        }

        // @dev Optimisically transfer all of the tokens to `swapper`
        {
            for (uint256 i; i < ordersLength;) {
                IERC20(orders[i].orderBase.tokenIn).safeTransferFrom(orders[i].orderBase.signer, address(swapper), orders[i].orderBase.amountIn);
                unchecked {
                    ++i;
                }
            }
        }

        // @notice Forward on inputs and pass transaction execution onto arbitrary `swapper` contract
        BridgelessOrder_Base[] memory orderBases = new BridgelessOrder_Base[](ordersLength);
        {
            for (uint256 i; i < ordersLength;) {
                orderBases[i] = orders[i].orderBase;
                unchecked {
                    ++i;
                }
            }
        }        swapper.bridgelessCalls(orderBases, extraCalldata);

        // @de Verify that each of the `order.signer`s received *at least* `orders[i].orderBase.amountOutMin` in `tokenOut[i]` from the swap.
        for (uint256 i; i < ordersLength;) {
            require(
                _getUserBalance(orders[i].orderBase.signer, orders[i].orderBase.tokenOut) - ownerBalancesBefore[i] >= orders[i].orderBase.amountOutMin,
                "Bridgeless.fulfillOrders: orders[i].orderBase.amountOutMin not met!"
            );
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Fulfills a single `BridgelessOrder`, swapping `order.amountIn` of the ERC20 token `order.tokenIn` for *at least*
     *          `order.amountOutMin` of `order.TokenOut`.
     * @notice Note that an input of `order.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from `order.signer` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCall(order, extraCalldata)`.
     * @param order A valid `BridgelessOrder` created by `order.signer`, specifying their desired order parameters.
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     * @dev This function assumes that allowance of at least `order.order.amountIn` of `order.order.tokenIn` has already been provided
     *       by `order.order.signer` to **this contract**.
     * @dev Allowance can be be provided by first calling `permit` on an ERC2612 token (either in a prior transaction or within the same transaction).
     */
    function _fulfillOrder(
        IBridgelessCallee swapper,
        BridgelessOrder calldata order,
        bytes calldata extraCalldata
    )
        internal
    {
        // @dev Optimisically transfer the tokens from `order.signer` to `swapper`
        IERC20(order.tokenIn).safeTransferFrom(order.signer, address(swapper), order.amountIn);

        // @notice Forward on inputs and pass transaction execution onto arbitrary `swapper` contract
        /**
         * @notice Forward on the order inputs and pass transaction execution onto arbitrary `swapper` contract.
         *          `extraCalldata` can be any set of execution instructions for the `swapper`
         * @notice After execution of `swapper` completes, control is handed back to this contract and order fulfillment is verified.
         */
        swapper.bridgelessCall(order, extraCalldata);   
    }

    /**
     * @notice Fulfills a single `BridgelessOrder_Base`, swapping `orderBase.amountIn` of the ERC20 token `orderBase.tokenIn` for *at least*
     *          `orderBase.amountOutMin` of `orderBase.TokenOut`.
     * @notice Note that an input of `orderBase.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from `orderBase.signer` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCall(order, extraCalldata)`.
     * @param orderBase A valid `BridgelessOrder_Base` created by `orderBase.signer`, specifying their desired order parameters.
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     * @dev This function assumes that allowance of at least `order.orderBase.amountIn` of `order.orderBase.tokenIn` has already been provided
     *       by `order.orderBase.signer` to **this contract**.
     * @dev Allowance can be be provided by first calling `permit` on an ERC2612 token (either in a prior transaction or within the same transaction).
     */
    function _fulfillOrder_Base(
        IBridgelessCallee swapper,
        BridgelessOrder_Base calldata orderBase,
        bytes calldata extraCalldata
    )
        internal
    {
        // @dev Optimisically transfer the tokens from `orderBase.signer` to `swapper`
        IERC20(orderBase.tokenIn).safeTransferFrom(orderBase.signer, address(swapper), orderBase.amountIn);

        // @notice Forward on inputs and pass transaction execution onto arbitrary `swapper` contract
        /**
         * @notice Forward on the order inputs and pass transaction execution onto arbitrary `swapper` contract.
         *          `extraCalldata` can be any set of execution instructions for the `swapper`
         * @notice After execution of `swapper` completes, control is handed back to this contract and order fulfillment is verified.
         */
        swapper.bridgelessCall(orderBase, extraCalldata);   
    }

    // fetches the `user`'s balance of `token`, where `token == address(0)` indicates the chain's native token
    function _getUserBalance(address user, address token) internal view returns (uint256) {
        if (token == address(0)) {
            return user.balance;
        } else {
            return IERC20(token).balanceOf(user);
        }
    }
}
