# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge build --sizes --via-ir
test   :; forge test -vvv --rpc-url=${ETH_RPC_URL} --fork-block-number 14302075 --via-ir
trace   :; forge test -vvvv --rpc-url=${ETH_RPC_URL} --fork-block-number 14302075
clean  :; forge clean
snapshot :; forge snapshot

# utils
download :; ETHERSCAN_API_KEY=${ETHERSCAN_API_KEY} cast etherscan-source -d etherscan/${address} ${address}

# deploy
deploy-l1-x-proposal-ledger :; forge script script/ProposalCreation.s.sol:DeployX --rpc-url ${RPC_URL} --broadcast --legacy --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} -vvvv
