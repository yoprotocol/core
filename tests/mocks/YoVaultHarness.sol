// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { YoVault_V2 } from "src/YoVault_V2.sol";

/// @dev Test harness exposing YoVault_V2 internals for assertions.
contract YoVaultHarness is YoVault_V2 {
    function exposed_feeOnRaw(uint256 assets, uint256 feeBasisPoints) external pure returns (uint256) {
        return _feeOnRaw(assets, feeBasisPoints);
    }

    function exposed_feeOnTotal(uint256 assets, uint256 feeBasisPoints) external pure returns (uint256) {
        return _feeOnTotal(assets, feeBasisPoints);
    }
}
