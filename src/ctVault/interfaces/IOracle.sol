// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IOracle {
    /// @notice Returns the price of the asset in USD.
    function price() external view returns (uint256);

    /**
     * @notice Returns the value of an amount of an asset in USD.
     * @param _amount The amount of the asset.
     * @return The value of the asset in USD.
     */
    function getValue(uint256 _amount) external view returns (uint256);

    /**
     * @notice Returns the amount of an asset that corresponds to a given value in USD.
     * @param _value The value of the asset in USD.
     * @return The amount of the asset.
     */
    function getAmount(uint256 _value) external view returns (uint256);
}
