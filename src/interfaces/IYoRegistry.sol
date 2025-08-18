// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IYoRegistry {
    event YoVaultAdded(address indexed asset, address indexed vault);
    event YoVaultRemoved(address indexed asset, address indexed vault);

    /// @notice Checks if an address is a valid YO vault
    /// @param vaultAddress Vault address to be added
    function isYoVault(address vaultAddress) external view returns (bool);

    /// @notice Registers a YO vault
    /// @param vaultAddress YO vault address to be added
    function addYoVault(address vaultAddress) external;

    /// @notice Removes YO vault registration
    /// @param vaultAddress YO vault address to be removed
    function removeYoVault(address vaultAddress) external;

    /// @notice Returns a list of all registered YO vaults
    function listYoVaults() external view returns (address[] memory);
}
