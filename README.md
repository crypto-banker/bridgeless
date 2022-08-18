# Bridgeless
Minimal (somewhat, at least) implementation of a method to perform a "gasless" (or so-called "meta transaction") swap, *from* an ERC20 token that is EIP-2612 compliant -- i.e. it implements the standard ERC20 `permit` function -- *to* the native token of the chain.

## Contracts
### Bridgeless_Uniswap

## Installation
This repo uses Foundry. Get it, then run:
`forge install`

## Running Tests
First create a .env file and set your RPC URLs (see .env.example)
Then run:
forge test -vv

You can also run the tests for just a single network using flags, for example:
forge test -vv --match-test Mainnet
or
forge test -vv --match-test BSC