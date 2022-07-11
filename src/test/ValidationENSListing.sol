// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import { AaveAddressBookV2 } from 'aave-address-book/AaveAddressBook.sol';
import { GovHelpers, IAaveGov } from "aave-helpers/GovHelpers.sol";
import {AaveV2Helpers, ReserveConfig, ReserveTokens, InterestStrategyValues} from "./utils/AaveV2Helpers.sol";

import {ENSListingPayload} from "../ENSListingPayload.sol";
import {IERC20} from "../interfaces/IERC20.sol";

contract ValidationENSListing is Test {
    address internal constant AAVE_WHALE =
        0x25F2226B597E8F9514B3F68F00f494cF4f286491;

    address internal constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;

    address internal constant ENS = 0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72;

    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address internal constant DAI_WHALE =
        0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;

    address public constant ENS_WHALE =
        0xd7A029Db2585553978190dB5E85eC724Aa4dF23f;

    // can't be constant for some reason
    string internal MARKET_NAME = AaveAddressBookV2.AaveV2Ethereum; 

    function setUp() public {}

    /// @dev Uses an already deployed payload on the target network
    function testProposalPostPayload() public {
        address payload = 0xf42D0a1b03C0795021272a4793CD03dCb97581D3;
        _testProposal(payload);
    }

    function _testProposal(address payload) internal {
        ReserveConfig[] memory allConfigsBefore = AaveV2Helpers
            ._getReservesConfigs(false, MARKET_NAME);

        address[] memory targets = new address[](1);
        targets[0] = payload;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "execute()";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        bool[] memory withDelegatecalls = new bool[](1);
        withDelegatecalls[0] = true;

        uint256 proposalId = GovHelpers.createProposal(
            vm,
            IAaveGov.SPropCreateParams({
                executor: GovHelpers.SHORT_EXECUTOR,
                targets: targets,
                values: values,
                signatures: signatures,
                calldatas: calldatas,
                withDelegatecalls: withDelegatecalls,
                ipfsHash: bytes32(0)
            })
        );

        GovHelpers.passVoteAndExecute(vm, proposalId);

        ReserveConfig[] memory allConfigsAfter = AaveV2Helpers
            ._getReservesConfigs(false, MARKET_NAME);

        AaveV2Helpers._validateCountOfListings(
            1,
            allConfigsBefore,
            allConfigsAfter
        );

        ReserveConfig memory expectedEnsConfig = ReserveConfig({
            symbol: "ENS",
            underlying: ENS,
            aToken: address(0), // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            variableDebtToken: address(0), // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            stableDebtToken: address(0), // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            decimals: 18,
            ltv: 5000,
            liquidationThreshold: 6000,
            liquidationBonus: 10800,
            reserveFactor: 2000,
            usageAsCollateralEnabled: true,
            borrowingEnabled: true,
            interestRateStrategy: 0xb2eD1eCE1c13455Ce9299d35D3B00358529f3Dc8,
            stableBorrowRateEnabled: false,
            isActive: true,
            isFrozen: false
        });

        AaveV2Helpers._validateReserveConfig(
            expectedEnsConfig,
            allConfigsAfter
        );

        AaveV2Helpers._validateInterestRateStrategy(
            ENS,
            ENSListingPayload(payload).INTEREST_RATE_STRATEGY(),
            InterestStrategyValues({
                excessUtilization: 55 * (AaveV2Helpers.RAY / 100),
                optimalUtilization: 45 * (AaveV2Helpers.RAY / 100),
                baseVariableBorrowRate: 0,
                stableRateSlope1: 0,
                stableRateSlope2: 0,
                variableRateSlope1: 7 * (AaveV2Helpers.RAY / 100),
                variableRateSlope2: 300 * (AaveV2Helpers.RAY / 100)
            }),
            MARKET_NAME
        );

        AaveV2Helpers._noReservesConfigsChangesApartNewListings(
            allConfigsBefore,
            allConfigsAfter
        );

        AaveV2Helpers._validateReserveTokensImpls(
            vm,
            AaveV2Helpers._findReserveConfig(allConfigsAfter, "ENS", false),
            ReserveTokens({
                aToken: ENSListingPayload(payload).ATOKEN_IMPL(),
                stableDebtToken: ENSListingPayload(payload).STABLE_DEBT_IMPL(),
                variableDebtToken: ENSListingPayload(payload)
                    .VARIABLE_DEBT_IMPL()
            }),
            MARKET_NAME
        );

        AaveV2Helpers._validateAssetSourceOnOracle(
            ENS,
            ENSListingPayload(payload).FEED_ENS_USD_TO_ENS_ETH(),
            MARKET_NAME
        );

        _validatePoolActionsPostListing(allConfigsAfter);
    }

    function _validatePoolActionsPostListing(
        ReserveConfig[] memory allReservesConfigs
    ) internal {
        AaveV2Helpers._deposit(
            vm,
            ENS_WHALE,
            ENS_WHALE,
            ENS,
            666 ether,
            true,
            AaveV2Helpers
                ._findReserveConfig(allReservesConfigs, "ENS", false)
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
            ENS_WHALE,
            ENS_WHALE,
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
            ENS,
            10 ether,
            2,
            AaveV2Helpers
                ._findReserveConfig(allReservesConfigs, "ENS", false)
                .variableDebtToken,
            MARKET_NAME
        );

        try
            AaveV2Helpers._borrow(
                vm,
                AAVE_WHALE,
                AAVE_WHALE,
                ENS,
                10 ether,
                1,
                AaveV2Helpers
                    ._findReserveConfig(allReservesConfigs, "ENS", false)
                    .stableDebtToken,
                MARKET_NAME
            )
        {
            revert("_testProposal() : STABLE_BORROW_NOT_REVERTING");
        } catch Error(string memory revertReason) {
            require(
                keccak256(bytes(revertReason)) == keccak256(bytes("12")),
                "_testProposal() : INVALID_STABLE_REVERT_MSG"
            );
            vm.stopPrank();
        }

        AaveV2Helpers._repay(
            vm,
            AAVE_WHALE,
            AAVE_WHALE,
            ENS,
            type(uint256).max,
            2,
            AaveV2Helpers
                ._findReserveConfig(allReservesConfigs, "ENS", false)
                .variableDebtToken,
            true,
            MARKET_NAME
        );

        vm.startPrank(DAI_WHALE);
        IERC20(DAI).transfer(ENS_WHALE, 300 ether);
        vm.stopPrank();

        AaveV2Helpers._repay(
            vm,
            ENS_WHALE,
            ENS_WHALE,
            DAI,
            IERC20(DAI).balanceOf(ENS_WHALE),
            2,
            AaveV2Helpers
                ._findReserveConfig(allReservesConfigs, "DAI", false)
                .variableDebtToken,
            true,
            MARKET_NAME
        );

        AaveV2Helpers._withdraw(
            vm,
            ENS_WHALE,
            ENS_WHALE,
            ENS,
            type(uint256).max,
            AaveV2Helpers
                ._findReserveConfig(allReservesConfigs, "ENS", false)
                .aToken,
            MARKET_NAME
        );
    }
}
