// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CommonModule } from "./CommonModule.sol";
import { CtVaultStorage, CtVaultStorageLib } from "../libraries/Storage.sol";
import { Errors } from "../libraries/Errors.sol";
import { Events } from "../libraries/Events.sol";

abstract contract ConfigModule is CommonModule {
    uint96 internal constant MAX_PERFORMANCE_FEE = 0.5e18;
    uint40 internal constant MAX_SYNC_COOLDOWN = 5 days;

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
}
