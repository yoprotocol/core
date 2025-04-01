// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ILendingAdapter } from "./interfaces/ILendingAdapter.sol";

enum LendingActionType {
    REPAY,
    ADD_COLLATERAL,
    REMOVE_COLLATERAL,
    BORROW
}

struct LendingAction {
    LendingActionType actionType;
    uint256 amount;
    uint256 adapterIndex;
}

enum InvestmentActionType {
    INVEST,
    DIVEST
}

struct InvestmentAction {
    InvestmentActionType actionType;
    uint256 amount;
    uint256 strategyIndex;
}

struct Repayment {
    uint256 amount;
    uint256 collateral;
    ILendingAdapter adapter;
}

struct Strategy {
    /// @notice The amount of assets allocated to the strategy.
    uint256 allocated;
    /// @notice The max amount of assets allowed to be allocated to the strategy.
    uint248 maxAllocation;
    /// @notice Whether the strategy is enabled for invest/divest or not.
    bool enabled;
}

struct LendingConfig {
    /// @notice The max amount of assets allowed to be allocated to the lending adapter.
    uint128 maxAllocation;
    /// @notice The target LTV for the lending adapter.
    uint128 targetLTV;
    /// @notice The min LTV for the lending adapter.
    uint128 minLTV;
    /// @notice The max LTV for the lending adapter.
    uint128 maxLTV;
}
