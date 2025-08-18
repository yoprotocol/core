// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "forge-std/console.sol";

import { Gateway_Base_Test } from "./Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";

contract Deposit_Test is Gateway_Base_Test {
    // ========================================= EVENTS =========================================
    event YoGatewayDeposit(
        uint32 indexed partnerId,
        address indexed yoVault,
        address indexed sender,
        address receiver,
        uint256 assets,
        uint256 sharesOut
    );

    // ========================================= VARIABLES =========================================
    uint256 public constant ASSETS = 1000e6;
    uint256 public constant MIN_SHARES_OUT = 900e6;
    uint32 public constant PARTNER_ID = 1;

    // ========================================= TESTS =========================================

    function test_deposit_Success() public {
        vm.startPrank(users.bob);

        uint256 balanceBefore = usdc.balanceOf(users.bob);
        uint256 sharesBefore = yoVault.balanceOf(users.bob);

        uint256 sharesOut = gateway.deposit(address(yoVault), ASSETS, MIN_SHARES_OUT, users.bob, PARTNER_ID);

        uint256 balanceAfter = usdc.balanceOf(users.bob);
        uint256 sharesAfter = yoVault.balanceOf(users.bob);

        assertEq(balanceBefore - balanceAfter, ASSETS, "Assets should be transferred");
        assertEq(sharesAfter - sharesBefore, sharesOut, "Shares should be minted");
        assertGt(sharesOut, 0, "Shares out should be greater than 0");

        vm.stopPrank();
    }

    function test_deposit_ToDifferentReceiver() public {
        vm.startPrank(users.bob);

        uint256 balanceBefore = usdc.balanceOf(users.bob);
        uint256 sharesBefore = yoVault.balanceOf(users.alice);

        uint256 sharesOut = gateway.deposit(address(yoVault), ASSETS, MIN_SHARES_OUT, users.alice, PARTNER_ID);

        uint256 balanceAfter = usdc.balanceOf(users.bob);
        uint256 sharesAfter = yoVault.balanceOf(users.alice);

        assertEq(balanceBefore - balanceAfter, ASSETS, "Assets should be transferred from sender");
        assertEq(sharesAfter - sharesBefore, sharesOut, "Shares should be minted to receiver");
        assertGt(sharesOut, 0, "Shares out should be greater than 0");

        vm.stopPrank();
    }

    function test_deposit_RevertWhen_ZeroAmount() public {
        vm.startPrank(users.bob);

        vm.expectRevert(Errors.Gateway__ZeroAmount.selector);

        gateway.deposit(address(yoVault), 0, MIN_SHARES_OUT, users.bob, PARTNER_ID);

        vm.stopPrank();
    }

    function test_deposit_RevertWhen_ZeroReceiver() public {
        vm.startPrank(users.bob);

        vm.expectRevert(Errors.Gateway__ZeroReceiver.selector);

        gateway.deposit(address(yoVault), ASSETS, MIN_SHARES_OUT, address(0), PARTNER_ID);

        vm.stopPrank();
    }

    function test_deposit_RevertWhen_VaultNotAllowed() public {
        vm.startPrank(users.bob);

        vm.expectRevert(Errors.Gateway__VaultNotAllowed.selector);

        gateway.deposit(DUMMY_VAULT, ASSETS, MIN_SHARES_OUT, users.bob, PARTNER_ID);

        vm.stopPrank();
    }

    function test_deposit_RevertWhen_InsufficientSharesOut() public {
        vm.startPrank(users.bob);

        uint256 veryHighMinShares = 10_000e18; // Much higher than what would be received

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Gateway__InsufficientSharesOut.selector, yoVault.previewDeposit(ASSETS), veryHighMinShares
            )
        );

        gateway.deposit(address(yoVault), ASSETS, veryHighMinShares, users.bob, PARTNER_ID);

        vm.stopPrank();
    }

    function test_deposit_RevertWhen_InsufficientAllowance() public {
        vm.startPrank(users.bob);

        uint256 balanceBefore = usdc.balanceOf(users.bob);
        console.log("balanceBefore", balanceBefore);

        // Revoke allowance
        usdc.approve(address(gateway), 0);
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        gateway.deposit(address(yoVault), ASSETS, MIN_SHARES_OUT, users.bob, PARTNER_ID);
        vm.stopPrank();
    }

    function test_deposit_RevertWhen_InsufficientBalance() public {
        vm.startPrank(users.bob);

        uint256 largeAmount = 10_000_000e6; // More than user has

        vm.expectRevert("ERC20: transfer amount exceeds balance");

        gateway.deposit(address(yoVault), largeAmount, MIN_SHARES_OUT, users.bob, PARTNER_ID);

        vm.stopPrank();
    }
}
