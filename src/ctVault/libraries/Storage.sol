// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Strategy, LendingConfig } from "../Types.sol";

import { ISwap } from "../interfaces/ISwap.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";
import { ILendingAdapter } from "../interfaces/ILendingAdapter.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @custom:storage-location erc7201.storage.ctVault
struct CtVaultStorage {
    /// @notice total amount of assets invested
    uint256 totalInvested;
    /// @notice total amount of assets borrowed
    uint256 totalBorrowed;
    /// @notice total amount of assets collateralized
    uint256 totalCollateral;
    /// @notice the minimum amount of earnings required to trigger a harvest
    uint256 harvestThreshold;
    /// @dev Packed in a single storage slot (96 + 40 + 40 + 40 + 8 = 224 bits)
    /// @notice fee minted to the treasury and deducted from the earnings
    uint96 performanceFee;
    /// @notice cooldown period for the sync function
    uint40 syncCooldown;
    /// @notice timestamp of the last sync
    uint40 lastSyncTimestamp;
    /// @notice the maximum allowed slippage when swapping earnings (1% = 100)
    uint40 slippageTolerance;
    /// @notice whether to automatically invest the assets on deposit or not
    bool autoInvest;
    /// @notice the address that receives the fees
    address feeRecipient;
    /// @notice the address of the investment token
    IERC20 investmentAsset;
    /// @notice the address of the swap router
    ISwap swapRouter;
    /// @notice state of each strategy
    mapping(IStrategy strategy => Strategy state) strategies;
    /// @notice configuration of each lending adapter
    mapping(ILendingAdapter adapter => LendingConfig config) lendingAdaptersConfig;
    /// @notice the list of lending protocols
    ILendingAdapter[] lendingAdapters;
    // @notice the list of strategies used to invest the assets
    IStrategy[] investQueue;
    // @notice the list of strategies used to divest the assets
    IStrategy[] divestQueue;
}

library CtVaultStorageLib {
    // keccak256(abi.encode(uint256(keccak256("erc7201.storage.ctVault")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line max-line-length, const-name-snakecase
    bytes32 private constant CtVaultStorageLocation = 0x153ab1664096712f403bc9f042f813c9650d7d4446c74ae26b3c39b846e10d00;

    /// @dev A function to return a pointer for the CtVaultStorageLocation.
    function _getCtVaultStorage() internal pure returns (CtVaultStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := CtVaultStorageLocation
        }
    }
}
