// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IOracle } from "../interfaces/IOracle.sol";
import { BaseChainlinkOracle } from "./BaseChainlinkOracle.sol";

contract FixedPriceOracle is BaseChainlinkOracle {
    uint256 public immutable fixedPrice;
    uint256 public immutable assetDecimals;

    constructor(uint256 _price, uint256 _assetDecimals) {
        fixedPrice = _price;
        assetDecimals = _assetDecimals;
    }

    /// @inheritdoc IOracle
    function price() public view override returns (uint256) {
        return fixedPrice;
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
