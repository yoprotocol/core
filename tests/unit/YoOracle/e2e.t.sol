// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";

import { YoOracle } from "src/YoOracle.sol";
import { IYoOracle } from "src/interfaces/IYoOracle.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract YoOracle_Test is Test {
    // --------------------------------- State ---------------------------------

    YoOracle internal oracle;

    address internal owner;
    address internal updater;
    address internal nonUpdater;
    address internal vault1;
    address internal vault2;

    uint64 internal constant DEFAULT_WINDOW_SECONDS = 86_400; // 1 day
    uint64 internal constant DEFAULT_MAX_CHANGE_BPS = 1_000_000; // 0.1% with 1e9 denominator

    uint64 internal constant BPS_DENOMINATOR = 1_000_000_000;

    // --------------------------------- Setup ---------------------------------

    function setUp() public {
        owner = address(this);
        updater = makeAddr("updater");
        nonUpdater = makeAddr("nonUpdater");
        vault1 = makeAddr("vault1");
        vault2 = makeAddr("vault2");

        oracle = new YoOracle(updater, DEFAULT_WINDOW_SECONDS, DEFAULT_MAX_CHANGE_BPS);
    }

    // =============================== Constructor ==============================

    function test_constructor_SetsDefaultsCorrectly() public view {
        assertEq(oracle.DEFAULT_WINDOW_SECONDS(), DEFAULT_WINDOW_SECONDS, "DEFAULT_WINDOW_SECONDS mismatch");
        assertEq(oracle.DEFAULT_MAX_CHANGE_BPS(), DEFAULT_MAX_CHANGE_BPS, "DEFAULT_MAX_CHANGE_BPS mismatch");
        assertEq(oracle.updater(), updater, "Updater mismatch");
        assertEq(oracle.owner(), owner, "Owner mismatch");
    }

    function test_constructor_RevertWhen_UpdaterZero() public {
        vm.expectRevert(IYoOracle.InvalidConfig.selector);
        new YoOracle(address(0), DEFAULT_WINDOW_SECONDS, DEFAULT_MAX_CHANGE_BPS);
    }

    // =============================== setUpdater ===============================

    function test_setUpdater_Success() public {
        address newUpdater = makeAddr("newUpdater");

        oracle.setUpdater(newUpdater);

        assertEq(oracle.updater(), newUpdater, "Updater should be updated");
    }

    function test_setUpdater_RevertWhen_NotOwner() public {
        address newUpdater = makeAddr("newUpdater");

        vm.prank(nonUpdater);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonUpdater));
        oracle.setUpdater(newUpdater);
    }

    function test_setUpdater_RevertWhen_ZeroAddress() public {
        vm.expectRevert(IYoOracle.InvalidConfig.selector);
        oracle.setUpdater(address(0));
    }

    // ============================== setAssetConfig ============================

    function test_setAssetConfig_Success() public {
        uint32 windowSeconds = 12 hours;
        uint32 maxChangeBps = 500_000; // 0.05%

        oracle.setAssetConfig(vault1, windowSeconds, maxChangeBps);

        (
            uint256 latestPrice,
            uint256 anchorPrice,
            uint64 anchorTimestamp,
            uint64 latestTimestamp,
            uint64 storedWindowSeconds,
            uint64 storedMaxChangeBps
        ) = oracle.oracleData(vault1);

        // Should not have changed any price-related fields
        assertEq(latestPrice, 0, "latestPrice should be zero");
        assertEq(anchorPrice, 0, "anchorPrice should be zero");
        assertEq(anchorTimestamp, 0, "anchorTimestamp should be zero");
        assertEq(latestTimestamp, 0, "latestTimestamp should be zero");

        // Config fields should be updated (note: struct uses uint64, function takes uint32)
        assertEq(storedWindowSeconds, uint64(windowSeconds), "windowSeconds should match");
        assertEq(storedMaxChangeBps, uint64(maxChangeBps), "maxChangeBps should match");
    }

    function test_setAssetConfig_RevertWhen_NotOwner() public {
        uint32 windowSeconds = 12 hours;
        uint32 maxChangeBps = 500_000;

        vm.prank(nonUpdater);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonUpdater));
        oracle.setAssetConfig(vault1, windowSeconds, maxChangeBps);
    }

    // ============================== updateSharePrice ==========================

    function test_updateSharePrice_RevertWhen_NotUpdater() public {
        uint256 price = 1e18;

        vm.prank(nonUpdater);
        vm.expectRevert(IYoOracle.NotUpdater.selector);
        oracle.updateSharePrice(vault1, price);
    }

    function test_updateSharePrice_FirstUpdate_InitializesPrices() public {
        uint256 price = 1e18;

        vm.prank(updater);
        oracle.updateSharePrice(vault1, price);

        (uint256 latestPrice, uint64 latestTs) = oracle.getLatestPrice(vault1);
        (uint256 anchorPrice, uint64 anchorTs) = oracle.getAnchor(vault1);

        assertEq(latestPrice, price, "latestPrice should be initialized");
        assertEq(anchorPrice, price, "anchorPrice should be initialized");
        assertEq(latestTs, anchorTs, "anchor and latest timestamps should match");
        assertGt(latestTs, 0, "timestamp should be set");
    }

    function test_updateSharePrice_UsesDefaultConfigWhenAssetConfigNotSet() public {
        uint256 price1 = 1e18;
        // +0.05% (0.0005) < 0.1% default limit
        uint256 price2 = (price1 * (BPS_DENOMINATOR + 500_000)) / BPS_DENOMINATOR;

        // First update
        vm.prank(updater);
        oracle.updateSharePrice(vault1, price1);

        // Small time skip, within window
        skip(1 hours);

        // Second update within 0.1% limit (default)
        vm.prank(updater);
        oracle.updateSharePrice(vault1, price2);

        (uint256 latestPrice,) = oracle.getLatestPrice(vault1);
        assertEq(latestPrice, price2, "latestPrice should be updated with default config");
    }

    function test_updateSharePrice_RespectsPerAssetConfig() public {
        // Set very strict per-asset max change: 0.01% (0.0001)
        uint32 windowSeconds = 1 days;
        uint32 maxChangeBps = 100_000; // 0.01%

        oracle.setAssetConfig(vault1, windowSeconds, maxChangeBps);

        uint256 price1 = 1e18;
        uint256 allowedPrice = (price1 * (BPS_DENOMINATOR + maxChangeBps)) / BPS_DENOMINATOR;
        uint256 tooHighPrice = (price1 * (BPS_DENOMINATOR + maxChangeBps + 1)) / BPS_DENOMINATOR;

        // First update
        vm.prank(updater);
        oracle.updateSharePrice(vault1, price1);

        // Within limit should succeed
        skip(1 hours);
        vm.prank(updater);
        oracle.updateSharePrice(vault1, allowedPrice);

        // Above limit should revert with full error data
        skip(1 hours);

        // What the contract will use as reference (anchor)
        uint256 ref = price1; // anchorPrice remains first price (no window rotation)
        uint256 diff = tooHighPrice > ref ? tooHighPrice - ref : ref - tooHighPrice;
        uint256 expectedDiffBps = (diff * BPS_DENOMINATOR) / ref;

        vm.prank(updater);
        vm.expectRevert(
            abi.encodeWithSelector(
                IYoOracle.PriceChangeTooBig.selector,
                vault1,
                tooHighPrice,
                ref,
                expectedDiffBps,
                uint256(maxChangeBps) // widened to uint256
            )
        );
        oracle.updateSharePrice(vault1, tooHighPrice);
    }

    function test_updateSharePrice_RevertWhen_ChangeAboveDefaultLimit() public {
        // Default maxChangeBps = 0.1% (1_000_000 / 1e9)
        uint256 price1 = 1e18;

        // 0.2% increase -> 2_000_000 in 1e9 units, above 1_000_000
        uint256 price2 = (price1 * (BPS_DENOMINATOR + 2_000_000)) / BPS_DENOMINATOR;

        vm.prank(updater);
        oracle.updateSharePrice(vault1, price1);

        skip(1 hours);

        // For the revert:
        // - vault = vault1
        // - newPrice = price2
        // - anchorPrice = price1 (no window rotation, no custom config)
        // - diffBps computed exactly as in the contract
        uint256 ref = price1;
        uint256 diff = price2 > ref ? price2 - ref : ref - price2;
        uint256 expectedDiffBps = (diff * BPS_DENOMINATOR) / ref;

        vm.prank(updater);
        vm.expectRevert(
            abi.encodeWithSelector(
                IYoOracle.PriceChangeTooBig.selector,
                vault1,
                price2,
                ref,
                expectedDiffBps,
                uint256(DEFAULT_MAX_CHANGE_BPS) // same value passed to constructor
            )
        );
        oracle.updateSharePrice(vault1, price2);
    }

    function test_updateSharePrice_AnchorRotatesAfterWindow() public {
        // Use a small window to test easily
        uint32 smallWindow = 100; // 100 seconds
        uint32 maxChangeBps = 1_000_000; // 0.1%

        oracle.setAssetConfig(vault1, smallWindow, maxChangeBps);

        uint256 price1 = 1e18;
        uint256 price2 = (price1 * (BPS_DENOMINATOR + 500_000)) / BPS_DENOMINATOR; // +0.05%

        // First update -> sets both latest and anchor
        vm.prank(updater);
        oracle.updateSharePrice(vault1, price1);

        (uint256 anchorPriceBefore, uint64 anchorTsBefore) = oracle.getAnchor(vault1);
        assertEq(anchorPriceBefore, price1, "anchorPrice should equal first price");

        // Move time forward beyond window
        skip(smallWindow + 1);

        // Second update -> should validate price2 against current anchor (price1),
        // then update latest, and rotate anchor to the new price (price2) since window passed.
        vm.prank(updater);
        oracle.updateSharePrice(vault1, price2);

        (uint256 latestPriceAfter, uint64 latestTsAfter) = oracle.getLatestPrice(vault1);
        (uint256 anchorPriceAfter, uint64 anchorTsAfter) = oracle.getAnchor(vault1);

        assertEq(latestPriceAfter, price2, "latestPrice should be updated to second price");
        assertEq(anchorPriceAfter, price2, "anchor should rotate to new price after window");
        assertGt(anchorTsAfter, anchorTsBefore, "anchor timestamp should move forward");
        assertEq(latestTsAfter, anchorTsAfter, "latest and anchor timestamps should match after rotation");
    }

    function test_updateSharePrice_IsIndependentPerVault() public {
        uint256 priceVault1_1 = 1e18;
        uint256 priceVault2_1 = 2e18;

        vm.startPrank(updater);
        oracle.updateSharePrice(vault1, priceVault1_1);
        oracle.updateSharePrice(vault2, priceVault2_1);
        vm.stopPrank();

        (uint256 latest1,) = oracle.getLatestPrice(vault1);
        (uint256 latest2,) = oracle.getLatestPrice(vault2);

        assertEq(latest1, priceVault1_1, "vault1 latestPrice mismatch");
        assertEq(latest2, priceVault2_1, "vault2 latestPrice mismatch");
    }

    function test_getLatestPrice_And_getAnchor_ReturnZeroForUninitializedVault() public view {
        (uint256 latestPrice, uint64 latestTs) = oracle.getLatestPrice(vault1);
        (uint256 anchorPrice, uint64 anchorTs) = oracle.getAnchor(vault1);

        assertEq(latestPrice, 0, "latestPrice should be zero for uninitialized vault");
        assertEq(anchorPrice, 0, "anchorPrice should be zero for uninitialized vault");
        assertEq(latestTs, 0, "latestTs should be zero for uninitialized vault");
        assertEq(anchorTs, 0, "anchorTs should be zero for uninitialized vault");
    }
}
