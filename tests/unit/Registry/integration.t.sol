// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Registry_Base_Test } from "./Base.t.sol";
import { IYoRegistry } from "src/interfaces/IYoRegistry.sol";

contract Integration_Test is Registry_Base_Test {
    address[] internal mockAssets;
    address[] internal mockVaults;

    function setUp() public override {
        super.setUp();

        // Create multiple mock assets and vaults
        for (uint256 i = 0; i < 5; i++) {
            address mockAsset = makeAddr(string.concat("MockAsset", vm.toString(i)));
            address mockVault = createMockVault(mockAsset);
            mockAssets.push(mockAsset);
            mockVaults.push(mockVault);
        }
    }

    // ========================================= INTEGRATION TESTS =========================================

    function test_fullWorkflow_AddRemoveReAdd() public {
        vm.startPrank({ msgSender: users.admin });

        // 1. Start with empty registry
        address[] memory vaults = registry.listYoVaults();
        assertEq(vaults.length, 0, "Registry should start empty");

        // 2. Add multiple vaults
        for (uint256 i = 0; i < mockVaults.length; i++) {
            vm.expectEmit({ emitter: address(registry) });
            emit IYoRegistry.YoVaultAdded(mockAssets[i], mockVaults[i]);

            registry.addYoVault(mockVaults[i]);
            assertTrue(registry.isYoVault(mockVaults[i]), "Vault should be registered");
        }

        // 3. Verify all vaults are in the list
        vaults = registry.listYoVaults();
        assertEq(vaults.length, mockVaults.length, "All vaults should be in list");

        // 4. Remove some vaults
        registry.removeYoVault(mockVaults[1]);
        registry.removeYoVault(mockVaults[3]);

        // 5. Verify remaining vaults
        assertFalse(registry.isYoVault(mockVaults[1]), "Vault1 should be removed");
        assertFalse(registry.isYoVault(mockVaults[3]), "Vault3 should be removed");
        assertTrue(registry.isYoVault(mockVaults[0]), "Vault0 should still be registered");
        assertTrue(registry.isYoVault(mockVaults[2]), "Vault2 should still be registered");
        assertTrue(registry.isYoVault(mockVaults[4]), "Vault4 should still be registered");

        // 6. Re-add removed vaults
        vm.expectEmit({ emitter: address(registry) });
        emit IYoRegistry.YoVaultAdded(mockAssets[1], mockVaults[1]);
        registry.addYoVault(mockVaults[1]);

        vm.expectEmit({ emitter: address(registry) });
        emit IYoRegistry.YoVaultAdded(mockAssets[3], mockVaults[3]);
        registry.addYoVault(mockVaults[3]);

        // 7. Verify all vaults are back
        vaults = registry.listYoVaults();
        assertEq(vaults.length, mockVaults.length, "All vaults should be back in list");

        for (uint256 i = 0; i < mockVaults.length; i++) {
            assertTrue(registry.isYoVault(mockVaults[i]), "All vaults should be registered");
        }

        vm.stopPrank();
    }

    function test_multipleUsers_Interaction() public {
        // Admin adds vaults
        vm.startPrank({ msgSender: users.admin });
        registry.addYoVault(mockVaults[0]);
        registry.addYoVault(mockVaults[1]);
        vm.stopPrank();

        // Bob can view but not modify
        vm.startPrank({ msgSender: users.bob });
        assertTrue(registry.isYoVault(mockVaults[0]), "Bob can check if vault is registered");
        assertTrue(registry.isYoVault(mockVaults[1]), "Bob can check if vault is registered");

        address[] memory vaults = registry.listYoVaults();
        assertEq(vaults.length, 2, "Bob can list vaults");

        // Bob cannot add or remove vaults
        vm.expectRevert();
        registry.addYoVault(mockVaults[2]);

        vm.expectRevert();
        registry.removeYoVault(mockVaults[0]);
        vm.stopPrank();

        // Alice can view but not modify
        vm.startPrank({ msgSender: users.alice });
        assertTrue(registry.isYoVault(mockVaults[0]), "Alice can check if vault is registered");
        assertTrue(registry.isYoVault(mockVaults[1]), "Alice can check if vault is registered");

        vaults = registry.listYoVaults();
        assertEq(vaults.length, 2, "Alice can list vaults");

        // Alice cannot add or remove vaults
        vm.expectRevert();
        registry.addYoVault(mockVaults[2]);

        vm.expectRevert();
        registry.removeYoVault(mockVaults[0]);
        vm.stopPrank();

        // Admin can still modify
        vm.startPrank({ msgSender: users.admin });
        registry.addYoVault(mockVaults[2]);
        registry.removeYoVault(mockVaults[0]);

        assertTrue(registry.isYoVault(mockVaults[1]), "Vault1 should still be registered");
        assertTrue(registry.isYoVault(mockVaults[2]), "Vault2 should be registered");
        assertFalse(registry.isYoVault(mockVaults[0]), "Vault0 should be removed");
        vm.stopPrank();
    }

    function test_edgeCases_ZeroAddressHandling() public {
        vm.startPrank({ msgSender: users.admin });

        // Try to add zero address
        vm.expectRevert();
        registry.addYoVault(address(0));

        // Try to remove zero address
        vm.expectRevert();
        registry.removeYoVault(address(0));

        // Check if zero address is registered (should return false)
        assertFalse(registry.isYoVault(address(0)), "Zero address should not be registered");

        vm.stopPrank();
    }

    function test_edgeCases_DuplicateOperations() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault
        registry.addYoVault(mockVaults[0]);

        // Try to add same vault again
        vm.expectRevert();
        registry.addYoVault(mockVaults[0]);

        // Remove vault
        registry.removeYoVault(mockVaults[0]);

        // Try to remove same vault again
        vm.expectRevert();
        registry.removeYoVault(mockVaults[0]);

        // Add vault again (should work)
        registry.addYoVault(mockVaults[0]);
        assertTrue(registry.isYoVault(mockVaults[0]), "Vault should be registered again");

        vm.stopPrank();
    }

    function test_edgeCases_LargeNumberOfVaults() public {
        vm.startPrank({ msgSender: users.admin });

        // Create many vaults
        address[] memory manyVaults = new address[](20);
        address[] memory manyAssets = new address[](20);

        for (uint256 i = 0; i < 20; i++) {
            address mockAsset = makeAddr(string.concat("ManyAsset", vm.toString(i)));
            address mockVault = createMockVault(mockAsset);
            manyAssets[i] = mockAsset;
            manyVaults[i] = mockVault;
        }

        // Add all vaults
        for (uint256 i = 0; i < manyVaults.length; i++) {
            registry.addYoVault(manyVaults[i]);
            assertTrue(registry.isYoVault(manyVaults[i]), "Vault should be registered");
        }

        // Verify all are in list
        address[] memory vaults = registry.listYoVaults();
        assertEq(vaults.length, 20, "Should have 20 vaults");

        // Remove some vaults
        registry.removeYoVault(manyVaults[5]);
        registry.removeYoVault(manyVaults[10]);
        registry.removeYoVault(manyVaults[15]);

        // Verify remaining vaults
        vaults = registry.listYoVaults();
        assertEq(vaults.length, 17, "Should have 17 vaults after removal");

        assertFalse(registry.isYoVault(manyVaults[5]), "Vault5 should be removed");
        assertFalse(registry.isYoVault(manyVaults[10]), "Vault10 should be removed");
        assertFalse(registry.isYoVault(manyVaults[15]), "Vault15 should be removed");

        vm.stopPrank();
    }

    function test_edgeCases_ConsistencyChecks() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vaults
        registry.addYoVault(mockVaults[0]);
        registry.addYoVault(mockVaults[1]);
        registry.addYoVault(mockVaults[2]);

        // Check consistency between isYoVault and listYoVaults
        address[] memory vaults = registry.listYoVaults();

        // Every vault in the list should return true for isYoVault
        for (uint256 i = 0; i < vaults.length; i++) {
            assertTrue(registry.isYoVault(vaults[i]), "Every vault in list should be registered");
        }

        // Every registered vault should be in the list
        assertTrue(registry.isYoVault(mockVaults[0]), "Vault0 should be registered");
        assertTrue(registry.isYoVault(mockVaults[1]), "Vault1 should be registered");
        assertTrue(registry.isYoVault(mockVaults[2]), "Vault2 should be registered");

        // Check that unregistered vaults are not in the list
        assertFalse(registry.isYoVault(mockVaults[3]), "Vault3 should not be registered");
        assertFalse(registry.isYoVault(mockVaults[4]), "Vault4 should not be registered");

        vm.stopPrank();
    }
}
