// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CommonModule } from "./CommonModule.sol";

import { IOracle } from "../interfaces/IOracle.sol";
import { ILendingAdapter } from "../interfaces/ILendingAdapter.sol";

import { Errors } from "../libraries/Errors.sol";
import { Events } from "../libraries/Events.sol";
import { CtVaultStorage, CtVaultStorageLib } from "../libraries/Storage.sol";
import { LendingAction, LendingActionType, LendingConfig, Repayment } from "../Types.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract LendingModule is CommonModule {
    using Math for uint256;
    using SafeERC20 for IERC20;

    /// @notice the maximum number of lending protocols that can be used
    uint256 public constant MAX_LENDING_PROTOCOLS = 5;

    uint256 public constant LTV_SCALE = 1e18;

    /// @notice The oracle for fetching the price of the borrowed asset
    IOracle public immutable bOracle;

    /// @notice The oracle for fetching the price of the collateral asset
    IOracle public immutable cOracle;

    constructor(address _bAssetOracle, address _cAssetOracle) {
        bOracle = IOracle(_bAssetOracle);
        cOracle = IOracle(_cAssetOracle);
    }

    /// @notice Sets a lending protocol for the vault.
    /// @param _index The index of the lending protocol to set.
    /// @param _adapter The lending adapter to set.
    /// @param _config The configuration for the lending protocol.
    function setLendingProtocol(
        uint256 _index,
        ILendingAdapter _adapter,
        LendingConfig calldata _config
    )
        external
        requiresAuth
    {
        if (_index >= MAX_LENDING_PROTOCOLS) {
            revert Errors.Common__MaxQueueLengthExceeded();
        }
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        if (_index == $.lendingAdapters.length) {
            $.lendingAdapters.push(_adapter);
        } else {
            $.lendingAdapters[_index] = _adapter;
        }

        $.lendingAdaptersConfig[_adapter] = _config;

        emit Events.LendingAdapterUpdated(msg.sender, address(_adapter), _index);
    }

    /// @notice Returns the lending adapter at the given index
    /// @param _index The index of the lending adapter to return
    /// @return The lending adapter at the given index
    function lendingAdaptersAt(uint256 _index) public view returns (address) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        return address($.lendingAdapters[_index]);
    }

    /// @notice Returns the number of lending adapters
    /// @return The number of lending adapters
    function lendingAdaptersLength() public view returns (uint256) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        return $.lendingAdapters.length;
    }

    /// @notice Returns the list of lending adapters
    /// @return The list of lending adapters
    function lendingAdapters() public view returns (ILendingAdapter[] memory) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        return $.lendingAdapters;
    }

    /// @notice Manages a lending position by executing a series of actions.
    /// @param _actions An array of actions to be executed.
    /// @dev The actions are executed in the order they are provided in the array.
    ///      Each action has:
    ///      - REPAY: Repay a borrow
    ///      - BORROW: Borrow an amount
    ///      - ADD_COLLATERAL: Add collateral
    ///      - REMOVE_COLLATERAL: Remove collateral
    /// @dev The function reverts if any of the actions is not valid.
    function manageLendingPosition(LendingAction[] calldata _actions) external requiresAuth {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        for (uint256 i; i < _actions.length; i++) {
            LendingAction memory action = _actions[i];
            require(action.adapterIndex < $.lendingAdapters.length, Errors.Lending__InvalidAdapterIndex());

            ILendingAdapter adapter = $.lendingAdapters[action.adapterIndex];
            LendingConfig memory config = $.lendingAdaptersConfig[adapter];

            // Repay
            if (action.actionType == LendingActionType.REPAY) {
                uint256 currentBorrowed = adapter.getBorrowed();
                require(action.amount <= currentBorrowed, Errors.Lending__InvalidRepayAmount());

                IERC20(_asset()).forceApprove(address(adapter), action.amount);
                uint256 repaid = adapter.repay(action.amount);
                $.totalBorrowed -= repaid;
            }
            // Borrow
            else if (action.actionType == LendingActionType.BORROW) {
                uint256 borrowLimit = adapter.getBorrowLimit();
                require(action.amount <= borrowLimit, Errors.Lending__BorrowLimitExceeded());

                uint256 currentBorrowed = adapter.getBorrowed();
                uint256 currentCollateral = adapter.getCollateral();
                uint256 newBorrowed = currentBorrowed + action.amount;

                uint256 newLTV = _getLTV(currentCollateral, newBorrowed);
                require(newLTV >= config.minLTV, Errors.Lending__LTVTooLow());
                require(newLTV <= config.maxLTV, Errors.Lending__LTVTooHigh());

                uint256 borrowed = adapter.borrow(action.amount);
                $.totalBorrowed += borrowed;
            }
            // Add collateral
            else if (action.actionType == LendingActionType.ADD_COLLATERAL) {
                uint256 currentCollateral = adapter.getCollateral();
                require(
                    currentCollateral + action.amount <= config.maxAllocation, Errors.Lending__MaxAllocationExceeded()
                );

                IERC20(_asset()).forceApprove(address(adapter), action.amount);
                $.totalCollateral += action.amount;
                adapter.addCollateral(action.amount);
            }
            // Remove collateral
            else if (action.actionType == LendingActionType.REMOVE_COLLATERAL) {
                uint256 currentCollateral = adapter.getCollateral();
                require(action.amount <= currentCollateral, Errors.Lending__InvalidCollateralAmount());

                uint256 currentBorrowed = adapter.getBorrowed();
                uint256 newCollateral = currentCollateral - action.amount;

                uint256 newLTV = _getLTV(newCollateral, currentBorrowed);
                require(newLTV <= config.maxLTV, Errors.Lending__LTVTooHigh());

                $.totalCollateral -= action.amount;
                adapter.removeCollateral(action.amount);
            }
        }

        // TODO: shall we check the health factor here? shall we keep the desired health factor in the vault state?
        for (uint256 i; i < $.lendingAdapters.length; i++) {
            ILendingAdapter adapter = $.lendingAdapters[i];
            uint256 healthFactor = adapter.getHealthFactor();
            require(healthFactor >= 1e18, Errors.Lending__HealthFactorTooLow());
        }
    }

    /// @notice Calculate the amount of borrowed assets based on the target LTV ratio
    /// @param _collateral The amount of collateral
    /// @param _targetLTV The target Loan-to-Value ratio
    /// @return borrowAmount The amount of borrowed assets
    function calculateBorrowAmount(
        uint256 _collateral,
        uint256 _targetLTV
    )
        public
        view
        returns (uint256 borrowAmount)
    {
        // get the collateral value in USD
        uint256 collateralValue = cOracle.getValue(_collateral);
        // get the target borrowed value in USD using ceilDiv to round up
        uint256 targetBorrowValue = collateralValue.mulDiv(_targetLTV, LTV_SCALE, Math.Rounding.Ceil);
        // get the amount of borrowed assets that corresponds to the target borrowed value
        borrowAmount = bOracle.getAmount(targetBorrowValue);
        return borrowAmount;
    }

    /**
     * @notice Converts an amount of borrowed assets to its equivalent
     * amount of collateral assets based on their prices
     * and decimal differences.
     *
     * @dev The formula used for conversion is:
     *      numerator = A1 * P1 * 10^(D2 - D1)
     *      A2 = (numerator + P2 - 1) / P2
     *
     *      Where:
     *        - A1 = borrow amount
     *        - P1 = price of borrowed asset
     *        - P2 = price of collateral asset
     *        - D1 = decimals of borrowed asset
     *        - D2 = decimals of collateral asset
     *        - 10^(D2 - D1) = Scaling factor to adjust decimals between the assets
     *        - Adding (P2 - 1) ensures ceiling division to avoid truncation errors.
     *
     * @param _borrowAmount The amount of asset1 to be converted.
     * @return collateralAmount The equivalent amount of asset2.
     */
    function convertToCollateral(uint256 _borrowAmount) public view returns (uint256 collateralAmount) {
        uint256 borrowedPrice = bOracle.price();
        uint256 collateralPrice = cOracle.price();
        uint256 numerator = _borrowAmount * borrowedPrice * (10 ** (cOracle.assetDecimals() - bOracle.assetDecimals()));
        return (numerator + collateralPrice - 1) / collateralPrice;
    }

    /// @notice Returns the Loan-to-Value ratio of the vault
    /// @return The LTV ratio
    function getVaultLTV() public view returns (uint256) {
        (uint256 totalBorrowed, uint256 totalCollateral) = getState();
        return _getLTV(totalCollateral, totalBorrowed);
    }

    function getState() public view returns (uint256 totalBorrowed, uint256 totalCollateral) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        for (uint256 i; i < $.lendingAdapters.length; i++) {
            ILendingAdapter adapter = ILendingAdapter($.lendingAdapters[i]);
            uint256 borrowed = adapter.getBorrowed();
            uint256 collateral = adapter.getCollateral();
            totalBorrowed += borrowed;
            totalCollateral += collateral;
        }
    }

    /// @notice Returns the total amount of collateral in the vault
    /// @return The total collateral
    function getTotalCollateral() public view returns (uint256) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        uint256 _totalCollateral = 0;
        for (uint256 i; i < $.lendingAdapters.length; i++) {
            ILendingAdapter adapter = ILendingAdapter($.lendingAdapters[i]);
            _totalCollateral += adapter.getCollateral();
        }
        return _totalCollateral;
    }

    /// @notice Returns the total amount of borrowed assets in the vault
    /// @return The total borrowed
    function getTotalBorrowed() public view returns (uint256) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        uint256 _totalBorrowed = 0;
        for (uint256 i; i < $.lendingAdapters.length; i++) {
            ILendingAdapter adapter = ILendingAdapter($.lendingAdapters[i]);
            _totalBorrowed += adapter.getBorrowed();
        }
        return _totalBorrowed;
    }

    /// @dev Get the Loan-to-Value ratio scaled by 1e18, i.e. 1e18 = 100% LTV (utilization)
    /// @param _collateral The amount of collateral
    /// @param _borrowed The amount of borrowed assets
    /// @return The LTV ratio
    function _getLTV(uint256 _collateral, uint256 _borrowed) internal view returns (uint256) {
        uint256 borrowedValue = bOracle.getValue(_borrowed);
        uint256 collateralValue = cOracle.getValue(_collateral);
        return borrowedValue.mulDiv(LTV_SCALE, collateralValue);
    }

    function _getRepayments(uint256 _amount) internal view returns (Repayment[] memory) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        uint256 remaining = _amount;
        Repayment[] memory repayments = new Repayment[]($.lendingAdapters.length);
        for (uint256 i; i < $.lendingAdapters.length && remaining > 0; i++) {
            ILendingAdapter adapter = ILendingAdapter($.lendingAdapters[i]);

            uint256 currentBorrowed = adapter.getBorrowed();
            uint256 currentCollateral = adapter.getCollateral();

            // if the remaining amount is greater than the current collateral, we must repay the entire collateral
            if (remaining >= currentCollateral) {
                unchecked {
                    remaining -= currentCollateral;
                }
                repayments[i] = Repayment({ amount: currentBorrowed, collateral: currentCollateral, adapter: adapter });
            } else {
                uint256 partialBorrowed = currentBorrowed.mulDiv(remaining, currentCollateral);
                repayments[i] = Repayment({ amount: partialBorrowed, collateral: remaining, adapter: adapter });
                remaining = 0;
            }
        }

        return repayments;
    }

    /// @dev Called when a deposit is made.
    /// @param _amount The amount of assets to deposit.
    /// @return totalBorrowed The total amount of borrowed assets.
    /// @return totalCollateral The total amount of collateral.
    function _onDeposit(uint256 _amount) internal returns (uint256 totalBorrowed, uint256 totalCollateral) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        uint256 remaining = _amount;
        for (uint256 i; i < $.lendingAdapters.length && remaining > 0; i++) {
            ILendingAdapter adapter = ILendingAdapter($.lendingAdapters[i]);
            LendingConfig memory config = $.lendingAdaptersConfig[adapter];

            uint256 currentCollateral = adapter.getCollateral();
            uint256 maxAllowedCollateral = config.maxAllocation;

            // If the adapter is already full, skip it
            if (currentCollateral >= maxAllowedCollateral) {
                continue;
            }

            uint256 capacity;
            uint256 collateralAmount;
            unchecked {
                capacity = maxAllowedCollateral - currentCollateral;
                collateralAmount = remaining > capacity ? capacity : remaining;
                remaining -= collateralAmount;
            }

            IERC20(_asset()).forceApprove(address(adapter), collateralAmount);
            totalCollateral += collateralAmount;
            adapter.addCollateral(collateralAmount);

            uint256 desiredBorrowAmount = calculateBorrowAmount(collateralAmount, config.targetLTV);
            uint256 borrowLimit = adapter.getBorrowLimit();

            uint256 borrowAmount = desiredBorrowAmount > borrowLimit ? borrowLimit : desiredBorrowAmount;
            totalBorrowed += adapter.borrow(borrowAmount);
        }

        $.totalBorrowed = totalBorrowed;
        $.totalCollateral = totalCollateral;
    }

    /// @dev Called when a sync is performed.
    function _sync() internal virtual {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        uint256 totalBorrowed = 0;
        uint256 totalCollateral = 0;

        for (uint256 i; i < $.lendingAdapters.length; i++) {
            ILendingAdapter adapter = ILendingAdapter($.lendingAdapters[i]);
            totalBorrowed += adapter.getBorrowed();
            totalCollateral += adapter.getCollateral();
        }
        $.totalBorrowed = totalBorrowed;
        $.totalCollateral = totalCollateral;
    }
}
