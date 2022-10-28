// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {AaveV2Ethereum} from 'aave-address-book/AaveAddressBook.sol';

interface IProposalGenericExecutor {
  function execute() external;
}

contract ENSListingPayload is IProposalGenericExecutor {
  address public constant ENS = 0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72;
  uint8 public constant ENS_DECIMALS = 18;

  address public constant FEED_ENS_USD_TO_ENS_ETH =
    0xd4641b75015E6536E8102D98479568D05D7123Db;

  address public constant INTEREST_RATE_STRATEGY =
    0xb2eD1eCE1c13455Ce9299d35D3B00358529f3Dc8;

  uint256 public constant RESERVE_FACTOR = 2000;
  uint256 public constant LTV = 5000;
  uint256 public constant LIQUIDATION_THRESHOLD = 6000;
  uint256 public constant LIQUIDATION_BONUS = 10800;

  address public immutable ATOKEN_IMPL;
  address public immutable VARIABLE_DEBT_IMPL;
  address public immutable STABLE_DEBT_IMPL;

  constructor(
    address aTokenImpl,
    address vTokenImpl,
    address sTokenImpl
  ) public {
    ATOKEN_IMPL = aTokenImpl;
    VARIABLE_DEBT_IMPL = vTokenImpl;
    STABLE_DEBT_IMPL = sTokenImpl;
  }

  function execute() external override {
    address[] memory assets = new address[](1);
    assets[0] = ENS;
    address[] memory sources = new address[](1);
    sources[0] = FEED_ENS_USD_TO_ENS_ETH;

    AaveV2Ethereum.ORACLE.setAssetSources(assets, sources);

    AaveV2Ethereum.POOL_CONFIGURATOR.initReserve(
      ATOKEN_IMPL,
      STABLE_DEBT_IMPL,
      VARIABLE_DEBT_IMPL,
      ENS_DECIMALS,
      INTEREST_RATE_STRATEGY
    );

    // WARNING: if you were to enable stable borrowing via `true` you also need to call `setMarketBorrowRate` on the LendingRateOracle to set the baseRate
    AaveV2Ethereum.POOL_CONFIGURATOR.enableBorrowingOnReserve(ENS, false);
    AaveV2Ethereum.POOL_CONFIGURATOR.setReserveFactor(ENS, RESERVE_FACTOR);
    AaveV2Ethereum.POOL_CONFIGURATOR.configureReserveAsCollateral(
      ENS,
      LTV,
      LIQUIDATION_THRESHOLD,
      LIQUIDATION_BONUS
    );
  }
}
