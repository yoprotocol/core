// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Registry_Base_Test } from "./Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";
import { IYoRegistry } from "src/interfaces/IYoRegistry.sol";

contract AddYoVault_Test is Registry_Base_Test {
    address internal mockAsset;
    address internal mockVault;

    function setUp() public override {
        super.setUp();

        // Create a mock asset (USDC)
        mockAsset = makeAddr("MockAsset");
        mockVault = createMockVault(mockAsset);
    }

    // ========================================= SUCCESS TESTS =========================================

    function test_addYoVault_Success() public {
        vm.startPrank({ msgSender: users.admin });

        vm.expectEmit({ emitter: address(registry) });
        emit IYoRegistry.YoVaultAdded(mockAsset, mockVault);

        registry.addYoVault(mockVault);

        assertTrue(registry.isYoVault(mockVault), "Vault should be registered");
        vm.stopPrank();
    }

    function test_addYoVault_MultipleVaults() public {
        vm.startPrank({ msgSender: users.admin });

        address mockAsset2 = makeAddr("MockAsset2");
        address mockVault2 = createMockVault(mockAsset2);

        // Add first vault
        registry.addYoVault(mockVault);
        assertTrue(registry.isYoVault(mockVault), "First vault should be registered");

        // Add second vault
        registry.addYoVault(mockVault2);
        assertTrue(registry.isYoVault(mockVault2), "Second vault should be registered");

        // Check both are in the list
        address[] memory vaults = registry.listYoVaults();
        assertEq(vaults.length, 2, "Should have 2 vaults");
        assertEq(vaults[0], mockVault, "First vault should be in list");
        assertEq(vaults[1], mockVault2, "Second vault should be in list");

        vm.stopPrank();
    }

    // ========================================= FAILURE TESTS =========================================

    function test_addYoVault_ZeroAddress() public {
        vm.startPrank({ msgSender: users.admin });

        vm.expectRevert(Errors.Registry__VaultAddressZero.selector);
        registry.addYoVault(address(0));

        vm.stopPrank();
    }

    function test_addYoVault_VaultAlreadyExists() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault first time
        registry.addYoVault(mockVault);
        assertTrue(registry.isYoVault(mockVault), "Vault should be registered");

        // Try to add the same vault again
        vm.expectRevert(abi.encodeWithSelector(Errors.Registry__VaultAlreadyExists.selector, mockVault));
        registry.addYoVault(mockVault);

        vm.stopPrank();
    }

    function test_addYoVault_Unauthorized() public {
        vm.startPrank({ msgSender: users.bob });

        vm.expectRevert();
        registry.addYoVault(mockVault);

        vm.stopPrank();
    }

    // ========================================= EDGE CASES =========================================

    function test_addYoVault_AfterRemoval() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault
        registry.addYoVault(mockVault);
        assertTrue(registry.isYoVault(mockVault), "Vault should be registered");

        // Remove vault
        registry.removeYoVault(mockVault);
        assertFalse(registry.isYoVault(mockVault), "Vault should not be registered");

        // Add vault again
        vm.expectEmit({ emitter: address(registry) });
        emit IYoRegistry.YoVaultAdded(mockAsset, mockVault);
        registry.addYoVault(mockVault);
        assertTrue(registry.isYoVault(mockVault), "Vault should be registered again");

        vm.stopPrank();
    }

    function test_addYoVault_EventEmission() public {
        vm.startPrank({ msgSender: users.admin });

        vm.expectEmit({ emitter: address(registry) });
        emit IYoRegistry.YoVaultAdded(mockAsset, mockVault);

        registry.addYoVault(mockVault);

        vm.stopPrank();
    }
}
