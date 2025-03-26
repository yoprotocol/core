// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IOracle } from "../interfaces/IOracle.sol";
import { AggregatorV3Interface } from "../interfaces/AggregatorV3Interface.sol";

import { Errors } from "../../libraries/Errors.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract BaseChainlinkOracle is IOracle {
    using Math for uint256;

    /// @notice We want prices scaled to 18 decimals
    uint256 public constant TARGET_DECIMALS = 1e18;

    function price() external view virtual returns (uint256);

    /**
     * @notice Returns the scaling factor of the oracle.
     * @return The scaling factor.
     */
    function scale() external pure override returns (uint256) {
        return 10 ** TARGET_DECIMALS;
    }

    /**
     * @dev Fetches the latest price from chainlink and scales it to TARGET_DECIMALS.
     * @param _feed The Chainlink aggregator interface.
     * @param _decimals The number of decimals in the price.
     * @return The scaled price.
     */
    function getPrice(AggregatorV3Interface _feed, uint256 _decimals) internal view returns (uint256) {
        (uint80 roundId, int256 answer, uint256 startedAt,, uint80 answeredInRound) =
            AggregatorV3Interface(_feed).latestRoundData();

        require(answer >= 0, Errors.ChainlinkInvalidPrice());
        require(startedAt > 0, Errors.ChainlinkIncompleteRound());
        require(answeredInRound >= roundId, Errors.ChainlinkStalePrice());

        return scalePrice(uint256(answer), _decimals);
    }

    /**
     * @dev Scales a given price to TARGET_DECIMALS.
     * @param _price The raw price from the feed.
     * @param _priceDecimals The number of decimals of the feed.
     * @return The price scaled to TARGET_DECIMALS.
     */
    function scalePrice(uint256 _price, uint256 _priceDecimals) internal pure returns (uint256) {
        if (_priceDecimals < TARGET_DECIMALS) {
            return _price * (10 ** (TARGET_DECIMALS - _priceDecimals));
        } else if (_priceDecimals > TARGET_DECIMALS) {
            return _price / (10 ** (_priceDecimals - TARGET_DECIMALS));
        }
        return _price;
    }
}
