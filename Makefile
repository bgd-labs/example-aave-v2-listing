# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge build --sizes --via-ir
test   :; forge test -vvv --rpc-url=${ETH_RPC_URL} --fork-block-number 15127191 --via-ir
trace   :; forge test -vvvv --rpc-url=${ETH_RPC_URL} --fork-block-number 15127191 --via-ir
clean  :; forge clean
snapshot :; forge snapshot