// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/interfaces/draft-IERC2612.sol";
import "../contracts/Bridgeless.sol";
import "../contracts/libraries/BridgelessOrderLibrary.sol";
import "../contracts/mocks/BridgelessSwapperUniswap.sol";
import "./utils/TokenAddresses.sol";
import "./utils/UsersAndSubmitter.sol";
import "multicall/Multicall3.sol";

contract Tests is
    TokenAddresses,
    UsersAndSubmitter,
    BridgelessOrderLibrary
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
    address _tokenToSwap;
    uint256 _amountIn;
    uint256 _amountOutMin;
    address _tokenIn;
    address _tokenOut;
    uint256 _deadline;
    // address that already has permit token balance, for forked testing
    address addressToSendTokenFrom;
    bytes32 orderHash;

    uint256 _nonce = 1559;
    uint32 _validAfter = 111;

    // this is a max number just for the existing tests.
    // nothing in the contracts actually enforces a max number, this is purely to decrease the computational cost of running all the tests.
    uint8 MAX_NUMBER_USERS = 8;

    constructor() UsersAndSubmitter(MAX_NUMBER_USERS) {}

    function setUp() public {
        // we would deploy the Bridgeless contract here, but it doesn't work nicely like this with forking existing networks.
        // better to deploy after creating fork!
        // bridgeless = new Bridgeless();
    }

    function testGaslessSwapMainnet() public {
        uint256 forkId = cheats.createFork("mainnet");
        cheats.selectFork(forkId);
        _runTestSuite();
    }

    function testGaslessSwapPolygon() public {
        uint256 forkId = cheats.createFork("polygon");
        cheats.selectFork(forkId);
        _runTestSuite();
    }

    function testGaslessSwapArbitrum() public {
        uint256 forkId = cheats.createFork("arbitrum");
        cheats.selectFork(forkId);
        _runTestSuite();
    }

    function testGaslessSwapAvalanche() public {
        uint256 forkId = cheats.createFork("avalanche");
        cheats.selectFork(forkId);
        _runTestSuite();
    }

    function testGaslessSwapFantom() public {
        uint256 forkId = cheats.createFork("fantom");
        cheats.selectFork(forkId);
        _runTestSuite();
    }

    function testGaslessSwapBSC() public {
        uint256 forkId = cheats.createFork("bsc");
        cheats.selectFork(forkId);
        _runTestSuite();
    }

    function _runTestSuite() internal {
        // swap ERC20 to native
        _testGaslessSwap_Simple(true);
        // swap ERC20 to ERC20
        _testGaslessSwap_Simple(false);
        // swap ERC20 to native
        _testGaslessSwap_Executor(true);
        // swap ERC20 to ERC20
        _testGaslessSwap_Executor(false);
        // swap ERC20 to native
        _testGaslessSwap_ValidAfter(true);
        // swap ERC20 to ERC20
        _testGaslessSwap_ValidAfter(false);
        // swap ERC20 to native
        _testGaslessSwap_Executor_ValidAfter(true);
        // swap ERC20 to ERC20
        _testGaslessSwap_Executor_ValidAfter(false);
    }

    function testFulfillMultipleOrdersMainnet(uint8 numberUsers) public {
        uint256 forkId = cheats.createFork("mainnet");
        cheats.selectFork(forkId);
        _testAggregatedGaslessSwap(numberUsers);
    }

    function testFulfillThreeOrdersMainnet() public {
        uint256 forkId = cheats.createFork("mainnet");
        cheats.selectFork(forkId);
        _testAggregatedGaslessSwap(3);
    }

    function _doOrder(BridgelessOrder memory order) internal {
        _deployContracts();

        // send tokens to the user from existing whale address, purely for testing
        cheats.startPrank(addressToSendTokenFrom);
        IERC20(order.tokenIn).transfer(user, _amountIn);
        cheats.stopPrank();

        // set up calls for gasless swap
        Multicall3.Call[] memory callsForMulticall = new Multicall3.Call[](2);

        // get the permit hash
        bytes32 permitHash = _getPermitHash(user, order);
        // get the permit signature
        Signature memory permitSignature = _getSignature(user_priv_key, permitHash);
        // set up the `token.permit` call
        callsForMulticall[0].target = _tokenToSwap;
        callsForMulticall[0].callData = _formatPermitCall(user, order, permitSignature);

        // get the order hash
        orderHash = bridgeless.calculateBridgelessOrderHash(order);
        // get the order signature
        PackedSignature memory orderSignature = _getPackedSignature(user_priv_key, orderHash);
        // set up the `Bridgeless.fulfillOrder` call
        callsForMulticall[1].target = address(bridgeless);
        bytes memory emptyBytes;
        callsForMulticall[1].callData = _formatFulfillOrderCall(order, orderSignature, emptyBytes);

        // actually make the gasless swap
        cheats.startPrank(submitter);
        multicall.aggregate(callsForMulticall);
        cheats.stopPrank();     
    }

    function _testGaslessSwap_Simple(bool swapForNative) internal {
        _setUpSwapParameters(swapForNative);
        // set up the order
        BridgelessOrder memory order;
        order = _makeOrder_Base(user);
        _doOrder(order);
    }

    function _testGaslessSwap_Executor(bool swapForNative) internal {
        _setUpSwapParameters(swapForNative);
        // set up the order
        BridgelessOrder memory order;
        order = _makeOrder_Base(user);
        order.optionalParameters = bridgeless.packOptionalParameters(true, false, address(multicall), _validAfter);
        _doOrder(order);
    }

    function _testGaslessSwap_ValidAfter(bool swapForNative) internal {
        _setUpSwapParameters(swapForNative);
        // set up the order
        BridgelessOrder memory order;
        order = _makeOrder_Base(user);
        order.optionalParameters = bridgeless.packOptionalParameters(false, true, address(multicall), _validAfter);
        _doOrder(order);
    }


    function _testGaslessSwap_Executor_ValidAfter(bool swapForNative) internal {
        _setUpSwapParameters(swapForNative);
        // set up the order
        BridgelessOrder memory order;
        order = _makeOrder_Base(user);
        order.optionalParameters = bridgeless.packOptionalParameters(true, true, address(multicall), _validAfter);
        _doOrder(order);
    }

    function _testAggregatedGaslessSwap(uint8 numberUsers) internal {
        // sanity check on fuzzed input
        cheats.assume(numberUsers <= MAX_NUMBER_USERS);

        _setUpSwapParameters(false);
        _deployContracts();

        // initialize memory structs
        BridgelessOrder[] memory orders = new BridgelessOrder[](numberUsers);
        PackedSignature[] memory orderSignatures = new PackedSignature[](numberUsers);
        Signature[] memory permitSignatures = new Signature[](numberUsers);
        // set up calls for approvals + swap at end
        Multicall3.Call[] memory callsForMulticall = new Multicall3.Call[](numberUsers + 1);

        // set up the orders
        for (uint256 i; i < numberUsers; ++i) {
            // fill in order parameters
            orders[i] = _makeOrder_Base(users[i]);
            // emit log_named_uint("i", i);
            // emit log_named_bytes("i-th order", abi.encode(orders[i]));

            // get the permit hash
            bytes32 permitHash = _getPermitHash(users[i], orders[i]);
            // get the permit signature
            permitSignatures[i] = _getSignature(user_priv_keys[i], permitHash);
            // set up the `token.permit` calls
            callsForMulticall[i].target = _tokenToSwap;
            callsForMulticall[i].callData = _formatPermitCall(users[i], orders[i], permitSignatures[i]);

            // get the order hash
            orderHash = bridgeless.calculateBridgelessOrderHash(orders[i]);
            // get order signature
            orderSignatures[i] = _getPackedSignature(user_priv_keys[i], orderHash);

            // send tokens to the user from existing whale address, purely for testing
            cheats.startPrank(addressToSendTokenFrom);
            IERC20(orders[i].tokenIn).transfer(users[i], _amountIn);
            cheats.stopPrank();

        }

        // set up the `Bridgeless.fulfillOrders` call
        {
            callsForMulticall[numberUsers].target = address(bridgeless);
            // function fulfillOrders(
            //     IBridgelessCallee swapper,
            //     BridgelessOrder[] calldata orders,
            //     Signature[] calldata signatures,
            //     bytes calldata extraCalldata
            // )
            bytes memory emptyBytes;
            callsForMulticall[numberUsers].callData = abi.encodeWithSelector(
                Bridgeless.fulfillOrders.selector,
                bridgelessSwapperUniswap,
                orders,
                orderSignatures,
                emptyBytes
            );
        }

        // emit log_named_bytes("callsForMulticall[numberUsers].callData", callsForMulticall[numberUsers].callData);

        // actually make the gasless swaps
        cheats.startPrank(submitter);
        multicall.aggregate(callsForMulticall);
        cheats.stopPrank();
    }

    function _setUpSwapParameters(bool swapForNative) internal {
        // swap for at least 1 gwei of the `tokenOut`
        _amountOutMin = 1e9;
        // infinite deadline -- generally not a great idea in practice
        _deadline = type(uint256).max;

        // swap for native token
        if (swapForNative) {
            _tokenOut = address(0);
        }

        // check chainId
        uint256 chainId = block.chainid;

        // for testing on forked ETH mainnet
        if (chainId == 1) {
            // swap 1e6 ETH_USDC for at least 1e9 ETH (i.e. one full ETH_USDC for at least one gwei of `tokenOut`)
            _amountIn = 1e6;

            // uniswap router
            ROUTER = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // ETH_USDC
            _tokenToSwap = ETH_USDC;

            // AAVE
            addressToSendTokenFrom = 0xBcca60bB61934080951369a648Fb03DF4F96263C;

            // example non-native `tokenOut` for this network (i.e. swap to an ERC20 token)
            if (!swapForNative) {
                _tokenOut = ETH_DAI;
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
            _tokenToSwap = POLYGON_USDC;

            // AAVE address
            addressToSendTokenFrom = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;
 
            // example non-native `tokenOut` for this network (i.e. swap to an ERC20 token)
            if (!swapForNative) {
                _tokenOut = POLYGON_DAI;
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
            _tokenToSwap = ARBI_USDC;

            // some bridge / exchange ? found through arbiscan
            addressToSendTokenFrom = 0x1714400FF23dB4aF24F9fd64e7039e6597f18C2b;

            // example non-native `tokenOut` for this network (i.e. swap to an ERC20 token)
            if (!swapForNative) {
                _tokenOut = ARBI_DAI;
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
            _tokenToSwap = AVAX_USDC;

            // AAVE
            addressToSendTokenFrom = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;

            // example non-native `tokenOut` for this network (i.e. swap to an ERC20 token)
            if (!swapForNative) {
                _tokenOut = AVAX_DAI;
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
            _tokenToSwap = BOO;

            // xBOO token address
            addressToSendTokenFrom = 0xa48d959AE2E88f1dAA7D5F611E01908106dE7598;

            // example non-native `tokenOut` for this network (i.e. swap to an ERC20 token)
            if (!swapForNative) {
                _tokenOut = FTM_DAI;
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
            _tokenToSwap = ORT;

            // ORT staking contract?
            addressToSendTokenFrom = 0x6f40A3d0c89cFfdC8A1af212A019C220A295E9bB;

            // example non-native `tokenOut` for this network (i.e. swap to an ERC20 token)
            if (!swapForNative) {
                _tokenOut = BUSD;
            }
        }

        else {
            emit log_named_uint("ERROR: unsupported chainId number", chainId);
            revert("support for chain not yet added to *tests* -- you can still launch on the chain though!");
        }
    }

    function _getUserBalance(address user, address token) internal view returns (uint256) {
        if (token == address(0)) {
            return user.balance;
        } else {
            return IERC20(token).balanceOf(user);
        }
    }

    function _getPermitHash(address user, BridgelessOrder memory order) internal view returns (bytes32) {
        IERC20Permit permitToken = IERC20Permit(order.tokenIn);
        uint256 nonce = permitToken.nonces(user);
        bytes32 domainSeparator = permitToken.DOMAIN_SEPARATOR();

        // calculation from USDC implementation code here -- https://etherscan.io/address/0xa2327a938febf5fec13bacfb16ae10ecbc4cbdcf#code
        bytes memory data = abi.encode(
            PERMIT_TYPEHASH,
            user,
            address(bridgeless),
            order.amountIn,
            nonce,
            order.deadline
        );
        return(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator,
                    keccak256(data)
                )
            )
        );
    }

    // util add-on to cheats.sign
    function _getSignature(uint256 privateKey, bytes32 dataToSign) internal returns (Signature memory signature) {
        // get signature and copy it over to struct
        (signature.v, signature.r, signature.s) = cheats.sign(privateKey, dataToSign);        
    }

    function _getPackedSignature(uint256 privateKey, bytes32 dataToSign) internal returns (PackedSignature memory signature) {
        // get signature
        (uint8 v, bytes32 r, bytes32 s) = cheats.sign(privateKey, dataToSign);
        // pack v and s together
        bytes32 vs = bytes32(uint256(bytes32(uint256(v) - 27)<<255) | uint256(s));
        // copy r + vs to struct
        signature.r = r;
        signature.vs = vs;
    }

    // note that this POC uses the `permit` standard defined in EIP2612, but Bridgeless itself is ultimately agnostic to the signed approval format
    function _formatPermitCall(address user, BridgelessOrder memory order, Signature memory permitSignature) internal view returns (bytes memory callData) {
        callData = abi.encodeWithSelector(
            // permit(address,address,uint256,uint256,uint8,bytes32,bytes32) has selector 0xd505accf
            IERC20Permit.permit.selector,
            user,
            // assumes permit is to `bridgeless` address
            address(bridgeless),
            order.amountIn,
            order.deadline,
            permitSignature.v,
            permitSignature.r,
            permitSignature.s
        );
    }

    // set up a `Bridgeless.fulfillOrder` call
    // currently use an `emptyBytes` arg for `extraCalldata`
    function _formatFulfillOrderCall(
        BridgelessOrder memory order,
        PackedSignature memory orderSignature,
        bytes memory extraCalldata
    )
        internal view returns (bytes memory callData)
    {
        // function fulfillOrder(
        //     IBridgelessCallee swapper,
        //     BridgelessOrder calldata order,
        //     Signature calldata signature,
        //     bytes calldata extraCalldata
        // )
        callData = abi.encodeWithSelector(
            Bridgeless.fulfillOrder.selector,
            // assumes `swapper` is `bridgelessSwapperUniswap`
            bridgelessSwapperUniswap,
            order,
            orderSignature,
            extraCalldata
        );
        // emit log_named_bytes("callData", callData);
    }

    function _deployContracts() internal {
        // deploy the Bridgeless contract
        bridgeless = new Bridgeless();
        // deploy POC IBridgelessCallee contract
        bridgelessSwapperUniswap = new BridgelessSwapperUniswap(ROUTER);
    }

    function _makeOrder_Base(address _signer) internal view returns (BridgelessOrder memory order) {
        order.signer = _signer;
        order.tokenIn = _tokenToSwap;
        order.amountIn = _amountIn;
        order.tokenOut = _tokenOut;
        order.amountOutMin = _amountOutMin;
        order.deadline = _deadline;
        order.nonce = _nonce;
        bytes memory emptyBytes;
        order.optionalParameters = emptyBytes;
    }

    function testPackUnpackOptionalParameters(
        bool _usingExecutor,
        bool _usingValidAfter,
        address executor_,
        uint32 validAfter_
    )
        public
    {
        // deploy the Bridgeless contract
        bridgeless = new Bridgeless();
        bytes memory optionalParameters = bridgeless.packOptionalParameters(_usingExecutor, _usingValidAfter, executor_, validAfter_);
        (bool usingExecutor, bool usingValidAfter, address executor, uint32 validAfter) = 
            bridgeless.unpackOptionalParameters(optionalParameters);
        assertTrue(usingExecutor == _usingExecutor, "usingExecutor != _usingExecutor");
        assertTrue(usingValidAfter == _usingValidAfter, "usingValidAfter != _usingValidAfter");
        if (_usingExecutor) {
            assertEq(executor, executor_);            
        } else {
            assertEq(executor, address(0));            
        }
        if (_usingValidAfter) {
            assertEq(validAfter, validAfter_);            
        } else {
            assertEq(validAfter, uint32(0));            
        }
    }

    function testProcessOptionalParameters() public {
        // deploy the Bridgeless contract
        bridgeless = new Bridgeless();
        cheats.warp(_validAfter + 1);
        bytes memory optionalParameters = bridgeless.packOptionalParameters(true, true, address(this), _validAfter);
        bridgeless.processOptionalParameters(optionalParameters);
    }
}

