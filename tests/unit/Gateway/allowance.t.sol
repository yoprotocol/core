// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Gateway_Base_Test } from "./Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";

contract Allowance_Test is Gateway_Base_Test {
    // ========================================= TESTS =========================================

    function test_getShareAllowance_Success() public {
        // Set up allowance
        vm.startPrank(users.bob);
        yoVault.approve(address(gateway), 1000e18);
        vm.stopPrank();

        uint256 allowance = gateway.getShareAllowance(address(yoVault), users.bob);
        assertEq(allowance, 1000e18, "Should return correct share allowance");
    }

    function test_getAssetAllowance_Success() public {
        // Set up allowance
        vm.startPrank(users.bob);
        usdc.approve(address(gateway), 1000e6);
        vm.stopPrank();

        uint256 allowance = gateway.getAssetAllowance(address(yoVault), users.bob);
        assertEq(allowance, 1000e6, "Should return correct asset allowance");
    }

    function test_getAssetAllowance_RevertWhen_VaultNotAllowed() public {
        vm.expectRevert(Errors.Gateway__VaultNotAllowed.selector);

        gateway.getAssetAllowance(DUMMY_VAULT, users.bob);
    }

    function test_allowanceFunctions_WithDifferentUsers() public {
        // Set up different allowances for different users
        vm.startPrank(users.bob);
        yoVault.approve(address(gateway), 1000e18);
        usdc.approve(address(gateway), 500e6);
        vm.stopPrank();

        vm.startPrank(users.alice);
        yoVault.approve(address(gateway), 2000e18);
        usdc.approve(address(gateway), 1500e6);
        vm.stopPrank();

        // Check Bob's allowances
        uint256 bobShareAllowance = gateway.getShareAllowance(address(yoVault), users.bob);
        uint256 bobAssetAllowance = gateway.getAssetAllowance(address(yoVault), users.bob);

        // Check Alice's allowances
        uint256 aliceShareAllowance = gateway.getShareAllowance(address(yoVault), users.alice);
        uint256 aliceAssetAllowance = gateway.getAssetAllowance(address(yoVault), users.alice);

        assertEq(bobShareAllowance, 1000e18, "Bob should have correct share allowance");
        assertEq(bobAssetAllowance, 500e6, "Bob should have correct asset allowance");
        assertEq(aliceShareAllowance, 2000e18, "Alice should have correct share allowance");
        assertEq(aliceAssetAllowance, 1500e6, "Alice should have correct asset allowance");
    }
}
