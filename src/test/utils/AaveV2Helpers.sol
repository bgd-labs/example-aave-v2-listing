// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import { AaveAddressBookV2 } from 'aave-address-book/AaveAddressBook.sol';
import { TokenData } from 'aave-address-book/AaveV2.sol';

import {IERC20} from "../../interfaces/IERC20.sol";

struct ReserveTokens {
    address aToken;
    address stableDebtToken;
    address variableDebtToken;
}

struct ReserveConfig {
    string symbol;
    address underlying;
    address aToken;
    address stableDebtToken;
    address variableDebtToken;
    uint256 decimals;
    uint256 ltv;
    uint256 liquidationThreshold;
    uint256 liquidationBonus;
    uint256 reserveFactor;
    bool usageAsCollateralEnabled;
    bool borrowingEnabled;
    address interestRateStrategy;
    bool stableBorrowRateEnabled;
    bool isActive;
    bool isFrozen;
}

struct ReserveConfigurationMap {
    //bit 0-15: LTV
    //bit 16-31: Liq. threshold
    //bit 32-47: Liq. bonus
    //bit 48-55: Decimals
    //bit 56: Reserve is active
    //bit 57: reserve is frozen
    //bit 58: borrowing is enabled
    //bit 59: stable rate borrowing enabled
    //bit 60-63: reserved
    //bit 64-79: reserve factor
    uint256 data;
}

struct ReserveData {
    //stores the reserve configuration
    ReserveConfigurationMap configuration;
    //the liquidity index. Expressed in ray
    uint128 liquidityIndex;
    //variable borrow index. Expressed in ray
    uint128 variableBorrowIndex;
    //the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;
    //the current variable borrow rate. Expressed in ray
    uint128 currentVariableBorrowRate;
    //the current stable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate;
    uint40 lastUpdateTimestamp;
    //tokens addresses
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    //address of the interest rate strategy
    address interestRateStrategyAddress;
    //the id of the reserve. Represents the position in the list of the active reserves
    uint8 id;
}

struct InterestStrategyValues {
    uint256 excessUtilization;
    uint256 optimalUtilization;
    uint256 baseVariableBorrowRate;
    uint256 stableRateSlope1;
    uint256 stableRateSlope2;
    uint256 variableRateSlope1;
    uint256 variableRateSlope2;
}

interface IAddressesProvider {
    function getPriceOracle() external returns (address);
}

interface IAaveOracle {
    function getSourceOfAsset(address asset) external returns (address);

    function getAssetPrice(address asset) external returns (address);
}

interface IReserveInterestRateStrategy {
    function getMaxVariableBorrowRate() external view returns (uint256);

    function EXCESS_UTILIZATION_RATE() external view returns (uint256);

    function OPTIMAL_UTILIZATION_RATE() external view returns (uint256);

    function addressesProvider() external view returns (address);

    function baseVariableBorrowRate() external view returns (uint256);

    function stableRateSlope1() external view returns (uint256);

    function stableRateSlope2() external view returns (uint256);

    function variableRateSlope1() external view returns (uint256);

    function variableRateSlope2() external view returns (uint256);
}

interface IProtocolDataProvider {
    function getReserveConfigurationData(address asset)
        external
        view
        returns (
            uint256 decimals,
            uint256 ltv,
            uint256 liquidationThreshold,
            uint256 liquidationBonus,
            uint256 reserveFactor,
            bool usageAsCollateralEnabled,
            bool borrowingEnabled,
            bool stableBorrowRateEnabled,
            bool isActive,
            bool isFrozen
        );

    function getAllReservesTokens() external view returns (TokenData[] memory);

    function getReserveTokensAddresses(address asset)
        external
        view
        returns (
            address aTokenAddress,
            address stableDebtTokenAddress,
            address variableDebtTokenAddress
        );
}

interface IAavePool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external returns (uint256);

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    function getReserveData(address asset)
        external
        view
        returns (ReserveData memory);
}

interface IInitializableAdminUpgradeabilityProxy {
    function upgradeTo(address newImplementation) external;

    function upgradeToAndCall(address newImplementation, bytes calldata data)
        external
        payable;

    function admin() external returns (address);

    function implementation() external returns (address);
}

library AaveV2Helpers {
    uint256 internal constant RAY = 1e27;

    struct LocalVars {
        TokenData[] reserves;
        ReserveConfig[] configs;
    }

    function _getReservesConfigs(bool withLogs, string memory marketName)
        internal
        view
        returns (ReserveConfig[] memory)
    {
        AaveAddressBookV2.Market memory market = AaveAddressBookV2.getMarket(marketName);
        LocalVars memory vars;

        vars.reserves = market.AAVE_PROTOCOL_DATA_PROVIDER.getAllReservesTokens();

        vars.configs = new ReserveConfig[](vars.reserves.length);

        for (uint256 i = 0; i < vars.reserves.length; i++) {
            vars.configs[i] = _getStructReserveConfig(vars.reserves[i], marketName);
            ReserveTokens memory reserveTokens = _getStructReserveTokens(
                vars.configs[i].underlying,
                marketName
            );
            vars.configs[i].aToken = reserveTokens.aToken;
            vars.configs[i].variableDebtToken = reserveTokens.variableDebtToken;
            vars.configs[i].stableDebtToken = reserveTokens.stableDebtToken;
            if (withLogs) {
                _logReserveConfig(vars.configs[i]);
            }
        }

        return vars.configs;
    }

    /// @dev Ugly, but necessary to avoid Stack Too Deep
    function _getStructReserveConfig(TokenData memory reserve, string memory marketName)
        internal
        view
        returns (ReserveConfig memory)
    {
        AaveAddressBookV2.Market memory market = AaveAddressBookV2.getMarket(marketName);
        ReserveConfig memory localConfig;
        (
            uint256 decimals,
            uint256 ltv,
            uint256 liquidationThreshold,
            uint256 liquidationBonus,
            uint256 reserveFactor,
            bool usageAsCollateralEnabled,
            bool borrowingEnabled,
            bool stableBorrowRateEnabled,
            bool isActive,
            bool isFrozen
        ) = market.AAVE_PROTOCOL_DATA_PROVIDER.getReserveConfigurationData(reserve.tokenAddress);
        localConfig.symbol = reserve.symbol;
        localConfig.underlying = reserve.tokenAddress;
        localConfig.decimals = decimals;
        localConfig.ltv = ltv;
        localConfig.liquidationThreshold = liquidationThreshold;
        localConfig.liquidationBonus = liquidationBonus;
        localConfig.reserveFactor = reserveFactor;
        localConfig.usageAsCollateralEnabled = usageAsCollateralEnabled;
        localConfig.borrowingEnabled = borrowingEnabled;
        localConfig.stableBorrowRateEnabled = stableBorrowRateEnabled;
        localConfig.interestRateStrategy = market.POOL
            .getReserveData(reserve.tokenAddress)
            .interestRateStrategyAddress;
        localConfig.isActive = isActive;
        localConfig.isFrozen = isFrozen;

        return localConfig;
    }

    /// @dev Ugly, but necessary to avoid Stack Too Deep
    function _getStructReserveTokens(address underlyingAddress, string memory marketName)
        internal
        view
        returns (ReserveTokens memory)
    {
        AaveAddressBookV2.Market memory market = AaveAddressBookV2.getMarket(marketName);
        ReserveTokens memory reserveTokens;
        (
            reserveTokens.aToken,
            reserveTokens.stableDebtToken,
            reserveTokens.variableDebtToken
        ) = market.AAVE_PROTOCOL_DATA_PROVIDER.getReserveTokensAddresses(underlyingAddress);

        return reserveTokens;
    }

    function _findReserveConfig(
        ReserveConfig[] memory configs,
        string memory symbolOfUnderlying,
        bool withLogs
    ) internal view returns (ReserveConfig memory) {
        for (uint256 i = 0; i < configs.length; i++) {
            if (
                keccak256(abi.encodePacked(configs[i].symbol)) ==
                keccak256(abi.encodePacked(symbolOfUnderlying))
            ) {
                if (withLogs) {
                    _logReserveConfig(configs[i]);
                }
                return configs[i];
            }
        }
        revert("RESERVE_CONFIG_NOT_FOUND");
    }

    function _logReserveConfig(ReserveConfig memory config) internal view {
        console.log("Symbol ", config.symbol);
        console.log("Underlying address ", config.underlying);
        console.log("AToken address ", config.aToken);
        console.log("Stable debt token address ", config.stableDebtToken);
        console.log("Variable debt token address ", config.variableDebtToken);
        console.log("Decimals ", config.decimals);
        console.log("LTV ", config.ltv);
        console.log("Liquidation Threshold ", config.liquidationThreshold);
        console.log("Liquidation Bonnus", config.liquidationBonus);
        console.log("Reserve Factor ", config.reserveFactor);
        console.log(
            "Usage as collateral enabled ",
            (config.usageAsCollateralEnabled) ? "Yes" : "No"
        );
        console.log(
            "Borrowing enabled ",
            (config.borrowingEnabled) ? "Yes" : "No"
        );
        console.log(
            "Stable borrow rate enabled ",
            (config.stableBorrowRateEnabled) ? "Yes" : "No"
        );
        console.log("Interest rate strategy ", config.interestRateStrategy);
        console.log("Is active ", (config.isActive) ? "Yes" : "No");
        console.log("Is frozen ", (config.isFrozen) ? "Yes" : "No");
        console.log("-----");
        console.log("-----");
    }

    function _validateReserveConfig(
        ReserveConfig memory expectedConfig,
        ReserveConfig[] memory allConfigs
    ) internal view {
        ReserveConfig memory config = _findReserveConfig(
            allConfigs,
            expectedConfig.symbol,
            false
        );
        require(
            config.underlying == expectedConfig.underlying,
            "_validateEnsConfigsInAave() : INVALID_UNDERLYING"
        );
        require(
            config.decimals == expectedConfig.decimals,
            "_validateEnsConfigsInAave: INVALID_DECIMALS"
        );
        require(
            config.ltv == expectedConfig.ltv,
            "_validateEnsConfigsInAave: INVALID_LTV"
        );
        require(
            config.liquidationThreshold == expectedConfig.liquidationThreshold,
            "_validateEnsConfigsInAave: INVALID_LIQ_THRESHOLD"
        );
        require(
            config.liquidationBonus == expectedConfig.liquidationBonus,
            "_validateEnsConfigsInAave: INVALID_LIQ_BONUS"
        );
        require(
            config.reserveFactor == expectedConfig.reserveFactor,
            "_validateEnsConfigsInAave: INVALID_RESERVE_FACTOR"
        );

        require(
            config.usageAsCollateralEnabled ==
                expectedConfig.usageAsCollateralEnabled,
            "_validateEnsConfigsInAave: INVALID_USAGE_AS_COLLATERAL"
        );
        require(
            config.borrowingEnabled == expectedConfig.borrowingEnabled,
            "_validateEnsConfigsInAave: INVALID_BORROWING_ENABLED"
        );
        require(
            config.stableBorrowRateEnabled ==
                expectedConfig.stableBorrowRateEnabled,
            "_validateEnsConfigsInAave: INVALID_STABLE_BORROW_ENABLED"
        );
        require(
            config.isActive == expectedConfig.isActive,
            "_validateEnsConfigsInAave: INVALID_IS_ACTIVE"
        );
        require(
            config.isFrozen == expectedConfig.isFrozen,
            "_validateEnsConfigsInAave: INVALID_IS_FROZEN"
        );
    }

    function _validateInterestRateStrategy(
        address asset,
        address expectedStrategy,
        InterestStrategyValues memory expectedStrategyValues,
        string memory marketName
    ) internal view {
        AaveAddressBookV2.Market memory market = AaveAddressBookV2.getMarket(marketName);
        IReserveInterestRateStrategy strategy = IReserveInterestRateStrategy(
            market.POOL.getReserveData(asset).interestRateStrategyAddress
        );

        require(
            address(strategy) == expectedStrategy,
            "_validateInterestRateStrategy() : INVALID_STRATEGY_ADDRESS"
        );

        require(
            strategy.EXCESS_UTILIZATION_RATE() ==
                expectedStrategyValues.excessUtilization,
            "_validateInterestRateStrategy() : INVALID_EXCESS_RATE"
        );
        require(
            strategy.OPTIMAL_UTILIZATION_RATE() ==
                expectedStrategyValues.optimalUtilization,
            "_validateInterestRateStrategy() : INVALID_OPTIMAL_RATE"
        );
        require(
            strategy.addressesProvider() ==
                address(market.POOL_ADDRESSES_PROVIDER),
            "_validateInterestRateStrategy() : INVALID_ADDRESSES_PROVIDER"
        );
        require(
            strategy.baseVariableBorrowRate() ==
                expectedStrategyValues.baseVariableBorrowRate,
            "_validateInterestRateStrategy() : INVALID_BASE_VARIABLE_BORROW"
        );
        require(
            strategy.stableRateSlope1() ==
                expectedStrategyValues.stableRateSlope1,
            "_validateInterestRateStrategy() : INVALID_STABLE_SLOPE_1"
        );
        require(
            strategy.stableRateSlope2() ==
                expectedStrategyValues.stableRateSlope2,
            "_validateInterestRateStrategy() : INVALID_STABLE_SLOPE_2"
        );
        require(
            strategy.variableRateSlope1() ==
                expectedStrategyValues.variableRateSlope1,
            "_validateInterestRateStrategy() : INVALID_VARIABLE_SLOPE_1"
        );
        require(
            strategy.variableRateSlope2() ==
                expectedStrategyValues.variableRateSlope2,
            "_validateInterestRateStrategy() : INVALID_VARIABLE_SLOPE_2"
        );
        require(
            strategy.getMaxVariableBorrowRate() ==
                expectedStrategyValues.baseVariableBorrowRate +
                    expectedStrategyValues.variableRateSlope1 +
                    expectedStrategyValues.variableRateSlope2,
            "_validateInterestRateStrategy() : INVALID_VARIABLE_SLOPE_2"
        );
    }

    function _noReservesConfigsChangesApartNewListings(
        ReserveConfig[] memory allConfigsBefore,
        ReserveConfig[] memory allConfigsAfter
    ) internal pure {
        for (uint256 i = 0; i < allConfigsBefore.length; i++) {
            require(
                keccak256(abi.encodePacked(allConfigsBefore[i].symbol)) ==
                    keccak256(abi.encodePacked(allConfigsAfter[i].symbol)),
                "_noReservesConfigsChangesApartNewListings() : UNEXPECTED_SYMBOL_CHANGED"
            );
            require(
                allConfigsBefore[i].underlying == allConfigsAfter[i].underlying,
                "_noReservesConfigsChangesApartNewListings() : UNEXPECTED_UNDERLYING_CHANGED"
            );
            require(
                allConfigsBefore[i].decimals == allConfigsAfter[i].decimals,
                "_noReservesConfigsChangesApartNewListings() : UNEXPECTED_DECIMALS_CHANGED"
            );
            require(
                allConfigsBefore[i].ltv == allConfigsAfter[i].ltv,
                "_noReservesConfigsChangesApartNewListings() : UNEXPECTED_LTV_CHANGED"
            );
            require(
                allConfigsBefore[i].liquidationThreshold ==
                    allConfigsAfter[i].liquidationThreshold,
                "_noReservesConfigsChangesApartNewListings() : UNEXPECTED_LIQ_THRESHOLD_CHANGED"
            );
            require(
                allConfigsBefore[i].liquidationBonus ==
                    allConfigsAfter[i].liquidationBonus,
                "_noReservesConfigsChangesApartNewListings() : UNEXPECTED_LIQ_BONUS_CHANGED"
            );
            require(
                allConfigsBefore[i].reserveFactor ==
                    allConfigsAfter[i].reserveFactor,
                "_noReservesConfigsChangesApartNewListings() : UNEXPECTED_RESERVE_FACTOR_CHANGED"
            );
            require(
                allConfigsBefore[i].usageAsCollateralEnabled ==
                    allConfigsAfter[i].usageAsCollateralEnabled,
                "_noReservesConfigsChangesApartNewListings() : UNEXPECTED_USAGE_AS_COLLATERAL_ENABLED_CHANGED"
            );
            require(
                allConfigsBefore[i].borrowingEnabled ==
                    allConfigsAfter[i].borrowingEnabled,
                "_noReservesConfigsChangesApartNewListings() : UNEXPECTED_BORROWING_ENABLED_CHANGED"
            );

            require(
                allConfigsBefore[i].stableBorrowRateEnabled ==
                    allConfigsAfter[i].stableBorrowRateEnabled,
                "_noReservesConfigsChangesApartNewListings() : UNEXPECTED_STABLE_BORROWING_CHANGED"
            );
            require(
                allConfigsBefore[i].isActive == allConfigsAfter[i].isActive,
                "_noReservesConfigsChangesApartNewListings() : UNEXPECTED_IS_ACTIVE_CHANGED"
            );
            require(
                allConfigsBefore[i].isFrozen == allConfigsAfter[i].isFrozen,
                "_noReservesConfigsChangesApartNewListings() : UNEXPECTED_IS_FROZEN_CHANGED"
            );
        }
    }

    function _validateCountOfListings(
        uint256 count,
        ReserveConfig[] memory allConfigsBefore,
        ReserveConfig[] memory allConfigsAfter
    ) internal pure {
        require(
            allConfigsBefore.length == allConfigsAfter.length - count,
            "_validateCountOfListings() : INVALID_COUNT_OF_LISTINGS"
        );
    }

    function _validateReserveTokensImpls(
        Vm vm,
        ReserveConfig memory config,
        ReserveTokens memory expectedImpls,
        string memory marketName
    ) internal {
        AaveAddressBookV2.Market memory market = AaveAddressBookV2.getMarket(marketName);
        vm.startPrank(address(market.POOL_CONFIGURATOR));
        require(
            IInitializableAdminUpgradeabilityProxy(config.aToken)
                .implementation() == expectedImpls.aToken,
            "_validateReserveTokensImpls() : INVALID_ATOKEN_IMPL"
        );
        vm.stopPrank();
    }

    function _deposit(
        Vm vm,
        address depositor,
        address onBehalfOf,
        address asset,
        uint256 amount,
        bool approve,
        address aToken,
        string memory marketName
    ) internal {
        AaveAddressBookV2.Market memory market = AaveAddressBookV2.getMarket(marketName);
        uint256 aTokenBefore = IERC20(aToken).balanceOf(onBehalfOf);
        vm.deal(depositor, 1 ether);
        vm.startPrank(depositor);
        if (approve) {
            IERC20(asset).approve(address(market.POOL), amount);
        }
        market.POOL.deposit(asset, amount, onBehalfOf, 0);
        vm.stopPrank();
        uint256 aTokenAfter = IERC20(aToken).balanceOf(onBehalfOf);

        require(
            _almostEqual(aTokenAfter, aTokenBefore + amount),
            "_deposit() : ERROR"
        );
    }

    function _borrow(
        Vm vm,
        address borrower,
        address onBehalfOf,
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address debtToken,
        string memory marketName
    ) public {
        AaveAddressBookV2.Market memory market = AaveAddressBookV2.getMarket(marketName);
        uint256 debtBefore = IERC20(debtToken).balanceOf(onBehalfOf);
        vm.deal(borrower, 1 ether);
        vm.startPrank(borrower);
        market.POOL.borrow(asset, amount, interestRateMode, 0, onBehalfOf);
        vm.stopPrank();

        uint256 debtAfter = IERC20(debtToken).balanceOf(onBehalfOf);
        require(
            _almostEqual(debtAfter, debtBefore + amount),
            "_borrow() : ERROR"
        );
    }

    function _repay(
        Vm vm,
        address whoRepays,
        address debtor,
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address debtToken,
        bool approve,
        string memory marketName
    ) internal {
        AaveAddressBookV2.Market memory market = AaveAddressBookV2.getMarket(marketName);
        uint256 debtBefore = IERC20(debtToken).balanceOf(debtor);
        vm.deal(whoRepays, 1 ether);
        vm.startPrank(whoRepays);
        if (approve) {
            IERC20(asset).approve(address(market.POOL), amount);
        }
        market.POOL.repay(asset, amount, interestRateMode, debtor);
        vm.stopPrank();

        uint256 debtAfter = IERC20(debtToken).balanceOf(debtor);

        require(
            debtAfter == ((debtBefore > amount) ? debtBefore - amount : 0),
            "_repay() : INCONSISTENT_DEBT_AFTER"
        );
    }

    function _withdraw(
        Vm vm,
        address whoWithdraws,
        address to,
        address asset,
        uint256 amount,
        address aToken,
        string memory marketName
    ) internal {
        AaveAddressBookV2.Market memory market = AaveAddressBookV2.getMarket(marketName);
        uint256 aTokenBefore = IERC20(aToken).balanceOf(whoWithdraws);
        vm.deal(whoWithdraws, 1 ether);
        vm.startPrank(whoWithdraws);

        market.POOL.withdraw(asset, amount, to);
        vm.stopPrank();
        uint256 aTokenAfter = IERC20(aToken).balanceOf(whoWithdraws);

        require(
            aTokenAfter ==
                ((aTokenBefore > amount) ? aTokenBefore - amount : 0),
            "_withdraw() : INCONSISTENT_ATOKEN_BALANCE_AFTER"
        );
    }

    function _validateAssetSourceOnOracle(address asset, address expectedSource, string memory marketName)
        external
    {
        AaveAddressBookV2.Market memory market = AaveAddressBookV2.getMarket(marketName);

        require(
            market.ORACLE.getSourceOfAsset(asset) == expectedSource,
            "_validateAssetSourceOnOracle() : INVALID_PRICE_SOURCE"
        );
    }

    /// @dev To contemplate +1/-1 precision issues when rounding, mainly on aTokens
    function _almostEqual(uint256 a, uint256 b) internal pure returns (bool) {
        if (b == 0) {
            return (a == b) || (a == (b + 1));
        } else {
            return (a == b) || (a == (b + 1)) || (a == (b - 1));
        }
    }
}
