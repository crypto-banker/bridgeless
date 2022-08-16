// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./BridgelessStructs.sol";
import "./interfaces/IBridgelessCallee.sol";

contract BridgelessOTC is
    BridgelessStructs,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;
    // Vm cheats = Vm(HEVM_ADDRESS);

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract");

    /// @notice The EIP-712 typehash for the order struct used by the contract
    bytes32 public constant ORDER_TYPEHASH = keccak256(
        "BridgelessOrder(address tokenIn,uint256 amountIn, address tokenOut,uint256 amountOutMin,uint256 deadline,uint256 feeBips,uint256 nonce)");

    /// @notice EIP-712 Domain separator
    bytes32 public immutable DOMAIN_SEPARATOR;

    // signer => number of signatures already provided
    mapping(address => uint256) public nonces;

    // set immutable variables
    constructor()
    {
        // initialize the immutable DOMAIN_SEPARATOR for signatures
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(DOMAIN_TYPEHASH, bytes("Bridgeless"), block.chainid, address(this))
        );
    }

    function swapGasless(
        address tokenOwner,
        IBridgelessCallee swapper,
        BridgelessOrder calldata order,
        Signature calldata signature,
        bytes calldata extraCalldata
    )
        // nonReentrant since we transfer native token later in the function
        external nonReentrant
    {
        // get the `tokenOwner`'s balance of the native asset, prior to any swap
        uint256 ownerNativeBalance = tokenOwner.balance;

        // calculate the orderHash and then increase the token owner's nonce to help prevent signature re-use
        bytes32 orderHash = keccak256(
            abi.encode(
                ORDER_TYPEHASH,
                order.tokenIn,
                order.amountIn,
                order.amountOutMin,
                order.deadline,
                nonces[tokenOwner]++
            )
        );
        
        // verify the uniswapBridgelessOrder signature
        address recoveredAddress = ECDSA.recover(orderHash, signature.v, signature.r, signature.s);
        require(
            recoveredAddress == tokenOwner,
            "BridgelessOTC.swapGasless: recoveredAddress != tokenOwner"
        );

        // optimisically transfer the tokens to `swapper`
        // assumes `permit` has already been called, presumably by the `swapper` or otherwise within this transaction!
        IERC20(order.tokenIn).safeTransferFrom(tokenOwner, address(swapper), order.amountIn);

        // forward on the swap instructions and pass execution to `swapper`
        // `extraCalldata` can be e.g. multiple DEX orders
        swapper.bridgelessCall(tokenOwner, order, extraCalldata);

        // verify that the `tokenOwner` received *at least* `order.amountOutMin` in native tokens from the swap
        require(
            tokenOwner.balance - ownerNativeBalance >= order.amountOutMin,
            "BridgelessOTC.swapGasless: order.amountOutMin not met!"
        );
    }

    function calculateBridgelessOrderHash(address owner, BridgelessOrder calldata order) external view returns (bytes32) {
        bytes32 orderHash = keccak256(
            abi.encode(
                ORDER_TYPEHASH,
                order.tokenIn,
                order.amountIn,
                order.amountOutMin,
                order.deadline,
                nonces[owner]
            )
        );
        return orderHash;
    }
}
