// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {YoToken} from "src/YoToken.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {MockAuthority} from "../../mocks/MockAuthority.sol";
import {Authority} from "src/base/AuthUpgradeable.sol";

contract YoToken_Test is Test {
    YoToken internal token;
    MockAuthority internal authority;

    address internal proxyAdmin;
    address internal owner;
    address internal bob;
    address internal alice;
    address internal charlie;

    uint256 internal constant INITIAL_SUPPLY = 1_000_000_000 * 1e18;

    // selector for internal _update(address,address,uint256)
    bytes4 internal constant UPDATE_SELECTOR = bytes4(0xa9059cbb);

    function setUp() public {
        owner = makeAddr("owner");
        bob = makeAddr("bob");
        alice = makeAddr("alice");
        charlie = makeAddr("charlie");

        vm.startPrank(owner);

        // Deploy implementation
        YoToken impl = new YoToken();

        // Deploy transparent proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            owner, // proxy admin (cannot call token functions through proxy)
            "" // no init data here; we'll call initialize explicitly
        );

        // Interact with token via proxy
        token = YoToken(address(proxy));

        authority = new MockAuthority(owner, Authority(address(0)));
        // Initialize through proxy as `owner` (NOT proxyAdmin)

        token.initialize(owner, "YoToken", "YO");
        token.setAuthority({newAuthority: authority});

        vm.stopPrank();
    }

    // ========================== Initialization ==========================

    function test_initialize_SetsMetadataAndSupply() public {
        assertEq(token.name(), "YoToken", "name mismatch");
        assertEq(token.symbol(), "YO", "symbol mismatch");
        assertEq(token.decimals(), 18, "decimals mismatch");

        assertEq(token.totalSupply(), INITIAL_SUPPLY, "totalSupply mismatch");
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY, "initial owner balance mismatch");
    }

    function test_initialize_RevertWhen_CalledTwice() public {
        // Second initialize should revert due to OZ Initializable
        vm.prank(owner);
        vm.expectRevert(); // "Initializable: contract is already initialized"
        token.initialize(owner, "YoToken", "YO");
    }

    // ============================== Transfers ==============================

    function test_ownerCanTransfer() public {
        uint256 amount = 100e18;

        vm.prank(owner);
        token.transfer(bob, amount);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount, "owner balance mismatch after transfer");
        assertEq(token.balanceOf(bob), amount, "bob balance mismatch after transfer");
    }

    function test_nonOwnerCannotTransfer() public {
        uint256 amount = 100e18;

        // First give bob some tokens (authorized transfer by owner)
        vm.prank(owner);
        token.transfer(bob, amount);
        assertEq(token.balanceOf(bob), amount, "bob should have tokens before attempting transfer");

        // Now bob tries to transfer – should fail because _update is requiresAuth
        vm.prank(bob);
        vm.expectRevert(); // auth revert from requiresAuth
        token.transfer(alice, 10e18);

        // Balances unchanged
        assertEq(token.balanceOf(bob), amount, "bob balance should not change");
        assertEq(token.balanceOf(alice), 0, "alice should still have zero");
    }

    function test_ownerCanTransferFrom() public {
        uint256 amount = 100e18;

        // Owner approves itself as spender
        vm.prank(owner);
        token.approve(owner, amount);

        // Owner (authorized by requiresAuth) calls transferFrom
        vm.prank(owner);
        token.transferFrom(owner, bob, amount);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount, "owner balance mismatch");
        assertEq(token.balanceOf(bob), amount, "bob balance mismatch");
    }

    function test_nonOwnerCannotTransferFrom_EvenWithAllowance() public {
        uint256 amount = 100e18;

        // Owner approves bob as spender
        vm.prank(owner);
        token.approve(bob, amount);

        // Bob tries to transferFrom – should revert due to requiresAuth on _update
        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(owner, alice, 10e18);

        // No balances changed
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY, "owner balance should be unchanged");
        assertEq(token.balanceOf(alice), 0, "alice should still have zero");
    }

    // =============================== Burn ===============================

    function test_ownerCanBurn() public {
        uint256 burnAmount = 50e18;

        uint256 supplyBefore = token.totalSupply();
        uint256 ownerBefore = token.balanceOf(owner);

        vm.prank(owner);
        token.burn(burnAmount);

        assertEq(token.totalSupply(), supplyBefore - burnAmount, "totalSupply mismatch after burn");
        assertEq(token.balanceOf(owner), ownerBefore - burnAmount, "owner balance mismatch after burn");
    }

    function test_nonOwnerCannotBurn() public {
        uint256 amount = 100e18;

        // Give bob some tokens
        vm.prank(owner);
        token.transfer(bob, amount);
        assertEq(token.balanceOf(bob), amount, "bob should have tokens before burn attempt");

        // Bob tries to burn his own tokens – should revert due to requiresAuth on _update
        vm.prank(bob);
        vm.expectRevert();
        token.burn(10e18);

        // Balances and supply unchanged
        assertEq(token.balanceOf(bob), amount, "bob balance should not change");
        assertEq(token.totalSupply(), INITIAL_SUPPLY, "totalSupply should not change");
    }

    // ============================ Auth behavior ============================

    function test_onlyOwnerHasTransferRightsByDefault() public {
        // sanity: owner transfer works
        vm.prank(owner);
        token.transfer(bob, 1e18);

        // bob cannot transfer onwards
        vm.prank(bob);
        vm.expectRevert();
        token.transfer(alice, 1e18);
    }

    function test_setPublicCapability_AllowsAnyoneToTransfer() public {
        // 3) Make _update(address,address,uint256) public for everyone
        vm.startPrank(owner);
        authority.setPublicCapability(address(token), UPDATE_SELECTOR, true);
        token.transfer(bob, 1e18);
        vm.stopPrank();

        // 5) Now bob should be able to transfer freely thanks to public capability
        vm.prank(bob);
        token.transfer(alice, 1e18);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - 1e18, "owner balance mismatch");
        assertEq(token.balanceOf(bob), 0, "bob should be drained");
        assertEq(token.balanceOf(alice), 1e18, "alice should have 1e18");
    }

    function test_roleBasedCapability_OnlyRoleHolderCanTransfer() public {
        uint8 ROLE_TRADER = 1;

        vm.startPrank(owner);
        authority.setPublicCapability(address(token), UPDATE_SELECTOR, false);
        authority.setRoleCapability(ROLE_TRADER, address(token), UPDATE_SELECTOR, true);
        authority.setUserRole(bob, ROLE_TRADER, true); // bob gets trader role
        vm.stopPrank();

        vm.prank(owner);
        token.transfer(bob, 1e18);

        vm.prank(owner);
        token.transfer(charlie, 1e18);

        vm.prank(bob);
        token.transfer(alice, 0.5e18);

        assertEq(token.balanceOf(bob), 0.5e18, "bob balance mismatch after transfer");
        assertEq(token.balanceOf(alice), 0.5e18, "alice balance mismatch after bob transfer");

        vm.prank(charlie);
        vm.expectRevert(); // UNAUTHORIZED from Authority/AuthUpgradeable
        token.transfer(alice, 0.5e18);

        // charlie's balance must remain unchanged
        assertEq(token.balanceOf(charlie), 1e18, "charlie balance should not have changed");
    }
}
