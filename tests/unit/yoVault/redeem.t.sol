// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "./Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";

contract Redeem_Unit_Concrete_Test is Base_Test {
    uint256 internal amount = 100 * 1e6;

    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.alice });
        depositVault.deposit(amount, users.alice);
    }

    function test_redeem_instant_success() public {
        uint256 aliceShares = depositVault.balanceOf(users.alice);
        assertEq(aliceShares, amount);
        assertEq(depositVault.totalAssets(), amount);

        depositVault.redeem(aliceShares, users.alice, users.alice);

        assertEq(depositVault.balanceOf(users.alice), 0);
        assertEq(depositVault.totalAssets(), 0);
    }

    function test_redeem_reverts_SharesAmountZero() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.SharesAmountZero.selector));
        depositVault.redeem(0, users.alice, users.alice);
    }

    function test_redeem_reverts_NotSharesOwner() public {
        uint256 aliceShares = depositVault.balanceOf(users.alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.NotSharesOwner.selector));
        depositVault.redeem(aliceShares, users.alice, users.bob);
    }

    function test_redeem_reverts_InsufficientShares() public {
        uint256 aliceShares = depositVault.balanceOf(users.alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientShares.selector));
        depositVault.redeem(aliceShares + 1, users.alice, users.alice);
    }
}
