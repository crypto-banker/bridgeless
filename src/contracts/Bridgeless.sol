// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./BridgelessOrderSignatures.sol";
import "./interfaces/IBridgelessCallee.sol";

// import "forge-std/Test.sol";

contract Bridgeless is
    BridgelessOrderSignatures,
    ReentrancyGuard
    // ,DSTest
{
    // Vm cheats = Vm(HEVM_ADDRESS);
    using SafeERC20 for IERC20;

    /**
     *  BitMap for storing (orderHash => whether or not the partialFill order corresponding to the orderHash is 'active' or not).
     *  A single BitMap entry can be read by using the `partialFillOrderIsActive(orderHash)` function
     */
    mapping(uint256 => uint256) public partialFillOrderActiveBitMap;

    function partialFillOrderIsActive(bytes32 orderHash) public view returns (bool) {
        uint256 bucket = (uint256(orderHash) >> 8);
        uint256 mask = 1 << ((uint256(orderHash) & 0xff));
        return ((partialFillOrderActiveBitMap[bucket] & mask) != 0);
    }

    // Check an order deadline. Orders must be executed at or before the UTC timestamp specified by their `deadline`.
    modifier checkOrderDeadline(uint256 deadline) {
        require(
            block.timestamp <= deadline,
            "Bridgeless.checkOrderDeadline: block.timestamp > deadline"
        );
        _;
    }

    event PartialFillStorageCreated(bytes32 indexed newOrderHash, BridgelessOrder indexed order, uint256 tokensTransferredOut, uint256 tokensObtained);

    /**
     * @notice Fulfills a single `BridgelessOrder`, swapping `order.amountIn` of the ERC20 token `order.tokenIn` for
     *          *at least* `order.amountOutMin` of `order.TokenOut`.
     * @notice Note that an input of `order.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from `order.signer` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCall(order, extraCalldata)`.
     * @param order A valid `BridgelessOrder` created by `order.signer`, specifying their desired order parameters.
     * @param signature A valid ECDSA signature, of `order` provided by `order.signer`. This signature is verified
     *        by checking against `calculateBridgelessOrderHash(order)`. Signatures should be packed into 64 byte format (r, vs), rather than (v, r, s) format
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     * @dev This function assumes that allowance of at least `order.amountIn` of `order.tokenIn` has already been provided
     *       by `order.signer` to **this contract**.
     * @dev Allowance can be be provided by first calling `permit` on an ERC2612 token (either in a prior transaction or within the same transaction).
     */
    function fulfillOrder(
        IBridgelessCallee swapper,
        BridgelessOrder calldata order,
        PackedSignature calldata signature,
        bytes calldata extraCalldata
    )   
        public virtual
        // @dev Modifier to verify that order is still valid
        checkOrderDeadline(order.deadline)
        // @dev nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        // @dev Verify that `order.signer` did indeed sign `order`, then mark the order nonce as spent
        _processOrderSignature(order, signature);
        // @dev check the optional order parameters
        bool partialFill = processOptionalParameters(order.optionalParameters);
        // get the `order.signer`'s balance of the `order.tokenOut`, *prior* to transferring tokens
        uint256 tokenOutBalanceBefore = _getUserBalance(order.signer, order.tokenOut);
        uint256 tokenInBalanceBefore;
        if (partialFill) {
            tokenInBalanceBefore = _getUserBalance(order.signer, order.tokenIn);
        }
        // @dev Optimisically transfer the tokens from `order.signer` to `swapper`
        IERC20(order.tokenIn).safeTransferFrom(order.signer, address(swapper), order.amountIn);

        /**
         * @notice Forward on the order inputs and pass transaction execution onto arbitrary `swapper` contract.
         *          `extraCalldata` can be any set of execution instructions for the `swapper`
         * @notice After execution of `swapper` completes, control is handed back to this contract and order fulfillment is verified.
         */
        swapper.bridgelessCall(order, extraCalldata);

        if (!partialFill) {
            // verify that the `order.signer` received *at least* `amountOutMin` in `order.tokenOut` *after* `swapper` execution has completed
            require(
                _getUserBalance(order.signer, order.tokenOut) - tokenOutBalanceBefore >= order.amountOutMin,
                "Bridgeless.fulfillOrder: amountOutMin not met!"
            );
        } else {
            uint256 tokensObtained = _getUserBalance(order.signer, order.tokenOut) - tokenOutBalanceBefore;
            // i.e. if order was indeed only partially filled
            if (tokensObtained < order.amountOutMin) {
                uint256 tokensTransferredOut = tokenInBalanceBefore - _getUserBalance(order.signer, order.tokenIn);
                /**
                 * ensure that the `order.signer` got *at least* the swap ratio specified in their order
                 * i.e. we want to check that (tokensObtained / tokensTransferredOut) >= (order.amountOutMin / order.amountIn)
                 * but this is equivalent to checking that (tokensObtained * order.amountIn) / (tokensTransferredOut * order.amountOutMin) >= 1
                 */
                require(
                    (tokensObtained * order.amountIn) / (tokensTransferredOut * order.amountOutMin) >= 1,
                    "Bridgeless.fulfillOrder: partialFillOrder swap ratio not met!"
                );
                _createPartialFillStorage(order, tokensTransferredOut, tokensObtained);
            }
        }
    }

    function fulfillOrderFromStorage(
        IBridgelessCallee swapper,
        BridgelessOrder calldata order,
        bytes calldata extraCalldata
    )   
        public virtual
        // @dev Modifier to verify that order is still valid
        checkOrderDeadline(order.deadline)
        // @dev nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        _markAsNoLongerActive(order);

        // @dev Check the optional order parameters. Ignore the return value here since we already know this is a partialFill order
        processOptionalParameters(order.optionalParameters);

        // get the `order.signer`'s balance of the `order.tokenOut`, *prior* to transferring tokens
        uint256 tokenOutBalanceBefore = _getUserBalance(order.signer, order.tokenOut);
        uint256 tokenInBalanceBefore = _getUserBalance(order.signer, order.tokenIn);
        // @dev Optimisically transfer the tokens from `order.signer` to `swapper`
        IERC20(order.tokenIn).safeTransferFrom(order.signer, address(swapper), order.amountIn);

        /**
         * @notice Forward on the order inputs and pass transaction execution onto arbitrary `swapper` contract.
         *          `extraCalldata` can be any set of execution instructions for the `swapper`
         * @notice After execution of `swapper` completes, control is handed back to this contract and order fulfillment is verified.
         */
        swapper.bridgelessCall(order, extraCalldata);

        uint256 tokensObtained = _getUserBalance(order.signer, order.tokenOut) - tokenOutBalanceBefore;
        // i.e. if order was indeed only partially filled
        if (tokensObtained < order.amountOutMin) {
            uint256 tokensTransferredOut = tokenInBalanceBefore - _getUserBalance(order.signer, order.tokenIn);
            /**
             * ensure that the `order.signer` got *at least* the swap ratio specified in their order
             * i.e. we want to check that (tokensObtained / tokensTransferredOut) >= (order.amountOutMin / order.amountIn)
             * but this is equivalent to checking that (tokensObtained * order.amountIn) / (tokensTransferredOut * order.amountOutMin) >= 1
             */
            require(
                (tokensObtained * order.amountIn) / (tokensTransferredOut * order.amountOutMin) >= 1,
                "Bridgeless.fulfillOrderFromStorage: partialFillOrder swap ratio not met!"
            );
            _createPartialFillStorage(order, tokensTransferredOut, tokensObtained);
        }
    }

    function _createPartialFillStorage(BridgelessOrder calldata order, uint256 tokensTransferredOut, uint256 tokensObtained) internal {
        // set the storage slot
        bytes32 newOrderHash = calculateBridgelessOrderHash_PartialFill(order, tokensTransferredOut, tokensObtained);
        uint256 bucket = (uint256(newOrderHash) >> 8);
        uint256 mask = 1 << ((uint256(newOrderHash) & 0xff));
        partialFillOrderActiveBitMap[bucket] = (partialFillOrderActiveBitMap[bucket] | mask);
        // emit an event
        emit PartialFillStorageCreated(newOrderHash, order, tokensTransferredOut, tokensObtained);
    }

    function fulfillOrdersFromStorage(
        IBridgelessCallee swapper,
        BridgelessOrder[] calldata orders,
        bytes calldata extraCalldata
    )   
        public virtual
        // @dev nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        // cache array length in memory
        uint256 ordersLength = orders.length;
        // @dev Verify that the `orders` are all still 'active' and then mark them as no longer active.
        {
            for (uint256 i; i < ordersLength;) {
                _markAsNoLongerActive(orders[i]);
                unchecked {
                    ++i;
                }
            }
        }

        {
            for (uint256 i; i < ordersLength;) {
                // @dev Check the optional order parameters. Ignore the return value here since we already know this is a partialFill order
                processOptionalParameters(orders[i].optionalParameters);
                unchecked {
                    ++i;
                }
            }
        }

        // @dev Get the `orders[i].signer`'s balances of the `tokenOut`s & `tokenIn`'s, and cache them in memory, prior to any swap.
        uint256[] memory tokenOutBalancesBefore = new uint256[](ordersLength);
        uint256[] memory tokenInBalancesBefore = new uint256[](ordersLength);
        // scoped block used here to 'avoid stack too deep' errors
        {
            for (uint256 i; i < ordersLength;) {
                tokenOutBalancesBefore[i] = _getUserBalance(orders[i].signer, orders[i].tokenOut);
                tokenInBalancesBefore[i] = _getUserBalance(orders[i].signer, orders[i].tokenIn);
                unchecked {
                    ++i;
                }
            }
        }

        // @dev Optimisically transfer all of the tokens to `swapper`
        {
            for (uint256 i; i < ordersLength;) {
                IERC20(orders[i].tokenIn).safeTransferFrom(orders[i].signer, address(swapper), orders[i].amountIn);
                unchecked {
                    ++i;
                }
            }
        }

        // @notice Forward on inputs and pass transaction execution onto arbitrary `swapper` contract
        swapper.bridgelessCalls(orders, extraCalldata);

        {
            for (uint256 i; i < ordersLength;) {
                uint256 tokensObtained = _getUserBalance(orders[i].signer, orders[i].tokenOut) - tokenOutBalancesBefore[i];
                // i.e. if order was indeed only partially filled
                if (tokensObtained < orders[i].amountOutMin) {
                    uint256 tokensTransferredOut = tokenInBalancesBefore[i] - _getUserBalance(orders[i].signer, orders[i].tokenIn);
                    /**
                     * ensure that the `orders[i].signer` got *at least* the swap ratio specified in their order
                     * i.e. we want to check that (tokensObtained / tokensTransferredOut) >= (orders[i].amountOutMin / orders[i].amountIn)
                     * but this is equivalent to checking that (tokensObtained * orders[i].amountIn) / (tokensTransferredOut * orders[i].amountOutMin) >= 1
                     */
                    require(
                        (tokensObtained * orders[i].amountIn) / (tokensTransferredOut * orders[i].amountOutMin) >= 1,
                        "Bridgeless.fulfillOrder: partialFillOrder swap ratio not met!"
                    );
                    _createPartialFillStorage(orders[i], tokensTransferredOut, tokensObtained);
                    unchecked {
                        ++i;
                    }
                }
            }
        }
    }

    function fulfillOrdersPartiallyFromStorage(
        IBridgelessCallee swapper,
        BridgelessOrder[] calldata orders,
        PackedSignature[] calldata signatures,
        uint256 fromStorageBitMap,
        bytes calldata extraCalldata
    )
        public virtual
        // nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        // cache array length in memory
        uint256 ordersLength = orders.length;

        // Used to store up to 256 boolean values. NOTE: Using this means assuming <= 256 orders in this call
        uint256 totalPartialFills;
        uint256 totalOrdersFromStorage;

        // @dev Verify that the `orders` are all still valid.
        {
            for (uint256 i; i < ordersLength;) {
                _checkOrderDeadline(orders[i].deadline);
                unchecked {
                    ++i;
                }
            }
        }

        // @dev Verify that the `order.signer`s did indeed sign the `orders`.
        // @dev For the *new* `orders`, mark their nonces as spent.
        // @dev For the `orders` *from storage*, check that they are 'active' and then mark them as no longer active.
        {
            bool partialFill;
            for (uint256 i; i < ordersLength;) {
                uint256 inputBitMapMask = 1 << ((uint256(i) & 0xff));
                // If i-th bit of `fromStorageBitMap` is a 1, indicating that the order is from storage
                if (fromStorageBitMap & inputBitMapMask != 0) {
                    // check that the provided `order` is the preimage of an 'active', stored orderHash, and then mark it as no longer active
                    _markAsNoLongerActive(orders[i]);
                    unchecked {
                        ++totalPartialFills;
                        ++totalOrdersFromStorage;
                    }
                    // @dev Check the optional order parameters. Ignore the return value here since we already know this is a partialFill order
                    processOptionalParameters(orders[i].optionalParameters);
                }
                // Otherwise order is *not* from storage
                else {
                    _processOrderSignature(orders[i], signatures[i]);     
                    // @dev check the optional order parameters
                    partialFill = processOptionalParameters(orders[i].optionalParameters);
                    // set transient BitMap entry and increment `totalPartialFills` if partialFill flag is set on order
                    if (partialFill) {
                        // write to `fromStorageBitMap` here, using it as a transient bitmap, since we've already passed the part where we mark it as spent
                        // uint256 mask = (1 << i);
                        // fromStorageBitMap = (fromStorageBitMap | mask);
                        fromStorageBitMap = (fromStorageBitMap | (1 << i));
                        unchecked {
                            ++totalPartialFills;
                        }
                    }
                }
                // increment loop regardless
                unchecked {
                    ++i;
                }
            }
        }

        // @dev Sanity check on input lengths.
        {
            require(
                ordersLength == signatures.length + totalOrdersFromStorage,
                "Bridgeless.fulfillOrdersPartiallyFromStorage: orders.length != signatures.length + totalOrdersFromStorage"
            );
        }

        // @dev Get the `order.signer`'s balances of the `tokenOut`s and cache them in memory, prior to any swap.
        uint256[] memory tokenOutBalancesBefore = new uint256[](ordersLength);
        // scoped block used here to 'avoid stack too deep' errors
        {
            for (uint256 i; i < ordersLength;) {
                tokenOutBalancesBefore[i] = _getUserBalance(orders[i].signer, orders[i].tokenOut);
                unchecked {
                    ++i;
                }
            }
        }

        uint256[] memory tokenInBalancesBefore = new uint256[](totalPartialFills);
        // scoped block used here to 'avoid stack too deep' errors
        {
            uint256 j;
            for (uint256 i; i < ordersLength;) {
                // read from transient BitMap
                // uint256 mask = (1 << i);
                // bool partialFill = ((fromStorageBitMap & (~mask)) != 0);
                if ((fromStorageBitMap & (~(1 << i))) != 0) {
                    tokenInBalancesBefore[j] = _getUserBalance(orders[i].signer, orders[i].tokenIn);
                    unchecked {
                        ++j;
                    }
                }
                unchecked {
                    ++i;
                }
            }
        }

        // @dev Optimisically transfer all of the tokens to `swapper`
        {
            for (uint256 i; i < ordersLength;) {
                IERC20(orders[i].tokenIn).safeTransferFrom(orders[i].signer, address(swapper), orders[i].amountIn);
                unchecked {
                    ++i;
                }
            }
        }

        // @notice Forward on inputs and pass transaction execution onto arbitrary `swapper` contract
        swapper.bridgelessCalls(orders, extraCalldata);

        {
            uint256 j;
            // @dev Verify that each of the `order.signer`s received *at least* `orders[i].amountOutMin` in `tokenOut[i]` from the swap.
            for (uint256 i; i < ordersLength;) {
                // read from transient BitMap
                // bool partialFill = ((fromStorageBitMap & (~mask)) != 0);
                // bool partialFill = ((fromStorageBitMap & (~(1 << i))) != 0);
                // If order is *not* a 'partialFill' order
                if (((fromStorageBitMap & (~(1 << i))) == 0)) {
                    // verify that the `order.signer` received *at least* `amountOutMin` in `order.tokenOut` *after* `swapper` execution has completed
                    require(
                        _getUserBalance(orders[i].signer, orders[i].tokenOut) - tokenOutBalancesBefore[i] >= orders[i].amountOutMin,
                        "Bridgeless.fulfillOrdersPartiallyFromStorage: amountOutMin not met!"
                    );
                } else {
                    uint256 tokensObtained = _getUserBalance(orders[i].signer, orders[i].tokenOut) - tokenOutBalancesBefore[i];
                    // i.e. if order was indeed only partially filled
                    if (tokensObtained < orders[i].amountOutMin) {
                        uint256 tokensTransferredOut = tokenInBalancesBefore[j] - _getUserBalance(orders[i].signer, orders[i].tokenIn);
                        /**
                         * ensure that the `order.signer` got *at least* the swap ratio specified in their order
                         * i.e. we want to check that (tokensObtained / tokensTransferredOut) >= (order.amountOutMin / order.amountIn)
                         * but this is equivalent to checking that (tokensObtained * order.amountIn) / (tokensTransferredOut * order.amountOutMin) >= 1
                         */
                        require(
                            (tokensObtained * orders[i].amountIn) / (tokensTransferredOut * orders[i].amountOutMin) >= 1,
                            "Bridgeless.fulfillOrdersPartiallyFromStorage: partialFillOrder swap ratio not met!"
                        );
                        _createPartialFillStorage(orders[i], tokensTransferredOut, tokensObtained);
                    }
                    unchecked {
                        ++j;
                    }
                }
                unchecked {
                    ++i;
                }
            }
        }
    }

    // check that the provided `order` is the preimage of an 'active', stored orderHash, and then mark it as no longer active
    function _markAsNoLongerActive(BridgelessOrder calldata order) internal {
        // calculate the orderHash
        bytes32 orderHash = calculateBridgelessOrderHash(order);
        // verify that `orderHash` is 'active' (i.e. its bit flag is set to '1' in the `partialFillOrderActiveBitMap`)
        uint256 bucket = (uint256(orderHash) >> 8);
        uint256 mask = 1 << ((uint256(orderHash) & 0xff));
        require(
            (partialFillOrderActiveBitMap[bucket] & mask != 0),
            "Bridgeless._markAsNoLongerActive: partialFillOrder not active at orderHash"
        );
        // mark the `orderHash` as no longer 'active'
        partialFillOrderActiveBitMap[bucket] = partialFillOrderActiveBitMap[bucket] & (~mask);
    }

    /**
     * @notice Fulfills any arbitrary number of `BridgelessOrder`s, swapping `order.amountIn`
     *         of the ERC20 token `orders[i].tokenIn` for *at least* `orders[i].amountOutMin` of `orders[i].TokenOut`.
     * @notice Note that an input of `order.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from each of the `order.signer`s to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCalls(orders, extraCalldata)`
     * @param orders A valid set of `BridgelessOrder`s created by `order.signer`s, specifying their desired order parameters.
     * @param signatures A valid set of ECDSA signatures of `orders` provided by `order.signer`s. These signature are verified
     *        by checking against `calculateBridgelessOrderHash(orders[i])`. Signatures should be packed into 64 byte format (r, vs), rather than (v, r, s) format
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     * @dev This function assumes that allowance of at least `order.amountIn` of `order.tokenIn` has already been provided
     *       by `order.signer` to **this contract**.
     * @dev Allowance can be be provided by first calling `permit` on an ERC2612 token (either in a prior transaction or within the same transaction).
     */
    function fulfillOrders(
        IBridgelessCallee swapper,
        BridgelessOrder[] calldata orders,
        PackedSignature[] calldata signatures,
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
                _checkOrderDeadline(orders[i].deadline);
                unchecked {
                    ++i;
                }
            }
        }

        // @dev Verify that the `order.signer`s did indeed sign the `orders`, and mark their nonces as spent.
        {
            for (uint256 i; i < ordersLength;) {
                _processOrderSignature(orders[i], signatures[i]);
                unchecked {
                    ++i;
                }
            }
        }

        // Used to store up to 256 boolean values. NOTE: Using this means assuming <= 256 orders in this call
        uint256 transientPartialFillBitMap;
        uint256 totalPartialFills;

        // @dev check the optional order parameters
        {
            bool partialFill;
            for (uint256 i; i < ordersLength;) {
                partialFill = processOptionalParameters(orders[i].optionalParameters);
                // set transient BitMap entry and increment `totalPartialFills` if partialFill flag is set on order
                if (partialFill) {
                    // uint256 mask = (1 << i);
                    transientPartialFillBitMap = (transientPartialFillBitMap | (1 << i));
                    unchecked {
                        ++totalPartialFills;
                    }
                }
                unchecked {
                    ++i;
                }
            }
        }

        // @dev Get the `order.signer`'s balances of the `tokenOut`s and cache them in memory, prior to any swap.
        uint256[] memory tokenOutBalancesBefore = new uint256[](ordersLength);
        // scoped block used here to 'avoid stack too deep' errors
        {
            for (uint256 i; i < ordersLength;) {
                tokenOutBalancesBefore[i] = _getUserBalance(orders[i].signer, orders[i].tokenOut);
                unchecked {
                    ++i;
                }
            }
        }

        uint256[] memory tokenInBalancesBefore = new uint256[](totalPartialFills);
        // scoped block used here to 'avoid stack too deep' errors
        {
            uint256 j;
            for (uint256 i; i < ordersLength;) {
                // read from transient BitMap
                // mask = (1 << i);
                // bool partialFill = ((transientPartialFillBitMap & (~mask)) != 0);
                // bool partialFill = ((transientPartialFillBitMap & (~(1 << i))) != 0);
                if ((transientPartialFillBitMap & (~(1 << i))) != 0) {
                    tokenInBalancesBefore[j] = _getUserBalance(orders[i].signer, orders[i].tokenIn);
                    unchecked {
                        ++j;
                    }
                }
                unchecked {
                    ++i;
                }
            }
        }

        // @dev Optimisically transfer all of the tokens to `swapper`
        {
            for (uint256 i; i < ordersLength;) {
                IERC20(orders[i].tokenIn).safeTransferFrom(orders[i].signer, address(swapper), orders[i].amountIn);
                unchecked {
                    ++i;
                }
            }
        }

        // @notice Forward on inputs and pass transaction execution onto arbitrary `swapper` contract
        swapper.bridgelessCalls(orders, extraCalldata);

        {
            uint256 j;
            // @dev Verify that each of the `order.signer`s received *at least* `orders[i].amountOutMin` in `tokenOut[i]` from the swap.
            for (uint256 i; i < ordersLength;) {
                // read from transient BitMap
                // mask = (1 << i);
                // bool partialFill = ((transientPartialFillBitMap & (~mask)) != 0);
                // bool partialFill = ((transientPartialFillBitMap & (~(1 << i))) != 0);
                // If order is *not* a 'partialFill' order
                if (((transientPartialFillBitMap & (~(1 << i))) == 0)) {
                    // verify that the `order.signer` received *at least* `amountOutMin` in `order.tokenOut` *after* `swapper` execution has completed
                    require(
                        _getUserBalance(orders[i].signer, orders[i].tokenOut) - tokenOutBalancesBefore[i] >= orders[i].amountOutMin,
                        "Bridgeless.fulfillOrders: amountOutMin not met!"
                    );
                } else {
                    uint256 tokensObtained = _getUserBalance(orders[i].signer, orders[i].tokenOut) - tokenOutBalancesBefore[i];
                    // i.e. if order was indeed only partially filled
                    if (tokensObtained < orders[i].amountOutMin) {
                        uint256 tokensTransferredOut = tokenInBalancesBefore[j] - _getUserBalance(orders[i].signer, orders[i].tokenIn);
                        /**
                         * ensure that the `order.signer` got *at least* the swap ratio specified in their order
                         * i.e. we want to check that (tokensObtained / tokensTransferredOut) >= (order.amountOutMin / order.amountIn)
                         * but this is equivalent to checking that (tokensObtained * order.amountIn) / (tokensTransferredOut * order.amountOutMin) >= 1
                         */
                        require(
                            (tokensObtained * orders[i].amountIn) / (tokensTransferredOut * orders[i].amountOutMin) >= 1,
                            "Bridgeless.fulfillOrders: partialFillOrder swap ratio not met!"
                        );
                        _createPartialFillStorage(orders[i], tokensTransferredOut, tokensObtained);
                    }
                    unchecked {
                        ++j;
                    }
                }
                unchecked {
                    ++i;
                }
            }
        }
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
