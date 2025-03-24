// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "./Base.t.sol";

import { Errors } from "src/libraries/Errors.sol";

contract UpdateFee_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.admin });
    }

    function test_UpdateDepositFee_Success() public {
        depositVault.updateDepositFee(1e16);
        assertEq(depositVault.feeOnDeposit(), 1e16, "Fee was not updated.");
    }

    function test_UpdateDepositFee_Revert_Max_Threshold() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidFee.selector));
        depositVault.updateDepositFee(MAX_FEE);
    }

    function test_UpdateDepositFee_NotAuthorized() public {
        vm.stopPrank();
        vm.expectRevert("UNAUTHORIZED");
        depositVault.updateDepositFee(MAX_FEE);
    }

    function test_UpdateWithdrawFee_Success() public {
        depositVault.updateWithdrawFee(1e16);
        assertEq(depositVault.feeOnWithdraw(), 1e16, "Fee was not updated.");
    }

    function test_UpdateWithdrawFee_Revert_Max_Threshold() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidFee.selector));
        depositVault.updateWithdrawFee(MAX_FEE);
    }

    function test_UpdateWithdrawFee_NotAuthorized() public {
        vm.stopPrank();
        vm.expectRevert("UNAUTHORIZED");
        depositVault.updateWithdrawFee(MAX_FEE);
    }
}
