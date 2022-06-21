// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { AaveAddressBookV2, Market } from 'aave-address-book/AaveAddressBookV2.sol';
import {AaveV2Helpers, ReserveConfig, ReserveTokens, InterestStrategyValues} from "./utils/AaveV2Helpers.sol";
import {AaveGovHelpers, IAaveGov} from "./utils/AaveGovHelpers.sol";

import {OneInchListingPayload} from "../1InchListingPayload.sol";
import {IERC20} from "../interfaces/IERC20.sol";

contract Validation1InchListing is Test {
    address internal constant AAVE_WHALE =
        0x25F2226B597E8F9514B3F68F00f494cF4f286491;

    address internal constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;

    address internal constant ONEINCH = 0x111111111117dC0aa78b770fA6A738034120C302;

    uint8 public constant ONEINCH_DECIMALS = 18;

    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address internal constant POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;

    address internal constant RESERVE_TREASURY_ADDRESS = 0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c;

    address internal constant LENDING_POOL_ADDRESSES_PROVIDER = 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5;

    address internal constant INCENTIVES_CONTROLLER = address(0);

    string internal constant ATOKEN_NAME = "Aave interest bearing 1INCH";

    string internal constant ATOKEN_SYMBOL = "a1INCH";

    string internal constant STABLE_DEBT_TOKEN_NAME = "Aave stable debt bearing 1INCH";

    string internal constant STABLE_DEBT_TOKEN_SYMBOL = "stableDebt1INCH";

    string internal constant VARIABLE_DEBT_TOKEN_NAME = "Aave variable debt bearing 1INCH";
    
    string internal constant VARIABLE_DEBT_TOKEN_SYMBOL = "variableDebt1INCH";

    address internal constant DAI_WHALE =
        0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;

    address public constant ONEINCH_WHALE =
        0x2f3Fa8b85fbD0e29BD0b4E68032F61421782BDF0;

    // can't be constant for some reason
    string internal MARKET_NAME = AaveAddressBookV2.AaveV2Ethereum; 

    // artifacts
    string internal constant aTokenArtifact = "AToken.sol:AToken";
    string internal constant stableDebtArtifact = "stableDebt.sol:StableDebtToken";
    string internal constant variableDebtArtifact = "varDebt.sol:VariableDebtToken";
    string internal constant interestRateStrategyArtifact = "interestRateStrat.sol:DefaultReserveInterestRateStrategy";


    uint256 internal constant OPTIMAL_UTILIZATION_RATE = 450000000000000000000000000;

    uint256 internal constant BASE_VARIABLE_BORROW_RATE = 0;

    uint256 internal constant VARIABLE_RATE_SLOPE_1 = 70000000000000000000000000;

    uint256 internal constant VARIABLE_RATE_SLOPE_2 = 3000000000000000000000000000;

    uint256 internal constant STABLE_RATE_SLOPE_1 = 100000000000000000000000000;

    uint256 internal constant STABLE_RATE_SLOPE_2 = 3000000000000000000000000000;

    function setUp() public {}

    /// @dev Uses an already deployed payload on the target network
    function testProposalPostPayload() public {
        /// deploy atoken and such
        address aToken = deployCode(aTokenArtifact, abi.encode(
            POOL,
            ONEINCH,
            RESERVE_TREASURY_ADDRESS,
            ATOKEN_NAME,
            ATOKEN_SYMBOL,
            INCENTIVES_CONTROLLER
        ));

        address stableDebt = deployCode(stableDebtArtifact, abi.encode(
            POOL,
            ONEINCH,
            STABLE_DEBT_TOKEN_NAME,
            STABLE_DEBT_TOKEN_SYMBOL,
            INCENTIVES_CONTROLLER
        ));

        address varDebt = deployCode(variableDebtArtifact, abi.encode(
            POOL,
            ONEINCH,
            VARIABLE_DEBT_TOKEN_NAME,
            VARIABLE_DEBT_TOKEN_SYMBOL,
            INCENTIVES_CONTROLLER
        ));

        address intRateStrat = deployCode(interestRateStrategyArtifact, abi.encode(
            LENDING_POOL_ADDRESSES_PROVIDER,
            OPTIMAL_UTILIZATION_RATE,
            BASE_VARIABLE_BORROW_RATE,
            VARIABLE_RATE_SLOPE_1,
            VARIABLE_RATE_SLOPE_2,
            STABLE_RATE_SLOPE_1,
            STABLE_RATE_SLOPE_2
        ));

        console.log("atoken ", aToken);
        console.log("stable ", stableDebt);
        console.log("var ", varDebt);
        console.log("intratestrat ", intRateStrat);
        /// deploy payload
        OneInchListingPayload one = new OneInchListingPayload(aToken, varDebt, stableDebt, intRateStrat);
        address payload = address(one);
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

        uint256 proposalId = AaveGovHelpers._createProposal(
            vm,
            AAVE_WHALE,
            IAaveGov.SPropCreateParams({
                executor: AaveGovHelpers.SHORT_EXECUTOR,
                targets: targets,
                values: values,
                signatures: signatures,
                calldatas: calldatas,
                withDelegatecalls: withDelegatecalls,
                ipfsHash: bytes32(0)
            })
        );

        AaveGovHelpers._passVote(vm, AAVE_WHALE, proposalId);

        ReserveConfig[] memory allConfigsAfter = AaveV2Helpers
            ._getReservesConfigs(false, MARKET_NAME);

        AaveV2Helpers._validateCountOfListings(
            1,
            allConfigsBefore,
            allConfigsAfter
        );

        ReserveConfig memory expectedEnsConfig = ReserveConfig({
            symbol: "1INCH",
            underlying: ONEINCH,
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
            interestRateStrategy: OneInchListingPayload(payload).INTEREST_RATE_STRATEGY(),
            stableBorrowRateEnabled: false,
            isActive: true,
            isFrozen: false
        });

        AaveV2Helpers._validateReserveConfig(
            expectedEnsConfig,
            allConfigsAfter
        );

        AaveV2Helpers._validateInterestRateStrategy(
            ONEINCH,
            OneInchListingPayload(payload).INTEREST_RATE_STRATEGY(),
            InterestStrategyValues({
                excessUtilization: 55 * (AaveV2Helpers.RAY / 100),
                optimalUtilization: 45 * (AaveV2Helpers.RAY / 100),
                baseVariableBorrowRate: 0,
                stableRateSlope1: 100000000000000000000000000,
                stableRateSlope2: 3000000000000000000000000000,
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
            AaveV2Helpers._findReserveConfig(allConfigsAfter, "1INCH", false),
            ReserveTokens({
                aToken: OneInchListingPayload(payload).ATOKEN_IMPL(),
                stableDebtToken: OneInchListingPayload(payload).STABLE_DEBT_IMPL(),
                variableDebtToken: OneInchListingPayload(payload)
                    .VARIABLE_DEBT_IMPL()
            }),
            MARKET_NAME
        );

        AaveV2Helpers._validateAssetSourceOnOracle(
            ONEINCH,
            OneInchListingPayload(payload).FEED_ONEINCH_ETH(),
            MARKET_NAME
        );

        _validatePoolActionsPostListing(allConfigsAfter);
    }

    function _validatePoolActionsPostListing(
        ReserveConfig[] memory allReservesConfigs
    ) internal {
        AaveV2Helpers._deposit(
            vm,
            ONEINCH_WHALE,
            ONEINCH_WHALE,
            ONEINCH,
            666 ether,
            true,
            AaveV2Helpers
                ._findReserveConfig(allReservesConfigs, "1INCH", false)
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
            ONEINCH_WHALE,
            ONEINCH_WHALE,
            DAI,
            10 ether,
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
            ONEINCH,
            10 ether,
            2,
            AaveV2Helpers
                ._findReserveConfig(allReservesConfigs, "1INCH", false)
                .variableDebtToken,
            MARKET_NAME
        );

        try
            AaveV2Helpers._borrow(
                vm,
                AAVE_WHALE,
                AAVE_WHALE,
                ONEINCH,
                10 ether,
                1,
                AaveV2Helpers
                    ._findReserveConfig(allReservesConfigs, "1INCH", false)
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
            ONEINCH,
            type(uint256).max,
            2,
            AaveV2Helpers
                ._findReserveConfig(allReservesConfigs, "1INCH", false)
                .variableDebtToken,
            true,
            MARKET_NAME
        );

        vm.startPrank(DAI_WHALE);
        IERC20(DAI).transfer(ONEINCH_WHALE, 300 ether);
        vm.stopPrank();

        AaveV2Helpers._repay(
            vm,
            ONEINCH_WHALE,
            ONEINCH_WHALE,
            DAI,
            IERC20(DAI).balanceOf(ONEINCH_WHALE),
            2,
            AaveV2Helpers
                ._findReserveConfig(allReservesConfigs, "DAI", false)
                .variableDebtToken,
            true,
            MARKET_NAME
        );

        AaveV2Helpers._withdraw(
            vm,
            ONEINCH_WHALE,
            ONEINCH_WHALE,
            ONEINCH,
            type(uint256).max,
            AaveV2Helpers
                ._findReserveConfig(allReservesConfigs, "1INCH", false)
                .aToken,
            MARKET_NAME
        );
    }
}
