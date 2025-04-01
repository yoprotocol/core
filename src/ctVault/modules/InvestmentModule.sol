// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CommonModule } from "./CommonModule.sol";

import { IStrategy } from "../interfaces/IStrategy.sol";

import { Strategy, InvestmentAction, InvestmentActionType } from "../Types.sol";
import { Errors } from "../libraries/Errors.sol";
import { Events } from "../libraries/Events.sol";
import { CtVaultStorage, CtVaultStorageLib } from "../libraries/Storage.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract InvestmentModule is CommonModule {
    using SafeERC20 for IERC20;

    /// @notice the maximum number of strategies that can be used
    uint256 public constant MAX_STRATEGIES = 20;

    /// @notice Updates the investment queue, which is the list of strategies the vault will use to invest available
    /// assets.
    /// @param _investQueue The new ordered list of strategy addresses to be used for investing.
    function setInvestQueue(IStrategy[] calldata _investQueue) external requiresAuth {
        uint256 length = _investQueue.length;

        if (length > MAX_STRATEGIES) {
            revert Errors.Common__MaxQueueLengthExceeded();
        }

        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        for (uint256 i; i < length; ++i) {
            if ($.strategies[_investQueue[i]].maxAllocation == 0) {
                revert Errors.Investment__UnauthorizedStrategy(address(_investQueue[i]));
            }
        }

        $.investQueue = _investQueue;

        emit Events.UpdateInvestQueue(msg.sender, _investQueue);
    }

    /// @notice Manages investment positions by executing a series of actions.
    /// @param _actions An array of actions to be executed.
    /// @dev The actions are executed in the order they are provided in the array.
    ///      Each action has:
    ///      - INVEST: Invest an amount in a strategy
    ///      - DIVEST: Divest an amount from a strategy
    /// @dev The function reverts if any of the actions is not valid.
    function manageInvestments(InvestmentAction[] calldata _actions) external requiresAuth {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        for (uint256 i; i < _actions.length; i++) {
            InvestmentAction memory action = _actions[i];
            require(action.strategyIndex < $.investQueue.length, Errors.Investment__UnauthorizedStrategy(address(0)));

            IStrategy strategy = $.investQueue[action.strategyIndex];
            Strategy storage strategyState = $.strategies[strategy];

            // Invest
            if (action.actionType == InvestmentActionType.INVEST) {
                require(strategyState.enabled, Errors.Investment__UnauthorizedStrategy(address(strategy)));
                uint256 investCapacity = strategyState.maxAllocation - strategyState.allocated;
                require(action.amount <= investCapacity, Errors.Investment__InvalidMaxAllocation());

                $.investmentAsset.forceApprove(address(strategy), action.amount);
                uint256 invested = strategy.invest(action.amount);
                $.totalInvested += invested;
                strategyState.allocated += invested;
            }
            // Divest
            else if (action.actionType == InvestmentActionType.DIVEST) {
                require(action.amount <= strategyState.allocated, Errors.Investment__NotEnoughAssets(address(strategy)));
                uint256 divested = strategy.divest(action.amount);

                // this can happen if sync was not called for a while
                if ($.totalInvested < divested) {
                    $.totalInvested = 0;
                } else {
                    $.totalInvested -= divested;
                }

                // this can happen if sync was not called for a while
                if (strategyState.allocated < divested) {
                    strategyState.allocated = 0;
                } else {
                    unchecked {
                        strategyState.allocated -= divested;
                    }
                }
            }
        }
    }

    /// @notice Updates the divest queue by reordering based on the provided indices.
    /// @dev The divest queue is an ordered list of strategies used when liquidating positions.
    ///      The function ensures that any strategy removed from the queue is inactive and has no assets.
    /// @param _indices An array of indices indicating the new order of strategies in the divest queue.
    function updateDivestQueue(uint256[] calldata _indices) external requiresAuth {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        uint256 newLength = _indices.length;
        uint256 length = $.divestQueue.length;

        if (newLength > MAX_STRATEGIES) {
            revert Errors.Common__MaxQueueLengthExceeded();
        }

        bool[] memory seen = new bool[](length);
        IStrategy[] memory newDivestQueue = new IStrategy[](newLength);

        for (uint256 i; i < newLength; ++i) {
            uint256 prevIndex = _indices[i];

            IStrategy strategy = $.divestQueue[prevIndex];
            if (seen[prevIndex]) {
                revert Errors.Investment__DuplicatedStrategy(address(strategy));
            }
            seen[prevIndex] = true;
            newDivestQueue[i] = strategy;
        }

        for (uint256 i; i < length; ++i) {
            if (!seen[i]) {
                IStrategy strategy = $.divestQueue[i];
                Strategy memory strategyState = $.strategies[strategy];

                if (strategyState.allocated > 0) {
                    revert Errors.Investment__StrategyHasAssets(address(strategy));
                }

                if (strategyState.maxAllocation != 0) {
                    revert Errors.Investment__CannotRemoveActiveStrategy(address(strategy));
                }
                delete $.strategies[strategy];
            }
        }

        $.divestQueue = newDivestQueue;
        emit Events.UpdateDivestQueue(msg.sender, newDivestQueue);
    }

    /// @notice Adds a new yield strategy to the vault configuration.
    /// @param _strategy The address of the strategy contract to add.
    /// @param _maxAllocation The maximum allocation for this strategy
    /// @dev This function requires proper authorization. It ensures that the strategy is not already
    /// registered, that the provided max allocation is non-zero,
    /// and then adds the strategy to both the invest and divest queues.
    /// It reverts if the queues exceed the maximum allowed strategies.
    function addStrategy(IStrategy _strategy, uint248 _maxAllocation) external requiresAuth {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        if ($.strategies[_strategy].maxAllocation != 0) {
            revert Errors.Investment__StrategyAlreadyExists(address(_strategy));
        }

        if (_maxAllocation == 0) {
            revert Errors.Investment__InvalidMaxAllocation();
        }

        $.strategies[_strategy] = Strategy({ maxAllocation: _maxAllocation, enabled: true, allocated: 0 });

        $.investQueue.push(_strategy);
        if ($.investQueue.length > MAX_STRATEGIES) {
            revert Errors.Common__MaxQueueLengthExceeded();
        }

        $.divestQueue.push(_strategy);
        if ($.divestQueue.length > MAX_STRATEGIES) {
            revert Errors.Common__MaxQueueLengthExceeded();
        }

        emit Events.StrategyAdded(msg.sender, _strategy, _maxAllocation);
    }

    /// @notice Returns the total amount of assets invested in all strategies.
    /// @return The total amount of assets invested in all strategies.
    function getTotalInvested() public view returns (uint256) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        uint256 _totalInvested = 0;
        for (uint256 i; i < $.investQueue.length; i++) {
            IStrategy strategy = $.investQueue[i];
            _totalInvested += strategy.totalAssets();
        }
        return _totalInvested;
    }

    /// @notice Returns the strategy at the given index in the investment queue.
    /// @param _index The index of the strategy to return.
    /// @return The strategy at the given index.
    function investQueueAt(uint256 _index) public view returns (IStrategy) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        return $.investQueue[_index];
    }

    /// @notice Returns the length of the investment queue.
    /// @return The length of the investment queue.
    function investQueueLength() public view returns (uint256) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        return $.investQueue.length;
    }

    /// @notice Returns the investment queue.
    /// @return The investment queue.
    function investQueue() public view returns (IStrategy[] memory) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        return $.investQueue;
    }

    /// @notice Returns the strategy at the given index in the divest queue.
    /// @param _index The index of the strategy to return.
    /// @return The strategy at the given index.
    function divestQueueAt(uint256 _index) public view returns (IStrategy) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        return $.divestQueue[_index];
    }

    /// @notice Returns the length of the divest queue.
    /// @return The length of the divest queue.
    function divestQueueLength() public view returns (uint256) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        return $.divestQueue.length;
    }

    /// @notice Returns the divest queue.
    /// @return The divest queue.
    function divestQueue() public view returns (IStrategy[] memory) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        return $.divestQueue;
    }

    function _divestUpTo(uint256 _amount) internal returns (uint256 divested) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        uint256 remaining = _amount;
        for (uint256 i = 0; i < $.divestQueue.length && remaining > 0; i++) {
            IStrategy strategy = $.divestQueue[i];
            Strategy storage strategyState = $.strategies[strategy];
            uint256 totalInvested = strategy.totalAssets();

            if (totalInvested > 0) {
                uint256 divestAmount = totalInvested > remaining ? remaining : totalInvested;

                remaining -= divestAmount;
                divested = strategy.divest(divestAmount);

                // this can happen if sync was not called for a while
                if (strategyState.allocated < divestAmount) {
                    strategyState.allocated = 0;
                } else {
                    unchecked {
                        strategyState.allocated -= divestAmount;
                    }
                }

                // this can happen if sync was not called for a while
                if ($.totalInvested < divestAmount) {
                    $.totalInvested = 0;
                } else {
                    unchecked {
                        $.totalInvested -= divestAmount;
                    }
                }
            }
        }
        return divested;
    }

    /// @dev Invests the available assets in the strategies. Called when a deposit is made.
    /// @param _amount The amount of assets to invest.
    /// @return The total amount of assets invested.
    function _investOnDeposit(uint256 _amount) internal returns (uint256) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        uint256 totalInvested = 0;
        uint256 remaining = _amount;
        for (uint256 i; i < $.investQueue.length; i++) {
            IStrategy strategy = $.investQueue[i];
            Strategy storage strategyState = $.strategies[strategy];

            // If the strategy is not enabled, skip it
            if (!strategyState.enabled) {
                continue;
            }

            uint256 investCapacity = strategyState.maxAllocation - strategyState.allocated;
            uint256 investAmount = remaining > investCapacity ? investCapacity : remaining;
            remaining -= investAmount;

            $.investmentAsset.forceApprove(address(strategy), investAmount);
            uint256 invested = strategy.invest(investAmount);
            totalInvested += invested;
            strategyState.allocated += invested;
        }
        $.totalInvested = totalInvested;

        return totalInvested;
    }

    /// @dev Syncs the total invested amount and updates the strategy states.
    /// @return True if the sync was successful.
    function _sync() internal virtual returns (bool) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        uint256 totalInvested = 0;
        for (uint256 i; i < $.investQueue.length; i++) {
            IStrategy strategy = $.investQueue[i];
            Strategy memory strategyState = $.strategies[strategy];
            uint256 strategyInvestment = strategy.totalAssets();
            totalInvested += strategyInvestment;

            uint256 gains = 0;
            uint256 losses = 0;
            if (strategyInvestment != strategyState.allocated) {
                // we have gains (yield)
                if (strategyInvestment > strategyState.allocated) {
                    unchecked {
                        gains += strategyInvestment - strategyState.allocated;
                    }
                }
                // we have losses
                else {
                    unchecked {
                        losses += strategyState.allocated - strategyInvestment;
                    }
                }
                strategyState.allocated += gains - losses;
            }
        }

        $.totalInvested = totalInvested;
        return true;
    }
}
