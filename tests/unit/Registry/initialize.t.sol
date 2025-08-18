// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { Registry_Base_Test } from "./Base.t.sol";
import { YoRegistry } from "src/YoRegistry.sol";
import { MockAuthority } from "../../mocks/MockAuthority.sol";
import { Authority } from "src/base/AuthUpgradeable.sol";

contract Initialize_Test is Registry_Base_Test {
    YoRegistry internal registryImpl;

    function setUp() public override {
        super.setUp();
        registryImpl = new YoRegistry();
    }

    // ========================================= SUCCESS TESTS =========================================

    function test_initialize_Success() public {
        address owner = makeAddr("Owner");
        Authority authority = new MockAuthority(owner, Authority(address(0)));

        YoRegistry newRegistry = new YoRegistry();

        bytes memory data = abi.encodeWithSelector(YoRegistry.initialize.selector, owner, authority);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(newRegistry), owner, data);

        YoRegistry registryInstance = YoRegistry(payable(address(proxy)));

        // Check that the registry is properly initialized
        assertEq(registryInstance.owner(), owner, "Owner should be set correctly");
        assertEq(address(registryInstance.authority()), address(authority), "Authority should be set correctly");
    }

    function test_initialize_CanOnlyBeCalledOnce() public {
        address owner = makeAddr("Owner");
        Authority authority = new MockAuthority(owner, Authority(address(0)));

        YoRegistry newRegistry = new YoRegistry();

        bytes memory data = abi.encodeWithSelector(YoRegistry.initialize.selector, owner, authority);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(newRegistry), owner, data);

        YoRegistry registryInstance = YoRegistry(payable(address(proxy)));

        // Try to initialize again
        vm.expectRevert();
        registryInstance.initialize(owner, authority);
    }

    // ========================================= AUTHORIZATION TESTS =========================================

    function test_addYoVault_RequiresAuth() public {
        address mockAsset = makeAddr("MockAsset");
        address mockVault = createMockVault(mockAsset);

        // Try to add vault without authorization
        vm.startPrank({ msgSender: users.bob });
        vm.expectRevert();
        registry.addYoVault(mockVault);
        vm.stopPrank();

        // Add vault with authorization
        vm.startPrank({ msgSender: users.admin });
        registry.addYoVault(mockVault);
        assertTrue(registry.isYoVault(mockVault), "Vault should be registered");
        vm.stopPrank();
    }

    function test_removeYoVault_RequiresAuth() public {
        address mockAsset = makeAddr("MockAsset");
        address mockVault = createMockVault(mockAsset);

        // Add vault first
        vm.startPrank({ msgSender: users.admin });
        registry.addYoVault(mockVault);
        vm.stopPrank();

        // Try to remove vault without authorization
        vm.startPrank({ msgSender: users.bob });
        vm.expectRevert();
        registry.removeYoVault(mockVault);
        vm.stopPrank();

        // Remove vault with authorization
        vm.startPrank({ msgSender: users.admin });
        registry.removeYoVault(mockVault);
        assertFalse(registry.isYoVault(mockVault), "Vault should not be registered");
        vm.stopPrank();
    }

    function test_viewFunctions_NoAuthRequired() public {
        address mockAsset = makeAddr("MockAsset");
        address mockVault = createMockVault(mockAsset);

        // Add vault first
        vm.startPrank({ msgSender: users.admin });
        registry.addYoVault(mockVault);
        vm.stopPrank();

        // Test that view functions don't require auth
        vm.startPrank({ msgSender: users.bob });

        // isYoVault should work
        assertTrue(registry.isYoVault(mockVault), "isYoVault should work without auth");

        // listYoVaults should work
        address[] memory vaults = registry.listYoVaults();
        assertEq(vaults.length, 1, "listYoVaults should work without auth");
        assertEq(vaults[0], mockVault, "Vault should be in list");

        vm.stopPrank();
    }

    // ========================================= EDGE CASES =========================================

    function test_constructor_DisablesInitializers() public {
        // The constructor should disable initializers
        YoRegistry newRegistry = new YoRegistry();

        // Try to initialize directly (should fail)
        vm.expectRevert();
        newRegistry.initialize(users.admin, authority);
    }

    function test_multipleUsers_Authorization() public {
        address mockAsset = makeAddr("MockAsset");
        address mockVault = createMockVault(mockAsset);

        // Only admin should be able to add vaults
        vm.startPrank({ msgSender: users.bob });
        vm.expectRevert();
        registry.addYoVault(mockVault);
        vm.stopPrank();

        vm.startPrank({ msgSender: users.alice });
        vm.expectRevert();
        registry.addYoVault(mockVault);
        vm.stopPrank();

        // Admin should be able to add vaults
        vm.startPrank({ msgSender: users.admin });
        registry.addYoVault(mockVault);
        assertTrue(registry.isYoVault(mockVault), "Admin should be able to add vaults");
        vm.stopPrank();
    }
}
