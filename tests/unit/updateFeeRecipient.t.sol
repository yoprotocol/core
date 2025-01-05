// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../Base.t.sol";

contract UpdateFeeRecipient_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.admin });
    }

    function test_UpdateFeeRecipient_Success() public {
        depositVault.updateFeeRecipient(users.admin);
        assertEq(depositVault.feeRecipient(), users.admin, "Fee recipient was not updated.");
    }

    function test_UpdateFeeRecipient_NotAuthorized() public {
        vm.stopPrank();
        vm.expectRevert("UNAUTHORIZED");
        depositVault.updateFeeRecipient(users.admin);
    }
}
