// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./BridgelessStructs.sol";
import "./interfaces/IBridgelessCallee.sol";

import "forge-std/Test.sol";

contract Bridgeless is
    BridgelessStructs,
    ReentrancyGuard
    ,DSTest
{
    Vm cheats = Vm(HEVM_ADDRESS);
    using SafeERC20 for IERC20;
    /// @notice The EIP-712 typehash for the contract's domain
    // bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract");
    bytes32 public constant DOMAIN_TYPEHASH = 0x4e2c4bf03f58b0b9d87019acd26e490aca9f5097fac5fd3eed5cccf6342a8d85;

    // struct BridgelessOrder_Base {
    //     // ERC20 token to trade
    //     address tokenIn;
    //     // amount of token to trade
    //     uint256 amountIn;
    //     // desired token to trade into
    //     address tokenOut;
    //     // minimum amount of native token to receive
    //     uint256 amountOutMin;
    //     // signature expiration
    //     uint256 deadline;
    // }
    /// @notice The EIP-712 typehash for the `ORDER_TYPEHASH_Base` order struct used by the contract
    bytes32 public constant ORDER_TYPEHASH_Base = keccak256(
        "BridgelessOrder_Base(address tokenIn,uint256 amountIn, address tokenOut,uint256 amountOutMin,uint256 deadline)");

    /// @notice The EIP-712 typehash for the `ORDER_TYPEHASH_Base` order struct used by the contract
    bytes32 public constant ORDER_TYPEHASH_WithNonce = keccak256(
        "BridgelessOrder_WithNonce(BridgelessOrder_Base orderBase,uint256 nonce)");

    /// @notice EIP-712 Domain separator
    bytes32 public immutable DOMAIN_SEPARATOR;

    // signer => nonce => whether or not the nonce has been spent already
    mapping(address => mapping(uint256 => bool)) public nonceIsSpent;

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

    // set immutable variables
    constructor()
    {
        // initialize the immutable DOMAIN_SEPARATOR for signatures
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(DOMAIN_TYPEHASH, bytes("Bridgeless"), block.chainid, address(this))
        );
    }

    /**
     * @notice Fulfills a single `BridgelessOrder_Simple`, swapping `order.orderBase.amountIn` of the ERC20 token `order.orderBase.tokenIn` for
     *          *at least* `order.orderBase.amountOutMin` of `order.orderBase.TokenOut`.
     * @notice Note that an input of `order.orderBase.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from `tokenOwner` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCall(tokenOwner, order, extraCalldata)`.
     * @param tokenOwner Address of the user whose order is being fulfilled.
     * @param order A valid `BridgelessOrder_Simple` created by `tokenOwner`, specifying their desired order parameters.
     * @param signature A valid ECDSA signature of `order` provided by `tokenOwner`. This signature is verified
     *        by checking against `calculateBridgelessOrderHash_Simple(order)`
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     * @dev This function assumes that allowance of at least `order.orderBase.amountIn` of `order.orderBase.tokenIn` has already been provided by `tokenOwner` to **this contract**.
     *      Allowance can be be provided by first calling `permit` on an ERC2612 token (either in a prior transaction or within the same transaction).
     */
    function fulfillOrder_Simple(
        IBridgelessCallee swapper,
        address tokenOwner,
        BridgelessOrder_Simple calldata order,
        Signature calldata signature,
        bytes calldata extraCalldata
    )   
        public virtual
        // @dev Modifier to verify that order is still valid
        checkOrderDeadline(order.orderBase.deadline)
        // @dev Modifier to verify correct order execution
        checkOrderFulfillment(tokenOwner, order.orderBase.tokenOut, order.orderBase.amountOutMin)
        // @dev nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        // @dev Verify that `tokenOwner` did indeed sign `order` and that it is still valid
        _checkOrderSignature_Simple(tokenOwner, order, signature);
        _fulfillOrder_Base(
            swapper,
            tokenOwner,
            order.orderBase,
            extraCalldata
        );
    }


    /**
     * @notice Fulfills a single `BridgelessOrder_WithNonce`, swapping `order.orderBase.amountIn` of the ERC20 token `order.orderBase.tokenIn` for
     *          *at least* `order.orderBase.amountOutMin` of `order.orderBase.TokenOut`.
     * @notice Note that an input of `order.orderBase.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from `tokenOwner` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCall(tokenOwner, order, extraCalldata)`.
     * @param tokenOwner Address of the user whose order is being fulfilled.
     * @param order A valid `BridgelessOrder_WithNonce` created by `tokenOwner`, specifying their desired order parameters.
     * @param signature A valid ECDSA signature of `order` provided by `tokenOwner`. This signature is verified
     *        by checking against `calculateBridgelessOrderHash_WithNonce(order)`
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     * @dev This function assumes that allowance of at least `order.orderBase.amountIn` of `order.orderBase.tokenIn` has already been provided by `tokenOwner` to **this contract**.
     *      Allowance can be be provided by first calling `permit` on an ERC2612 token (either in a prior transaction or within the same transaction).
     */
    function fulfillOrder_WithNonce(
        IBridgelessCallee swapper,
        address tokenOwner,
        BridgelessOrder_WithNonce calldata order,
        Signature calldata signature,
        bytes calldata extraCalldata
    )   
        external virtual
        // @dev Modifier to verify that order is still valid
        checkOrderDeadline(order.orderBase.deadline)
        // @dev Modifier to verify correct order execution
        checkOrderFulfillment(tokenOwner, order.orderBase.tokenOut, order.orderBase.amountOutMin)
        // @dev nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        // @dev Verify that `tokenOwner` did indeed sign `order` and that it is still valid
        _checkOrderSignature_WithNonce(tokenOwner, order, signature);
        _fulfillOrder_Base(
            swapper,
            tokenOwner,
            order.orderBase,
            extraCalldata
        );
    }

    /**
     * @notice Fulfills any arbitrary number of `BridgelessOrder_Simple`s, swapping `order.orderBase.amountIn`
     *         of the ERC20 token `orders[i].orderBase.tokenIn` for *at least* `orders[i].orderBase.amountOutMin` of `orders[i].orderBase.TokenOut`.
     * @notice Note that an input of `order.orderBase.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from each of the `tokenOwners` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCalls(tokenOwners, orders, extraCalldata)`
     * @param tokenOwners Addresses of the users whose orders are being fulfilled.
     * @param orders A valid set of `BridgelessOrder_Simple`s created by `tokenOwners`, specifying their desired order parameters.
     * @param signatures A valid set of ECDSA signatures of `orders` provided by `tokenOwners`. Thess signature are verified
     *        by checking against `calculateBridgelessOrderHash_Simple(orders[i])`
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     * @dev This function assumes that allowance of at least `order.orderBase.amountIn` of `order.orderBase.tokenIn` has already been provided by `tokenOwner` to **this contract**,
     *      as well as *for each order*.
     *      Allowance can be be provided by first calling `permit` on an ERC2612 token (either in a prior transaction or within the same transaction).
     */

    function fulfillOrders_Simple(
        IBridgelessCallee swapper,
        address[] calldata tokenOwners,
        BridgelessOrder_Simple[] calldata orders,
        Signature[] calldata signatures,
        bytes calldata extraCalldata
    )
        public virtual
        // nonReentrant modifier since we hand over control of execution to the aribtrary contract input `swapper` later in this function
        nonReentrant
    {
        // cache array length in memory
        uint256 ownersLength = tokenOwners.length;
        // @dev Sanity check on input lengths.
        {
            require(
                ownersLength == orders.length,
                "Bridgeless.fulfillOrders: tokenOwners.length != orders.length"
            );
            require(
                ownersLength == signatures.length,
                "Bridgeless.fulfillOrders: tokenOwners.length != signatures.length"
            );
        }

        // @dev Verify that the `orders` are all still valid.
        {
            for (uint256 i; i < ownersLength;) {
                _checkOrderDeadline(orders[i].orderBase.deadline);
                unchecked {
                    ++i;
                }
            }
        }

        // @dev Verify that the `tokenOwners` did indeed sign the `orders`.
        {
            for (uint256 i; i < ownersLength;) {
                _checkOrderSignature_Simple(tokenOwners[i], orders[i], signatures[i]);
                unchecked {
                    ++i;
                }
            }
        }

        // @dev Get the `tokenOwners`'s balances of the `tokenOut`s and cache them in memory, prior to any swap.
        uint256[] memory ownerBalancesBefore = new uint256[](ownersLength);
        // scoped block used here to 'avoid stack too deep' errors
        {
            for (uint256 i; i < ownersLength;) {
                ownerBalancesBefore[i] = _getUserBalance(tokenOwners[i], orders[i].orderBase.tokenOut);
                unchecked {
                    ++i;
                }
            }
        }

        // @dev Optimisically transfer all of the tokens to `swapper`
        {
            for (uint256 i; i < ownersLength;) {
                IERC20(orders[i].orderBase.tokenIn).safeTransferFrom(tokenOwners[i], address(swapper), orders[i].orderBase.amountIn);
                unchecked {
                    ++i;
                }
            }
        }

        // @notice Forward on inputs and pass transaction execution onto arbitrary `swapper` contract
        BridgelessOrder_Base[] memory orderBases = new BridgelessOrder_Base[](ownersLength);
        {
            for (uint256 i; i < ownersLength;) {
                orderBases[i] = orders[i].orderBase;
                unchecked {
                    ++i;
                }
            }
        }        swapper.bridgelessCalls(tokenOwners, orderBases, extraCalldata);

        // @de Verify that each of the `tokenOwners` received *at least* `orders[i].orderBase.amountOutMin` in `tokenOut[i]` from the swap.
        for (uint256 i; i < ownersLength;) {
            require(
                _getUserBalance(tokenOwners[i], orders[i].orderBase.tokenOut) - ownerBalancesBefore[i] >= orders[i].orderBase.amountOutMin,
                "Bridgeless.fulfillOrders: orders[i].orderBase.amountOutMin not met!"
            );
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Simple getter function to calculate the `orderHash` for a `BridgelessOrder_Base`
     * @param orderBase A `BridgelessOrder_Base` ojbect
     */
    function calculateBridgelessOrderHash_Base(BridgelessOrder_Base calldata orderBase) public pure returns (bytes32) {
        return(
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH_Base,
                    orderBase.tokenIn,
                    orderBase.amountIn,
                    orderBase.tokenOut,
                    orderBase.amountOutMin,
                    orderBase.deadline
                )
            )
        );
    }

    /**
     * @notice Simple getter function to calculate the `orderHash` for a `BridgelessOrder_Simple`
     * @param order A `BridgelessOrder_Simple`-type order
     */
    function calculateBridgelessOrderHash_Simple(BridgelessOrder_Simple calldata order) public pure returns (bytes32) {
        return calculateBridgelessOrderHash_Base(order.orderBase);
    }

    /**
     * @notice Simple getter function to calculate the `orderHash` for a `BridgelessOrder_WithNonce`
     * @param order A `BridgelessOrder_WithNonce`-type order
     */
    function calculateBridgelessOrderHash_WithNonce(BridgelessOrder_WithNonce calldata order) public pure returns (bytes32) {
        return(
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH_WithNonce,
                    calculateBridgelessOrderHash_Base(order.orderBase),
                    order.nonce
                )
            )
        );
    }

    function _checkOrderSignature_Simple(address signer, BridgelessOrder_Simple calldata order, Signature calldata signature) internal pure {
        // verify the order signature
        require(
            signer == ECDSA.recover(
                // calculate the orderHash
                calculateBridgelessOrderHash_Simple(order),
                signature.v,
                signature.r,
                signature.s
            ),
            "Bridgeless._checkOrderSignature_Simple: signer != recoveredAddress"
        );
    }

    function _checkOrderSignature_WithNonce(address signer, BridgelessOrder_WithNonce calldata order, Signature calldata signature) internal {
        // check nonce validity
        if (nonceIsSpent[signer][order.nonce]) {
            revert("Bridgeless._checkOrderSignature_WithNonce: nonce is already spent");
        }
        // mark nonce as spent
        nonceIsSpent[signer][order.nonce] = true;
        // verify the order signature
        require(
            signer == ECDSA.recover(
                // calculate the orderHash
                calculateBridgelessOrderHash_WithNonce(order),
                signature.v,
                signature.r,
                signature.s
            ),
            "Bridgeless._checkOrderSignature_WithNonce: signer != recoveredAddress"
        );
    }

    function _checkOrderDeadline(uint256 deadline) internal view {
        require(
            block.timestamp <= deadline,
            "Bridgeless._checkOrderDeadline: block.timestamp > deadline"
        );
    }


    // fetches the `user`'s balance of `token`, where `token == address(0)` indicates the chain's native token
    function _getUserBalance(address user, address token) internal view returns (uint256) {
        if (token == address(0)) {
            return user.balance;
        } else {
            return IERC20(token).balanceOf(user);
        }
    }

    /**
     * @notice Fulfills a single `BridgelessOrder_Base`, swapping `orderBase.amountIn` of the ERC20 token `orderBase.tokenIn` for *at least*
     *          `orderBase.amountOutMin` of `orderBase.TokenOut`.
     * @notice Note that an input of `orderBase.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from `tokenOwner` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCall(tokenOwner, order, extraCalldata)`.
     * @param tokenOwner Address of the user whose order is being fulfilled.
     * @param orderBase A valid `BridgelessOrder_Base` created by `tokenOwner`, specifying their desired order parameters.
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     * @dev This function assumes that allowance of at least `orderBase.amountIn` of `orderBase.tokenIn` has already been provided by `tokenOwner` to **this contract**.
     *      Allowance can be be provided by first calling `permit` on an ERC2612 token (either in a prior transaction or within the same transaction).
     */
    function _fulfillOrder_Base(
        IBridgelessCallee swapper,
        address tokenOwner,
        BridgelessOrder_Base calldata orderBase,
        bytes calldata extraCalldata
    )
        internal
    {
        // @dev Optimisically transfer the tokens to `swapper`
        IERC20(orderBase.tokenIn).safeTransferFrom(tokenOwner, address(swapper), orderBase.amountIn);

        // @notice Forward on inputs and pass transaction execution onto arbitrary `swapper` contract
        /**
         * @notice Forward on the order inputs and pass transaction execution onto arbitrary `swapper` contract.
         *          `extraCalldata` can be any set of execution instructions for the `swapper`
         * @notice After execution of `swapper` completes, control is handed back to this contract and order fulfillment is verified.
         */
        swapper.bridgelessCall(tokenOwner, orderBase, extraCalldata);   
    }

}
