// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../../Base.t.sol";
import { MockAuthority } from "../../mocks/MockAuthority.sol";

/// @notice Base test contract with common logic needed by all tests.

contract IsAuthorized_Unit_Concrete_Test is Base_Test {
    // ====================================== TEST CONTRACTS =======================================

    // ====================================== SET-UP FUNCTION ======================================
    function setUp() public override {
        super.setUp();
    }

    function test_setAuthority() public {
        vm.startPrank({ msgSender: users.admin });

        MockAuthority(address(authority)).setUserRole(users.bob, 2, true);
        MockAuthority(address(depositVault.authority())).setRoleCapability(
            2, address(depositVault), depositVault.setAuthority.selector, true
        );

        MockAuthority newAuthority = new MockAuthority(users.bob, authority);
        vm.startPrank({ msgSender: users.bob });
        depositVault.setAuthority(newAuthority);
        assertEq(address(depositVault.authority()), address(newAuthority));
    }

    function test_setAuthority_reverts() public {
        MockAuthority newAuthority = new MockAuthority(users.bob, authority);
        vm.startPrank({ msgSender: users.bob });
        vm.expectRevert();
        depositVault.setAuthority(newAuthority);
        assertFalse(address(depositVault.authority()) == address(newAuthority));
    }
}
