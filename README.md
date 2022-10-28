# :ghost: Example listing Aave v2

This repository contains an example of a listing on Aave v2 Ethereum, including some useful helpers to test the protocol post-proposal execution.

- Implementations deploy script: [DeployImplementations](./script/DeployImplementations.sol)
- Proposal payload: [ENSListingPayload](./src/ENSListingPayload.sol)
- Listing tests: [ValidationENSListing](test/ValidationENSListing.t.sol)
- Aave v2 pool helpers: [AaveV2Helpers](test/utils/AaveV2Helpers.sol)

### Prepare env

```sh
cp .env.example .env
```

### Dependencies

```sh
forge update
```

### Compilation

```sh
forge build
```

### Testing

```sh
forge test
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
sh ./diff.sh ./etherscan/0x7b2a3cf972c3193f26cdec6217d27379b6417bd0 ./etherscan/0xB2f4Fb41F01CdeF7c10F0e8aFbeB3cFA79d1686F aENSimplDiff

# If the code is only available with flattened format you would need to bring the contracts in a similar format.
# You can do so by flattening the respective contract.
# In the example case of ENS and DAI where both are verified via json this method should not be used.
forge flatten ./etherscan/0x7b2a3cf972c3193f26cdec6217d27379b6417bd0/AToken/@aave/protocol-v2/contracts/protocol/tokenization/AToken.sol --output ./etherscan/0x7b2a3cf972c3193f26cdec6217d27379b6417bd0/Flattened.sol
```

### Production deployment

1. You first need to deploy the implementations for your asset and initialize them.
   You can do so by altering [this line](./script/DeployImplementations.s.sol#L104) in the implementations deployment script to suite your needs and deploying the implementations via `make deploy-implementations`.

2. You then need to deploy the payload following the [ENSListingPayload example](./src/ENSListingPayload.sol). The Payload expects the 3 addresses deployed in step 1) as input on the [constructor](./src/ENSListingPayload.sol#L29).

3. You then need to create the on-chain proposal following the example in [ProposalCreation](./script/ProposalCreation.s.sol).

While these steps build on each other, they don't have to be performed by the same address.
