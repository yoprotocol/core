// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../Base.t.sol";

import { Errors } from "src/libraries/Errors.sol";

contract UpdateFee_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.admin });
    }

    function test_UpdateFee_Success() public {
        depositVault.updateFee(1e16);
        assertEq(depositVault.fee(), 1e16, "Fee was not updated.");
    }

    function test_UpdateFee_Revert_Max_Threshold() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidFee.selector));
        depositVault.updateFee(MAX_FEE);
    }

    function test_UpdateFee_NotAuthorized() public {
        vm.stopPrank();
        vm.expectRevert("UNAUTHORIZED");
        depositVault.updateFee(MAX_FEE);
    }
}
