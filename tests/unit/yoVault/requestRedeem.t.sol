// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "./Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";

contract RequestRedeem_Unit_Concrete_Test is Base_Test {
    uint256 internal amount = 100 * 1e6;

    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.alice });
        depositVault.deposit(amount, users.alice);
    }

    function test_requestRedeem_instant_success() public {
        uint256 aliceShares = depositVault.balanceOf(users.alice);
        uint256 totalAssetsBefore = depositVault.totalAssets();
        assertEq(aliceShares, amount);
        assertEq(totalAssetsBefore, amount);

        depositVault.requestRedeem(aliceShares, users.alice, users.alice);

        assertEq(depositVault.balanceOf(users.alice), 0);
        assertEq(depositVault.totalAssets(), 0);
    }

    function test_requestRedeem_reverts_ZeroReceiver() public {
        uint256 aliceShares = depositVault.balanceOf(users.alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroReceiver.selector));
        depositVault.requestRedeem(aliceShares, address(0), users.alice);
    }

    function test_requestRedeem_reverts_SharesAmountZero() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.SharesAmountZero.selector));
        depositVault.requestRedeem(0, users.alice, users.alice);
    }

    function test_requestRedeem_reverts_NotSharesOwner() public {
        uint256 aliceShares = depositVault.balanceOf(users.alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.NotSharesOwner.selector));
        depositVault.requestRedeem(aliceShares, users.alice, users.bob);
    }

    function test_requestRedeem_reverts_InsufficientShares() public {
        uint256 aliceShares = depositVault.balanceOf(users.alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientShares.selector));
        depositVault.requestRedeem(aliceShares + 1, users.alice, users.alice);
    }
}
