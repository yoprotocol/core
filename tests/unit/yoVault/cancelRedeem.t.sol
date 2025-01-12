// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../../Base.t.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Errors } from "src/libraries/Errors.sol";

contract Deposit_Unit_Concrete_Test is Base_Test {
    using Math for uint256;

    uint256 internal amount = 100 * 1e6;
    uint256 internal aliceShares;

    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.alice });

        depositVault.deposit(amount, users.alice);

        moveAssetsFromVault(amount);
        updateUnderlyingBalance(amount);

        vm.startPrank({ msgSender: users.alice });
        aliceShares = depositVault.balanceOf(users.alice);
        depositVault.requestRedeem(aliceShares, users.alice, users.alice);

        vm.roll(block.number + 1);
        usdc.transfer(address(depositVault), amount);
        updateUnderlyingBalance(0);
    }

    function test_cancel_redeem() public {
        uint256 totalPendingAssets = depositVault.totalPendingAssets();
        (uint256 pendingAssets, uint256 pendingShares) = depositVault.pendingRedeemRequest(users.alice);
        uint256 aliceSharesBefore = depositVault.balanceOf(users.alice);

        vm.startPrank({ msgSender: users.admin });
        depositVault.cancelRedeem(users.alice, pendingShares, pendingAssets);

        uint256 totalPendingAssetsAfter = depositVault.totalPendingAssets();
        (uint256 pendingAssetsAfter, uint256 pendingSharesAfter) = depositVault.pendingRedeemRequest(users.alice);
        uint256 aliceSharesAfter = depositVault.balanceOf(users.alice);

        assertTrue(
            totalPendingAssetsAfter == totalPendingAssets - pendingShares,
            "Total pending assets after is not the difference"
        );
        assertTrue(pendingAssetsAfter == 0, "Pending assets after is not 0");
        assertTrue(pendingSharesAfter == 0, "Pending shares after is not 0");
        assertEq(aliceSharesAfter, aliceSharesBefore + pendingShares, "Alice did not receive the pending shares back");
    }

    function test_cancel_redeem_invalid_amounts() public {
        (uint256 pendingAssets, uint256 pendingShares) = depositVault.pendingRedeemRequest(users.alice);

        vm.startPrank({ msgSender: users.admin });

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidSharesAmount.selector));
        depositVault.cancelRedeem(users.alice, pendingShares + 1, pendingAssets);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAssetsAmount.selector));
        depositVault.cancelRedeem(users.alice, pendingShares, pendingAssets + 1);
    }

    function test_cancel_double_cancel() public {
        (uint256 pendingAssets, uint256 pendingShares) = depositVault.pendingRedeemRequest(users.alice);

        vm.startPrank({ msgSender: users.admin });
        depositVault.cancelRedeem(users.alice, pendingShares, pendingAssets);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidSharesAmount.selector));
        depositVault.cancelRedeem(users.alice, pendingShares, pendingAssets);
    }
}
