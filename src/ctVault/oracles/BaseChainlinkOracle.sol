// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IOracle } from "../interfaces/IOracle.sol";
import { AggregatorV3Interface } from "../interfaces/AggregatorV3Interface.sol";

import { Errors } from "../libraries/Errors.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract BaseChainlinkOracle is IOracle {
    using Math for uint256;

    /// @notice We want prices scaled to 18 decimals
    uint256 public constant TARGET_DECIMALS = 18;

    /// @inheritdoc IOracle
    function price() public view virtual returns (uint256);

    /// @dev Returns the value of an amount of an asset in USD.
    /// @param _amount The amount of the asset.
    /// @param _assetDecimals The number of decimals of the asset.
    /// @return The value of the asset in USD.
    function _getValue(uint256 _amount, uint256 _assetDecimals) internal view returns (uint256) {
        return _amount.mulDiv(price(), 10 ** _assetDecimals);
    }

    /// @dev Returns the amount of an asset that corresponds to a given value in USD.
    /// @param _value The value of the asset in USD.
    /// @param _assetDecimals The number of decimals of the asset.
    /// @return The amount of the asset.
    function _getAmount(uint256 _value, uint256 _assetDecimals) internal view returns (uint256) {
        return _value.mulDiv(10 ** _assetDecimals, price());
    }

    /**
     * @dev Fetches the latest price from chainlink and scales it to TARGET_DECIMALS.
     * @param _feed The Chainlink aggregator interface.
     * @param _feedDecimals The number of decimals in the price.
     * @return The scaled price.
     */
    function getPrice(AggregatorV3Interface _feed, uint256 _feedDecimals) internal view returns (uint256) {
        (uint80 roundId, int256 answer, uint256 startedAt,, uint80 answeredInRound) =
            AggregatorV3Interface(_feed).latestRoundData();

        require(answer >= 0, Errors.ChainlinkInvalidPrice());
        require(startedAt > 0, Errors.ChainlinkIncompleteRound());
        require(answeredInRound >= roundId, Errors.ChainlinkStalePrice());

        return scalePrice(uint256(answer), _feedDecimals);
    }

    /**
     * @dev Scales a given price to TARGET_DECIMALS.
     * @param _price The raw price from the feed.
     * @param _feedDecimals The number of decimals of the feed.
     * @return The price scaled to TARGET_DECIMALS.
     */
    function scalePrice(uint256 _price, uint256 _feedDecimals) internal pure returns (uint256) {
        if (_feedDecimals < TARGET_DECIMALS) {
            return _price * (10 ** (TARGET_DECIMALS - _feedDecimals));
        } else if (_feedDecimals > TARGET_DECIMALS) {
            return _price / (10 ** (_feedDecimals - TARGET_DECIMALS));
        }
        return _price;
    }
}
