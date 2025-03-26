// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IOracle } from "../interfaces/IOracle.sol";
import { BaseChainlinkOracle } from "./BaseChainlinkOracle.sol";

import { AggregatorV3Interface } from "../interfaces/AggregatorV3Interface.sol";

import { Errors } from "../../libraries/Errors.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract ctVaultAssetOracle is BaseChainlinkOracle {
    using Math for uint256;

    AggregatorV3Interface public immutable feed;
    uint256 public immutable feedDecimals;

    constructor(address _feed) {
        feed = AggregatorV3Interface(_feed);
        feedDecimals = feed.decimals();
    }

    function price() external view override returns (uint256) {
        return getPrice(feed, feedDecimals);
    }
}
