// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Registry_Base_Test } from "./Base.t.sol";

contract ListYoVaults_Test is Registry_Base_Test {
    address internal mockAsset1;
    address internal mockVault1;
    address internal mockAsset2;
    address internal mockVault2;
    address internal mockAsset3;
    address internal mockVault3;

    function setUp() public override {
        super.setUp();

        // Create mock assets and vaults
        mockAsset1 = makeAddr("MockAsset1");
        mockVault1 = createMockVault(mockAsset1);
        mockAsset2 = makeAddr("MockAsset2");
        mockVault2 = createMockVault(mockAsset2);
        mockAsset3 = makeAddr("MockAsset3");
        mockVault3 = createMockVault(mockAsset3);
    }

    // ========================================= SUCCESS TESTS =========================================

    function test_listYoVaults_EmptyRegistry() public view {
        // Check empty registry
        address[] memory vaults = registry.listYoVaults();
        assertEq(vaults.length, 0, "Empty registry should return empty array");
    }

    function test_listYoVaults_SingleVault() public {
        vm.startPrank({ msgSender: users.admin });

        // Add single vault
        registry.addYoVault(mockVault1);

        // Check list
        address[] memory vaults = registry.listYoVaults();
        assertEq(vaults.length, 1, "Should have 1 vault");
        assertEq(vaults[0], mockVault1, "Vault should be in list");

        vm.stopPrank();
    }

    function test_listYoVaults_MultipleVaults() public {
        vm.startPrank({ msgSender: users.admin });

        // Add multiple vaults
        registry.addYoVault(mockVault1);
        registry.addYoVault(mockVault2);
        registry.addYoVault(mockVault3);

        // Check list
        address[] memory vaults = registry.listYoVaults();
        assertEq(vaults.length, 3, "Should have 3 vaults");

        // Check all vaults are in the list (order may vary due to EnumerableSet)
        bool found1 = false;
        bool found2 = false;
        bool found3 = false;

        for (uint256 i = 0; i < vaults.length; i++) {
            if (vaults[i] == mockVault1) found1 = true;
            if (vaults[i] == mockVault2) found2 = true;
            if (vaults[i] == mockVault3) found3 = true;
        }

        assertTrue(found1, "Vault1 should be in list");
        assertTrue(found2, "Vault2 should be in list");
        assertTrue(found3, "Vault3 should be in list");

        vm.stopPrank();
    }

    function test_listYoVaults_AfterRemoval() public {
        vm.startPrank({ msgSender: users.admin });

        // Add multiple vaults
        registry.addYoVault(mockVault1);
        registry.addYoVault(mockVault2);
        registry.addYoVault(mockVault3);

        // Remove one vault
        registry.removeYoVault(mockVault2);

        // Check list
        address[] memory vaults = registry.listYoVaults();
        assertEq(vaults.length, 2, "Should have 2 vaults after removal");

        // Check remaining vaults
        bool found1 = false;
        bool found3 = false;
        bool found2 = false;

        for (uint256 i = 0; i < vaults.length; i++) {
            if (vaults[i] == mockVault1) found1 = true;
            if (vaults[i] == mockVault3) found3 = true;
            if (vaults[i] == mockVault2) found2 = true;
        }

        assertTrue(found1, "Vault1 should still be in list");
        assertTrue(found3, "Vault3 should still be in list");
        assertFalse(found2, "Vault2 should not be in list");

        vm.stopPrank();
    }

    function test_listYoVaults_RemoveAll() public {
        vm.startPrank({ msgSender: users.admin });

        // Add multiple vaults
        registry.addYoVault(mockVault1);
        registry.addYoVault(mockVault2);

        // Remove all vaults
        registry.removeYoVault(mockVault1);
        registry.removeYoVault(mockVault2);

        // Check empty list
        address[] memory vaults = registry.listYoVaults();
        assertEq(vaults.length, 0, "Should have 0 vaults after removing all");

        vm.stopPrank();
    }

    // ========================================= EDGE CASES =========================================

    function test_listYoVaults_AddRemoveAdd() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault
        registry.addYoVault(mockVault1);
        address[] memory vaults = registry.listYoVaults();
        assertEq(vaults.length, 1, "Should have 1 vault");

        // Remove vault
        registry.removeYoVault(mockVault1);
        vaults = registry.listYoVaults();
        assertEq(vaults.length, 0, "Should have 0 vaults after removal");

        // Add vault again
        registry.addYoVault(mockVault1);
        vaults = registry.listYoVaults();
        assertEq(vaults.length, 1, "Should have 1 vault after re-adding");
        assertEq(vaults[0], mockVault1, "Vault should be in list");

        vm.stopPrank();
    }

    function test_listYoVaults_AnyUserCanCall() public {
        vm.startPrank({ msgSender: users.admin });
        registry.addYoVault(mockVault1);
        registry.addYoVault(mockVault2);
        vm.stopPrank();

        // Bob should be able to call listYoVaults
        vm.startPrank({ msgSender: users.bob });
        address[] memory vaults = registry.listYoVaults();
        assertEq(vaults.length, 2, "Bob should be able to list vaults");
        vm.stopPrank();

        // Alice should be able to call listYoVaults
        vm.startPrank({ msgSender: users.alice });
        vaults = registry.listYoVaults();
        assertEq(vaults.length, 2, "Alice should be able to list vaults");
        vm.stopPrank();
    }

    function test_listYoVaults_ConsistencyWithIsYoVault() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vaults
        registry.addYoVault(mockVault1);
        registry.addYoVault(mockVault2);

        // Check consistency
        address[] memory vaults = registry.listYoVaults();
        assertEq(vaults.length, 2, "Should have 2 vaults");

        // Verify each vault in the list is registered
        for (uint256 i = 0; i < vaults.length; i++) {
            assertTrue(registry.isYoVault(vaults[i]), "Each vault in list should be registered");
        }

        // Verify registered vaults are in the list
        assertTrue(registry.isYoVault(mockVault1), "Vault1 should be registered");
        assertTrue(registry.isYoVault(mockVault2), "Vault2 should be registered");

        vm.stopPrank();
    }
}
