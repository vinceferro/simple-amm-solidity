https://github.com/ShipyardDAO/student.vinceferro/tree/13120d2b3cb9ef46a7051bbc7b01ad0c1682eecf/lp

The following is a micro audit of git commit by 13120d2b3cb9ef46a7051bbc7b01ad0c1682eecf by brianwatroba

# General Comments

1. Great work! Really clean code and a pleasure to audit. I especially liked how compact some of your functions were, especially `getReserves()` and `getBalances()`. You declare your return types and return the calculations in-line without using additional variables. This is very clean and easy to read and makes the contract feel more compact.
2. I appreciated your use of the Space.sol library to separate the concerns of your contract functions.
3. Your commments are well detailed and give good direction without being overly long. Made it much easier to navigate your contracts.

_To think about:_

1. There was one significant high vulnerability related to how you process fees and do your constant product formula checks in SpaceLP.sol. I can tell you modeled your contracts after Uniswap V2, which is great! It's a very innovative model, especially how it optimistically transfers tokens. I encourage you to review how, why, and where Uniswap optimistically transfers tokens, both in the router and pair contracts. [Here is a great resource](https://ethereum.org/en/developers/tutorials/uniswap-v2-annotated-code/) to deep dive into Uniswap's code and understand their design decisions.
2. You had the right intuition to include reentrancy guards where functions make external calls. There were also a few cases where they weren't totally necessary. You'll never hurt your contract's functionality by over including them, but it introduces extra bloat. I encourage you to read more about reentrancy guards to not only feel comfortable with when you should include them, but to also feel comfortable with not using them.

# Design Exercise

1. This is an interesting take! I like that you're focused on optimistic rewards for participants. To think about: how would you guard against people trying to game the system by repeatedly adding and removing liquidity to receive the reward tokens, but not actually participate in the pool?

# Issues

**[H-1]** _Fees are not collected in SpaceLP.sol_

Intended functionality: The SpaceLP.sol contract should receive the full 100% of the "in token" and return an amount of the "out token" equal to 99% of the original "in token". This is how the fee is taken, and the fee should remain in the SpaceLP.sol contract pool and slightly increase K.

However, your `_swap()` function in SpaceRouter.sol currently sends 99% of the original amount to be swapped (lines 131/134) instead of 100%. the `ethOut` or `spcOut` you pass to SpaceLP.sol's `swap()` function is--however--based on the 100% value. In other words, you're expecting more value out than you should be allowed based on what you put in.

In normal cases this would be caught by SpaceLP.sol's `swap()` function when it checks for any decrease in K (your require statement in line 172).

The reason it's not reverting: you're not optimistically transferring the requested "token out" before you check for a decrease in K. In other words, your pool is receiving an inflow of "token in", you're checking the balances (line 160), and then doing a K calculation based on never sending any "tokens out".

If you hadn't added the `onlyRouter()` modifier, this would be a larger vulnerability as I could call the pair contract directly send much lower "token in" and lie to the contract by expecting a full amount out.

The 1% fee is getting lost in the router contract and never making it to the pair contract.

Consider sending the full 100% of token in to your pair contract and optimisitically transferring the token out before doing your K comparison.

**[Insufficient tests]** _Too few tests_

I appreciate the brevity of your tests! It makes them easy to read.

However, I encourage you to review your test coverage to ensure you're considering all of your code paths. You can always run `npx hardhat coverage` to see the diagnostics. Currently, your coverage is ~65%. I encourage you to not only test the "happy paths" for your code, but also the "sad paths".

An example of inefficient tests: in testing your swap functionality, you only test the case of swapping ETH for SPC. It's a core functionality to swap between both tokens.

Consider reviewing test coverage reports and ensuring "sad paths" are tested in addition to "happy paths".

**[Technical mistake-1]** _Reentrancy guard present where not necessary_

All of your functions in SpaceRouter.sol that include external calls to SpaceLP.sol include a reentrancy guard. However, all of the functions they are calling in SpaceLP.sol _also_ have a reentrancy guard. This is effectively doubling up, and the router's guards are not needed in this case.

Consider removing reentrancy guards in SpaceRouter.sol.

**[Code quality]** _Gating Pair Contract Calls to Router_

In SpaceLP.sol you add the `onlyRouter()` modifier to ensure all main function calls can only be called from the router. This is good intuition to control how the pair contract can be called, but also may be limiting.

Uniswap V2 separates the router and the pair contract partly for upgradability. They've already introduced a second router contract to interact with the pair contract. If you hardcode which router can interact with the pair, you can never introduce another version of the router without upgrading both contracts.

Consider not gating your pair contract's functions to only be called by your router.

**[Code quality]** _Interfaces vs. contract imports_

Your SpaceRouter.sol contract imports your SpaceLP.sol and SpaceCoinToken.sol contracts. This effectively copies those contracts into the code of your router contract. This does make it easy to then call functions from the imported contracts, but it greatly increases contract size and deployment costs.

Consider using interfaces for these contracts. It would cut down on contract size and deployment costs.

**[Code quality]** _Declaring variable initial values_

In line 100 you instantiate the `liquidity` variable as having a value of 0. Uint256 types have a default value of 0, so you don't need to set the initial value to 0.

Consider not setting initial values for variables where those initial values are equal to their default values.

# Nitpicks

- You can also declare the variable name (in addition to the type) as your return value in your function definition. In this case, you wouldn't need to provide an explicit `return` statement at the end of your functions. The function would know to find the variable you delcared up front and return that implicitly. It's a personal design decision, but wanted to make sure you're aware of it so you can use it where you'd like!

# Score

| Reason                     | Score |
| -------------------------- | ----- |
| Late                       | -     |
| Unfinished features        | -     |
| Extra features             | -     |
| Vulnerability              | 3     |
| Unanswered design exercise | -     |
| Insufficient tests         | 2     |
| Technical mistake          | 1     |

Total: 6

Good effort!
