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

    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 _amountIn;
    uint256 _amountOutMin;
    // address that already has permit token balance, for forked testing
    address addressToSendTokenFrom;

    function setUp() public {
    }

    function testGaslessSwap() public {
        // initialize memory structs
        Bridgeless.UniswapOrder memory uniswapOrder;
        Bridgeless.Permit memory permit;

        // check chainId
        uint256 chainId = block.chainid;
        // emit the chainId for logging purposes
        emit log_named_uint("chainId", chainId);
        // for testing on forked ETH mainnet
        if (chainId == 1) {
            // swap 1e6 USDC for at least 1e9 ETH (i.e. one full USDC for at least one gwei)
            _amountIn = 1e6;
            _amountOutMin = 1e9;

            ROUTER = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
            FACTORY = IUniswapV2Factory(ROUTER.factory());

            // set path to swap USDC => ETH
            address[] memory _path = new address[](2);
            // USDC
            _path[0] = USDC;
            // canonical WETH
            _path[1] = WETH;
            uniswapOrder.path = _path;

            // binance bridge
            addressToSendTokenFrom = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503;
        }

        uniswapOrder.amountIn = _amountIn;
        uniswapOrder.amountOutMin = _amountOutMin;

        // infinite deadline
        uniswapOrder.deadline = type(uint256).max;

        // set fee at 10%
        uniswapOrder.feeBips = 1000;

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
        emit log_named_uint("user.balance", user.balance);
        emit log_named_uint("submitter.balance", submitter.balance);
        // I'm fairly certain this will fail on a flaky basis due to rounding, but it seemed fun to add
        assertEq(
            user.balance * uniswapOrder.feeBips / (10000 - uniswapOrder.feeBips),
            submitter.balance,
            "bad fee charge"
        );
    }

    // unused internal function, left in from prior testing
    function _callPermit(IERC2612 permitToken, address sender, address spender, Bridgeless.Permit memory permit) internal {
        permitToken.permit(sender, spender, permit.value, permit.deadline, permit.v, permit.r, permit.s);
    }
}