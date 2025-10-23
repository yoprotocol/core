// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library Errors {
    //============================== GENERICS ===============================
    /// @notice Thrown when an unauthorized method to a target is called.
    /// @dev The method must be authorized by setUserRole and setRoleCapability from RolesAuthority
    error TargetMethodNotAuthorized(address target, bytes4 functionSig);

    /// @notice Thrown when insufficient shares balance is available to complete the operation.
    error InsufficientShares();

    /// @notice Thrown when the operation is called by a user that is not the owner of the shares.
    error NotSharesOwner();

    /// @notice Thrown when the input shares amount is zero.
    error SharesAmountZero();

    /// @notice Thrown when a claim request is fulfilled with an invalid shares amount.
    error InvalidSharesAmount();

    /// @notice Thrown when a withdraw is attempted with an amount different than the claimable assets.
    error InvalidAssetsAmount();

    /// @notice Thrown when the new max percentage is greater than the current max percentage.
    error InvalidMaxPercentage();

    /// @notice Thrown when the new fee is greater than the max allowed fee.
    error InvalidFee();

    /// @notice Thrown when the underlying balance has already been updated in the current block.
    error UpdateAlreadyCompletedInThisBlock();

    /// @notice Thrown when redeem() or withdraw() is called
    error UseRequestRedeem();

    error UseOnSharePriceUpdate();

    /// @notice Thrown when msg.sender is not the vault
    error Escrow__OnlyVault();

    /// @notice Thrown when the requested amount of assets is zero
    error Escrow__AmountZero();

    /// @notice Thrown when the vault address is zero
    error Registry__VaultAddressZero();

    /// @notice Thrown when the vault already exists
    error Registry__VaultAlreadyExists(address vaultAddress);

    /// @notice Thrown when the vault does not exist
    error Registry__VaultNotExists(address vaultAddress);

    /// @notice Thrown when the vault is not allowed
    error Gateway__VaultNotAllowed();

    /// @notice Thrown when the amount is zero
    error Gateway__ZeroAmount();

    /// @notice Thrown when the receiver is zero
    error Gateway__ZeroReceiver();

    /// @notice Thrown when the shares out is less than the minimum shares out
    error Gateway__InsufficientSharesOut(uint256 sharesOut, uint256 minSharesOut);

    /// @notice Thrown when the owner of the shares is zero
    error Gateway__ZeroOwner();

    /// @notice Thrown when the assets out is less than the minimum assets out
    error Gateway__InsufficientAssetsOut(uint256 assetsOut, uint256 minAssetsOut);
}
