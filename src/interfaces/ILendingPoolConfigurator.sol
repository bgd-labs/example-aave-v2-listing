pragma solidity 0.8.10;
pragma experimental ABIEncoderV2;

interface ILendingPoolConfigurator {
  
    struct InitReserveInput {
        address aTokenImpl;
        address stableDebtTokenImpl;
        address variableDebtTokenImpl;
        uint8 underlyingAssetDecimals;
        address interestRateStrategyAddress;
        address underlyingAsset;
        address treasury;
        address incentivesController;
        string underlyingAssetName;
        string aTokenName;
        string aTokenSymbol;
        string variableDebtTokenName;
        string variableDebtTokenSymbol;
        string stableDebtTokenName;
        string stableDebtTokenSymbol;
        bytes params;
    }

    function batchInitReserve(InitReserveInput[] calldata input) external;

    function configureReserveAsCollateral(
        address asset,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    ) external;

    function enableBorrowingOnReserve(address asset, bool stableBorrowRateEnabled) external;

    function setReserveFactor(address asset, uint256 reserveFactor) external;
}
