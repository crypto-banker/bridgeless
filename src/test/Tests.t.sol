// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "../contracts/Bridgeless.sol";

import "forge-std/Test.sol";

contract Tests is Test {
    Vm cheats = Vm(HEVM_ADDRESS);

    IUniswapV2Router02 public ROUTER;
    IUniswapV2Factory public FACTORY;

    Bridgeless public bridgeless;

    uint256 user_priv_key = uint256(keccak256("pseudorandom-address-01"));
    address payable user = payable(cheats.addr(user_priv_key));

    uint256 submitter_priv_key = uint256(keccak256("pseudorandom-address-02"));
    address payable submitter = payable(cheats.addr(submitter_priv_key));

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    address internal constant ETH_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant ETH_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address internal constant POLYGON_USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address internal constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    address internal constant ARBI_USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address internal constant ARBI_WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    uint256 internal constant MAX_BIPS = 10000;
    uint256 internal constant MAX_FEE_BIPS = 9000;

    uint256 _amountIn;
    uint256 _amountOutMin;
    // address that already has permit token balance, for forked testing
    address addressToSendTokenFrom;

    function setUp() public {
    }

    function testGaslessSwapMainnet() public {
        uint256 forkId = cheats.createFork("mainnet");
        cheats.selectFork(forkId);
        _testGaslessSwap(5555);
    }

    function testGaslessSwapPolygon() public {
        uint256 forkId = cheats.createFork("polygon");
        cheats.selectFork(forkId);
        _testGaslessSwap(2500);
    }

    function testGaslessSwapArbitrum(uint16 feeBips) public {
        uint256 forkId = cheats.createFork("arbitrum");
        cheats.selectFork(forkId);
        _testGaslessSwap(feeBips);
    }

    function _testGaslessSwap(uint16 _feeBips) internal {
        cheats.assume(_feeBips <= MAX_FEE_BIPS);

        // initialize memory structs
        Bridgeless.UniswapOrder memory uniswapOrder;
        Bridgeless.Permit memory permit;

        // check chainId
        uint256 chainId = block.chainid;
        // emit the chainId for logging purposes
        emit log_named_uint("chainId", chainId);

        // for testing on forked ETH mainnet
        if (chainId == 1) {
            // swap 1e6 ETH_USDC for at least 1e9 ETH (i.e. one full ETH_USDC for at least one gwei)
            _amountIn = 1e6;
            _amountOutMin = 1e9;

            // uniswap router
            ROUTER = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // set path to swap ETH_USDC => ETH
            address[] memory _path = new address[](2);
            // ETH_USDC
            _path[0] = ETH_USDC;
            // canonical ETH_WETH
            _path[1] = ETH_WETH;
            uniswapOrder.path = _path;

            // binance bridge
            addressToSendTokenFrom = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503;
        }

        // for testing on forked polygon mainnet
        else if (chainId == 137) {
            // swap 1e6 POLYGON_USDC for at least 1e9 WMATIC (i.e. one full POLYGON_USDC for at least one gwei)
            _amountIn = 1e6;
            _amountOutMin = 1e9;

            // quickswap router
            ROUTER = IUniswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // set path to swap POLYGON_USDC => WMATIC
            address[] memory _path = new address[](2);
            // POLYGON_USDC
            _path[0] = POLYGON_USDC;
            // canonical WMATIC
            _path[1] = WMATIC;
            uniswapOrder.path = _path;

            // AAVE address
            addressToSendTokenFrom = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;
        }

        // for testing on forked arbitrum
        else if (chainId == 42161) {
            // swap 1e6 ARBI_USDC for at least 1e9 ARBI_WETH (i.e. one full ARBI_USDC for at least one gwei)
            _amountIn = 1e6;
            _amountOutMin = 1e9;

            // SushiSwap router
            ROUTER = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // set path to swap ARBI_USDC => ARBI_WETH
            address[] memory _path = new address[](2);
            // ARBI_USDC
            _path[0] = ARBI_USDC;
            // canonical ARBI_WETH
            _path[1] = ARBI_WETH;
            uniswapOrder.path = _path;

            // some bridge / exchange ? found through arbiscan
            addressToSendTokenFrom = 0x1714400FF23dB4aF24F9fd64e7039e6597f18C2b;
        }

        else {
            emit log_named_uint("ERROR: unsupported chainId number", chainId);
            revert("support for chain not yet added to *tests* -- you can still launch on the chain though!");
        }

        uniswapOrder.amountIn = _amountIn;
        uniswapOrder.amountOutMin = _amountOutMin;

        // infinite deadline
        uniswapOrder.deadline = type(uint256).max;

        // set fee at 10%
        uniswapOrder.feeBips = _feeBips;

        // deploy the Bridgeless contract
        bridgeless = new Bridgeless(ROUTER);

        // get the order hash
        bytes32 orderHash = bridgeless.calculateOrderHash(user, uniswapOrder);
        // get order signature and copy it over
        (uint8 v, bytes32 r, bytes32 s) = cheats.sign(user_priv_key, orderHash);
        uniswapOrder.v = v;
        uniswapOrder.r = r;
        uniswapOrder.s = s;

        permit.owner = user;
        permit.value = _amountIn;
        // infinite deadline
        permit.deadline = type(uint256).max;

        // get the permit hash
        IERC20Permit permitToken = IERC20Permit(uniswapOrder.path[0]);
        uint256 nonce = permitToken.nonces(user);
        bytes32 domainSeparator = permitToken.DOMAIN_SEPARATOR();

        // calculation from USDC implementation code here -- https://etherscan.io/address/0xa2327a938febf5fec13bacfb16ae10ecbc4cbdcf#code
        bytes memory data = abi.encode(
            PERMIT_TYPEHASH,
            user,
            address(bridgeless),
            permit.value,
            nonce,
            permit.deadline
        );
        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(data)
            )
        );

        // get permit signature and copy it over
        (v, r, s) = cheats.sign(user_priv_key, permitHash);
        permit.v = v;
        permit.r = r;
        permit.s = s;

        // get user tokens
        cheats.startPrank(addressToSendTokenFrom);
        IERC20(address(permitToken)).transfer(user, _amountIn);
        cheats.stopPrank();

        // actually make the gasless swap
        cheats.startPrank(submitter);
        bridgeless.swapGasless(uniswapOrder, permit);
        cheats.stopPrank();

        // log address balances
        uint256 userBalance = user.balance;
        uint256 submitterBalance = submitter.balance;
        emit log_named_uint("userBalance", userBalance);
        emit log_named_uint("submitterBalance", submitterBalance);
        uint256 calculatedFeeBips;
        if (submitterBalance > 0) {
            // we add (submitterBalance - 1) in the first part of this calculation here to counter-act rounding down when the fee is actually calculated
            calculatedFeeBips = (submitterBalance * MAX_BIPS + submitterBalance - 1) / (submitterBalance + userBalance);
        }
        emit log_named_uint("calculatedFeeBips (backed out)", calculatedFeeBips);
        require(calculatedFeeBips == uniswapOrder.feeBips, "fee bips incorrect!");
    }

    // unused internal function, left in from prior testing
    function _callPermit(IERC2612 permitToken, address sender, address spender, Bridgeless.Permit memory permit) internal {
        permitToken.permit(sender, spender, permit.value, permit.deadline, permit.v, permit.r, permit.s);
    }
}