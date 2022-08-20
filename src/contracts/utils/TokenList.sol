// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

abstract contract TokenList {
    mapping(address => bool) public is_IERC2612;
    mapping(address => bool) public is_IDAILike;

    constructor() {
        uint256 chainId = block.chainid;
        // ETH
        if (chainId == 1) {
            _add_IERC2612(ETH_USDC);
            _add_IDAILike(ETH_DAI);
            _add_IERC2612(ETH_ANY_WOW);
            _add_IERC2612(ETH_ANY_STFI);
            _add_IERC2612(ETH_ANY_HND);
            _add_IERC2612(ETH_ANY_MIM);
            _add_IERC2612(ETH_ANY_AGS);
            _add_IERC2612(ETH_ANY_DAI);
            _add_IERC2612(ETH_ANY_USDC);
            _add_IERC2612(ETH_ANY_ETH);
            _add_IERC2612(ETH_ANY_USDT);
            _add_IERC2612(ETH_ANY_AVA);
            _add_IERC2612(ETH_ANY_BOO);
            _add_IERC2612(ETH_ANY_wMEMO);
        }
    }

    function _add_IERC2612s(address[] memory tokens) internal {
        uint256 tokensLength = tokens.length;
        for (uint256 i; i < tokensLength;) {
            _add_IERC2612(tokens[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _add_IERC2612(address token) internal {
        is_IERC2612[token] = true;
    }

    function _add_IDAILikes(address[] memory tokens) internal {
        uint256 tokensLength = tokens.length;
        for (uint256 i; i < tokensLength;) {
            _add_IDAILike(tokens[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _add_IDAILike(address token) internal {
        is_IDAILike[token] = true;
    }

    // IERC2612
    address internal constant ETH_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // no permit functionality
    address internal constant ETH_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // IDAILikePermit
    address internal constant ETH_DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
// AnyswapV5ERC20s
    // IERC2612
    address internal constant ETH_ANY_WOW = 0x3405A1bd46B85c5C029483FbECf2F3E611026e45;
    // IERC2612
    address internal constant ETH_ANY_STFI = 0xFD9cd8c0D18cD7e06958F3055e0Ec3ADbdba0B17;
    // IERC2612
    address internal constant ETH_ANY_HND = 0x10010078a54396F62c96dF8532dc2B4847d47ED3;
    // IERC2612
    address internal constant ETH_ANY_MIM = 0xbbc4A8d076F4B1888fec42581B6fc58d242CF2D5;
    // IERC2612
    address internal constant ETH_ANY_AGS = 0x667Fd83E24Ca1D935d36717D305D54fA0CAC991C;
    // IERC2612
    address internal constant ETH_ANY_DAI = 0x739ca6D71365a08f584c8FC4e1029045Fa8ABC4B;
    // IERC2612
    address internal constant ETH_ANY_USDC = 0x7EA2be2df7BA6E54B1A9C70676f668455E329d29;
    // IERC2612
    address internal constant ETH_ANY_ETH = 0xB153FB3d196A8eB25522705560ac152eeEc57901;
    // IERC2612
    address internal constant ETH_ANY_USDT = 0x22648C12acD87912EA1710357B1302c6a4154Ebc;
    // IERC2612
    address internal constant ETH_ANY_AVA = 0x442B153F6F61C0c99A33Aa4170DCb31e1ABDa1D0;
    // IERC2612
    address internal constant ETH_ANY_BOO = 0x55aF5865807b196bD0197e0902746F31FBcCFa58;
    // IERC2612
    address internal constant ETH_ANY_wMEMO = 0x3b79a28264fC52c7b4CEA90558AA0B162f7Faf57;
    // IERC2612
    // address internal constant ETH_ANY_ = ;

    // IERC2612
    address internal constant POLYGON_USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    // no permit functionality
    address internal constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    // IDAILikePermit
    address internal constant POLYGON_DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
// AnyswapV5ERC20s
    // IERC2612
    address internal constant POLYGON_ANY_HAKKA = 0x978338A9d2d0aa2fF388d3dc98b9bF25bfF5efB4;
    // IERC2612
    address internal constant POLYGON_ANY_WBTC = 0x161DE8f0b9a59C8197E152da422B9031D3eaf338;
    // IERC2612
    address internal constant POLYGON_ANY_ICE = 0x4e1581f01046eFDd7a1a2CDB0F82cdd7F71F2E59;
    // IERC2612
    address internal constant POLYGON_ANY_REQ = 0xB25e20De2F2eBb4CfFD4D16a55C7B395e8a94762;
    // IERC2612
    address internal constant POLYGON_ANY_MIMATIC = 0x95dD59343a893637BE1c3228060EE6afBf6F0730;
    // IERC2612
    address internal constant POLYGON_ANY_DERC = 0xB35fcBCF1fD489fCe02Ee146599e893FDCdC60e6;

    // IERC2612
    address internal constant ARBI_USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    // IERC2612
    address internal constant ARBI_WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    // IERC2612
    address internal constant ARBI_DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
// AnyswapV5ERC20 -- more are bound to exist
    // IERC2612
    address internal constant ARBI_MIM = 0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A;
    // IERC2612
    address internal constant ARBI_ELK = 0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A;

    // IERC2612
    address internal constant AVAX_USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    // no permit functionality
    address internal constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    // "DAI.e" -- no permit functionality
    address internal constant AVAX_DAI = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70;
    // *nearly* IERC2612, but does not define a `DOMAIN_SEPARATOR` function
    address internal constant AVAX_PNG = 0x60781C2586D68229fde47564546784ab3fACA982;
    // *nearly* IERC2612, but defines `getDomainSeparator` function instead of `DOMAIN_SEPARATOR`
    address internal constant AVAX_YAK = 0x59414b3089ce2AF0010e7523Dea7E2b35d776ec7;
    // *nearly* IERC2612, but defines `EIP712_REVISION` function (which returns bytes) instead of `version` (which returns string) --  used in calculating DOMAIN_SEPARATOR
    address internal constant AVAX_avWETH = 0x53f7c5869a859F0AeC3D334ee8B4Cf01E3492f21;
    // *nearly* IERC2612, but defines `EIP712_REVISION` function (which returns bytes) instead of `version` (which returns string) --  used in calculating DOMAIN_SEPARATOR
    address internal constant AVAX_avDAI = 0x47AFa96Cdc9fAb46904A55a6ad4bf6660B53c38a;
    // *nearly* IERC2612, but defines `EIP712_REVISION` function (which returns bytes) instead of `version` (which returns string) --  used in calculating DOMAIN_SEPARATOR
    address internal constant AVAX_avUSDT = 0x532E6537FEA298397212F09A61e03311686f548e;
    // *nearly* IERC2612, but defines `EIP712_REVISION` function (which returns bytes) instead of `version` (which returns string) --  used in calculating DOMAIN_SEPARATOR
// uses "USDC.e" as underlying
    address internal constant AVAX_avUSDC = 0x46A51127C3ce23fb7AB1DE06226147F446e4a857;
    // *nearly* IERC2612, but defines `EIP712_REVISION` function (which returns bytes) instead of `version` (which returns string) --  used in calculating DOMAIN_SEPARATOR
    address internal constant AVAX_avAAVE = 0xD45B7c061016102f9FA220502908f2c0f1add1D7;
    // *nearly* IERC2612, but defines `EIP712_REVISION` function (which returns bytes) instead of `version` (which returns string) --  used in calculating DOMAIN_SEPARATOR
    address internal constant AVAX_avWBTC = 0x686bEF2417b6Dc32C50a3cBfbCC3bb60E1e9a15D;
    // *nearly* IERC2612, but defines `EIP712_REVISION` function (which returns bytes) instead of `version` (which returns string) --  used in calculating DOMAIN_SEPARATOR
    address internal constant AVAX_avWAVAX = 0xDFE521292EcE2A4f44242efBcD66Bc594CA9714B;
    // *nearly* IERC2612, but defines `EIP712_REVISION` function (which returns bytes) instead of `version` (which returns string) --  used in calculating DOMAIN_SEPARATOR
// uses "USDC" as underlying
    address internal constant AVAX_aAvaUSDC = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;
    // *nearly* IERC2612, but defines `EIP712_REVISION` function (which returns bytes) instead of `version` (which returns string) --  used in calculating DOMAIN_SEPARATOR
    address internal constant AVAX_aAvaDAI = 0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE;

    // IERC2612
    address internal constant BOO = 0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE;
    // no permit functionality
    address internal constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
    // IERC2612
    address internal constant FTM_DAI = 0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E;

    // one of first tokens to come up when you google 'erc2612 bsc'
    // IERC2612
    address internal constant ORT = 0x1d64327C74d6519afeF54E58730aD6fc797f05Ba;
    // no permit functionality
    address internal constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    // no permit functionality
    address internal constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    // IDAILikePermit
    address internal constant VAI = 0x4BD17003473389A42DAF6a0a729f6Fdb328BbBd7;
}
