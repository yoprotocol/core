// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Gateway_Base_Test } from "./Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";

contract Quotes_Test is Gateway_Base_Test {
    // ========================================= VARIABLES =========================================
    uint256 constant ASSETS = 1000e6;
    uint256 constant SHARES = 1000e18;

    // ========================================= TESTS =========================================

    function test_quoteConvertToShares_Success() public view {
        uint256 expectedShares = yoVault.convertToShares(ASSETS);
        uint256 actualShares = gateway.quoteConvertToShares(address(yoVault), ASSETS);

        assertEq(actualShares, expectedShares, "Should return correct shares for assets");
    }

    function test_quoteConvertToAssets_Success() public view {
        uint256 expectedAssets = yoVault.convertToAssets(SHARES);
        uint256 actualAssets = gateway.quoteConvertToAssets(address(yoVault), SHARES);

        assertEq(actualAssets, expectedAssets, "Should return correct assets for shares");
    }

    function test_quotePreviewDeposit_Success() public view {
        uint256 expectedShares = yoVault.previewDeposit(ASSETS);
        uint256 actualShares = gateway.quotePreviewDeposit(address(yoVault), ASSETS);

        assertEq(actualShares, expectedShares, "Should return correct preview shares for deposit");
    }

    function test_quotePreviewRedeem_Success() public view {
        uint256 expectedAssets = yoVault.previewRedeem(SHARES);
        uint256 actualAssets = gateway.quotePreviewRedeem(address(yoVault), SHARES);

        assertEq(actualAssets, expectedAssets, "Should return correct preview assets for redeem");
    }

    function test_quoteConvertToShares_RevertWhen_VaultNotAllowed() public {
        vm.expectRevert(Errors.Gateway__VaultNotAllowed.selector);

        gateway.quoteConvertToShares(DUMMY_VAULT, ASSETS);
    }

    function test_quoteConvertToAssets_RevertWhen_VaultNotAllowed() public {
        vm.expectRevert(Errors.Gateway__VaultNotAllowed.selector);

        gateway.quoteConvertToAssets(DUMMY_VAULT, SHARES);
    }

    function test_quotePreviewDeposit_RevertWhen_VaultNotAllowed() public {
        vm.expectRevert(Errors.Gateway__VaultNotAllowed.selector);

        gateway.quotePreviewDeposit(DUMMY_VAULT, ASSETS);
    }

    function test_quotePreviewRedeem_RevertWhen_VaultNotAllowed() public {
        vm.expectRevert(Errors.Gateway__VaultNotAllowed.selector);

        gateway.quotePreviewRedeem(DUMMY_VAULT, SHARES);
    }

    function test_quoteFunctions_WithZeroValues() public view {
        // These should work with zero values
        uint256 sharesForZeroAssets = gateway.quoteConvertToShares(address(yoVault), 0);
        uint256 assetsForZeroShares = gateway.quoteConvertToAssets(address(yoVault), 0);
        uint256 previewSharesForZeroAssets = gateway.quotePreviewDeposit(address(yoVault), 0);
        uint256 previewAssetsForZeroShares = gateway.quotePreviewRedeem(address(yoVault), 0);

        assertEq(sharesForZeroAssets, 0, "Zero assets should convert to zero shares");
        assertEq(assetsForZeroShares, 0, "Zero shares should convert to zero assets");
        assertEq(previewSharesForZeroAssets, 0, "Zero assets should preview to zero shares");
        assertEq(previewAssetsForZeroShares, 0, "Zero shares should preview to zero assets");
    }
}
