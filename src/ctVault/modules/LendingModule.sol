// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CtVaultStorageLib } from "../libraries/Storage.sol";
import { LendingAction, LendingActionType, LendingConfig } from "../Types.sol";
import { AuthUpgradeable, Authority } from "../../base/AuthUpgradable.sol";
import { CtVaultStorage, CtVaultStorageLib } from "../libraries/Storage.sol";
import { IOracle } from "../interfaces/IOracle.sol";
import { ILendingAdapter } from "../interfaces/ILendingAdapter.sol";
import { Errors } from "../libraries/Errors.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { CommonModule } from "./Common.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract LendingModule is CommonModule {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public constant LTV_SCALE = 1e18;

    /// @notice The oracle for fetching the price of the borrowed asset
    IOracle public immutable bOracle;

    /// @notice The oracle for fetching the price of the collateral asset
    IOracle public immutable cOracle;

    constructor(address _bAssetOracle, address _cAssetOracle) {
        bOracle = IOracle(_bAssetOracle);
        cOracle = IOracle(_cAssetOracle);
    }

    function manageLendingPosition(LendingAction[] calldata actions) external requiresAuth {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        for (uint256 i; i < actions.length; i++) {
            LendingAction memory action = actions[i];
            require(action.adapterIndex < $.lendingAdapters.length, Errors.InvalidAdapterIndex());

            ILendingAdapter adapter = $.lendingAdapters[action.adapterIndex];
            LendingConfig memory config = $.lendingAdaptersConfig[adapter];

            // Repay
            if (action.actionType == LendingActionType.REPAY) {
                uint256 currentBorrowed = adapter.getBorrowed();
                require(action.amount <= currentBorrowed, Errors.InvalidRepayAmount());

                IERC20(_asset()).forceApprove(address(adapter), action.amount);
                adapter.repay(action.amount);
            }
            // Borrow
            else if (action.actionType == LendingActionType.BORROW) {
                uint256 borrowLimit = adapter.getBorrowLimit();
                require(action.amount <= borrowLimit, Errors.BorrowLimitExceeded());

                uint256 currentBorrowed = adapter.getBorrowed();
                uint256 currentCollateral = adapter.getCollateral();
                uint256 newBorrowed = currentBorrowed + action.amount;

                uint256 newLTV = _getLTV(currentCollateral, newBorrowed);
                require(newLTV >= config.minLTV, Errors.LTVTooLow());
                require(newLTV <= config.maxLTV, Errors.LTVTooHigh());

                adapter.borrow(action.amount);
            }
            // Add collateral
            else if (action.actionType == LendingActionType.ADD_COLLATERAL) {
                uint256 currentCollateral = adapter.getCollateral();
                require(currentCollateral + action.amount <= config.maxAllocation, Errors.MaxAllocationExceeded());

                IERC20(_asset()).forceApprove(address(adapter), action.amount);
                adapter.addCollateral(action.amount);
            }
            // Remove collateral
            else if (action.actionType == LendingActionType.REMOVE_COLLATERAL) {
                uint256 currentCollateral = adapter.getCollateral();
                require(action.amount <= currentCollateral, Errors.InvalidCollateralAmount());

                uint256 currentBorrowed = adapter.getBorrowed();
                uint256 newCollateral = currentCollateral - action.amount;

                uint256 newLTV = _getLTV(newCollateral, currentBorrowed);
                require(newLTV <= config.maxLTV, Errors.LTVTooHigh());

                adapter.removeCollateral(action.amount);
            }
        }

        // TODO: shall we check the health factor here? shall we keep the desired health factor in the vault state?
        for (uint256 i; i < $.lendingAdapters.length; i++) {
            ILendingAdapter adapter = $.lendingAdapters[i];
            uint256 healthFactor = adapter.getHealthFactor();
            require(healthFactor >= 1e18, Errors.HealthFactorTooLow());
        }
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
        // get the target borrowed value in USD
        uint256 targetBorrowValue = collateralValue.mulDiv(_targetLTV, LTV_SCALE);
        // get the amount of borrowed assets that corresponds to the target borrowed value
        borrowAmount = bOracle.getAmount(targetBorrowValue);
        return borrowAmount;
    }

    function getVaultLTV() public view returns (uint256) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();
        uint256 _totalCollateral = 0;
        uint256 _totalBorrowed = 0;

        for (uint256 i; i < $.lendingAdapters.length; i++) {
            ILendingAdapter adapter = ILendingAdapter($.lendingAdapters[i]);
            uint256 borrowed = adapter.getBorrowed();
            uint256 collateral = adapter.getCollateral();
            _totalBorrowed += borrowed;
            _totalCollateral += collateral;
        }

        return _getLTV(_totalCollateral, _totalBorrowed);
    }

    function getTotalCollateral() public view returns (uint256) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        uint256 _totalCollateral = 0;
        for (uint256 i; i < $.lendingAdapters.length; i++) {
            ILendingAdapter adapter = ILendingAdapter($.lendingAdapters[i]);
            _totalCollateral += adapter.getCollateral();
        }
        return _totalCollateral;
    }

    function getTotalBorrowed() public view returns (uint256) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        uint256 _totalBorrowed = 0;
        for (uint256 i; i < $.lendingAdapters.length; i++) {
            ILendingAdapter adapter = ILendingAdapter($.lendingAdapters[i]);
            _totalBorrowed += adapter.getBorrowed();
        }
        return _totalBorrowed;
    }
}
