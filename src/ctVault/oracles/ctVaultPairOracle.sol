// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IOracle } from "../interfaces/IOracle.sol";
import { AggregatorV3Interface } from "../interfaces/AggregatorV3Interface.sol";

import { BaseChainlinkOracle } from "./BaseChainlinkOracle.sol";

import { Errors } from "../../libraries/Errors.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract ctVaultPairOracle is BaseChainlinkOracle {
    using Math for uint256;

    AggregatorV3Interface public immutable base;
    uint256 public immutable baseDecimals;

    AggregatorV3Interface public immutable quote;
    uint256 public immutable quoteDecimals;

    /**
     * @notice Initializes the oracle with the base and quote feed addresses.
     * @param _base The address of the base asset aggregator (e.g., BTC/USD).
     * @param _quote The address of the quote asset aggregator (e.g., USDC/USD).
     */
    constructor(address _base, address _quote) {
        base = AggregatorV3Interface(_base);
        baseDecimals = base.decimals();

        quote = AggregatorV3Interface(_quote);
        quoteDecimals = quote.decimals();
    }

    /**
     * @notice Returns the derived price of the base asset in terms of the quote asset,
     * scaled to TARGET_DECIMALS (18 decimals).
     * @return The derived price.
     */
    function price() external view override returns (uint256) {
        uint256 basePrice = getPrice(base, baseDecimals);
        uint256 quotePrice = getPrice(quote, quoteDecimals);
        return basePrice.mulDiv(10 ** TARGET_DECIMALS, quotePrice);
    }
}
