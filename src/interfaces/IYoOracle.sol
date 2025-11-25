// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IYoOracle {
    struct AssetOracleData {
        uint256 latestPrice;
        uint256 anchorPrice;
        uint64 anchorTimestamp;
        uint64 latestTimestamp;
        uint64 windowSeconds;
        uint64 maxChangeBps;
    }

    error NotUpdater();
    error InvalidConfig();

    error PriceChangeTooBig(
        address vault,
        uint256 newPrice,
        uint256 anchorPrice,
        uint256 diffBps,
        uint256 maxChangeBps
    );

    event UpdaterChanged(address indexed oldUpdater, address indexed newUpdater);
    event SharePriceUpdated(address indexed vault, uint256 price, uint64 timestamp);
    event AssetConfigUpdated(address indexed vault, uint32 windowSeconds, uint32 maxChangeBps);

    function getLatestPrice(address _vault) external view returns (uint256 sharePrice, uint64 timestamp);
}
