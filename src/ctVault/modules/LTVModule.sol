// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IOracle } from "../interfaces/IOracle.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title LTVModule
/// @author YO.xyz
/// @notice This module calculates the Loan-to-Value ratio for a given collateral and borrowed assets
abstract contract LTVModule {
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
}
