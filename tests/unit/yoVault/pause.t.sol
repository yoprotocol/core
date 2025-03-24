// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "./Base.t.sol";

contract Pause_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_Pause_Success() public {
        vm.startPrank({ msgSender: users.admin });
        depositVault.pause();
        assertTrue(depositVault.paused(), "Vault was not paused.");
    }

    function test_Pause_Revert_NotAuthorized() public {
        vm.stopPrank();
        vm.expectRevert("UNAUTHORIZED");
        depositVault.pause();
    }
}
