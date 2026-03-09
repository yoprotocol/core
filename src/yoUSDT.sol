// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { YoVault_V2 } from "src/YoVault_V2.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// __   __    ____            _                  _
// \ \ / /__ |  _ \ _ __ ___ | |_ ___   ___ ___ | |
//  \ V / _ \| |_) | '__/ _ \| __/ _ \ / __/ _ \| |
//   | | (_) |  __/| | | (_) | || (_) | (_| (_) | |
//   |_|\___/|_|   |_|  \___/ \__\___/ \___\___/|_|
/// @title yoUSDT - USDT extension vault that relays 95% of deposits to yoUSD.
/// @dev Inherits all YoVault_V2 mechanics. Overrides oracle pricing to use the yoUSD price
/// (so yoUSDT shares are valued identically to yoUSD shares) and adds a deposit-time relay
/// that forwards 95% of net assets to the yoUSD vault. The remaining 5% stays as liquidity
/// for instant redemptions.
contract yoUSDT is YoVault_V2 {
    using Math for uint256;
    using SafeERC20 for IERC20;

    /// @dev Fraction of net deposits relayed to yoUSD (95%).
    uint256 internal constant RELAY_PERCENTAGE = 95e16;
    /// @dev yoUSD vault — relay destination and oracle pricing reference.
    address public constant YO_USD_ADDRESS = 0x0000000f2eB9f69274678c76222B35eEc7588a65;

    /// @dev Prices yoUSDT shares using the yoUSD oracle entry.
    function _oracleAsset() internal pure override returns (address) {
        return YO_USD_ADDRESS;
    }

    /// @dev Handles deposit fees via {YoVault_V2._deposit}, then relays 95% of net assets to yoUSD.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        uint256 feeAmount = _feeOnTotal(assets, feeOnDeposit);

        super._deposit(caller, receiver, assets, shares);

        uint256 assetsAfterFee = assets - feeAmount;
        uint256 relayAmount = assetsAfterFee.mulDiv(RELAY_PERCENTAGE, DENOMINATOR, Math.Rounding.Floor);
        if (relayAmount > 0) {
            IERC20(asset()).safeTransfer(YO_USD_ADDRESS, relayAmount);
        }
    }
}
