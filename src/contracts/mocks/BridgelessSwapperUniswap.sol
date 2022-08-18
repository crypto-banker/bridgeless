// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@uniswap-v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap-v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../interfaces/IBridgelessCallee.sol";

import "forge-std/Test.sol";

contract BridgelessSwapperUniswap is
    IBridgelessCallee,
    ReentrancyGuard
    ,DSTest
{
    using SafeERC20 for IERC20;

    struct UniswapOrder {
        uint256 amountIn;
        uint256 amountOutMin;
        address[] path;
        // we don't need `to` since it is assumed to be the address of this contract
        // address to;
        uint256 deadline;
    }

    // main/most popular UniV2 router for this chain
    IUniswapV2Router02 public immutable ROUTER;
    // factory corresponding to `ROUTER`
    IUniswapV2Factory public immutable FACTORY;

    bytes4 public immutable SELECTOR_swapExactTokensForETHSupportingFeeOnTransferTokens;

    event SwapFailed(bytes returnData);

    // set immutable variables
    constructor(
        IUniswapV2Router02 _ROUTER)
    {
        // initialize immutable UniV2 (fork) addresses
        ROUTER = _ROUTER;
        FACTORY = IUniswapV2Factory(_ROUTER.factory());
        uint256 chainId = block.chainid;
        bytes4 selector;
        // Avalance
        if (chainId == 43114) {
            // first 4 bytes of keccak hash of swapExactTokensForAVAXSupportingFeeOnTransferTokens(uint256,uint256,address[],address,uint256)
            selector = 0x762b1562;
        } else {
            // first 4 bytes of keccak hash of swapExactTokensForETHSupportingFeeOnTransferTokens(uint256,uint256,address[],address,uint256)
            selector = 0x791ac947;            
        }
        SELECTOR_swapExactTokensForETHSupportingFeeOnTransferTokens = selector;
    }

    // receive function to allow this contract to accept simple native-token transfers
    receive() external payable {}

    function bridgelessCall(address swapDestination, BridgelessOrder calldata order, bytes calldata) external {
        // approve the router to transfer tokens
        IERC20(order.tokenIn).safeApprove(address(ROUTER), order.amountIn);

        // if swap to native token
        if (order.tokenOut == address(0)) {
            // set up path variable. swap `tokenIn` to `tokenOut`
            address[] memory _path = new address[](2);
            // `tokenIn`
            _path[0] = order.tokenIn;
            // canonical wrapped-token
            uint256 chainId = block.chainid;
            if (chainId != 43114) {
                _path[1] = ROUTER.WETH();
            } else {
                // WAVAX
                _path[1] = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
            }            
            // perform the swap
            // function swapExactTokensForETHSupportingFeeOnTransferTokens(
            //     uint amountIn,
            //     uint amountOutMin,
            //     address[] calldata path,
            //     address to,
            //     uint deadline
            // ) external;
            (bool success, bytes memory returnData) = address(ROUTER).call(
                abi.encodeWithSelector(
                    SELECTOR_swapExactTokensForETHSupportingFeeOnTransferTokens,
                    order.amountIn,
                    order.amountOutMin,
                    _path,
                    address(this),
                    order.deadline
                )
            );

            if (!success) {
                emit SwapFailed(returnData);
                revert("BridgelessSwapperUniswap.bridgelessCall: swap failed!");
            }

            // check amount out
            uint256 amountOut = address(this).balance;
            require(amountOut >= order.amountOutMin, "BridgelessSwapperUniswap.bridgelessCall: amount obtained < order.amountOutMin");
            Address.sendValue(payable(swapDestination), order.amountOutMin);
            // transfer any remainder to `tx.origin`
            uint256 profit = amountOut - order.amountOutMin;
            if (profit != 0) {
                emit log_named_address("profit obtained in token", order.tokenOut);
                emit log_named_uint("amount of profit", profit);
                Address.sendValue(payable(tx.origin), profit);
            }
        }
        // if swap to another ERC20 -- note that the path routing is bad here, this is just a PoC
        else {
            // set up path variable. swap `tokenIn` to `tokenOut`
            address[] memory _path = new address[](3);
            // `tokenIn`
            _path[0] = order.tokenIn;
            // canonical wrapped-token
            uint256 chainId = block.chainid;
            if (chainId != 43114) {
                _path[1] = ROUTER.WETH();
            } else {
                // WAVAX
                _path[1] = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
            }
            _path[2] = order.tokenOut;          
            // perform the swap
            // function swapExactTokensForTokensSupportingFeeOnTransferTokens(
            //     uint amountIn,
            //     uint amountOutMin,
            //     address[] calldata path,
            //     address to,
            //     uint deadline
            // ) external;
            (bool success, bytes memory returnData) = address(ROUTER).call(
                abi.encodeWithSelector(
                    IUniswapV2Router02.swapExactTokensForTokensSupportingFeeOnTransferTokens.selector,
                    order.amountIn,
                    order.amountOutMin,
                    _path,
                    address(this),
                    order.deadline
                )
            );

            if (!success) {
                emit SwapFailed(returnData);
                revert("BridgelessSwapperUniswap.bridgelessCall: swap failed!");
            }

            // check amount out
            uint256 amountOut = IERC20(order.tokenOut).balanceOf(address(this));
            require(amountOut >= order.amountOutMin, "BridgelessSwapperUniswap.bridgelessCall: amount obtained < order.amountOutMin");
            IERC20(order.tokenOut).transfer(swapDestination, order.amountOutMin);
            // transfer any remainder to `tx.origin`
            uint256 profit = amountOut - order.amountOutMin;
            if (profit != 0) {
                emit log_named_address("profit obtained in token", order.tokenOut);
                emit log_named_uint("amount of profit", profit);
                IERC20(order.tokenOut).transfer(tx.origin, profit);
            }
        }
    }
}
