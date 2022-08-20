// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/interfaces/draft-IERC2612.sol";
import "../contracts/Bridgeless.sol";
import "../contracts/BridgelessStructs.sol";
import "../contracts/mocks/BridgelessSwapperUniswap.sol";
import "./utils/TokenAddresses.sol";
import "./utils/UsersAndSubmitter.sol";
import "multicall/Multicall3.sol";

contract Tests is
    TokenAddresses,
    UsersAndSubmitter,
    BridgelessStructs
{
    // deployed on a huge number of chains at the same address -- see here https://github.com/mds1/multicall
    Multicall3 internal constant multicall = Multicall3(0xcA11bde05977b3631167028862bE2a173976CA11);

    Bridgeless public bridgeless;

    // POC implementation of the IBridgelessCallee interface
    BridgelessSwapperUniswap public bridgelessSwapperUniswap;

    // addresses for deploying POC adapater
    IUniswapV2Router02 public ROUTER;
    IUniswapV2Factory public FACTORY;

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;


    // storage variables declared to deal with 'stack too deep' errors
    address tokenToSwap;
    uint256 _amountIn;
    uint256 _amountOutMin;
    // address that already has permit token balance, for forked testing
    address addressToSendTokenFrom;
    bytes32 orderHash;
    uint8 v;
    bytes32 r;
    bytes32 s;

    // this is a max number just for the existing tests.
    // nothing in the contracts actually enforces a max number, this is purely to decrease the computational cost of running all the tests.
    uint8 MAX_NUMBER_USERS = 8;

    constructor() UsersAndSubmitter(MAX_NUMBER_USERS) {}

    function setUp() public {
        // we would deploy the Bridgeless contract here, but it doesn't work nicely like this with forking existing networks.
        // better to deploy after creating fork!
        // bridgeless = new Bridgeless();
    }

    function testGaslessSwapToNativeMainnet() public {
        uint256 forkId = cheats.createFork("mainnet");
        cheats.selectFork(forkId);
        _testGaslessSwap(true);
    }

    function testGaslessSwapToNativePolygon() public {
        uint256 forkId = cheats.createFork("polygon");
        cheats.selectFork(forkId);
        _testGaslessSwap(true);
    }

    function testGaslessSwapToNativeArbitrum() public {
        uint256 forkId = cheats.createFork("arbitrum");
        cheats.selectFork(forkId);
        _testGaslessSwap(true);
    }

    function testGaslessSwapToNativeAvalanche() public {
        uint256 forkId = cheats.createFork("avalanche");
        cheats.selectFork(forkId);
        _testGaslessSwap(true);
    }

    function testGaslessSwapToNativeFantom() public {
        uint256 forkId = cheats.createFork("fantom");
        cheats.selectFork(forkId);
        _testGaslessSwap(true);
    }

    function testGaslessSwapToNativeBSC() public {
        uint256 forkId = cheats.createFork("bsc");
        cheats.selectFork(forkId);
        _testGaslessSwap(true);
    }
    function testGaslessSwapToNonNativeMainnet() public {
        uint256 forkId = cheats.createFork("mainnet");
        cheats.selectFork(forkId);
        _testGaslessSwap(false);
    }

    function testGaslessSwapToNonNativePolygon() public {
        uint256 forkId = cheats.createFork("polygon");
        cheats.selectFork(forkId);
        _testGaslessSwap(false);
    }

    function testGaslessSwapToNonNativeArbitrum() public {
        uint256 forkId = cheats.createFork("arbitrum");
        cheats.selectFork(forkId);
        _testGaslessSwap(false);
    }

    function testGaslessSwapToNonNativeAvalanche() public {
        uint256 forkId = cheats.createFork("avalanche");
        cheats.selectFork(forkId);
        _testGaslessSwap(false);
    }

    function testGaslessSwapToNonNativeFantom() public {
        uint256 forkId = cheats.createFork("fantom");
        cheats.selectFork(forkId);
        _testGaslessSwap(false);
    }

    function testGaslessSwapToNonNativeBSC() public {
        uint256 forkId = cheats.createFork("bsc");
        cheats.selectFork(forkId);
        _testGaslessSwap(false);
    }

    function testFulfillMultipleOrdersMainnet(uint8 numberUsers) public {
        uint256 forkId = cheats.createFork("mainnet");
        cheats.selectFork(forkId);
        _testAggregatedGaslessSwap(numberUsers);
    }

    function _testGaslessSwap(bool swapForNative) internal {
        // deploy the Bridgeless contract
        bridgeless = new Bridgeless();

        // initialize memory structs
        BridgelessOrder_Simple memory order;
        Signature memory orderSignature;

        // check chainId
        uint256 chainId = block.chainid;
        // emit the chainId for logging purposes
        emit log_named_uint("chainId", chainId);

        // swap for at least 1 gwei of the `tokenOut`
        _amountOutMin = 1e9;

        if (swapForNative) {
            // swap for native token
            order.orderBase.tokenOut = address(0);
        }

        // for testing on forked ETH mainnet
        if (chainId == 1) {
            // swap 1e6 ETH_USDC for at least 1e9 ETH (i.e. one full ETH_USDC for at least one gwei of `tokenOut`)
            _amountIn = 1e6;

            // uniswap router
            ROUTER = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // ETH_USDC
            tokenToSwap = ETH_USDC;

            // AAVE
            addressToSendTokenFrom = 0xBcca60bB61934080951369a648Fb03DF4F96263C;

            // example non-native `tokenOut` for this network (i.e. swap to an ERC20 token)
            if (!swapForNative) {
                order.orderBase.tokenOut = ETH_DAI;
            }
        }

        // for testing on forked polygon mainnet
        else if (chainId == 137) {
            // swap 1e6 POLYGON_USDC for at least 1e9 WMATIC (i.e. one full POLYGON_USDC for at least one gwei of `tokenOut`)
            _amountIn = 1e6;

            // quickswap router
            ROUTER = IUniswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // POLYGON_USDC
            tokenToSwap = POLYGON_USDC;

            // AAVE address
            addressToSendTokenFrom = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;
 
            // example non-native `tokenOut` for this network (i.e. swap to an ERC20 token)
            if (!swapForNative) {
                order.orderBase.tokenOut = POLYGON_DAI;
            }
       }

        // for testing on forked arbitrum
        else if (chainId == 42161) {
            // swap 1e6 ARBI_USDC for at least 1e9 ARBI_WETH (i.e. one full ARBI_USDC for at least one gwei of `tokenOut`)
            _amountIn = 1e6;

            // SushiSwap router
            ROUTER = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // ARBI_USDC
            tokenToSwap = ARBI_USDC;

            // some bridge / exchange ? found through arbiscan
            addressToSendTokenFrom = 0x1714400FF23dB4aF24F9fd64e7039e6597f18C2b;

            // example non-native `tokenOut` for this network (i.e. swap to an ERC20 token)
            if (!swapForNative) {
                order.orderBase.tokenOut = ARBI_DAI;
            }
        }

        // for testing on forked Avalanche C-Chain
        else if (chainId == 43114) {
            // swap 1e6 AVAX_USDC for at least 1e9 WAVAX (i.e. one full AVAX_USDC for at least one gwei of `tokenOut`)
            _amountIn = 1e6;

            // JOE router
            ROUTER = IUniswapV2Router02(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // AVAX_USDC
            tokenToSwap = AVAX_USDC;

            // AAVE
            addressToSendTokenFrom = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;

            // example non-native `tokenOut` for this network (i.e. swap to an ERC20 token)
            if (!swapForNative) {
                order.orderBase.tokenOut = AVAX_DAI;
            }
        }

        // for testing on forked fantom opera
        else if (chainId == 250) {
            // swap 1e18 BOO for at least 1e9 WFTM (i.e. one full BOO for at least one gwei of `tokenOut`)
            _amountIn = 1e18;

            // SpookySwap router
            ROUTER = IUniswapV2Router02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // BOO
            tokenToSwap = BOO;

            // xBOO token address
            addressToSendTokenFrom = 0xa48d959AE2E88f1dAA7D5F611E01908106dE7598;

            // example non-native `tokenOut` for this network (i.e. swap to an ERC20 token)
            if (!swapForNative) {
                order.orderBase.tokenOut = FTM_DAI;
            }
        }

        // for testing on forked BSC
        else if (chainId == 56) {
            // swap 1e18 ORT for at least 1e9 WBNB (i.e. one full ORT for at least one gwei of `tokenOut`)
            _amountIn = 1e18;

            // PancakeSwap router
            ROUTER = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // ORT
            tokenToSwap = ORT;

            // ORT staking contract?
            addressToSendTokenFrom = 0x6f40A3d0c89cFfdC8A1af212A019C220A295E9bB;

            // example non-native `tokenOut` for this network (i.e. swap to an ERC20 token)
            if (!swapForNative) {
                order.orderBase.tokenOut = BUSD;
            }
        }

        else {
            emit log_named_uint("ERROR: unsupported chainId number", chainId);
            revert("support for chain not yet added to *tests* -- you can still launch on the chain though!");
        }

        // deploy POC IBridgelessCallee contract
        bridgelessSwapperUniswap = new BridgelessSwapperUniswap(ROUTER);

        // infinite deadline -- generally not a great idea in practice
        uint256 _deadline = type(uint256).max;

        // set up the order
        order.orderBase.tokenIn = tokenToSwap;
        order.orderBase.amountIn = _amountIn;
        order.orderBase.amountOutMin = _amountOutMin;
        order.orderBase.deadline = _deadline;

        // get the order hash
        orderHash = bridgeless.calculateBridgelessOrderHash_Simple(order);
        // get order signature and copy it over to struct
        (v, r, s) = cheats.sign(user_priv_key, orderHash);
        orderSignature.v = v;
        orderSignature.r = r;
        orderSignature.s = s;

        // get the permit hash
        bytes32 permitHash;
        {
            IERC20Permit permitToken = IERC20Permit(order.orderBase.tokenIn);
            uint256 nonce = permitToken.nonces(user);
            bytes32 domainSeparator = permitToken.DOMAIN_SEPARATOR();

            // calculation from USDC implementation code here -- https://etherscan.io/address/0xa2327a938febf5fec13bacfb16ae10ecbc4cbdcf#code
            bytes memory data = abi.encode(
                PERMIT_TYPEHASH,
                user,
                address(bridgeless),
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
        IERC20(order.orderBase.tokenIn).transfer(user, _amountIn);
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
            address(bridgeless),
            uint256(_amountIn),
            uint256(_deadline),
            uint8(v),
            bytes32(r),
            bytes32(s)
        );
        }

        // set up the `Bridgeless.fulfillOrder` call
        {
            callsForMulticall[1].target = address(bridgeless);
            // function fulfillOrder(
            //     IBridgelessCallee swapper,
            //     address tokenOwner,
            //     BridgelessOrder_Simple calldata order,
            //     Signature calldata signature,
            //     bytes calldata extraCalldata
            // )
            bytes memory emptyBytes;
            callsForMulticall[1].callData = abi.encodeWithSelector(
                Bridgeless.fulfillOrder.selector,
                bridgelessSwapperUniswap,
                user,
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
        uint256 userBalance = _getUserBalance(user, order.orderBase.tokenOut);
        emit log_named_uint("userBalance", userBalance);
        require(userBalance >= _amountOutMin, "order not fulfilled correctly!");
    }

    function _testAggregatedGaslessSwap(uint8 numberUsers) internal {
        cheats.assume(numberUsers <= MAX_NUMBER_USERS);

        // deploy the Bridgeless contract
        bridgeless = new Bridgeless();

        // initialize memory structs
        BridgelessOrder_Simple[] memory orders = new BridgelessOrder_Simple[](numberUsers);
        Signature[] memory orderSignatures = new Signature[](numberUsers);
        Signature[] memory permitSignatures = new Signature[](numberUsers);
        address[] memory tokenOwners = new address[](numberUsers);

        // check chainId
        uint256 chainId = block.chainid;
        // emit the chainId for logging purposes
        emit log_named_uint("chainId", chainId);

        // swap for at least 1 gwei of the `tokenOut`
        _amountOutMin = 1e9;

        // for testing on forked ETH mainnet
        if (chainId == 1) {
            // swap 1e6 ETH_USDC for at least 1e9 ETH (i.e. one full ETH_USDC for at least one gwei of `tokenOut`)
            _amountIn = 1e6;

            // uniswap router
            ROUTER = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // ETH_USDC
            tokenToSwap = ETH_USDC;

            // AAVE
            addressToSendTokenFrom = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
        }

        else {
            emit log_named_uint("ERROR: unsupported chainId number", chainId);
            revert("support for chain not yet added to *tests* -- you can still launch on the chain though!");
        }

          // deploy POC IBridgelessCallee contract
        bridgelessSwapperUniswap = new BridgelessSwapperUniswap(ROUTER);

        // infinite deadline -- generally not a great idea in practice
        uint256 _deadline = type(uint256).max;

        // set up calls for gasless swaps
        Multicall3.Call[] memory callsForMulticall = new Multicall3.Call[](numberUsers + 1);

        // set up the orders
        for (uint256 i; i < numberUsers; ++i) {
            orders[i].orderBase.tokenIn = tokenToSwap;
            orders[i].orderBase.amountIn = _amountIn;
            orders[i].orderBase.amountOutMin = _amountOutMin;
            orders[i].orderBase.deadline = _deadline;

            // get the order hash
            orderHash = bridgeless.calculateBridgelessOrderHash_Simple(orders[i]);
            // get order signature and copy it over to struct
            (v, r, s) = cheats.sign(user_priv_keys[i], orderHash);
            orderSignatures[i].v = v;
            orderSignatures[i].r = r;
            orderSignatures[i].s = s;

            // get the permit hash
            bytes32 permitHash;
            {
                IERC20Permit permitToken = IERC20Permit(orders[i].orderBase.tokenIn);
                uint256 nonce = permitToken.nonces(users[i]);
                bytes32 domainSeparator = permitToken.DOMAIN_SEPARATOR();

                // calculation from USDC implementation code here -- https://etherscan.io/address/0xa2327a938febf5fec13bacfb16ae10ecbc4cbdcf#code
                bytes memory data = abi.encode(
                    PERMIT_TYPEHASH,
                    users[i],
                    address(bridgeless),
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
            (v, r, s) = cheats.sign(user_priv_keys[i], permitHash);
            permitSignatures[i].v = v;
            permitSignatures[i].r = r;
            permitSignatures[i].s = s;

            // send tokens to the user from existing whale address, purely for testing
            cheats.startPrank(addressToSendTokenFrom);
            IERC20(orders[i].orderBase.tokenIn).transfer(users[i], _amountIn);
            cheats.stopPrank();

            // set up the `token.permit` calls
            {
            callsForMulticall[i].target = tokenToSwap;
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
            callsForMulticall[i].callData = abi.encodeWithSelector(
                // permit(address,address,uint256,uint256,uint8,bytes32,bytes32) has selector 0xd505accf
                IERC20Permit.permit.selector,
                address(users[i]),
                address(bridgeless),
                uint256(_amountIn),
                uint256(_deadline),
                uint8(v),
                bytes32(r),
                bytes32(s)
            );
            }

            // set up tokenOwners struct
            tokenOwners[i] = users[i];
        }

        // set up the `Bridgeless.fulfillOrders` call
        {
            callsForMulticall[numberUsers].target = address(bridgeless);
            // function fulfillOrders(
            //     IBridgelessCallee swapper,
            //     address[] calldata tokenOwners,
            //     BridgelessOrder_Simple[] calldata orders,
            //     Signature[] calldata signatures,
            //     bytes calldata extraCalldata
            // )
            bytes memory emptyBytes;
            callsForMulticall[numberUsers].callData = abi.encodeWithSelector(
                Bridgeless.fulfillOrders.selector,
                bridgelessSwapperUniswap,
                tokenOwners,
                orders,
                orderSignatures,
                emptyBytes
            );
        }

        // actually make the gasless swaps
        cheats.startPrank(submitter);
        multicall.aggregate(callsForMulticall);
        cheats.stopPrank();

        // log address balances
        for (uint256 i; i < numberUsers; ++i) {
            uint256 userBalance = _getUserBalance(users[i], orders[i].orderBase.tokenOut);
            emit log_named_uint("userBalance", userBalance);
            require(userBalance >= _amountOutMin, "order not fulfilled correctly!");    
        }  
    }


    function _getUserBalance(address user, address token) internal view returns (uint256) {
        if (token == address(0)) {
            return user.balance;
        } else {
            return IERC20(token).balanceOf(user);
        }
    }
}

