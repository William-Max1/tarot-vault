## Tarot Vault

This repository contains the vault contracts of Leverage Finance(forked from the Tarot Protocol). Protocol users can deposit LP tokens in Tarot Vaults and receive Vault Tokens. The deposited LP tokens are then farmed and earned rewards are automatically converted to additional LP tokens and reinvested.

Tarot Vault Tokens are fully compatible with the Tarot Core Contracts. As such, they can be used as collateral in Tarot lending pools, along with their underlying token pairs.

## what have we changed?
- Changing to minting pool into canto dex/lending market pools.
- Changing the fee distribution mode.
- change the uniswap interfaces to better connect to canto dex. 