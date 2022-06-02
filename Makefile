# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge build --sizes --force
test   :; forge test -vvv --rpc-url=${ETH_RPC_URL} --fork-block-number 14302075 --via-ir
trace   :; forge test -vvvv --rpc-url=${ETH_RPC_URL} --fork-block-number 14302075
clean  :; forge clean
snapshot :; forge snapshot