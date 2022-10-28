// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import 'forge-std/Test.sol';
import 'forge-std/Script.sol';
import {AaveV2Ethereum} from 'aave-address-book/AaveV2Ethereum.sol';

contract DeployImplementationsScript is Script, Test {
  address internal constant UNDERLYING_ASSET = address(0);
  string public constant UNDERLYING_ASSET_SYMBOL = 'ENS';
  uint8 public constant DECIMALS = 18;

  address internal constant INCENTIVES_CONTROLLER =
    address(0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5);

  string public constant ATOKEN_NAME_PREFIX = 'Aave interest bearing ';
  string public constant ATOKEN_SYMBOL_PREFIX = 'a';
  string public constant VAR_DEBT_NAME_PREFIX = 'Aave variable debt bearing ';
  string public constant VAR_DEBT_SYMBOL_PREFIX = 'variableDebt';
  string public constant STABLE_DEBT_NAME_PREFIX = 'Aave stable debt bearing ';
  string public constant STABLE_DEBT_SYMBOL_PREFIX = 'stableDebt';

  // artifacts
  string internal constant aTokenArtifact = 'AToken.sol:AToken';
  string internal constant stableDebtArtifact =
    'stableDebt.sol:StableDebtToken';
  string internal constant variableDebtArtifact =
    'varDebt.sol:VariableDebtToken';

  function run() external {
    vm.startBroadcast();

    address aToken = deployCode(
      aTokenArtifact,
      abi.encode(
        AaveV2Ethereum.POOL,
        UNDERLYING_ASSET,
        AaveV2Ethereum.COLLECTOR,
        string(abi.encodePacked(ATOKEN_NAME_PREFIX, UNDERLYING_ASSET_SYMBOL)),
        string(abi.encodePacked(ATOKEN_SYMBOL_PREFIX, UNDERLYING_ASSET_SYMBOL)),
        INCENTIVES_CONTROLLER
      )
    );

    address stableDebt = deployCode(
      stableDebtArtifact,
      abi.encode(
        AaveV2Ethereum.POOL,
        UNDERLYING_ASSET,
        string(
          abi.encodePacked(STABLE_DEBT_NAME_PREFIX, UNDERLYING_ASSET_SYMBOL)
        ),
        string(
          abi.encodePacked(STABLE_DEBT_SYMBOL_PREFIX, UNDERLYING_ASSET_SYMBOL)
        ),
        INCENTIVES_CONTROLLER
      )
    );

    address varDebt = deployCode(
      variableDebtArtifact,
      abi.encode(
        AaveV2Ethereum.POOL,
        UNDERLYING_ASSET,
        string(abi.encodePacked(VAR_DEBT_NAME_PREFIX, UNDERLYING_ASSET_SYMBOL)),
        string(
          abi.encodePacked(VAR_DEBT_SYMBOL_PREFIX, UNDERLYING_ASSET_SYMBOL)
        ),
        INCENTIVES_CONTROLLER
      )
    );

    vm.stopBroadcast();
  }
}
