// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseChainlinkOracle } from "./BaseChainlinkOracle.sol";

import { IOracle } from "../interfaces/IOracle.sol";
import { AggregatorV3Interface } from "../interfaces/AggregatorV3Interface.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract ctVaultAssetOracle is BaseChainlinkOracle {
    using Math for uint256;

    /// @notice The Chainlink price feed for the asset
    AggregatorV3Interface public immutable feed;
    /// @notice The number of decimals of the feed
    uint256 public immutable feedDecimals;

    constructor(address _feed, uint256 _assetDecimals) BaseChainlinkOracle(_assetDecimals) {
        feed = AggregatorV3Interface(_feed);
        feedDecimals = feed.decimals();
    }

    /// @inheritdoc IOracle
    function price() public view override returns (uint256) {
        return getPrice(feed, feedDecimals);
    }
}
