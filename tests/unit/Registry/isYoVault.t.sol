// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Registry_Base_Test } from "./Base.t.sol";

contract IsYoVault_Test is Registry_Base_Test {
    address internal mockAsset;
    address internal mockVault;
    address internal mockAsset2;
    address internal mockVault2;

    function setUp() public override {
        super.setUp();

        // Create mock assets and vaults
        mockAsset = makeAddr("MockAsset");
        mockVault = createMockVault(mockAsset);
        mockAsset2 = makeAddr("MockAsset2");
        mockVault2 = createMockVault(mockAsset2);
    }

    // ========================================= SUCCESS TESTS =========================================

    function test_isYoVault_RegisteredVault() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault
        registry.addYoVault(mockVault);

        // Check if vault is registered
        assertTrue(registry.isYoVault(mockVault), "Registered vault should return true");

        vm.stopPrank();
    }

    function test_isYoVault_UnregisteredVault() public {
        // Check if unregistered vault returns false
        assertFalse(registry.isYoVault(mockVault), "Unregistered vault should return false");
    }

    function test_isYoVault_ZeroAddress() public {
        // Check if zero address returns false
        assertFalse(registry.isYoVault(address(0)), "Zero address should return false");
    }

    function test_isYoVault_MultipleVaults() public {
        vm.startPrank({ msgSender: users.admin });

        // Add both vaults
        registry.addYoVault(mockVault);
        registry.addYoVault(mockVault2);

        // Check both are registered
        assertTrue(registry.isYoVault(mockVault), "First vault should be registered");
        assertTrue(registry.isYoVault(mockVault2), "Second vault should be registered");

        // Check random address is not registered
        address randomAddress = makeAddr("RandomAddress");
        assertFalse(registry.isYoVault(randomAddress), "Random address should not be registered");

        vm.stopPrank();
    }

    // ========================================= EDGE CASES =========================================

    function test_isYoVault_AfterRemoval() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault
        registry.addYoVault(mockVault);
        assertTrue(registry.isYoVault(mockVault), "Vault should be registered");

        // Remove vault
        registry.removeYoVault(mockVault);
        assertFalse(registry.isYoVault(mockVault), "Vault should not be registered after removal");

        vm.stopPrank();
    }

    function test_isYoVault_ReAddAfterRemoval() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault
        registry.addYoVault(mockVault);
        assertTrue(registry.isYoVault(mockVault), "Vault should be registered");

        // Remove vault
        registry.removeYoVault(mockVault);
        assertFalse(registry.isYoVault(mockVault), "Vault should not be registered after removal");

        // Add vault again
        registry.addYoVault(mockVault);
        assertTrue(registry.isYoVault(mockVault), "Vault should be registered again");

        vm.stopPrank();
    }

    function test_isYoVault_NonExistentContract() public {
        // Check if non-existent contract address returns false
        address nonExistentContract = address(0x1234567890123456789012345678901234567890);
        assertFalse(registry.isYoVault(nonExistentContract), "Non-existent contract should return false");
    }

    function test_isYoVault_AnyUserCanCall() public {
        vm.startPrank({ msgSender: users.admin });
        registry.addYoVault(mockVault);
        vm.stopPrank();

        // Bob should be able to call isYoVault
        vm.startPrank({ msgSender: users.bob });
        assertTrue(registry.isYoVault(mockVault), "Bob should be able to check if vault is registered");
        vm.stopPrank();

        // Alice should be able to call isYoVault
        vm.startPrank({ msgSender: users.alice });
        assertTrue(registry.isYoVault(mockVault), "Alice should be able to check if vault is registered");
        vm.stopPrank();
    }
}
