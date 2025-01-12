// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IyoVault
/// @notice Interface for the YO vault part of the YO protocol
interface IyoVault {
    struct PendingRedeem {
        uint256 assets;
        uint256 shares;
    }

    /// @notice Emitted when the fee is updated
    /// @param lastFee The last fee
    /// @param newFee The new fee
    event WithdrawFeeUpdated(uint256 lastFee, uint256 newFee);

    /// @notice Emitted when the fee is updated
    /// @param lastFee The last fee
    /// @param newFee The new fee
    event DepositFeeUpdated(uint256 lastFee, uint256 newFee);

    /// @notice Emitted when the fee recipient is updated
    /// @param lastFeeRecipient The last fee recipient
    /// @param newFeeRecipient The new fee recipient
    event FeeRecipientUpdated(address lastFeeRecipient, address newFeeRecipient);

    /// @notice Emitted when the max percentage is updated
    /// @param lastMaxPercentage The last max percentage
    /// @param newMaxPercentage The new max percentage
    event MaxPercentageUpdated(uint256 lastMaxPercentage, uint256 newMaxPercentage);

    /// @notice Emitted when the underlying balance is updated by the oracle
    /// @param lastUnderlyingBalance The last underlying balance
    /// @param newUnderlyingBalance The new underlying balance
    event UnderlyingBalanceUpdated(uint256 lastUnderlyingBalance, uint256 newUnderlyingBalance);

    /// @notice Emitted when a new redeem request is created
    /// @param receiver The receiving address
    /// @param owner The owner address
    /// @param assets The assets amount
    /// @param shares The shares amount
    /// @param instant The instant status
    event RedeemRequest(
        address indexed receiver, address indexed owner, uint256 assets, uint256 shares, bool indexed instant
    );

    /// @notice Emitted when an operator status is updated
    /// @param operator The operator address
    /// @param status The operator status
    event OperatorSet(address indexed controller, address indexed operator, bool indexed status);

    /// @notice Emitted when a redeem request is fulfilled
    /// @param receiver The receiving address
    /// @param shares The shares amount
    /// @param assets The assets amount
    event RequestFulfilled(address indexed receiver, uint256 shares, uint256 assets);

    /// @notice Emitted when a redeem request is cancelled
    /// @param receiver The receiving address
    /// @param shares The shares amount
    /// @param assets The assets amount
    event RequestCancelled(address indexed receiver, uint256 shares, uint256 assets);

    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256 requestId);
}
