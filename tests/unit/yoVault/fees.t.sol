// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../../Base.t.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract Deposit_Unit_Concrete_Test is Base_Test {
    using Math for uint256;

    uint256 internal depositAmount;
    uint256 internal depositFee;
    uint256 internal withdrawFee;
    address internal feeRecipient;

    function setUp() public override {
        Base_Test.setUp();

        depositAmount = 115 * 1e6;
        depositFee = 1e16;
        withdrawFee = 1e16;
        feeRecipient = users.bob;

        vm.startPrank({ msgSender: users.admin });
        depositVault.updateDepositFee(depositFee);
        depositVault.updateWithdrawFee(withdrawFee);
        depositVault.updateFeeRecipient(feeRecipient);
        vm.stopPrank();
    }

    function test_deposit_and_redeem_all_fees() public {
        vm.startPrank({ msgSender: users.alice });

        uint256 aliceAssetsBeforeDeposit = usdc.balanceOf(users.alice);
        uint256 aliceSharesBeforeDeposit = depositVault.balanceOf(users.alice);
        uint256 vaultAssetsBeforeDeposit = usdc.balanceOf(address(depositVault));
        uint256 feeRecipientBalanceBeforeDeposit = usdc.balanceOf(feeRecipient);

        uint256 depositFeeAmount = _feeOnTotal(depositAmount, depositFee);
        uint256 previewDeposit = depositVault.previewDeposit(depositAmount);
        depositVault.deposit(depositAmount, users.alice);

        uint256 aliceAssetsAfterDeposit = usdc.balanceOf(users.alice);
        uint256 aliceSharesAfterDeposit = depositVault.balanceOf(users.alice);
        uint256 vaultAssetsAfterDeposit = usdc.balanceOf(address(depositVault));
        uint256 feeRecipientBalanceAfterDeposit = usdc.balanceOf(feeRecipient);

        assertEq(aliceAssetsAfterDeposit, aliceAssetsBeforeDeposit - depositAmount);
        assertEq(aliceSharesAfterDeposit, previewDeposit);
        assertEq(aliceSharesAfterDeposit, aliceSharesBeforeDeposit + (depositAmount - depositFeeAmount));
        assertEq(vaultAssetsAfterDeposit, vaultAssetsBeforeDeposit + (depositAmount - depositFeeAmount));
        assertEq(feeRecipientBalanceAfterDeposit, feeRecipientBalanceBeforeDeposit + depositFeeAmount);

        uint256 redeemFeeAmount = _feeOnTotal(aliceSharesAfterDeposit, withdrawFee);
        uint256 previewRedeem = depositVault.previewRedeem(aliceSharesAfterDeposit);
        depositVault.requestRedeem(aliceSharesAfterDeposit, users.alice, users.alice);

        uint256 aliceAssetsAfterRedeem = usdc.balanceOf(users.alice);
        uint256 aliceSharesAfterRedeem = depositVault.balanceOf(users.alice);
        uint256 vaultAssetsAfterRedeem = usdc.balanceOf(address(depositVault));
        uint256 feeRecipientBalanceAfterRedeem = usdc.balanceOf(feeRecipient);

        assertEq(aliceAssetsAfterRedeem, aliceAssetsAfterDeposit + (aliceSharesAfterDeposit - redeemFeeAmount));
        assertEq(aliceAssetsAfterRedeem, aliceAssetsAfterDeposit + previewRedeem);
        assertEq(aliceSharesAfterRedeem, 0);
        assertEq(vaultAssetsAfterRedeem, vaultAssetsAfterDeposit - aliceSharesAfterDeposit);
        assertEq(feeRecipientBalanceAfterRedeem, feeRecipientBalanceAfterDeposit + redeemFeeAmount);
    }

    function test_deposit_and_redeem_deposit_fee() public {
        vm.startPrank({ msgSender: users.admin });
        depositVault.updateWithdrawFee(0);
        vm.stopPrank();

        vm.startPrank({ msgSender: users.alice });

        uint256 aliceAssetsBeforeDeposit = usdc.balanceOf(users.alice);
        uint256 aliceSharesBeforeDeposit = depositVault.balanceOf(users.alice);
        uint256 vaultAssetsBeforeDeposit = usdc.balanceOf(address(depositVault));
        uint256 feeRecipientBalanceBeforeDeposit = usdc.balanceOf(feeRecipient);

        uint256 depositFeeAmount = _feeOnTotal(depositAmount, depositFee);
        depositVault.deposit(depositAmount, users.alice);

        uint256 aliceAssetsAfterDeposit = usdc.balanceOf(users.alice);
        uint256 aliceSharesAfterDeposit = depositVault.balanceOf(users.alice);
        uint256 vaultAssetsAfterDeposit = usdc.balanceOf(address(depositVault));
        uint256 feeRecipientBalanceAfterDeposit = usdc.balanceOf(feeRecipient);

        assertEq(aliceAssetsAfterDeposit, aliceAssetsBeforeDeposit - depositAmount);
        assertEq(aliceSharesAfterDeposit, aliceSharesBeforeDeposit + (depositAmount - depositFeeAmount));
        assertEq(vaultAssetsAfterDeposit, vaultAssetsBeforeDeposit + (depositAmount - depositFeeAmount));
        assertEq(feeRecipientBalanceAfterDeposit, feeRecipientBalanceBeforeDeposit + depositFeeAmount);

        depositVault.requestRedeem(aliceSharesAfterDeposit, users.alice, users.alice);

        uint256 aliceAssetsAfterRedeem = usdc.balanceOf(users.alice);
        uint256 aliceSharesAfterRedeem = depositVault.balanceOf(users.alice);
        uint256 vaultAssetsAfterRedeem = usdc.balanceOf(address(depositVault));
        uint256 feeRecipientBalanceAfterRedeem = usdc.balanceOf(feeRecipient);

        assertEq(aliceAssetsAfterRedeem, aliceAssetsAfterDeposit + aliceSharesAfterDeposit);
        assertEq(aliceSharesAfterRedeem, 0);
        assertEq(vaultAssetsAfterRedeem, vaultAssetsAfterDeposit - aliceSharesAfterDeposit);
        assertEq(feeRecipientBalanceAfterRedeem, feeRecipientBalanceAfterDeposit);
    }

    function test_deposit_and_redeem_withdraw_fee() public {
        vm.startPrank({ msgSender: users.admin });
        depositVault.updateDepositFee(0);
        vm.stopPrank();

        vm.startPrank({ msgSender: users.alice });

        uint256 aliceAssetsBeforeDeposit = usdc.balanceOf(users.alice);
        uint256 aliceSharesBeforeDeposit = depositVault.balanceOf(users.alice);
        uint256 vaultAssetsBeforeDeposit = usdc.balanceOf(address(depositVault));
        uint256 feeRecipientBalanceBeforeDeposit = usdc.balanceOf(feeRecipient);

        depositVault.deposit(depositAmount, users.alice);

        uint256 aliceAssetsAfterDeposit = usdc.balanceOf(users.alice);
        uint256 aliceSharesAfterDeposit = depositVault.balanceOf(users.alice);
        uint256 vaultAssetsAfterDeposit = usdc.balanceOf(address(depositVault));
        uint256 feeRecipientBalanceAfterDeposit = usdc.balanceOf(feeRecipient);

        assertEq(aliceAssetsAfterDeposit, aliceAssetsBeforeDeposit - depositAmount);
        assertEq(aliceSharesAfterDeposit, aliceSharesBeforeDeposit + depositAmount);
        assertEq(vaultAssetsAfterDeposit, vaultAssetsBeforeDeposit + depositAmount);
        assertEq(feeRecipientBalanceAfterDeposit, feeRecipientBalanceBeforeDeposit);

        uint256 redeemFeeAmount = _feeOnTotal(aliceSharesAfterDeposit, withdrawFee);
        depositVault.requestRedeem(aliceSharesAfterDeposit, users.alice, users.alice);

        uint256 aliceAssetsAfterRedeem = usdc.balanceOf(users.alice);
        uint256 aliceSharesAfterRedeem = depositVault.balanceOf(users.alice);
        uint256 vaultAssetsAfterRedeem = usdc.balanceOf(address(depositVault));
        uint256 feeRecipientBalanceAfterRedeem = usdc.balanceOf(feeRecipient);

        assertEq(aliceAssetsAfterRedeem, aliceAssetsAfterDeposit + (aliceSharesAfterDeposit - redeemFeeAmount));
        assertEq(aliceSharesAfterRedeem, 0);
        assertEq(vaultAssetsAfterRedeem, vaultAssetsAfterDeposit - aliceSharesAfterDeposit);
        assertEq(feeRecipientBalanceAfterRedeem, feeRecipientBalanceAfterDeposit + redeemFeeAmount);
    }

    function test_mint_and_redeem_all_fees() public {
        vm.startPrank({ msgSender: users.alice });

        uint256 aliceAssetsBeforeDeposit = usdc.balanceOf(users.alice);
        uint256 aliceSharesBeforeDeposit = depositVault.balanceOf(users.alice);
        uint256 vaultAssetsBeforeDeposit = usdc.balanceOf(address(depositVault));
        uint256 feeRecipientBalanceBeforeDeposit = usdc.balanceOf(feeRecipient);

        uint256 depositFeeAmount = _feeOnRaw(depositAmount, depositFee);
        uint256 previewMint = depositVault.previewMint(depositAmount);
        depositVault.mint(depositAmount, users.alice);

        uint256 aliceAssetsAfterDeposit = usdc.balanceOf(users.alice);
        uint256 aliceSharesAfterDeposit = depositVault.balanceOf(users.alice);
        uint256 vaultAssetsAfterDeposit = usdc.balanceOf(address(depositVault));
        uint256 feeRecipientBalanceAfterDeposit = usdc.balanceOf(feeRecipient);

        assertEq(aliceAssetsAfterDeposit, aliceAssetsBeforeDeposit - (depositAmount + depositFeeAmount), "1");
        assertEq(aliceAssetsAfterDeposit, aliceAssetsBeforeDeposit - previewMint);
        assertEq(aliceSharesAfterDeposit, aliceSharesBeforeDeposit + depositAmount, "2");
        assertEq(vaultAssetsAfterDeposit, vaultAssetsBeforeDeposit + depositAmount, "3");
        assertEq(feeRecipientBalanceAfterDeposit, feeRecipientBalanceBeforeDeposit + depositFeeAmount, "4");

        uint256 redeemFeeAmount = _feeOnTotal(aliceSharesAfterDeposit, withdrawFee);
        depositVault.requestRedeem(aliceSharesAfterDeposit, users.alice, users.alice);

        uint256 aliceAssetsAfterRedeem = usdc.balanceOf(users.alice);
        uint256 aliceSharesAfterRedeem = depositVault.balanceOf(users.alice);
        uint256 vaultAssetsAfterRedeem = usdc.balanceOf(address(depositVault));
        uint256 feeRecipientBalanceAfterRedeem = usdc.balanceOf(feeRecipient);

        assertEq(aliceAssetsAfterRedeem, aliceAssetsAfterDeposit + (aliceSharesAfterDeposit - redeemFeeAmount));
        assertEq(aliceSharesAfterRedeem, 0);
        assertEq(vaultAssetsAfterRedeem, vaultAssetsAfterDeposit - aliceSharesAfterDeposit);
        assertEq(feeRecipientBalanceAfterRedeem, feeRecipientBalanceAfterDeposit + redeemFeeAmount);
    }

    function test_async_redeem() public {
        vm.startPrank({ msgSender: users.alice });
        uint256 depositFeeAmount = _feeOnTotal(depositAmount, depositFee);
        uint256 netDepositAmount = depositAmount - depositFeeAmount;

        uint256 feeRecipientBalance = usdc.balanceOf(feeRecipient);

        depositVault.deposit(depositAmount, users.alice);

        moveAssetsFromVault(netDepositAmount);
        updateUnderlyingBalance(netDepositAmount);

        vm.startPrank({ msgSender: users.alice });
        uint256 aliceShares = depositVault.balanceOf(users.alice);
        uint256 totalPendingAssetsBefore = depositVault.totalPendingAssets();

        uint256 redeemFeeAmount = _feeOnTotal(aliceShares, withdrawFee);
        depositVault.requestRedeem(aliceShares, users.alice, users.alice);

        vm.roll(block.number + 1);
        usdc.transfer(address(depositVault), netDepositAmount);
        updateUnderlyingBalance(0);

        vm.startPrank({ msgSender: users.admin });
        uint256 totalPendingAssetsAfter = depositVault.totalPendingAssets();
        // check that the total pending assets are accounted for correctly including both the deposit and redeem fees
        assertEq(totalPendingAssetsAfter, totalPendingAssetsBefore + netDepositAmount);
        (uint256 pendingAssets, uint256 pendingShares) = depositVault.pendingRedeemRequest(users.alice);
        // check that the user pending assets and shares are accounted for correctly including both the deposit and
        // redeem fees
        assertEq(pendingAssets, netDepositAmount);
        assertEq(pendingShares, aliceShares);

        depositVault.fulfillRedeem(users.alice, pendingShares, pendingAssets);

        (uint256 pendingAssetsAfterr, uint256 pendingSharesAfter) = depositVault.pendingRedeemRequest(users.alice);
        uint256 feeRecipientBalanceAfter = usdc.balanceOf(feeRecipient);

        assertEq(depositVault.totalPendingAssets(), 0);
        assertEq(pendingAssetsAfterr, 0);
        assertEq(pendingSharesAfter, 0);
        assertEq(depositVault.balanceOf(users.alice), 0);
        assertEq(depositVault.totalAssets(), 0);
        assertEq(depositVault.balanceOf(address(depositVault)), 0);

        assertEq(feeRecipientBalanceAfter, feeRecipientBalance + redeemFeeAmount + depositFeeAmount);
    }

    /// @dev Calculates the fees that should be added to an amount `assets` that does not already include fees.
    /// Used in {IERC4626-mint} and {IERC4626-withdraw} operations.
    function _feeOnRaw(uint256 assets, uint256 feeBasisPoints) private pure returns (uint256) {
        return assets.mulDiv(feeBasisPoints, DENOMINATOR, Math.Rounding.Ceil);
    }

    /// @dev Calculates the fee part of an amount `assets` that already includes fees.
    /// Used in {IERC4626-deposit} and {IERC4626-redeem} operations.
    function _feeOnTotal(uint256 assets, uint256 feeBasisPoints) private pure returns (uint256) {
        return assets.mulDiv(feeBasisPoints, feeBasisPoints + DENOMINATOR, Math.Rounding.Ceil);
    }
}
