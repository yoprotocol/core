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

    IOracle public immutable b;
    uint256 public immutable bScale;

    IOracle public immutable c;
    uint256 public immutable cScale;

    constructor(address _borrowedAssetOracle, address _collateralAssetOracle) {
        b = IOracle(_borrowedAssetOracle);
        bScale = b.scale();

        c = IOracle(_collateralAssetOracle);
        cScale = b.scale();
    }

    /// @notice Get the Loan-to-Value ratio scaled by 1e18, i.e. 1e18 = 100% LTV (utilization)
    /// @param _collateral The amount of collateral
    /// @param _borrowed The amount of borrowed assets
    /// @return The LTV ratio
    function getLTV(uint256 _collateral, uint256 _borrowed) public view returns (uint256) {
        uint256 bAssetPrice = b.price();
        uint256 cAssetPrice = c.price();

        uint256 borrowedValue = _borrowed.mulDiv(bAssetPrice, bScale);
        uint256 collateralValue = _collateral.mulDiv(cAssetPrice, cScale);

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
        uint256 cAssetPrice = c.price();
        uint256 bAssetPrice = b.price();

        // Calculate the collateral value in USD.
        uint256 collateralValue = _collateral.mulDiv(cAssetPrice, cScale);
        // Calculate the target borrowed value in USD based on the target LTV.
        uint256 targetBorrowValue = collateralValue.mulDiv(_targetLTV, LTV_SCALE);
        // Convert the target borrowed USD value into the borrowed asset amount.
        borrowAmount = targetBorrowValue.mulDiv(bScale, bAssetPrice);
        return borrowAmount;
    }
}
