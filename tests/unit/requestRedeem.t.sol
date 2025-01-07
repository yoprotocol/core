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

        uint256 pendingRedeemRequestBefore = depositVault.pendingRedeemRequest(users.alice);
        (uint256 sharesBefore, uint256 assetsBefore) = depositVault.claimableRedeemRequest(users.alice);
        uint256 totalClaimableAssets = depositVault.totalClaimableAssets();

        depositVault.requestRedeem(aliceShares, users.alice, users.alice);

        uint256 pendingRedeemRequestAfter = depositVault.pendingRedeemRequest(users.alice);
        (uint256 sharesAfter, uint256 assetsAfter) = depositVault.claimableRedeemRequest(users.alice);
        uint256 totalClaimableAssetsAfter = depositVault.totalClaimableAssets();

        assertEq(pendingRedeemRequestAfter, pendingRedeemRequestBefore, "Pending redeem should be the same");
        assertEq(sharesAfter, sharesBefore + aliceShares, "Shares should be increased");
        assertEq(assetsAfter, assetsBefore + amount, "Assets should be increased");
        assertEq(totalClaimableAssetsAfter, totalClaimableAssets + amount, "Total claimable must be increased");

        uint256 aliceSharesAfter = depositVault.balanceOf(users.alice);
        assertEq(aliceSharesAfter, aliceShares - amount, "Alice Shares after is wrong");

        uint256 vaultAssetsAfter = usdc.balanceOf(address(depositVault));
        assertEq(vaultAssetsAfter, vaultAssets, "Vault assets after is wrong");

        uint256 aliceAssetsAfter = usdc.balanceOf(users.alice);
        assertEq(aliceAssetsAfter, aliceAssets, "Alice assets after is wrong");
    }

    function test_requestRedeem_async_success() public {
        uint256 aliceShares = depositVault.balanceOf(users.alice);
        assertEq(aliceShares, amount, "Alice Shares before is 0");

        uint256 aliceAssets = usdc.balanceOf(users.alice);

        uint256 transferAmount = amount / 2;
        moveAssetsAndUpdateUnderlyingBalances(transferAmount);
        uint256 vaultAssets = usdc.balanceOf(address(depositVault));
        assertEq(vaultAssets, transferAmount, "Vault assets before is 0");
        uint256 totalClaimableAssets = depositVault.totalClaimableAssets();

        depositVault.requestRedeem(aliceShares, users.alice, users.alice);

        uint256 totalClaimableAssetsAfter = depositVault.totalClaimableAssets();
        assertEq(totalClaimableAssetsAfter, totalClaimableAssets, "Total claimable assets should not be increased");

        uint256 aliceSharesAfter = depositVault.balanceOf(users.alice);
        assertEq(aliceSharesAfter, aliceShares - amount, "Alice Shares after is wrong");
        uint256 vaultAssetsAfter = usdc.balanceOf(address(depositVault));
        assertEq(vaultAssetsAfter, vaultAssets, "Vault assets after is wrong");

        uint256 aliceAssetsAfter = usdc.balanceOf(users.alice);
        assertEq(aliceAssetsAfter, aliceAssets, "Alice assets after is wrong");

        uint256 pendingShares = depositVault.pendingRedeemRequest(users.alice);
        assertEq(pendingShares, amount, "Pending shares is wrong");
    }

    function test_requestRedeem_async_total_claimable() public {
        vm.startPrank({ msgSender: users.bob });
        depositVault.deposit(amount, users.bob);
        uint256 bobShares = depositVault.balanceOf(users.bob);

        (uint256 shares, uint256 assets) = depositVault.claimableRedeemRequest(users.bob);
        depositVault.requestRedeem(amount, users.bob, users.bob);
        (uint256 sharesAfter, uint256 assetsAfter) = depositVault.claimableRedeemRequest(users.bob);
        assertEq(sharesAfter, shares + bobShares, "Shares should be increased");
        assertEq(assetsAfter, assets + amount, "Assets should be increased");

        vm.startPrank({ msgSender: users.alice });
        uint256 aliceShares = depositVault.balanceOf(users.alice);
        (shares, assets) = depositVault.claimableRedeemRequest(users.alice);
        depositVault.requestRedeem(amount, users.alice, users.alice);

        (sharesAfter, assetsAfter) = depositVault.claimableRedeemRequest(users.alice);
        assertEq(sharesAfter, shares + aliceShares, "Shares should be increased");
        assertEq(assetsAfter, assets + amount, "Assets should be increased");
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
