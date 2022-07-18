# :ghost: Example listing Aave v2

This repository contains an example of a listing on Aave v2 Ethereum, including some useful helpers to test the protocol post-proposal execution.

- Proposal payload: [ENSListingPayload](./src/ENSListingPayload.sol)
- Listing tests: [ValidationENSListing](./src/test/ValidationENSListing.sol)
- Aave v2 pool helpers: [AaveV2Helpers](./src/test/utils/AaveV2Helpers.sol)
- Aave governance helpers: [AaveGovHelpers](./src/test/utils/AaveGovHelpers.sol)

### Prepare env

```sh
cp .env.example .env
```

### Dependencies

```sh
make update
```

### Compilation

```sh
make build
```

### Testing

```sh
make test
```

### Diffing

You can use the diffing utility to generate the diff between two contracts.

```sh
sh diff.sh <pathA> <pathB> <outName>
```

If one of the contracts is deployed you can download the contract from etherscan via `make download address=0x...`

For a mainnet v2 listing you might want to diff the a/s/v implementations, with a standard implementation (like e.g. the ones of DAI) to ensure it's correct.

```sh
# ENS vs DAI diff example
make download address=0x7b2a3cf972c3193f26cdec6217d27379b6417bd0 # aDAI impl
make download address=0xB2f4Fb41F01CdeF7c10F0e8aFbeB3cFA79d1686F # aENS impl

# generate aTokenDiff via
sh ./diff.sh ./src/etherscan/0x7b2a3cf972c3193f26cdec6217d27379b6417bd0 ./src/etherscan/0xB2f4Fb41F01CdeF7c10F0e8aFbeB3cFA79d1686F aENSimplDiff

# If the code is verified with flattened format you would need to bring the contracts in a similar format.
# You can do so by flattening the respective contract.
# In the example case of ENS and DAI where both are verified via json this method should not be used.
forge flatten ./src/etherscan/0x7b2a3cf972c3193f26cdec6217d27379b6417bd0/AToken/@aave/protocol-v2/contracts/protocol/tokenization/AToken.sol --output ./src/etherscan/0x7b2a3cf972c3193f26cdec6217d27379b6417bd0/Flattened.sol
```
