// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import { AaveAddressBookV2 } from 'aave-address-book/AaveAddressBook.sol';
import { GovHelpers, IAaveGov } from "aave-helpers/GovHelpers.sol";
import {AaveV2Helpers, ReserveConfig, ReserveTokens, InterestStrategyValues} from "./utils/AaveV2Helpers.sol";

import {LUSDListingPayload} from "src/contracts/LUSDListingPayload.sol";
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {DeployL1Proposal} from '../script/ProposalCreation.s.sol';

contract ValidationLUSDListing is Test {
  address internal constant AAVE_WHALE =
  0x25F2226B597E8F9514B3F68F00f494cF4f286491;

  address internal constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;

  address internal constant LUSD = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;

  address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

  address internal constant DAI_WHALE =
  0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;

  address public constant LUSD_WHALE =
  0x3DdfA8eC3052539b6C9549F12cEA2C295cfF5296;

  // can't be constant for some reason
  string internal MARKET_NAME = AaveAddressBookV2.AaveV2Ethereum;

//  LUSDListingPayload lusdPayload;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('ethereum'), 15407940);
  }

  /// @dev Uses an already deployed payload on the target network
  function testProposalPostPayload() public {
//    lusdPayload = new LUSDListingPayload();
    address payload = 0xe0070f7a961dcb102e3D904A170613BE3f3B37A9;
    _testProposal(payload);
  }

  function _testProposal(address payload) internal {
    ReserveConfig[] memory allConfigsBefore = AaveV2Helpers
    ._getReservesConfigs(false, MARKET_NAME);

    vm.startPrank(GovHelpers.AAVE_WHALE);
    uint256 proposalId = DeployL1Proposal._deployL1Proposal(
      payload,
      0xe4daadc3e2908d80c1f613d8c9afd20531f47163444bde175732556d3d3b5575
    );
    console.log('proposalId', proposalId);
    vm.stopPrank();

    GovHelpers.passVoteAndExecute(vm, uint256(95));

    ReserveConfig[] memory allConfigsAfter = AaveV2Helpers
    ._getReservesConfigs(false, MARKET_NAME);

    AaveV2Helpers._validateCountOfListings(
      1,
      allConfigsBefore,
      allConfigsAfter
    );

    ReserveConfig memory expectedLusdConfig = ReserveConfig({
    symbol: "LUSD",
    underlying: LUSD,
    aToken: address(0), // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
    variableDebtToken: address(0), // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
    stableDebtToken: address(0), // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
    decimals: 18,
    ltv: 0,
    liquidationThreshold: 0,
    liquidationBonus: 0,
    reserveFactor: 1000,
    usageAsCollateralEnabled: false,
    borrowingEnabled: true,
    interestRateStrategy: 0x545Ae1908B6F12e91E03B1DEC4F2e06D0570fE1b,
    stableBorrowRateEnabled: true,
    isActive: true,
    isFrozen: false
    });

    AaveV2Helpers._validateReserveConfig(
      expectedLusdConfig,
      allConfigsAfter
    );

    AaveV2Helpers._validateInterestRateStrategy(
      LUSD,
      LUSDListingPayload(payload).INTEREST_RATE_STRATEGY(),
      InterestStrategyValues({
    excessUtilization: 20 * (AaveV2Helpers.RAY / 100),
    optimalUtilization: 80 * (AaveV2Helpers.RAY / 100),
    baseVariableBorrowRate: 0,
    stableRateSlope1: 2 * (AaveV2Helpers.RAY / 100),
    stableRateSlope2: 75 * (AaveV2Helpers.RAY / 100),
    variableRateSlope1: 4 * (AaveV2Helpers.RAY / 100),
    variableRateSlope2: 75 * (AaveV2Helpers.RAY / 100)
    }),
      MARKET_NAME
    );

    AaveV2Helpers._noReservesConfigsChangesApartNewListings(
      allConfigsBefore,
      allConfigsAfter
    );

    AaveV2Helpers._validateReserveTokensImpls(
      vm,
      AaveV2Helpers._findReserveConfig(allConfigsAfter, "LUSD", false),
      ReserveTokens({
    aToken: LUSDListingPayload(payload).ATOKEN_IMPL(),
    stableDebtToken: LUSDListingPayload(payload).STABLE_DEBT_IMPL(),
    variableDebtToken: LUSDListingPayload(payload)
    .VARIABLE_DEBT_IMPL()
    }),
      MARKET_NAME
    );

    AaveV2Helpers._validateAssetSourceOnOracle(
      LUSD,
      LUSDListingPayload(payload).FEED_LUSD_USD_TO_LUSD_ETH(),
      MARKET_NAME
    );

    _validatePoolActionsPostListing(allConfigsAfter);
  }

  function _validatePoolActionsPostListing(
    ReserveConfig[] memory allReservesConfigs
  ) internal {
    AaveV2Helpers._deposit(
      vm,
      LUSD_WHALE,
      LUSD_WHALE,
      LUSD,
      666 ether,
      true,
      AaveV2Helpers
      ._findReserveConfig(allReservesConfigs, "LUSD", false)
      .aToken,
      MARKET_NAME
    );
    AaveV2Helpers._deposit(
      vm,
      AAVE_WHALE,
      AAVE_WHALE,
      AAVE,
      666 ether,
      true,
      AaveV2Helpers
      ._findReserveConfig(allReservesConfigs, "AAVE", false)
      .aToken,
      MARKET_NAME
    );

    AaveV2Helpers._borrow(
      vm,
      LUSD_WHALE,
      LUSD_WHALE,
      DAI,
      222 ether,
      2,
      AaveV2Helpers
      ._findReserveConfig(allReservesConfigs, "DAI", false)
      .variableDebtToken,
      MARKET_NAME
    );

    AaveV2Helpers._borrow(
      vm,
      AAVE_WHALE,
      AAVE_WHALE,
      LUSD,
      10 ether,
      2,
      AaveV2Helpers
      ._findReserveConfig(allReservesConfigs, "LUSD", false)
      .variableDebtToken,
      MARKET_NAME
    );

    AaveV2Helpers._borrow(
      vm,
      AAVE_WHALE,
      AAVE_WHALE,
      LUSD,
      10 ether,
      1,
      AaveV2Helpers
      ._findReserveConfig(allReservesConfigs, "LUSD", false)
      .stableDebtToken,
      MARKET_NAME
    );

    AaveV2Helpers._repay(
      vm,
      AAVE_WHALE,
      AAVE_WHALE,
      LUSD,
      type(uint256).max,
      2,
      AaveV2Helpers
      ._findReserveConfig(allReservesConfigs, "LUSD", false)
      .variableDebtToken,
      true,
      MARKET_NAME
    );

    AaveV2Helpers._repay(
      vm,
      AAVE_WHALE,
      AAVE_WHALE,
      LUSD,
      type(uint256).max,
      1,
      AaveV2Helpers
      ._findReserveConfig(allReservesConfigs, "LUSD", false)
      .stableDebtToken,
      true,
      MARKET_NAME
    );

    vm.startPrank(DAI_WHALE);
    IERC20(DAI).transfer(LUSD_WHALE, 300 ether);
    vm.stopPrank();

    AaveV2Helpers._repay(
      vm,
      LUSD_WHALE,
      LUSD_WHALE,
      DAI,
      IERC20(DAI).balanceOf(LUSD_WHALE),
      2,
      AaveV2Helpers
      ._findReserveConfig(allReservesConfigs, "DAI", false)
      .variableDebtToken,
      true,
      MARKET_NAME
    );

    AaveV2Helpers._withdraw(
      vm,
      LUSD_WHALE,
      LUSD_WHALE,
      LUSD,
      type(uint256).max,
      AaveV2Helpers
      ._findReserveConfig(allReservesConfigs, "LUSD", false)
      .aToken,
      MARKET_NAME
    );
  }
}
