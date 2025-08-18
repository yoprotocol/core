// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Registry_Base_Test } from "./Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";
import { IYoRegistry } from "src/interfaces/IYoRegistry.sol";

contract RemoveYoVault_Test is Registry_Base_Test {
    address internal mockAsset;
    address internal mockVault;

    function setUp() public override {
        super.setUp();

        // Create a mock asset (USDC)
        mockAsset = makeAddr("MockAsset");
        mockVault = createMockVault(mockAsset);
    }

    // ========================================= SUCCESS TESTS =========================================

    function test_removeYoVault_Success() public {
        vm.startPrank({ msgSender: users.admin });

        // First add the vault
        registry.addYoVault(mockVault);
        assertTrue(registry.isYoVault(mockVault), "Vault should be registered");

        // Then remove it
        vm.expectEmit({ emitter: address(registry) });
        emit IYoRegistry.YoVaultRemoved(mockAsset, mockVault);

        registry.removeYoVault(mockVault);

        assertFalse(registry.isYoVault(mockVault), "Vault should not be registered");
        vm.stopPrank();
    }

    function test_removeYoVault_MultipleVaults() public {
        vm.startPrank({ msgSender: users.admin });

        address mockAsset2 = makeAddr("MockAsset2");
        address mockVault2 = createMockVault(mockAsset2);

        // Add both vaults
        registry.addYoVault(mockVault);
        registry.addYoVault(mockVault2);

        // Remove first vault
        registry.removeYoVault(mockVault);
        assertFalse(registry.isYoVault(mockVault), "First vault should not be registered");
        assertTrue(registry.isYoVault(mockVault2), "Second vault should still be registered");

        // Check list
        address[] memory vaults = registry.listYoVaults();
        assertEq(vaults.length, 1, "Should have 1 vault");
        assertEq(vaults[0], mockVault2, "Second vault should be in list");

        // Remove second vault
        registry.removeYoVault(mockVault2);
        assertFalse(registry.isYoVault(mockVault2), "Second vault should not be registered");

        // Check empty list
        vaults = registry.listYoVaults();
        assertEq(vaults.length, 0, "Should have 0 vaults");

        vm.stopPrank();
    }

    // ========================================= FAILURE TESTS =========================================

    function test_removeYoVault_ZeroAddress() public {
        vm.startPrank({ msgSender: users.admin });

        vm.expectRevert(Errors.Registry__VaultAddressZero.selector);
        registry.removeYoVault(address(0));

        vm.stopPrank();
    }

    function test_removeYoVault_VaultNotExists() public {
        vm.startPrank({ msgSender: users.admin });

        vm.expectRevert(abi.encodeWithSelector(Errors.Registry__VaultNotExists.selector, mockVault));
        registry.removeYoVault(mockVault);

        vm.stopPrank();
    }

    function test_removeYoVault_Unauthorized() public {
        vm.startPrank({ msgSender: users.admin });
        registry.addYoVault(mockVault);
        vm.stopPrank();

        vm.startPrank({ msgSender: users.bob });

        vm.expectRevert();
        registry.removeYoVault(mockVault);

        vm.stopPrank();
    }

    // ========================================= EDGE CASES =========================================

    function test_removeYoVault_AlreadyRemoved() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault
        registry.addYoVault(mockVault);
        assertTrue(registry.isYoVault(mockVault), "Vault should be registered");

        // Remove vault
        registry.removeYoVault(mockVault);
        assertFalse(registry.isYoVault(mockVault), "Vault should not be registered");

        // Try to remove again
        vm.expectRevert(abi.encodeWithSelector(Errors.Registry__VaultNotExists.selector, mockVault));
        registry.removeYoVault(mockVault);

        vm.stopPrank();
    }

    function test_removeYoVault_EventEmission() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault first
        registry.addYoVault(mockVault);

        // Remove vault and check event
        vm.expectEmit({ emitter: address(registry) });
        emit IYoRegistry.YoVaultRemoved(mockAsset, mockVault);

        registry.removeYoVault(mockVault);

        vm.stopPrank();
    }
}
