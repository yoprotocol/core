// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { Errors } from "./libraries/Errors.sol";
import { IYoRegistry } from "./interfaces/IYoRegistry.sol";
import { Authority, AuthUpgradeable } from "./base/AuthUpgradeable.sol";

// __     __   _____            _     _
// \ \   / /  |  __ \          (_)   | |
//  \ \_/ /__ | |__) |___  __ _ _ ___| |_ _ __ _   _
//   \   / _ \|  _  // _ \/ _` | / __| __| '__| | | |
//    | | (_) | | \ \  __/ (_| | \__ \ |_| |  | |_| |
//    |_|\___/|_|  \_\___|\__, |_|___/\__|_|   \__, |
//                         __/ |                __/ |
//                        |___/                |___/
/// @title YoRegistry - A registry for YO vaults
/// @dev This contract is used to register and unregister YO vaults
contract YoRegistry is AuthUpgradeable, IYoRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _vaults;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, Authority _authority) public initializer {
        __Auth_init(_owner, _authority);
    }

    /// @inheritdoc IYoRegistry
    function addYoVault(address vaultAddress) external requiresAuth {
        if (vaultAddress == address(0)) {
            revert Errors.Registry__VaultAddressZero();
        }

        IERC4626 vault = IERC4626(vaultAddress);
        address asset = vault.asset();

        if (!_vaults.add(vaultAddress)) {
            revert Errors.Registry__VaultAlreadyExists(vaultAddress);
        }

        emit YoVaultAdded(asset, vaultAddress);
    }

    /// @inheritdoc IYoRegistry
    function removeYoVault(address vaultAddress) external requiresAuth {
        if (vaultAddress == address(0)) {
            revert Errors.Registry__VaultAddressZero();
        }

        if (!_vaults.remove(vaultAddress)) {
            revert Errors.Registry__VaultNotExists(vaultAddress);
        }

        IERC4626 vault = IERC4626(vaultAddress);
        address asset = vault.asset();

        emit YoVaultRemoved(asset, vaultAddress);
    }

    /// @inheritdoc IYoRegistry
    function isYoVault(address vaultAddress) external view override returns (bool) {
        return _vaults.contains(vaultAddress);
    }

    /// @inheritdoc IYoRegistry
    function listYoVaults() external view returns (address[] memory) {
        return _vaults.values();
    }
}
