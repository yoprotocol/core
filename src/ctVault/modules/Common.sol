// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AuthUpgradeable } from "../../base/AuthUpgradable.sol";

import { ERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

abstract contract CommonModule is AuthUpgradeable {
    bytes32 private constant ERC4626StorageLocation = 0x0773e532dfede91f04b12a73d3d2acd361424f41f76b4fb79f090161e36b4e00;

    function _asset() internal view returns (address) {
        ERC4626Upgradeable.ERC4626Storage storage $ = _getInheritedERC4626Storage();
        return address($._asset);
    }

    function _getInheritedERC4626Storage() private pure returns (ERC4626Upgradeable.ERC4626Storage storage $) {
        assembly {
            $.slot := ERC4626StorageLocation
        }
    }
}
