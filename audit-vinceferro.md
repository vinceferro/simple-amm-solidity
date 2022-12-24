## General comments
- Like the use of a `uint8` for the lock rather than a `bool`. More gas efficient
- Rather than doing `bool success = token.transferFrom()` there's a nice library `SafeERC20` from OZ that you can use

### L - 1
SpaceLP.sol
- There is an `onlyRouter()` method on all state changing functions, and it is tied to a particular address. This means that if the immutable router `address public immutable router;` ever had a problem and was faulty, this liquidity pool would become potentially unuseable. You wouldn't be able to swap out the flawed router for another. I don't believe there's any reason why you need to restrict the `SpaceLP.sol` to only being callable by the router?

### Q - 1
SpaceRouter.sol
- Not sure you need this check: `require(token.allowance(msg.sender, address(this)) >= _spcIn, "E_INSUFFICIENT_SPC_ALLOWANCE");`. It adds gas and is just there for convenience - the transfer would fail regardless if the allowance wasn't sufficient and the ERC20 would revert with the error. You could query this allowance on the frontend if you want to help a user understand if their allowance is great enough

### Q - 2
SpaceLP.sol 
- It's not necessary to initialise variables to null/zero, like `uint256 private rETH = 0;`. The EVM will set `uint256 private rETH` to 0 automatically. Assume it costs more gas to explicitly set to 0