// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../../Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";

contract Fulfill_Unit_Concrete_Test is Base_Test {
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

    function test_fulfill_success() public {
        vm.startPrank({ msgSender: users.admin });
        uint256 totalPendingAssets = depositVault.totalPendingAssets();
        (uint256 pendingAssets, uint256 pendingShares) = depositVault.pendingRedeemRequest(users.alice);

        depositVault.fulfillRedeem(users.alice, pendingShares, pendingAssets);

        (uint256 pendingAssetsAfter, uint256 pendingSharesAfter) = depositVault.pendingRedeemRequest(users.alice);
        uint256 totalPendingAssetsAfter = depositVault.totalPendingAssets();

        assertEq(totalPendingAssetsAfter, totalPendingAssets - pendingAssets);
        assertEq(pendingAssetsAfter, 0);
        assertEq(pendingSharesAfter, 0);
    }

    function test_fulfill_revert_zero_shares() public {
        vm.startPrank({ msgSender: users.admin });
        (uint256 pendingAssets, uint256 pendingShares) = depositVault.pendingRedeemRequest(users.alice);
        depositVault.fulfillRedeem(users.alice, pendingShares, pendingAssets);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidSharesAmount.selector));
        depositVault.fulfillRedeem(users.alice, pendingShares, pendingAssets);
    }

    function test_fulfill_revert_invalid_amounts() public {
        vm.startPrank({ msgSender: users.admin });
        (uint256 pendingAssets, uint256 pendingShares) = depositVault.pendingRedeemRequest(users.alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidSharesAmount.selector));
        depositVault.fulfillRedeem(users.alice, pendingShares + 1, pendingAssets);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAssetsAmount.selector));
        depositVault.fulfillRedeem(users.alice, pendingShares, pendingAssets + 1);
    }

    function test_fulfill_revert_insufficient_assets() public {
        moveAssetsFromVault(amount);
        vm.roll(block.number + 1);
        updateUnderlyingBalance(amount);
        vm.startPrank({ msgSender: users.admin });
        (uint256 pendingAssets, uint256 pendingShares) = depositVault.pendingRedeemRequest(users.alice);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        depositVault.fulfillRedeem(users.alice, pendingShares, pendingAssets);
    }
}
