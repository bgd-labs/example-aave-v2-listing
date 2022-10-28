// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import 'forge-std/Test.sol';
import 'forge-std/Script.sol';
import {AaveV2Ethereum} from 'aave-address-book/AaveV2Ethereum.sol';

interface Initializable {
  function initialize(
    uint8 underlyingAssetDecimals,
    string calldata tokenName,
    string calldata tokenSymbol
  ) external;
}

contract DeployImplementationsScript is Script, Test {
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

  function deployASVTokens(
    address underlyingAsset,
    uint8 decimals,
    string memory underlyingAssetSymbol
  )
    public
    returns (
      address,
      address,
      address
    )
  {
    address aToken = deployCode(
      aTokenArtifact,
      abi.encode(
        AaveV2Ethereum.POOL,
        underlyingAsset,
        AaveV2Ethereum.COLLECTOR,
        string(abi.encodePacked(ATOKEN_NAME_PREFIX, underlyingAssetSymbol)),
        string(abi.encodePacked(ATOKEN_SYMBOL_PREFIX, underlyingAssetSymbol)),
        INCENTIVES_CONTROLLER
      )
    );
    Initializable(aToken).initialize(
      decimals,
      string(abi.encodePacked(ATOKEN_NAME_PREFIX, underlyingAssetSymbol)),
      string(abi.encodePacked(ATOKEN_SYMBOL_PREFIX, underlyingAssetSymbol))
    );

    address stableDebt = deployCode(
      stableDebtArtifact,
      abi.encode(
        AaveV2Ethereum.POOL,
        underlyingAsset,
        string(
          abi.encodePacked(STABLE_DEBT_NAME_PREFIX, underlyingAssetSymbol)
        ),
        string(
          abi.encodePacked(STABLE_DEBT_SYMBOL_PREFIX, underlyingAssetSymbol)
        ),
        INCENTIVES_CONTROLLER
      )
    );
    Initializable(stableDebt).initialize(
      decimals,
      string(abi.encodePacked(STABLE_DEBT_NAME_PREFIX, underlyingAssetSymbol)),
      string(abi.encodePacked(STABLE_DEBT_SYMBOL_PREFIX, underlyingAssetSymbol))
    );

    address varDebt = deployCode(
      variableDebtArtifact,
      abi.encode(
        AaveV2Ethereum.POOL,
        underlyingAsset,
        string(abi.encodePacked(VAR_DEBT_NAME_PREFIX, underlyingAssetSymbol)),
        string(abi.encodePacked(VAR_DEBT_SYMBOL_PREFIX, underlyingAssetSymbol)),
        INCENTIVES_CONTROLLER
      )
    );
    Initializable(varDebt).initialize(
      decimals,
      string(abi.encodePacked(VAR_DEBT_NAME_PREFIX, underlyingAssetSymbol)),
      string(abi.encodePacked(VAR_DEBT_SYMBOL_PREFIX, underlyingAssetSymbol))
    );

    return (aToken, varDebt, stableDebt);
  }

  function run() external {
    vm.startBroadcast();
    deployASVTokens(0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72, 18, 'ENS');
    vm.stopBroadcast();
  }
}
