// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CommonModule } from "./CommonModule.sol";
import { CtVaultStorage, CtVaultStorageLib } from "../libraries/Storage.sol";
import { Errors } from "../libraries/Errors.sol";
import { Events } from "../libraries/Events.sol";
import { ISwap } from "../interfaces/ISwap.sol";

abstract contract ConfigModule is CommonModule {
    uint96 internal constant MAX_PERFORMANCE_FEE = 0.5e18;
    uint40 internal constant MAX_SYNC_COOLDOWN = 5 days;
    uint40 internal constant SLIPPAGE_PRECISION = 10_000;

    /// @notice Sets the swap router.
    /// @param _swapRouter The address of the swap router.
    function setSwapRouter(address _swapRouter) external requiresAuth {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        emit Events.SwapRouterUpdated(address($.swapRouter), _swapRouter);
        $.swapRouter = ISwap(_swapRouter);
    }

    /// @notice Sets the address that receives the fees.
    /// @param _feeRecipient The address that receives the fees.
    function setFeeRecipient(address _feeRecipient) external requiresAuth {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        emit Events.FeeRecipientUpdated($.feeRecipient, _feeRecipient);
        $.feeRecipient = _feeRecipient;
    }

    /// @notice Sets the performance fee.
    /// @param _performanceFee The performance fee.
    function setPerformanceFee(uint256 _performanceFee) external requiresAuth {
        require(_performanceFee <= MAX_PERFORMANCE_FEE, Errors.Common__MaxPerformanceFeeExceeded());
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        $.performanceFee = uint96(_performanceFee);
        emit Events.PerformanceFeeUpdated(_performanceFee);
    }

    /// @notice Sets the cooldown period for the sync function.
    /// @param _syncCooldown The cooldown period for the sync function.
    function setSyncCooldown(uint256 _syncCooldown) external requiresAuth {
        require(_syncCooldown <= MAX_SYNC_COOLDOWN, Errors.Common__MaxSyncCooldownExceeded());
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        $.syncCooldown = uint40(_syncCooldown);
        emit Events.SyncCooldownUpdated(_syncCooldown);
    }

    /// @notice Sets whether to automatically invest the assets on deposit or not.
    /// @param _autoInvest Whether to automatically invest the assets on deposit or not.
    function setAutoInvest(bool _autoInvest) external requiresAuth {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        $.autoInvest = _autoInvest;
        emit Events.AutoInvestUpdated(_autoInvest);
    }

    /// @notice Sets the minimum amount of earnings required to trigger a harvest
    /// @param _threshold The new threshold
    function setHarvestThreshold(uint256 _threshold) external requiresAuth {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        emit Events.HarvestThresholdUpdated($.harvestThreshold, _threshold);
        $.harvestThreshold = _threshold;
    }

    /// @notice Sets the maximum allowed slippage when swapping earnings
    /// @param _slippageTolerance The slippage tolerance in basis points (1% = 100)
    function setSlippageTolerance(uint40 _slippageTolerance) external requiresAuth {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        emit Events.SlippageToleranceUpdated($.slippageTolerance, _slippageTolerance);
        $.slippageTolerance = _slippageTolerance;
    }
}
