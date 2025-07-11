// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IOracle } from "../interfaces/IOracle.sol";
import { BaseChainlinkOracle } from "./BaseChainlinkOracle.sol";

contract FixedPriceOracle is BaseChainlinkOracle {
    uint256 public immutable fixedPrice;

    constructor(uint256 _price, uint256 _assetDecimals) BaseChainlinkOracle(_assetDecimals) {
        fixedPrice = _price;
    }

    /// @inheritdoc IOracle
    function price() public view override returns (uint256) {
        return fixedPrice;
    }
}
