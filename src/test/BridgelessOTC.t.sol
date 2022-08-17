// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/interfaces/draft-IERC2612.sol";
import "../contracts/BridgelessOTC.sol";
import "../contracts/BridgelessStructs.sol";
import "../contracts/mocks/BridgelessSwapperUniswap.sol";
import "./utils/TokenAddresses.sol";
import "./utils/UserAndSubmitter.sol";
import "multicall/Multicall3.sol";

contract BridgelessOTCTests is
    TokenAddresses,
    UserAndSubmitter,
    BridgelessStructs
{
    // deployed on a huge number of chains at the same address -- see here https://github.com/mds1/multicall
    Multicall3 internal constant multicall = Multicall3(0xcA11bde05977b3631167028862bE2a173976CA11);

    BridgelessOTC public bridgelessOTC;

    // POC implementation of the IBridgelessCallee interface
    BridgelessSwapperUniswap public bridgelessSwapperUniswap;

    address tokenToSwap;
    uint256 _amountIn;
    uint256 _amountOutMin;
    // address that already has permit token balance, for forked testing
    address addressToSendTokenFrom;

    // addresses for deploying POC adapater
    IUniswapV2Router02 public ROUTER;
    IUniswapV2Factory public FACTORY;

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    function setUp() public {
        // we would deploy the BridgelessOTC contract here, but it doesn't work nicely like this with forking existing networks.
        // better to deploy after creating fork!
        // bridgelessOTC = new BridgelessOTC();
    }

    function testGaslessSwapMainnet() public {
        uint256 forkId = cheats.createFork("mainnet");
        cheats.selectFork(forkId);
        _testGaslessSwap();
    }

    function testGaslessSwapPolygon() public {
        uint256 forkId = cheats.createFork("polygon");
        cheats.selectFork(forkId);
        _testGaslessSwap();
    }

    function testGaslessSwapArbitrum() public {
        uint256 forkId = cheats.createFork("arbitrum");
        cheats.selectFork(forkId);
        _testGaslessSwap();
    }

    function testGaslessSwapAvalanche() public {
        uint256 forkId = cheats.createFork("avalanche");
        cheats.selectFork(forkId);
        _testGaslessSwap();
    }

    function testGaslessSwapFantom() public {
        uint256 forkId = cheats.createFork("fantom");
        cheats.selectFork(forkId);
        _testGaslessSwap();
    }

    function testGaslessSwapBSC() public {
        uint256 forkId = cheats.createFork("bsc");
        cheats.selectFork(forkId);
        _testGaslessSwap();
    }

    function _testGaslessSwap() internal {
        // deploy the BridgelessOTC contract
        bridgelessOTC = new BridgelessOTC();

        // check chainId
        uint256 chainId = block.chainid;
        // emit the chainId for logging purposes
        emit log_named_uint("chainId", chainId);

        // for testing on forked ETH mainnet
        if (chainId == 1) {
            // swap 1e6 ETH_USDC for at least 1e9 ETH (i.e. one full ETH_USDC for at least one gwei in native token)
            _amountIn = 1e6;
            _amountOutMin = 1e9;

            // uniswap router
            ROUTER = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // ETH_USDC
            tokenToSwap = ETH_USDC;

            // AAVE
            addressToSendTokenFrom = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
        }

        // for testing on forked polygon mainnet
        else if (chainId == 137) {
            // swap 1e6 POLYGON_USDC for at least 1e9 WMATIC (i.e. one full POLYGON_USDC for at least one gwei in native token)
            _amountIn = 1e6;
            _amountOutMin = 1e9;

            // quickswap router
            ROUTER = IUniswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // POLYGON_USDC
            tokenToSwap = POLYGON_USDC;

            // AAVE address
            addressToSendTokenFrom = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;
        }

        // for testing on forked arbitrum
        else if (chainId == 42161) {
            // swap 1e6 ARBI_USDC for at least 1e9 ARBI_WETH (i.e. one full ARBI_USDC for at least one gwei in native token)
            _amountIn = 1e6;
            _amountOutMin = 1e9;

            // SushiSwap router
            ROUTER = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // ARBI_USDC
            tokenToSwap = ARBI_USDC;

            // some bridge / exchange ? found through arbiscan
            addressToSendTokenFrom = 0x1714400FF23dB4aF24F9fd64e7039e6597f18C2b;
        }

        // for testing on forked Avalanche C-Chain
        else if (chainId == 43114) {
            // swap 1e6 AVAX_USDC for at least 1e9 WAVAX (i.e. one full AVAX_USDC for at least one gwei in native token)
            _amountIn = 1e6;
            _amountOutMin = 1e9;

            // JOE router
            ROUTER = IUniswapV2Router02(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // AVAX_USDC
            tokenToSwap = AVAX_USDC;

            // AAVE
            addressToSendTokenFrom = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;
        }

        // for testing on forked fantom opera
        else if (chainId == 250) {
            // swap 1e18 BOO for at least 1e9 WFTM (i.e. one full BOO for at least one gwei in native token)
            _amountIn = 1e18;
            _amountOutMin = 1e9;

            // SpookySwap router
            ROUTER = IUniswapV2Router02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // BOO
            tokenToSwap = BOO;

            // xBOO token address
            addressToSendTokenFrom = 0xa48d959AE2E88f1dAA7D5F611E01908106dE7598;
        }

        // for testing on forked BSC
        else if (chainId == 56) {
            // swap 1e18 ORT for at least 1e9 WBNB (i.e. one full ORT for at least one gwei in native token)
            _amountIn = 1e18;
            _amountOutMin = 1e9;

            // PancakeSwap router
            ROUTER = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // ORT
            tokenToSwap = ORT;

            // ORT staking contract?
            addressToSendTokenFrom = 0x6f40A3d0c89cFfdC8A1af212A019C220A295E9bB;
        }

        else {
            emit log_named_uint("ERROR: unsupported chainId number", chainId);
            revert("support for chain not yet added to *tests* -- you can still launch on the chain though!");
        }

        // initialize memory structs
        BridgelessOrder memory order;
        Signature memory orderSignature;

        // deploy POC IBridgelessCallee contract
        bridgelessSwapperUniswap = new BridgelessSwapperUniswap(ROUTER);

        // infinite deadline -- generally not a great idea in practice
        uint256 _deadline = type(uint256).max;

        // set up the order
        order.tokenIn = tokenToSwap;
        order.amountIn = _amountIn;
        order.amountOutMin = _amountOutMin;
        order.deadline = _deadline;

        // get the order hash
        bytes32 orderHash = bridgelessOTC.calculateBridgelessOrderHash(user, order);
        // get order signature and copy it over to struct
        (uint8 v, bytes32 r, bytes32 s) = cheats.sign(user_priv_key, orderHash);
        orderSignature.v = v;
        orderSignature.r = r;
        orderSignature.s = s;

        // get the permit hash
        bytes32 permitHash;
        {
            IERC20Permit permitToken = IERC20Permit(order.tokenIn);
            uint256 nonce = permitToken.nonces(user);
            bytes32 domainSeparator = permitToken.DOMAIN_SEPARATOR();

            // calculation from USDC implementation code here -- https://etherscan.io/address/0xa2327a938febf5fec13bacfb16ae10ecbc4cbdcf#code
            bytes memory data = abi.encode(
                PERMIT_TYPEHASH,
                user,
                address(bridgelessOTC),
                _amountIn,
                nonce,
                _deadline
            );
            permitHash = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator,
                    keccak256(data)
                )
            );
        }


        // get the permit signature
        (v, r, s) = cheats.sign(user_priv_key, permitHash);

        // send tokens to the user from existing whale address, purely for testing
        cheats.startPrank(addressToSendTokenFrom);
        IERC20(order.tokenIn).transfer(user, _amountIn);
        cheats.stopPrank();

        // set up calls for gasless swap
        Multicall3.Call[] memory callsForMulticall = new Multicall3.Call[](2);

        // set up the `token.permit` call
        {
        callsForMulticall[0].target = tokenToSwap;
        // note that this POC uses the `permit` standard defined in EIP2612, but Bridgeless itself is ultimately agnostic to the signed approval format
        // function permit(
        //     address owner,
        //     address spender,
        //     uint256 value,
        //     uint256 deadline,
        //     uint8 v,
        //     bytes32 r,
        //     bytes32 s
        // ) external;
        callsForMulticall[0].callData = abi.encodeWithSelector(
            // permit(address,address,uint256,uint256,uint8,bytes32,bytes32) has selector 0xd505accf
            IERC20Permit.permit.selector,
            address(user),
            address(bridgelessOTC),
            uint256(_amountIn),
            uint256(_deadline),
            uint8(v),
            bytes32(r),
            bytes32(s)
        );
        }

        // set up the `BridgelessOTC.swapGasless` call
        {
            callsForMulticall[1].target = address(bridgelessOTC);
            // function swapGasless(
            //     address tokenOwner,
            //     IBridgelessCallee swapper,
            //     BridgelessOrder calldata order,
            //     Signature calldata signature,
            //     bytes calldata extraCalldata
            // )
            bytes memory emptyBytes;
            callsForMulticall[1].callData = abi.encodeWithSelector(
                BridgelessOTC.swapGasless.selector,
                user,
                bridgelessSwapperUniswap,
                order,
                orderSignature,
                emptyBytes
            );
        }

        // actually make the gasless swap
        cheats.startPrank(submitter);
        multicall.aggregate(callsForMulticall);
        cheats.stopPrank();

        // log address balances
        uint256 userBalance = user.balance;
        uint256 submitterBalance = submitter.balance;
        emit log_named_uint("userBalance", userBalance);
        emit log_named_uint("submitterBalance", submitterBalance);
        require(userBalance > _amountOutMin, "order not fulfilled correctly!");
    }
}

