# Liquidity Pool Contract

Implement a liquidity pool for ETH-SPC. You will need to:

- Write an ERC-20 contract for your pool's LP tokens.
- Write a liquidity pool contract that:
  - Mints LP tokens for liquidity deposits (ETH + SPC tokens)
  - Burns LP tokens to return liquidity to holder
  - Accepts trades with a 1% fee

# SpaceRouter
Transferring tokens to an LP pool requires two transactions:

1. Trader grants allowance to contract X for Y tokens
2. Trader invokes contract X to make the transfer

Write a router contract to handles these transactions. Be sure it can:

- Add / remove liquidity
- Swap tokens, rejecting if the slippage is above a given amount

# Frontend
Extend the given frontend code (coming soon) to enable:

1. LP Management
- Allow users to deposit ETH and SPC for LP tokens (and vice-versa)
2. Trading
- Allow users to trade ETH for SPC (and vice-versa)
- Configure max slippage
- Show the estimated trade value they will be receiving


# Design Exercises
How would you extend your LP contract to award additional rewards – say, a separate ERC-20 token – to further incentivize liquidity providers to deposit into your pool?

The contract for token would be deployed and then assigned to an `address` variable in the LP contract.
This address can be changed so the reward can be any different token that the owner of the LP can buy and offer as a reward - say campaign X gives WETH, campaigns Y gives UNI etc.
Those ERC-20 would be transfered to the LP contract address so the contract can transfer the balance to the liquidity provider.
When a liquidity provider pours in liquidity, they get the burnable LP tokens and the additional ERC-20 token that stays with them even after the funds are reclaimed.

# Deployed contracts
Network: Rinkeby

SpaceCoinToken deployed to:  0x17e3Af701028E804aCAeD7350838A84DF7DA5F3D

SpaceCoinICO deployed to:  0x7fd3734a66C6880658D804A017ac3A85a10B6c78

SpaceRouter deployed to:  0x6F014797d5D8731Ae8Cce4d22f7A5bB27349751f

SpaceLP deployed to:  0x6f015D3423bE8B2F4cC759eac7d80723E2f1f6CF