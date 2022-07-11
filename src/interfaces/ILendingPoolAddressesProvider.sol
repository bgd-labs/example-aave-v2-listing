// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

interface ILendingPoolAddressesProvider {
    function getLendingPoolConfigurator() external returns (address);

    function getPriceOracle() external view returns (address);
}