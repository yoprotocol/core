// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../Base.t.sol";
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
        assertEq(aliceShares, amount, "Alice Shares before is 0");

        uint256 vaultAssets = usdc.balanceOf(address(depositVault));
        assertEq(vaultAssets, amount, "Vault assets before is 0");

        uint256 aliceAssets = usdc.balanceOf(users.alice);

        depositVault.requestRedeem(aliceShares, users.alice, users.alice);

        uint256 aliceSharesAfter = depositVault.balanceOf(users.alice);
        assertEq(aliceSharesAfter, aliceShares - amount, "Alice Shares after is wrong");

        uint256 vaultAssetsAfter = usdc.balanceOf(address(depositVault));
        assertEq(vaultAssetsAfter, vaultAssets - amount, "Vault assets after is wrong");

        uint256 aliceAssetsAfter = usdc.balanceOf(users.alice);
        assertEq(aliceAssetsAfter, aliceAssets + amount, "Alice assets after is wrong");
    }

    function test_requestRedeem_async_success() public {
        uint256 aliceShares = depositVault.balanceOf(users.alice);
        assertEq(aliceShares, amount, "Alice Shares before is 0");

        uint256 aliceAssets = usdc.balanceOf(users.alice);

        uint256 transferAmount = amount / 2;
        moveAssetsAndUpdateUnderlyingBalances(transferAmount);
        uint256 vaultAssets = usdc.balanceOf(address(depositVault));
        assertEq(vaultAssets, transferAmount, "Vault assets before is 0");

        depositVault.requestRedeem(aliceShares, users.alice, users.alice);

        uint256 aliceSharesAfter = depositVault.balanceOf(users.alice);
        assertEq(aliceSharesAfter, aliceShares - amount, "Alice Shares after is wrong");

        uint256 vaultAssetsAfter = usdc.balanceOf(address(depositVault));
        assertEq(vaultAssetsAfter, vaultAssets, "Vault assets after is wrong");

        uint256 aliceAssetsAfter = usdc.balanceOf(users.alice);
        assertEq(aliceAssetsAfter, aliceAssets, "Alice assets after is wrong");

        uint256 pendingShares = depositVault.pendingRedeemRequest(users.alice);
        assertEq(pendingShares, amount, "Pending shares is wrong");
    }

    function test_requestRedeem_accumulate() public {
        uint256 aliceShares = depositVault.balanceOf(users.alice);
        assertEq(aliceShares, amount, "Alice Shares before is 0");

        uint256 aliceAssets = usdc.balanceOf(users.alice);

        // transfer the whole amount
        uint256 transferAmount = amount;
        moveAssetsAndUpdateUnderlyingBalances(transferAmount);
        uint256 vaultAssets = usdc.balanceOf(address(depositVault));
        assertEq(vaultAssets, 0, "Vault assets before should be 0");

        uint256 requestAmount = aliceShares / 2;
        depositVault.requestRedeem(requestAmount, users.alice, users.alice);

        uint256 aliceSharesAfter = depositVault.balanceOf(users.alice);
        assertEq(aliceSharesAfter, aliceShares - requestAmount, "Alice Shares after is wrong");

        uint256 vaultAssetsAfter = usdc.balanceOf(address(depositVault));
        assertEq(vaultAssetsAfter, vaultAssets, "Vault assets after is wrong");

        uint256 aliceAssetsAfter = usdc.balanceOf(users.alice);
        assertEq(aliceAssetsAfter, aliceAssets, "Alice assets after is wrong");

        uint256 pendingShares = depositVault.pendingRedeemRequest(users.alice);
        assertEq(pendingShares, requestAmount, "Pending shares is wrong");

        // request the rest of the shares
        depositVault.requestRedeem(requestAmount, users.alice, users.alice);

        aliceSharesAfter = depositVault.balanceOf(users.alice);
        assertEq(aliceSharesAfter, aliceShares - requestAmount * 2, "Alice Shares after is wrong");

        vaultAssetsAfter = usdc.balanceOf(address(depositVault));
        assertEq(vaultAssetsAfter, vaultAssets, "Vault assets after is wrong");

        aliceAssetsAfter = usdc.balanceOf(users.alice);
        assertEq(aliceAssetsAfter, aliceAssets, "Alice assets after is wrong");

        pendingShares = depositVault.pendingRedeemRequest(users.alice);
        assertEq(pendingShares, requestAmount * 2, "Pending shares is wrong");
    }

    function test_requestRedeem_insufficient_balance_revert() public {
        uint256 shares = depositVault.balanceOf(users.alice) + 1;
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientShares.selector));
        depositVault.requestRedeem(shares + 1, users.alice, users.alice);
    }

    function test_requestRedeem_zero_shares_revert() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.SharesAmountZero.selector));
        depositVault.requestRedeem(0, users.alice, users.alice);
    }

    function test_requestRedeem_not_owner_revert() public {
        uint256 shares = depositVault.balanceOf(users.alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotSharesOwner.selector));
        depositVault.requestRedeem(shares, users.alice, users.bob);
    }
}
