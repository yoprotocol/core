// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "./Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract RequestRedeem_Unit_Concrete_Test is Base_Test {
    using Math for uint256;

    uint256 internal amount = 100 * 1e6;

    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.alice });
        depositVault.deposit(amount, users.alice);
    }

    function test_requestRedeem_instant_success() public {
        uint256 aliceShares = depositVault.balanceOf(users.alice);
        uint256 aliceBalanceBefore = depositVault.balanceOf(users.alice);
        uint256 totalAssetsBefore = depositVault.totalAssets();
        assertTrue(aliceBalanceBefore == amount, "Alice balance before is not the amount");
        assertTrue(totalAssetsBefore == amount, "Total assets before is not the amount");

        depositVault.requestRedeem(aliceShares, users.alice, users.alice);

        uint256 aliceSharesAfter = depositVault.balanceOf(users.alice);
        uint256 aliceBalanceAfter = depositVault.balanceOf(users.alice);
        uint256 totalAssetsAfter = depositVault.totalAssets();
        assertTrue(aliceSharesAfter == 0, "Alice shares after is not 0");
        assertTrue(aliceBalanceAfter == 0, "Alice balance after is not 0");
        assertTrue(totalAssetsAfter == 0, "Total assets after is not 0");
    }

    function test_requestRedeem_reverts_SharesAmountZero() public {
        uint256 aliceShares = depositVault.balanceOf(users.alice);
        assertTrue(aliceShares == amount, "Alice shares is not the amount");

        vm.expectRevert(abi.encodeWithSelector(Errors.SharesAmountZero.selector));
        depositVault.requestRedeem(0, users.alice, users.alice);
    }

    function test_requestRedeem_reverts_NotSharesOwner() public {
        uint256 aliceShares = depositVault.balanceOf(users.alice);
        assertTrue(aliceShares == amount, "Alice shares is not the amount");

        vm.expectRevert(abi.encodeWithSelector(Errors.NotSharesOwner.selector));
        depositVault.requestRedeem(aliceShares, users.alice, users.bob);
    }

    function test_requestRedeem_reverts_InsufficientShares() public {
        uint256 aliceShares = depositVault.balanceOf(users.alice);
        assertTrue(aliceShares == amount, "Alice shares is not the amount");

        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientShares.selector));
        depositVault.requestRedeem(aliceShares + 1, users.alice, users.alice);
    }
}
