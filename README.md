# Bridgeless
Minimal (somewhat, at least) implementation of a method to perform a "gasless" (or so-called "meta transaction") swap, *from* an ERC20 token that is EIP-2612 compliant -- i.e. it implements the standard ERC20 `permit` function -- *to* the native token of the chain.

## Installation
This repo uses Foundry. Get it, then run
`forge install`

## Running Tests
First set
`ETH_RPC_URL="YOUR_RPC_URL_HERE"`
Then run
forge test --fork-url $ETH_RPC_URL -vv