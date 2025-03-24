// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "./Base.t.sol";

contract Unpause_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();

        vm.startPrank({ msgSender: users.admin });
        depositVault.pause();
        assertTrue(depositVault.paused(), "Vault was not paused.");
    }

    function test_Unpause_Success() public {
        depositVault.unpause();
        assertFalse(depositVault.paused(), "Vault was not unpaused.");
    }

    function test_Unpause_Revert_NotAuthorized() public {
        vm.stopPrank();
        vm.expectRevert("UNAUTHORIZED");
        depositVault.unpause();
    }
}
