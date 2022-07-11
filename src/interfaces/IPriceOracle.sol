// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

interface IPriceOracle {
    function setAssetSources(
        address[] calldata assets,
        address[] calldata sources
    ) external;

    function getSourceOfAsset(address asset) external view returns (address);
}