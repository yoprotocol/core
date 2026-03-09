// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { YoVault_V2 } from "src/YoVault_V2.sol";

/// @title YoVault_V3 - Adds asset re-initialization for correcting a misconfigured deployment.
contract YoVault_V3 is YoVault_V2 {
    /// @notice Re-initialize the underlying asset. Can only be called once (reinitializer v2).
    /// @param newAsset The correct ERC-20 asset address.
    function reinitializeAsset(IERC20 newAsset) external reinitializer(2) {
        __ERC4626_init(newAsset);
    }
}
