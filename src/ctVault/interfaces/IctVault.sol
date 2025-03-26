// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IctVault {
    /// @notice Updates the investment queue, which is the list of strategies the vault will use to invest available
    /// assets.
    /// @param _investQueue The new ordered list of strategy addresses to be used for investing.
    function setInvestQueue(address[] calldata _investQueue) external;

    /// @notice Updates the divest queue by reordering based on the provided indices.
    /// @dev The divest queue is an ordered list of strategies used when liquidating positions.
    ///      The function ensures that any strategy removed from the queue is inactive and has no assets.
    /// @param _indices An array of indices indicating the new order of strategies in the divest queue.
    function updateDivestQueue(uint256[] calldata _indices) external;

    /// @notice Adds a new yield strategy to the vault configuration.
    /// @param _strategy The address of the strategy contract to add.
    /// @param _maxAllocation The maximum allocation for this strategy
    /// @dev This function requires proper authorization. It ensures that the strategy is not already
    /// registered, that the provided max allocation is non-zero,
    /// and then adds the strategy to both the invest and divest queues.
    /// It reverts if the queues exceed the maximum allowed strategies.
    function addStrategy(address _strategy, uint248 _maxAllocation) external;
}
