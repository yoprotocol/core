// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title ILendingAdapter
/// @notice Interface for a lending adapter that allows a vault to manage collateral, borrowing, and repayment.
/// It exposes functions to add/remove collateral, borrow/repay stablecoins, and retrieve key statistics.
interface ILendingAdapter {
    /// @notice Returns the vault address associated with this adapter.
    function vault() external view returns (address);

    /// @notice Adds collateral to the lending protocol.
    /// @param _amount The amount of collateral (cbBTC) to add.
    function addCollateral(uint256 _amount) external;

    /// @notice Removes collateral from the lending protocol.
    /// @param _amount The amount of collateral (cbBTC) to remove.
    function removeCollateral(uint256 _amount) external;

    /// @notice Borrows a specified amount of stablecoins against the collateral.
    /// @param _amount The amount of stablecoins to borrow.
    function borrow(uint256 _amount) external;

    /// @notice Repays a specified amount of borrowed stablecoins.
    /// @param _amount The amount of stablecoins to repay.
    function repay(uint256 _amount) external;

    /// @notice Repays all outstanding borrowed stablecoins.
    function repayAll() external;

    /// @notice Triggers an on-chain event logging current lending stats.
    /// Stats include collateral, borrowed amounts, supply APY, borrow APY, and the health factor.
    function logStats() external;

    /// @notice Retrieves the current total collateral (in cbBTC) held by the adapter.
    /// @return The amount of collateral.
    function getCollateral() external view returns (uint256);

    /// @notice Retrieves the current borrow limit (in stablecoins) available.
    /// @return The borrow limit.
    function getBorrowLimit() external view returns (uint256);

    /// @notice Retrieves the total borrowed stablecoin amount.
    /// @return The borrowed amount.
    function getBorrowed() external view returns (uint256);

    /// @notice Retrieves the current supply APY (annual percentage yield) for collateral.
    /// @return The supply APY.
    function getSupplyAPY() external view returns (uint256);

    /// @notice Retrieves the current borrow APY for stablecoin debt.
    /// @return The borrow APY.
    function getBorrowAPY() external view returns (uint256);

    /// @notice Retrieves the current health factor of the collateral position.
    /// @return The health factor.
    function getHealthFactor() external view returns (uint256);
}
