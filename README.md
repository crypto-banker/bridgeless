<a name="intro"/></a>
# Bridgeless
Bridgeless is a minimal implementation of a framework for "gasless" swaps, utilizing so-called "meta transactions".
It currently supports swaps *from* an ERC20 token that has some kind of signed approval support (e.g. EIP-2612 compliant, DAI-like approvals, etc.) *to* **EITHER**:
* the native token of the chain (ETH for Ethereum Mainnet, BNB for Binance Smart Chain, AVAX for Avalanche C-Chain, etc.)
**OR**
* another ERC20 token

<a name="disclaimer"/></a>
## Disclaimer
THIS SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THIS SOFTWARE OR THE USE OR OTHER DEALINGS IN THIS SOFTWARE.

# Table of Contents  
- [Intro](#intro)
* [Disclaimer](#disclaimer)  
* [Features](#features)  
* [Installation](#installation)  
* [Contracts](#contracts)  
* [Future Improvements](#improvements)  
* [Contributing To or Building On Bridgeless](#contributing)  
* [Donating / Tips](#donating)

<a name="features"/></a>
## Features
Bridgeless is:
1. **Chain-Agnostic**: Bridgeless makes no assumptions about existing chain infrastructure, and can be easily deployed on any EVM-compatible chain.
2. **Exchange-Agnostic**: Bridgeless does not care how a `fulfiller` satisfies any (set of) user order(s). `Fulfiller`s can use multiple DEXes and a private orderbook all in the same transaction if they'd like to -- the sky is the limit!
3. **Signed Approval Signature Scheme-Agnostic** : As mentioned above, Bridgeless makes no assumptions about the signed approval scheme of the ERC20 tokens which its `user`s swap.
4. **Not Rent Seeking**: Bridgeless makes *zero* money itself, and has *no value capture mechanism* built into it. Instead, Bridgeless merely provides a free, open source, trustless platform on which `user`s and `fulfiller`s can transact freely.
5. **A Public Good**: Bridgeless provides a *provably neutral platform*, facilitating transactions that would otherwise be impossible. Bridgeless is licensed with the copyleft [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.en.html) license, to ensure that it will remain in the public domain.

<a name="installation"/></a>
## Installation
This repo uses [Foundry](https://book.getfoundry.sh/). Get it, then run:
`forge install`

<a name="tests"/></a>
## Running Tests
First create a .env file and set your RPC URLs (see .env.example)
Then run:
forge test -vv

You can also run the tests for just a single network using flags, for example:
forge test -vv --match-test Mainnet
or
forge test -vv --match-test BSC

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
This function fulfills a single `BridgelessOrder`, swapping `order.amountIn` of the ERC20 token `order.tokenIn`. The `Bridgeless` contract verifies that the `tokenOwner` did indeed sign the output of `calculateBridgelessOrderHash(tokenOwner, order)` (see below for `calculateBridgelessOrderHash` function description) by checking against the provided ECDSA `signature` input. Next, `order.amountIn` of the ERC20 token `order.tokenIn` is *optimistically transferred* to the provided `swapper` contract, and execution is then handed over to the `swapper` through a call to `swapper.bridgelessCall(tokenOwner, order, extraCalldata)`. Lastly, after the call to the `swapper` contract has resolved and execution has passed back to the `Bridgeless` contract, it checks that the `tokenOwner`'s order was properly fulfilled by verifying that their balance of `order.tokenOut` increased by *at least* `order.amountOutMin` as a result of the call to the `swapper` contract.

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
This function fulfills an arbitrary number of `BridgelessOrder`s at the same time. It operates very similarly to the `fulfillOrder` function, but expects that all of the aggregated `BridgelessOrder`s are fulfilled through a single call to `swapper.bridgelessCalls(tokenOwners, orders, extraCalldata)`. Verification of order fulfillment is performed in a batch fashion following this call.

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
This interface defines the (at present) two functions that a `Bridgeless Adapter` must define in order to be used in calls to `Bridgeless.fulfillOrder` and `Bridgeless.fulfillOrders`.

### BridgelessStructs
The `BridgelessStructs` interface simply defines the two struct types -- `BridgelessOrder` and `Signature` that are shared amongst all of Bridgeless's other contracts.

### BridgelessSwapperUniswap
This is a *mock* contract, designed to demonstrate a single possible implementation of the `IBridgelessCallee` interface. While not necessarily intended for production use, it is used as a Proof of Concept for all of the tests in the `Tests.t.sol` file, which provide evidence of its functionality.
The `BridgelessSwapperUniswap` contract routes all trades through UniswapV2 pools, using very simple routing; for each order it fulfills, it swaps 100% of `order.amountIn` for `order.tokenOut`, sends `order.amountOutMin` of `order.tokenOut` to the `user` who created the order, and sends any extra `order.tokenOut` tokens obtained in the swap to `tx.origin`.

<a name="improvements"/></a>
## Future Improvements
I would like to add:
* More order types. Perhaps one-to-many type orders, or orders supporting ERC721 (and/or ERC1155) tokens as well.
* More flexibility in order-fulfillment checks. Perhaps something like the [Drippie](https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts-periphery/contracts/universal/drippie/Drippie.sol) contract for support of arbitrary checks.
* Additional mocks. More advanced integrations, additional architectures, etc.
* More tests. Support for additional chains, complex order aggregation & routing, etc.
* Gas optimization. There's definitely some "low hanging fruit" for places to save gas, as well as less obvious and more difficult gas savings to be realized.

<a name="contributing"/></a>
## Contributing To or Building On Bridgeless
Bridgeless is an open source project built with love! :heart:

If you'd like to contribute, feel free to open a PR. If you're adding more features, please document your changes, at the very least with some in-line comments.

If you have questions or you'd like to discuss Bridgeless, you can DM @TokenPhysicist on Twitter.

If you're thinking of building on Bridgeless, I'd be thrilled to help support your work -- building these contracts was cool, but it would be way more fun to see them really put to use!

<a name="donating"/></a>
## Donating / Tips
Bridgeless is and will always be free software; it is distributed free-of-charge and was built for fun, with no goal or expectation of monetary gain.

That being said, if you appreciate Bridgeless and would like to contribute to its continued development and the development of other similar public goods, we happily accept donations on any EVM-enabled chain to the following address:

0x5A94A7Acb3F34aEeac6BbCF7D8fFc3302D9b3d63