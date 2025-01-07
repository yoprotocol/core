// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";

contract SetOperator_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_setOperator_success() public {
        depositVault.setOperator(users.bob, true);
        assertEq(depositVault.isOperator(users.alice, users.bob), true, "Bob should be an operator");

        depositVault.setOperator(users.bob, false);
        assertEq(depositVault.isOperator(users.alice, users.bob), false, "Bob should not be an operator");
    }

    function test_setOperator_fail() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CannotSetSelfAsOperator.selector));
        depositVault.setOperator(users.alice, true);
    }
}
