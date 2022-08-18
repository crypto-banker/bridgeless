// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

abstract contract TokenAddresses {
    address internal constant ETH_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant ETH_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant ETH_DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address internal constant POLYGON_USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address internal constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address internal constant POLYGON_DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;

    address internal constant ARBI_USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address internal constant ARBI_WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant ARBI_DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    address internal constant AVAX_USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address internal constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    // "DAI.e"
    address internal constant AVAX_DAI = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70;

    address internal constant BOO = 0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE;
    address internal constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
    address internal constant FTM_DAI = 0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E;

    // one of first tokens to come up when you google 'erc2612 bsc'
    address internal constant ORT = 0x1d64327C74d6519afeF54E58730aD6fc797f05Ba;
    address internal constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
}