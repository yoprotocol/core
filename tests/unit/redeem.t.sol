// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract Redeem_Unit_Concrete_Test is Base_Test {
    using Math for uint256;

    uint256 internal fee = 1e16; // 1%
    uint256 internal amount = 100 * 1e6;
    uint256 internal aliceShares;

    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.alice });
        depositVault.deposit(amount, users.alice);

        moveAssetsAndUpdateUnderlyingBalances(amount);
        aliceShares = depositVault.balanceOf(users.alice);
        depositVault.requestRedeem(aliceShares, users.alice, users.alice);

        vm.startPrank({ msgSender: users.admin });
        depositVault.fulfillRedeem(users.alice, aliceShares);
        vm.startPrank({ msgSender: users.alice });
        // transfer funds back to the vault
        usdc.transfer(address(depositVault), amount);
    }

    function test_redeem_success() public {
        uint256 vaultAssets = usdc.balanceOf(address(depositVault));
        assertEq(vaultAssets, amount);

        uint256 aliceAssets = usdc.balanceOf(users.alice);
        uint256 totalClaimableAssets = depositVault.totalClaimableAssets();

        depositVault.redeem(aliceShares, users.alice, users.alice);

        uint256 totalClaimableAssetsAfter = depositVault.totalClaimableAssets();
        assertEq(totalClaimableAssetsAfter, totalClaimableAssets - amount);
        uint256 aliceSharesAfter = depositVault.balanceOf(users.alice);
        assertEq(aliceSharesAfter, 0);

        uint256 vaultAssetsAfter = usdc.balanceOf(address(depositVault));
        assertEq(vaultAssetsAfter, 0);

        uint256 aliceAssetsAfter = usdc.balanceOf(users.alice);
        assertEq(aliceAssetsAfter, aliceAssets + amount);
    }

    function test_redeem_success_with_fees() public {
        enableFees();

        uint256 vaultAssets = usdc.balanceOf(address(depositVault));
        assertEq(vaultAssets, amount);

        uint256 aliceAssets = usdc.balanceOf(users.alice);
        uint256 bobAssets = usdc.balanceOf(users.bob);

        depositVault.redeem(aliceShares, users.alice, users.alice);

        uint256 feeAmount = amount.mulDiv(fee, DENOMINATOR, Math.Rounding.Floor);

        uint256 aliceAssetsAfter = usdc.balanceOf(users.alice);
        assertEq(aliceAssetsAfter, aliceAssets + (amount - feeAmount));

        uint256 bobAssetsAfter = usdc.balanceOf(users.bob);
        assertEq(bobAssetsAfter, bobAssets + feeAmount);
    }

    function test_redeem_revert_zero_assets() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.SharesAmountZero.selector));
        depositVault.redeem(0, users.alice, users.alice);
    }

    function test_redeem_revert_not_shares_owner() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NotSharesOwner.selector));
        depositVault.redeem(aliceShares, users.alice, users.bob);
    }

    function test_redeem_revert_insufficient_claimable() public {
        depositVault.redeem(aliceShares - 2, users.alice, users.alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientShares.selector));
        depositVault.redeem(aliceShares + 3, users.alice, users.alice);
    }

    function test_redeem_as_operator() public {
        bytes32 nonce = keccak256(abi.encodePacked("test-nonce"));
        uint256 deadline = block.timestamp + 1 hours;

        uint256 aliceAssets = usdc.balanceOf(users.alice);
        uint256 bobAssets = usdc.balanceOf(users.bob);

        // withdraw as operator

        vm.startPrank({ msgSender: users.bob });
        vm.expectRevert(abi.encodeWithSelector(Errors.NotSharesOwner.selector));
        depositVault.redeem(aliceShares, users.alice, users.alice);

        authorizeOperator(users.aliceKey, users.alice, users.bob, true, nonce, deadline, 0);
        depositVault.redeem(aliceShares, users.alice, users.alice);

        uint256 aliceAssetsAfter = usdc.balanceOf(users.alice);
        assertEq(aliceAssetsAfter, aliceAssets + amount, "Alice assets should increase");

        uint256 bobAssetsAfter = usdc.balanceOf(users.bob);
        assertEq(bobAssetsAfter, bobAssets, "Bob assets should not change");
    }

    function enableFees() internal {
        vm.startPrank({ msgSender: users.admin });
        depositVault.updateFee(fee); // 1%
        depositVault.updateFeeRecipient(users.bob);
        vm.startPrank({ msgSender: users.alice });
    }
}
