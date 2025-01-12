// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../../Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract Withdraw_Unit_Concrete_Test is Base_Test {
    using Math for uint256;

    uint256 internal amount = 100 * 1e6;

    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.alice });
    }

    function test_withdraw_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UseRequestRedeem.selector));
        depositVault.withdraw(amount, users.alice, users.alice);
    }
}
