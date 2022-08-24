# Bridgeless

## Table of Contents  
* [Introduction](#introduction)
* [Installation](#installation)
* [Example Use Case & Order Flow](#example)
* [Contracts](#contracts)
* [Ethos](#ethos) 
* [Future Improvements](#improvements)
* [Contributing To or Building On Bridgeless](#contributing)
* [Donating / Tips](#donating)
* [Disclaimer](#disclaimer)

<a name="introduction"/></a>
## Introduction
Bridgeless is a decentralized order book and conduit that sits outside of and above existing decentralized exchanges. Orders exist off-chain until they are executed, and by design anyone can fulfill an order on behalf of the user who created it.

Bridgeless is designed to do the minimum amount necessary, to allow maximum flexibility in as many ways as possible. On order execution, Bridgeless verifies order legitimacy & validity, optimistically passes order fulfillment onto code specified by the Fulfiller, and verifies that the order was correctly fulfilled. That's it.

Through its flexible, minimal design, Bridgeless simultaneously realizes multiple upgrades to all DEXes in a permissionless fashion:

1. By decoupling the order book from any single exchange, Bridgeless *flips the order flow* – rather than forcing users to select a single DEX or even single DEX aggregator to "own" their order, users can broadcast their order and make aggregators compete to fill it! Driving aggregator competition to its maximum forces aggregators to compete in every aspect – fastest execution, best matching engine, most gas-efficient implementation – accelerating the rate of innovation and pushing the market to deliver the absolute best user experience.

2. Since orders are simply digital signatures rather than transactions, *order creation is totally free*.

3. Splitting order creation and execution means order execution can be performed by the party fulfilling an order, rather than the user placing it. This means that *users never have to pay gas fees*, and in particular, that *costs for failed transactions are never borne by users*, but instead only by aggregators.

4. Bridgeless's powerful, composable orders can be combined into arbitrarily complex “programmable” order chains and order trees, enabling the construction of entire trading strategies through order composition. This empowers innovative new types of services, which can aide users in constructing sets of orders for bespoke trading logic.

Bridgeless currently supports orders on any EVM-compatible blockchain, from any ERC20 token to either another ERC20 token or the native token of the chain.

Orders follow a *single standard* with optional flags and parameters to enhance order specificity while keeping the standard unified and extensible.

The base of an order is an offer to trade `X` of `token A` for `Y` of `token B`, at or before the order's `deadline`.

Each order also has a specified `nonce`. For each signer, a maximum of one order with a given `nonce` value can ever be executed; this allows users to create mutually-exclusive orders that share a nonce, such as a set of limit orders to trade the same fixed block of tokens at various prices, where as soon as one order in the set is executed, the others automatically become invalid.

Optional Parameters currently supported are:

* **Order Executor** – specify an address that is allowed to execute your order. This can be your counterparty in an OTC trade, or a specific aggregator network that you trust to pay you referral fees, share trading revenue with you, etc.
* **Order Delay** – sign an order now that only becomes valid in the future. Combine with **nonce set** functionality to make *conditional orders*, e.g. a limit order that becomes valid only if your other order has not already been fulfilled an hour from now.

Even more features coming soon.

Check out the existing functionality showcased in our tests, or learn more by reading on below.


<a name="installation"/></a>
## Installation
This repo uses [Foundry](https://book.getfoundry.sh/). Get it, then run:

`forge install`


<a name="tests"/></a>
## Tests
The tests file -- `/src/test/Tests.t.sol` provides multiple automated tests against forked networks.

Currently, tests have coverage for 6 networks, although adding more is easy!

To run the tests, first create a .env file and set your RPC URLs (see the .env.example file).

Then run:

`forge test -vv`

You can also run the tests for just a single network using flags. For example:

`forge test -vv --match-test Mainnet`

or

`forge test -vv --match-test BSC`

If you're looking to learn more about how to use Bridgeless's contracts, the tests are a great place to start.


<a name="example"/></a>
## Example Usecase & Order Flow
Suppose `User` has been airdropped some ERC20 `tokenA` on a new EVM chain, named `NewChain`. `User` would like to transact on `NewChain`, but they cannot send any transactions on `NewChain`, since they don't have any of the chain's native token, `NEW`. The simplest solution would be swapping some of their `tokenA` for `NEW`, but since the `User` does not have any `NEW`, they cannot even pay the gas fee to perform this swap on a DEX.

With Bridgeless, `User` can simply issue 2 **digital signatures**, and let a `fulfiller` perform the swap for them! The first digital signature is a signed approval to allow the `Bridgeless` contract to transfer the `User`'s `tokenA`. The second digital signature cryptographically attests to the `User`'s desire to swap `X` of `tokenA` for `Y` of `NEW`, within their desired `deadline` (e.g. within the next 5 minutes).

`Fulfiller` finds a good swap route, takes the `User`'s digital signatures, and bundles together a single complex transaction, in which:
1. A call is made to `tokenA.permit`; the `tokenA` contract checks the `User`'s first digital signature and then completes the action of `User` giving the `Bridgeless` contract the power to transfer their `tokenA`s.
2. A call is made to `Bridgeless.fulfillOrder`, which verifies the integrity of the order by checking it against the `User`'s second digital signature, transfers `X` of `tokenA` from `User` to an `BridgelessCallee` contract specified by the `Fulfiller`, passing on the order details.
3. The `BridgelessCallee` contract executes the trade, taking the provide `tokenA` ERC20 tokens and swapping them for `Z` of `NEW`, where `Z > Y`.
4. The adapter sends `Y` of `NEW` to `User`. The `Fulfiller` is free to keep the excess `(Z - Y)` in `NEW` tokens.
5. The `Bridgeless` contract verifies that the order was fulfilled successfully and **reverts the entire transaction** if the order was not adequately fulfilled. If a transaction reversion takes place, the `Fulfiller` still pays the transaction fees; in this case the `User` does not pay anything and all `tokenA` tokens remain in their wallet.

Assuming successful order fulfillment, we have:
* The `User` has successfully swapped `X` of `tokenA` for `Y` of `NEW`
* The `Fulfiller` has made a revenue of `(Z - Y)` in `NEW` tokens -- if this amount exceeds the gas fees of their transaction, then they have made a profit!

Note that a fulfiller can accomplish this complex transaction through a custom-built smart contract, or by simply intelligently combining multiple permissionless smart contracts, as is demonstrated in this repository's existing tests.


<a name="contracts"/></a>
## Contracts
### Bridgeless
This is the core Bridgeless contract, acting as the conduit for **Gasless Swaps**.
Gasless Swaps are transactions in which the `user` making the swap pays zero gas fees. Transaction fees are instead paid by a `fulfiller` who executes the swap; the `Bridgeless`contract itself merely checks that:
1. The `user` signed the `BridgelessOrder` defining their order.
2. The `BridgelessOrder` has not expired.
3. The `fulfiller` properly meets the requirements of the `user`'s `BridgelessOrder`.

At present `Bridgeless` contract provides only 3 external functions. They are:
#### 1. fulfillOrder
```solidity!
    function fulfillOrder(
        IBridgelessCallee swapper,
        address tokenOwner,
        BridgelessOrder calldata order,
        Signature calldata signature,
        bytes calldata extraCalldata
    )
```
This function fulfills a single `BridgelessOrder`, swapping `order.amountIn` of the ERC20 token `order.tokenIn`.

The `Bridgeless` contract verifies that the `tokenOwner` did indeed sign the output of `calculateBridgelessOrderHash(tokenOwner, order)` (see below for `calculateBridgelessOrderHash` function description) by checking against the provided ECDSA `signature` input.

Next, `order.amountIn` of the ERC20 token `order.tokenIn` is *optimistically transferred* to the provided `swapper` contract, and execution is then handed over to the `swapper` through a call to `swapper.bridgelessCall(tokenOwner, order, extraCalldata)`.

Lastly, after the call to the `swapper` contract has resolved and execution has passed back to the `Bridgeless` contract, it checks that the `tokenOwner`'s order was properly fulfilled by verifying that their balance of `order.tokenOut` increased by *at least* `order.amountOutMin` as a result of the call to the `swapper` contract.

#### 2. fulfillOrders
```solidity!
    function fulfillOrders(
        IBridgelessCallee swapper,
        address[] calldata tokenOwners,
        BridgelessOrder[] calldata orders,
        Signature[] calldata signatures,
        bytes calldata extraCalldata
    )
```
This function fulfills an arbitrary number of `BridgelessOrder`s at the same time.

It operates very similarly to the `fulfillOrder` function, but expects that all of the aggregated `BridgelessOrder`s are fulfilled through a single call to `swapper.bridgelessCalls(tokenOwners, orders, extraCalldata)`.

Verification of order fulfillment by the `Bridgeless` contract is performed in a batch fashion following the call to the `swapper` contract.

#### 3. calculateBridgelessOrderHash
```solidity!
    function calculateBridgelessOrderHash(address owner, BridgelessOrder calldata order) public view returns (bytes32) {
        bytes32 orderHash = keccak256(
            abi.encode(
                ORDER_TYPEHASH,
                order.tokenIn,
                order.amountIn,
                order.tokenOut,
                order.amountOutMin,
                order.deadline,
                nonces[owner]
            )
        );
        return orderHash;
    }
```
This is a simple, 'view'-type function designed to help calculate orderHashes for `BridgelessOrder`s.

### IBridgelessCallee
This interface defines the (at present) two functions that a `BridgelessCallee`-type contract must define in order to be used in calls to `Bridgeless.fulfillOrder` and `Bridgeless.fulfillOrders`.

### BridgelessStructs
The `BridgelessStructs` interface simply defines the two struct types -- `BridgelessOrder` and `Signature` that are shared amongst all of Bridgeless's other contracts.

### BridgelessSwapperUniswap
This is a *mock* contract, designed to demonstrate a single possible implementation of the `IBridgelessCallee` interface. While not necessarily intended for production use, it is used as a Proof of Concept for all of the tests in the `Tests.t.sol` file, which provide evidence of its functionality.

The `BridgelessSwapperUniswap` contract routes all trades through UniswapV2 pools, using very simple routing; for each order it fulfills, it swaps 100% of `order.amountIn` for `order.tokenOut`, sends `order.amountOutMin` of `order.tokenOut` to the `user` who created the order, and sends any extra `order.tokenOut` tokens obtained in the swap to `tx.origin`.


<a name="ethos"/></a>
## Ethos
Bridgeless is built to be:
1. **Trustless**: There are absolutely zero admin or owner privileges in Bridgeless, and it is entirely non-upgradeable. Bridgeless acts a verifiably neutral intermediary, facilitating transactions between users and order fulfillers that would otherwise require the users to trust the fulfillers.
2. **Chain-Agnostic**: Bridgeless makes no assumptions about existing chain infrastructure, and can be easily deployed on any EVM-compatible chain.
3. **Exchange-Agnostic**: Bridgeless does not care how a Fulfiller satisfies any (set of) user order(s). Fulfillers can use multiple DEXes and a private orderbook all in the same transaction if they'd like to -- the sky is the limit.
4. **Not Rent Seeking**: Bridgeless makes *zero* money itself, and has *no value capture mechanism* built into it. Instead, Bridgeless merely provides a free, open source, trustless platform on which users and Fulfillers can transact permissionlessly.
5. **A Public Good**: Bridgeless provides a *provably neutral platform*, facilitating transactions that would otherwise be impossible. Bridgeless is licensed with the copyleft [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.en.html) license, to ensure that improvements to it will remain in the public domain. Anyone is free to commercialize Bridgeless, but they must apply the same copyleft license to their work!
6. **Decentralized**: Bridgeless was designed with a maximally decentralized architecture in mind. If a user has provided the necessary signatures to a Bridgeless contract, then *anyone* can fulfill their order, in any fashion they'd like. Likewise, even the 'mock' BridgelessSwapperUniswap contract is designed as a permissionless adapter, allowing anyone to fulfill a user's order through a simple swap on UniswapV2-type pools.


<a name="improvements"/></a>
## Future Improvements
I would like to add:
* More order types. Perhaps one-to-many type orders, or orders supporting ERC721 (and/or ERC1155) tokens as well as support of more "Uniswap-style" orders, like specifying an exact amount out with maxAmountIn.
* More flexibility in order-fulfillment checks. Perhaps something like the [Drippie](https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts-periphery/contracts/universal/drippie/Drippie.sol) contract for support of arbitrary checks.
* Additional mocks. More advanced integrations, additional architectures, etc.
* More tests. Support for additional chains, complex order aggregation & routing, etc.
* Gas optimization. There's definitely some "low hanging fruit" for places to save gas, as well as less obvious and more difficult gas savings to be realized.


<a name="contributing"/></a>
## Contributing To or Building On Bridgeless
Bridgeless is an open source project built with love! :heart:

If you'd like to contribute, feel free to open a PR. If you're adding more features, please document your changes, at the very least with some in-line comments.

If you're thinking of building on Bridgeless, I'd be thrilled to help support your work -- building these contracts was cool, but it would be way more fun to see them really put to use!

If you have questions or you'd like to discuss Bridgeless, you can DM @TokenPhysicist on Twitter.


<a name="donating"/></a>
## Donating / Tips
Bridgeless is and will always be free software; it is distributed free-of-charge and was built for fun, with no goal or expectation of monetary gain.

That being said, if you appreciate Bridgeless and would like to contribute to its continued development and the development of other similar public goods, we happily accept donations on any EVM-enabled chain to the following address:

0x5A94A7Acb3F34aEeac6BbCF7D8fFc3302D9b3d63


<a name="disclaimer"/></a>
## Disclaimer
THIS SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THIS SOFTWARE OR THE USE OR OTHER DEALINGS IN THIS SOFTWARE.