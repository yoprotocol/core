// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "forge-std/console.sol";

import { IOracle } from "../interfaces/IOracle.sol";
import { BaseChainlinkOracle } from "./BaseChainlinkOracle.sol";

import { AggregatorV3Interface } from "../interfaces/AggregatorV3Interface.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract ctVaultAssetOracle is BaseChainlinkOracle {
    using Math for uint256;

    /// @notice The Chainlink price feed for the asset
    AggregatorV3Interface public immutable feed;
    /// @notice The number of decimals of the asset
    uint256 public immutable assetDecimals;
    /// @notice The number of decimals of the feed
    uint256 public immutable feedDecimals;

    constructor(address _feed, uint256 _assetDecimals) {
        feed = AggregatorV3Interface(_feed);
        assetDecimals = _assetDecimals;
        feedDecimals = feed.decimals();
    }

    /// @inheritdoc IOracle
    function price() public view override returns (uint256) {
        console.log("ORACLE:: price", uint256(getPrice(feed, feedDecimals)));

        return getPrice(feed, feedDecimals);
    }

    /// @inheritdoc IOracle
    function getValue(uint256 _amount) public view returns (uint256) {
        return _getValue(_amount, assetDecimals);
    }

    /// @inheritdoc IOracle
    function getAmount(uint256 _value) public view returns (uint256) {
        return _getAmount(_value, assetDecimals);
    }
}
