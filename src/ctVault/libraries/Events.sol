// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IStrategy } from "../interfaces/IStrategy.sol";

library Events {
    event UpdateInvestQueue(address indexed user, IStrategy[] queue);
    event UpdateDivestQueue(address indexed user, IStrategy[] queue);
    event StrategyAdded(address indexed user, IStrategy indexed strategy, uint248 maxAllocation);
    event LendingAdapterUpdated(address indexed user, address indexed adapter, uint256 index);

    event AddCollateral(uint256 assets);
    event RemoveCollateral(uint256 assets);
    event Borrow(uint256 assets);
    event Repay(uint256 assets, uint256 repaid);
    event LendingStrategyStats(
        uint256 collateral, uint256 borrowed, uint256 supplyAPY, uint256 borrowAPY, uint256 healthFactor
    );

    event AutoInvestUpdated(bool autoInvest);
    event SyncCooldownUpdated(uint256 syncCooldown);
    event PerformanceFeeUpdated(uint256 performanceFee);
    event HarvestThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event SlippageToleranceUpdated(uint256 oldTolerance, uint256 newTolerance);
    event SwapRouterUpdated(address indexed oldRouter, address indexed newRouter);
    event Harvest(uint256 earnings, uint256 harvestedAmount, bool addToCollateral);
    event FeeRecipientUpdated(address indexed lastFeeRecipient, address indexed feeRecipient);
}
