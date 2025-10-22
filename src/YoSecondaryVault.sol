// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Errors} from "./libraries/Errors.sol";

import {YoVault} from "./YoVault.sol";

// __   __    ____            _                  _
// \ \ / /__ |  _ \ _ __ ___ | |_ ___   ___ ___ | |
//  \ V / _ \| |_) | '__/ _ \| __/ _ \ / __/ _ \| |
//   | | (_) |  __/| | | (_) | || (_) | (_| (_) | |
//   |_|\___/|_|   |_|  \___/ \__\___/ \___\___/|_|
contract YoSecondaryVault is YoVault {
    using Math for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    event SharePriceUpdated(uint256 lastSharePrice, uint256 newSharePrice);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeV2(uint256 _lastPricePerShare) public reinitializer(2) {
        lastPricePerShare = _lastPricePerShare;
    }

    /// @dev Can be called only once per block.
    /// @param newSharePrice The new share price shared between all deposit vaults.
    function onSharePriceUpdate(uint256 newSharePrice) external requiresAuth {
        require(block.number > lastBlockUpdated, Errors.UpdateAlreadyCompletedInThisBlock());

        uint256 percentageChange = _calculatePercentageChange(lastPricePerShare, newSharePrice);

        /// @dev Pause the vault if the percentage change is greater than the threshold (works in both directions)
        if (percentageChange > maxPercentageChange) {
            _pause();
            return;
        }

        emit SharePriceUpdated(lastPricePerShare, newSharePrice);

        lastPricePerShare = newSharePrice;
        lastBlockUpdated = block.number;
    }

    /// @dev Converts assets to shares using the last price per share directly, ignoring the total assets and total
    /// supply (shares)
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        uint8 _decimals = (super.decimals());
        return assets.mulDiv(10 ** _decimals, lastPricePerShare, rounding);
    }

    /// @dev Converts assets to shares using the last price per share directly, ignoring the total assets and total
    /// supply (shares)
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        uint8 _decimals = (super.decimals());
        return shares.mulDiv(lastPricePerShare, 10 ** _decimals, rounding);
    }
}
