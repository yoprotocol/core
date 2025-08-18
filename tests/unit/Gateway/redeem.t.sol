// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Gateway_Base_Test } from "./Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";

contract Redeem_Test is Gateway_Base_Test {
    error ERC20InsufficientAllowance(address user, uint256 allowance, uint256 expected);
    error ERC20InsufficientBalance(address user, uint256 balance, uint256 expected);

    // ========================================= EVENTS =========================================
    event YoGatewayRedeem(
        uint32 indexed partnerId,
        address indexed yoVault,
        address indexed receiver,
        uint256 shares,
        uint256 assetsOrRequestId,
        bool instant
    );

    // ========================================= VARIABLES =========================================
    uint256 constant ASSETS = 1000e6;
    uint256 constant MIN_ASSETS_OUT = 900e6;
    uint32 constant PARTNER_ID = 1;

    // ========================================= SETUP =========================================

    function setUp() public override {
        super.setUp();

        // First deposit some assets to have shares to redeem
        vm.startPrank(users.bob);
        gateway.deposit(address(yoVault), ASSETS, 0, users.bob, PARTNER_ID);
        vm.stopPrank();
    }

    // ========================================= TESTS =========================================

    function test_redeem_Success() public {
        uint256 shares = yoVault.balanceOf(users.bob);
        require(shares > 0, "User should have shares to redeem");

        vm.startPrank(users.bob);

        uint256 sharesBefore = yoVault.balanceOf(users.bob);
        uint256 assetsBefore = usdc.balanceOf(users.bob);

        uint256 assetsOrRequestId = gateway.redeem(address(yoVault), shares, MIN_ASSETS_OUT, users.bob, PARTNER_ID);

        uint256 sharesAfter = yoVault.balanceOf(users.bob);
        uint256 assetsAfter = usdc.balanceOf(users.bob);

        assertEq(sharesBefore - sharesAfter, shares, "Shares should be burned");
        assertGt(assetsAfter - assetsBefore, 0, "Assets should be received");
        assertGt(assetsOrRequestId, 0, "Should return assets amount for instant redemption");

        vm.stopPrank();
    }

    function test_redeem_EmitsEvent() public {
        uint256 shares = yoVault.balanceOf(users.bob);
        require(shares > 0, "User should have shares to redeem");

        vm.startPrank(users.bob);

        vm.expectEmit(true, true, true, true);
        emit YoGatewayRedeem(
            PARTNER_ID,
            address(yoVault),
            users.bob,
            shares,
            yoVault.previewRedeem(shares),
            true // instant
        );

        gateway.redeem(address(yoVault), shares, MIN_ASSETS_OUT, users.bob, PARTNER_ID);

        vm.stopPrank();
    }

    function test_redeem_RevertWhen_ZeroAmount() public {
        vm.startPrank(users.bob);

        vm.expectRevert(Errors.Gateway__ZeroAmount.selector);

        gateway.redeem(address(yoVault), 0, MIN_ASSETS_OUT, users.bob, PARTNER_ID);

        vm.stopPrank();
    }

    function test_redeem_RevertWhen_ZeroReceiver() public {
        uint256 shares = yoVault.balanceOf(users.bob);
        require(shares > 0, "User should have shares to redeem");

        vm.startPrank(users.bob);

        vm.expectRevert(Errors.Gateway__ZeroReceiver.selector);

        gateway.redeem(address(yoVault), shares, MIN_ASSETS_OUT, address(0), PARTNER_ID);

        vm.stopPrank();
    }

    function test_redeem_RevertWhen_VaultNotAllowed() public {
        uint256 shares = yoVault.balanceOf(users.bob);
        require(shares > 0, "User should have shares to redeem");

        vm.startPrank(users.bob);

        vm.expectRevert(Errors.Gateway__VaultNotAllowed.selector);

        gateway.redeem(DUMMY_VAULT, shares, MIN_ASSETS_OUT, users.bob, PARTNER_ID);

        vm.stopPrank();
    }

    function test_redeem_RevertWhen_InsufficientAssetsOut() public {
        uint256 shares = yoVault.balanceOf(users.bob);
        require(shares > 0, "User should have shares to redeem");

        vm.startPrank(users.bob);

        uint256 veryHighMinAssets = 10_000_000e6; // Much higher than what would be received

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Gateway__InsufficientAssetsOut.selector, yoVault.previewRedeem(shares), veryHighMinAssets
            )
        );

        gateway.redeem(address(yoVault), shares, veryHighMinAssets, users.bob, PARTNER_ID);

        vm.stopPrank();
    }

    function test_redeem_RevertWhen_InsufficientAllowance() public {
        uint256 shares = yoVault.balanceOf(users.bob);
        require(shares > 0, "User should have shares to redeem");

        vm.startPrank(users.bob);

        // Revoke allowance
        yoVault.approve(address(gateway), 0);

        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientAllowance.selector, address(gateway), 0, shares));

        gateway.redeem(address(yoVault), shares, MIN_ASSETS_OUT, users.bob, PARTNER_ID);

        vm.stopPrank();
    }

    function test_redeem_RevertWhen_InsufficientBalance() public {
        uint256 shares = yoVault.balanceOf(users.bob);
        require(shares > 0, "User should have shares to redeem");

        vm.startPrank(users.bob);

        uint256 largeShares = shares * 2; // More shares than user has

        vm.expectRevert(
            abi.encodeWithSelector(ERC20InsufficientBalance.selector, address(users.bob), shares, largeShares)
        );

        gateway.redeem(address(yoVault), largeShares, MIN_ASSETS_OUT, users.bob, PARTNER_ID);

        vm.stopPrank();
    }
}
