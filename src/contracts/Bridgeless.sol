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
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract");

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
    /// @notice The EIP-712 typehash for the `ORDER_TYPEHASH_Simple` order struct used by the contract
    bytes32 public constant ORDER_TYPEHASH_Simple = keccak256(
        "BridgelessOrder_Simple(address tokenIn,uint256 amountIn, address tokenOut,uint256 amountOutMin,uint256 deadline)");

    /// @notice The EIP-712 typehash for the `ORDER_TYPEHASH_Simple` order struct used by the contract
    bytes32 public constant ORDER_TYPEHASH_WithNonce = keccak256(
        "BridgelessOrder_WithNonce(address tokenIn,uint256 amountIn, address tokenOut,uint256 amountOutMin,uint256 deadline,address nonce)");

    /// @notice EIP-712 Domain separator
    bytes32 public immutable DOMAIN_SEPARATOR;

    // signer => nonce => whether or not the nonce has been spent already
    mapping(address => mapping(uint256 => bool)) public nonceIsSpent;

    // verify that the `tokenOwner` receives *at least* `amountOutMin in `tokenOut` from the swap
    modifier checkOrderExecution(
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
            "Bridgeless.checkOrderExecution: amountOutMin not met!"
        );
    }

    // verify that each of the `tokenOwners` receives *at least* `orders[i].orderBase.amountOutMin` in `tokenOut[i]` from the swap

    // set immutable variables
    constructor()
    {
        // initialize the immutable DOMAIN_SEPARATOR for signatures
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(DOMAIN_TYPEHASH, bytes("Bridgeless"), block.chainid, address(this))
        );
    }

    /**
     * @notice Fulfills a single `BridgelessOrder_Simple`, swapping `order.orderBase.amountIn` of the ERC20 token `order.orderBase.tokenIn` for *at least* `order.orderBase.amountOutMin` of `order.orderBase.TokenOut`.
     * @notice Note that an input of `order.orderBase.tokenOut == address(0)` is used to indicate that the chain's *native token* is desired!
     * @notice This function assumes that `permit` has already been called, or allowance has elsewise been provided from `tokenOwner` to this contract!
     * @param swapper The `IBridgelessCallee`-type contract to be the recipient of a call to `swapper.bridgelessCall(tokenOwner, order, extraCalldata)`.
     * @param tokenOwner Address of the user whose order is being fulfilled.
     * @param order A valid `BridgelessOrder_Simple` created by `tokenOwner`, specifying their desired order parameters.
     * @param signature A valid ECDSA signature of `order` provided by `tokenOwner`. This signature is verified
     *        by checking against `calculateBridgelessOrderHash_Simple(order)`
     * @param extraCalldata "Optional" parameter that is simply passed onto `swapper` when it is called.
     */
    function fulfillOrder(
        IBridgelessCallee swapper,
        address tokenOwner,
        BridgelessOrder_Simple calldata order,
        Signature calldata signature,
        bytes calldata extraCalldata
    )   
        public virtual
        // nonReentrant since we hand over control of execution to an arbitrary contract later in this function
        nonReentrant
        // modifier to verify correct order execution
        checkOrderExecution(tokenOwner, order.orderBase.tokenOut, order.orderBase.amountOutMin)
    {
        // verify that `tokenOwner` did indeed sign `order` and that it is still valid
        _validateOrder_Simple(tokenOwner, order, signature);

        // optimisically transfer the tokens to `swapper`
        // assumes `permit` has already been called, or allowance has elsewise been provided!
        IERC20(order.orderBase.tokenIn).safeTransferFrom(tokenOwner, address(swapper), order.orderBase.amountIn);

        // forward on the swap instructions and pass execution to `swapper`
        // `extraCalldata` can be e.g. multiple DEX orders
        swapper.bridgelessCall(tokenOwner, order, extraCalldata);
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
     */
    function fulfillOrders(
        IBridgelessCallee swapper,
        address[] calldata tokenOwners,
        BridgelessOrder_Simple[] calldata orders,
        Signature[] calldata signatures,
        bytes calldata extraCalldata
    )
        public virtual
        // nonReentrant since we hand over control of execution to an arbitrary contract later in this function
        nonReentrant
    {
        // sanity check on input lengths
        uint256 ownersLength = tokenOwners.length;
        // scoped block used here to 'avoid stack too deep' errors
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

        // verify that `tokenOwners` did indeed sign `orders` and that they are still valid
        // scoped block used here to 'avoid stack too deep' errors
        {
            for (uint256 i; i < ownersLength;) {
                _validateOrder_Simple(tokenOwners[i], orders[i], signatures[i]);
                unchecked {
                    ++i;
                }
            }
        }

        // get the `tokenOwners`'s balances of the `tokenOut`s, prior to any swap
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

        // optimisically transfer the tokens to `swapper`
        // assumes `permit` has already been called, or allowance has elsewise been provided!
        // scoped block used here to 'avoid stack too deep' errors
        {
            for (uint256 i; i < ownersLength;) {
                IERC20(orders[i].orderBase.tokenIn).safeTransferFrom(tokenOwners[i], address(swapper), orders[i].orderBase.amountIn);
                unchecked {
                    ++i;
                }
            }
        }

        // forward on the swap instructions and pass execution to `swapper`
        // `extraCalldata` can be e.g. multiple DEX orders
        swapper.bridgelessCalls(tokenOwners, orders, extraCalldata);

        // verify that each of the `tokenOwners` received *at least* `orders[i].orderBase.amountOutMin` in `tokenOut[i]` from the swap
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
     * @notice Simple getter function to calculate the `orderHash` for a `BridgelessOrder_Simple`
     * @param order A `BridgelessOrder_Simple`-type order
     */
    function calculateBridgelessOrderHash_Simple(BridgelessOrder_Simple calldata order) public pure returns (bytes32) {
        return(
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH_Simple,
                    order.orderBase.tokenIn,
                    order.orderBase.amountIn,
                    order.orderBase.tokenOut,
                    order.orderBase.amountOutMin,
                    order.orderBase.deadline
                )
            )
        );
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
                    order.orderBase.tokenIn,
                    order.orderBase.amountIn,
                    order.orderBase.tokenOut,
                    order.orderBase.amountOutMin,
                    order.orderBase.deadline,
                    order.nonce
                )
            )
        );
    }

    function _validateOrder_Simple(address signer, BridgelessOrder_Simple calldata order, Signature calldata signature) internal view {
        // check order deadline
        require(
            block.timestamp <= order.orderBase.deadline,
            "Bridgeless._validateOrder_Simple: block.timestamp > order.orderBase.deadline"
        );

        // verify the order signature
        require(
            signer == ECDSA.recover(
                // calculate the orderHash
                calculateBridgelessOrderHash_Simple(order),
                signature.v,
                signature.r,
                signature.s
            ),
            "Bridgeless._validateOrder_Simple: signer != recoveredAddress"
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
}
