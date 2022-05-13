# :ghost: Example listing Aave v2

This repository contains an example of a listing on Aave v2 Ethereum, including some useful helpers to test the protocol post-proposal execution.

- Proposal payload: [ENSListingPayload](./src/ENSListingPayload.sol)
- Listing tests: [ValidationENSListing](./src/test/ValidationENSListing.sol)
- Aave v2 pool helpers: [AaveV2Helpers](./src/test/utils/AaveV2Helpers.sol)
- Aave governance helpers: [AaveGovHelpers](./src/test/utils/AaveGovHelpers.sol)

<br>
<br>

### Dependencies

```
make update
```

### Compilation

```
make build
```

### Testing

```
make test
```