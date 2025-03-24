// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "./Base.t.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract Deposit_Unit_Concrete_Test is Base_Test {
    using Math for uint256;

    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.alice });
    }

    function test_deposit_success() public {
        uint256 amount = 100 * 1e6;
        uint256 aliceBalanceBefore = depositVault.balanceOf(users.alice);
        assertTrue(aliceBalanceBefore == 0, "Alice balance before is not 0");

        vm.expectCall(address(usdc), abi.encodeCall(usdc.transferFrom, (users.alice, address(depositVault), amount)));
        depositVault.deposit(amount, users.alice);

        uint256 aliceBalanceAfter = depositVault.balanceOf(users.alice);
        assertTrue(aliceBalanceAfter == amount, "Alice balance after is not the amount");
    }
}
