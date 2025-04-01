// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library Errors {
    //============================== Common ===============================
    error Common__OnlyVault();
    error Common__ZeroAmount();
    error Common__ZeroAddress();
    error Common__OnlyHarvester();
    error Common__MaxQueueLengthExceeded();
    error Common__MaxSyncCooldownExceeded();
    error Common__MaxPerformanceFeeExceeded();

    //============================== Investment Module ===============================
    error Investment__InvalidMaxAllocation();
    error Investment__NotEnoughAssets(address strategy);
    error Investment__StrategyHasAssets(address strategy);
    error Investment__DuplicatedStrategy(address strategy);
    error Investment__UnauthorizedStrategy(address strategy);
    error Investment__StrategyAlreadyExists(address strategy);
    error Investment__CannotRemoveActiveStrategy(address strategy);

    //============================== Lending Module ===============================
    error Lending__LTVTooLow();
    error Lending__LTVTooHigh();
    error Lending__HealthFactorTooLow();
    error Lending__InvalidRepayAmount();
    error Lending__BorrowLimitExceeded();
    error Lending__InvalidAdapterIndex();
    error Lending__MaxAllocationExceeded();
    error Lending__InvalidCollateralAmount();

    //============================== Oracle ===============================
    error Oracle__ChainlinkStalePrice();
    error Oracle__ChainlinkInvalidPrice();
    error Oracle__ChainlinkIncompleteRound();
}
