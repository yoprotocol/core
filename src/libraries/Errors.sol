// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library Errors {
    //============================== GENERICS ===============================
    /// @notice Thrown when an unauthorized method to a target is called.
    /// @dev The method must be authorized by setUserRole and setRoleCapability from RolesAuthority
    error TargetMethodNotAuthorized(address target, bytes4 functionSig);

    /// @notice Thrown when insufficient shares balance is available to complete the operation.
    error InsufficientShares();

    /// @notice Thrown when insufficient assets balance is available to complete the operation.
    error InsufficientAssets();

    /// @notice Thrown when the operation is called by a user that is not the owner of the shares.
    error NotSharesOwner();

    /// @notice Thrown when the input shares amount is zero.
    error SharesAmountZero();

    /// @notice Thrown when the input assets amount is zero.
    error AssetsAmountZero();

    /// @notice Thrown when a claim request is fulfilled with an invalid shares amount.
    error InvalidSharesAmount();

    /// @notice Thrown when the new max percentage is greater than the current max percentage.
    error InvalidMaxPercentage();

    /// @notice Thrown when the new fee is greater than the max allowed fee.
    error InvalidFee();
}
