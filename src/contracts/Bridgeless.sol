// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@uniswap-v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap-v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC2612.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// import "forge-std/Test.sol";

contract Bridgeless is
    ReentrancyGuard
    // ,DSTest
{
    using SafeERC20 for IERC20;
    // Vm cheats = Vm(HEVM_ADDRESS);

    struct UniswapOrder {
        uint256 amountIn;
        uint256 amountOutMin;
        address[] path;
        // we don't need `to` since it is assumed to be the address of this contract
        // address to;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
        // additional fee parameter
        uint256 feeBips;
    }

    struct Permit {
        address owner;
        // we don't need `spender` since it is assumed to be the address of this contract
        // address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    uint256 internal constant MAX_BIPS = 10000;
    uint256 internal constant MAX_FEE_BIPS = 9000;

    // main/most popular UniV2 router for this chain
    IUniswapV2Router02 public immutable ROUTER;
    // factory corresponding to `ROUTER`
    IUniswapV2Factory public immutable FACTORY;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract,address router)");

    /// @notice The EIP-712 typehash for the order struct used by the contract
    bytes32 public constant ORDER_TYPEHASH = keccak256("UniswapV2Order(uint256 amountIn,uint256 amountOutMin,address[] calldata path,address to,uint256 deadline,uint256 feeBips,uint256 nonce)");

    /// @notice EIP-712 Domain separator
    bytes32 public immutable DOMAIN_SEPARATOR;

    // signer => number of signatures already provided
    mapping(address => uint256) public nonces;

    // set immutable variables
    constructor(
        IUniswapV2Router02 _ROUTER)
    {
        // initialize immutable UniV2 (fork) addresses
        ROUTER = _ROUTER;
        FACTORY = IUniswapV2Factory(_ROUTER.factory());
        // initialize the immutable DOMAIN_SEPARATOR for signatures
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(DOMAIN_TYPEHASH, bytes("Bridgeless"), block.chainid, address(this), address(_ROUTER))
        );
    }

    // do-nothing receive function to let this contract accept native tokens (ETH-equivalent)
    receive() external payable {}

// note that uniswapOrder.amountIn and permit.value can differ. this is potentially useful in supporting fee-on-transfer tokens
    function swapGasless(
        UniswapOrder calldata uniswapOrder,
        Permit calldata permit
    )
        // nonReentrant since we transfer native token later in the function
        external nonReentrant
    {
        // pull the token owner, token to swap and fee bips from inputs
        address owner = permit.owner;
        IERC20 tokenToSwap = IERC20(uniswapOrder.path[0]);
        uint256 feeBips = uniswapOrder.feeBips;

        // check that the `feeBips` is valid
        require(
            feeBips <= MAX_FEE_BIPS,
            "Bridgeless.swapGasless: invalid feeBips provided"
        );

        // calculate the orderHash and then increase the token owner's nonce to help prevent signature re-use
        bytes32 orderHash = keccak256(
            abi.encode(ORDER_TYPEHASH, uniswapOrder.amountIn, uniswapOrder.amountOutMin, uniswapOrder.path, address(this), uniswapOrder.deadline, feeBips, nonces[owner]++)
        );

        // verify the uniswapOrder signature
        address recoveredAddress = ECDSA.recover(orderHash, uniswapOrder.v, uniswapOrder.r, uniswapOrder.s);
        require(
            recoveredAddress == owner,
            "Bridgeless.swapGasless: recoveredAddress != owner"
        );

        // perform the permit call
        IERC2612(address(tokenToSwap)).permit(owner, address(this), permit.value, permit.deadline, permit.v, permit.r, permit.s);

        // pull the tokens to this address
        tokenToSwap.safeTransferFrom(owner, address(this), permit.value);

        // approve the router to transfer tokens
        tokenToSwap.safeApprove(address(ROUTER), uniswapOrder.amountIn);

        // perform the swap
        // function swapExactTokensForETHSupportingFeeOnTransferTokens(
        //     uint amountIn,
        //     uint amountOutMin,
        //     address[] calldata path,
        //     address to,
        //     uint deadline
        // ) external;
        ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(uniswapOrder.amountIn, uniswapOrder.amountOutMin, uniswapOrder.path, address(this), uniswapOrder.deadline);

        // check ETH balance of this contract
        uint256 ethBal = address(this).balance;

        // find and send feeAmount to `msg.sender`
        if (feeBips != 0) {
            uint256 feeAmount = (ethBal * feeBips) / MAX_BIPS;
            Address.sendValue(payable(msg.sender), feeAmount);
            ethBal -= feeAmount;
        }

        // send remaining native token to owner
        Address.sendValue(payable(owner), ethBal);
    }

    function calculateOrderHash(address owner, UniswapOrder calldata uniswapOrder) external view returns (bytes32) {
        bytes32 orderHash = keccak256(
            abi.encode(ORDER_TYPEHASH, uniswapOrder.amountIn, uniswapOrder.amountOutMin, uniswapOrder.path, address(this), uniswapOrder.deadline, uniswapOrder.feeBips, nonces[owner])
        );
        return orderHash;
    }
}
