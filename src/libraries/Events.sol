// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library Events {
    event UpdateInvestQueue(address indexed user, address[] queue);
    event UpdateDivestQueue(address indexed user, address[] queue);
    event StrategyAdded(address indexed user, address indexed strategy, uint248 maxAllocation);
    event LendingAdapterUpdated(address indexed user, address indexed adapter, uint256 index);

    event AddCollateral(uint256 assets);
    event RemoveCollateral(uint256 assets);
    event Borrow(uint256 assets);
    event Repay(uint256 assets, uint256 repaid);
    event LendingStrategyStats(
        uint256 collateral, uint256 borrowed, uint256 supplyAPY, uint256 borrowAPY, uint256 healthFactor
    );
}
