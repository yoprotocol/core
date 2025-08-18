// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Gateway_Base_Test } from "./Base.t.sol";

contract Integration_Test is Gateway_Base_Test {
    // ========================================= VARIABLES =========================================
    uint256 public constant ASSETS = 1000e6;
    uint32 public constant PARTNER_ID = 1;

    // ========================================= TESTS =========================================

    function test_FullDepositAndRedeemWorkflow() public {
        // Step 1: Bob deposits assets
        vm.startPrank(users.bob);

        uint256 bobBalanceBefore = usdc.balanceOf(users.bob);
        uint256 bobSharesBefore = yoVault.balanceOf(users.bob);

        uint256 sharesOut = gateway.deposit(
            address(yoVault),
            ASSETS,
            0, // No minimum shares requirement
            users.bob,
            PARTNER_ID
        );

        uint256 bobBalanceAfter = usdc.balanceOf(users.bob);
        uint256 bobSharesAfter = yoVault.balanceOf(users.bob);

        assertEq(bobBalanceBefore - bobBalanceAfter, ASSETS, "Bob's USDC should be reduced");
        assertEq(bobSharesAfter - bobSharesBefore, sharesOut, "Bob should receive shares");
        assertGt(sharesOut, 0, "Shares out should be positive");

        vm.stopPrank();

        // Step 2: Bob redeems all shares
        vm.startPrank(users.bob);

        uint256 sharesToRedeem = yoVault.balanceOf(users.bob);
        uint256 bobBalanceBeforeRedeem = usdc.balanceOf(users.bob);
        uint256 bobSharesBeforeRedeem = yoVault.balanceOf(users.bob);

        uint256 assetsOut = gateway.redeem(
            address(yoVault),
            sharesToRedeem,
            0, // No minimum assets requirement
            users.bob,
            PARTNER_ID
        );

        uint256 bobBalanceAfterRedeem = usdc.balanceOf(users.bob);
        uint256 bobSharesAfterRedeem = yoVault.balanceOf(users.bob);

        assertEq(bobSharesBeforeRedeem - bobSharesAfterRedeem, sharesToRedeem, "Bob's shares should be burned");
        assertGt(bobBalanceAfterRedeem - bobBalanceBeforeRedeem, 0, "Bob should receive assets back");
        assertGt(assetsOut, 0, "Assets out should be positive");

        vm.stopPrank();
    }

    function test_DepositToDifferentReceiver() public {
        // Bob deposits assets but Alice receives the shares
        vm.startPrank(users.bob);

        uint256 bobBalanceBefore = usdc.balanceOf(users.bob);
        uint256 aliceSharesBefore = yoVault.balanceOf(users.alice);

        uint256 sharesOut = gateway.deposit(
            address(yoVault),
            ASSETS,
            0,
            users.alice, // Alice receives the shares
            PARTNER_ID
        );

        uint256 bobBalanceAfter = usdc.balanceOf(users.bob);
        uint256 aliceSharesAfter = yoVault.balanceOf(users.alice);

        assertEq(bobBalanceBefore - bobBalanceAfter, ASSETS, "Bob's USDC should be reduced");
        assertEq(aliceSharesAfter - aliceSharesBefore, sharesOut, "Alice should receive shares");

        vm.stopPrank();
    }

    function test_MultipleDepositsAndRedeems() public {
        // Multiple deposits
        vm.startPrank(users.bob);
        gateway.deposit(address(yoVault), ASSETS, 0, users.bob, PARTNER_ID);
        gateway.deposit(address(yoVault), ASSETS, 0, users.bob, PARTNER_ID);
        vm.stopPrank();

        vm.startPrank(users.alice);
        gateway.deposit(address(yoVault), ASSETS, 0, users.alice, PARTNER_ID);
        vm.stopPrank();

        // Check balances
        uint256 bobShares = yoVault.balanceOf(users.bob);
        uint256 aliceShares = yoVault.balanceOf(users.alice);

        assertGt(bobShares, 0, "Bob should have shares");
        assertGt(aliceShares, 0, "Alice should have shares");

        // Multiple redeems
        vm.startPrank(users.bob);
        gateway.redeem(address(yoVault), bobShares / 2, 0, users.bob, PARTNER_ID);
        vm.stopPrank();

        vm.startPrank(users.alice);
        gateway.redeem(address(yoVault), aliceShares, 0, users.alice, PARTNER_ID);
        vm.stopPrank();

        // Check final balances
        uint256 bobSharesAfter = yoVault.balanceOf(users.bob);
        uint256 aliceSharesAfter = yoVault.balanceOf(users.alice);

        assertEq(bobSharesAfter, bobShares / 2, "Bob should have half shares remaining");
        assertEq(aliceSharesAfter, 0, "Alice should have no shares remaining");
    }

    function test_QuoteFunctionsIntegration() public view {
        // Test that quote functions work correctly with the actual vault
        uint256 expectedShares = gateway.quoteConvertToShares(address(yoVault), ASSETS);
        uint256 expectedAssets = gateway.quoteConvertToAssets(address(yoVault), expectedShares);
        uint256 previewShares = gateway.quotePreviewDeposit(address(yoVault), ASSETS);
        uint256 previewAssets = gateway.quotePreviewRedeem(address(yoVault), expectedShares);

        // These should be close to each other (allowing for small rounding differences)
        assertApproxEqRel(expectedAssets, ASSETS, 0.01e18, "Convert functions should be consistent");
        assertApproxEqRel(previewShares, expectedShares, 0.01e18, "Preview deposit should match convert");
        assertApproxEqRel(previewAssets, expectedAssets, 0.01e18, "Preview redeem should match convert");
    }

    function test_AllowanceIntegration() public {
        // Test allowance functions work correctly
        vm.startPrank(users.bob);
        yoVault.approve(address(gateway), 1000e18);
        usdc.approve(address(gateway), 1000e6);
        vm.stopPrank();

        uint256 shareAllowance = gateway.getShareAllowance(address(yoVault), users.bob);
        uint256 assetAllowance = gateway.getAssetAllowance(address(yoVault), users.bob);

        assertEq(shareAllowance, 1000e18, "Share allowance should be correct");
        assertEq(assetAllowance, 1000e6, "Asset allowance should be correct");
    }
}
