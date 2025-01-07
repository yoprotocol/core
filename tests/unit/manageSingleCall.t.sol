// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "src/libraries/Errors.sol";

import { Base_Test } from "../Base.t.sol";
import { MockTarget } from "../mocks/MockTarget.sol";
import { MockAuthority } from "../mocks/MockAuthority.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockAuthority } from "../mocks/MockAuthority.sol";

contract ManageSingleCall_Unit_Concrete_Test is Base_Test {
    uint256 internal value = 1 ether;
    address internal mockTarget;
    bytes4 internal targetfunctionSig = MockTarget.someFunction.selector;
    bytes internal data = abi.encodeWithSelector(MockTarget.someFunction.selector, uint256(42));

    function setUp() public override {
        Base_Test.setUp();

        vm.deal(address(depositVault), value); // Fund the vault with native assets

        mockTarget = address(new MockTarget());

        vm.startPrank({ msgSender: users.admin });
        MockAuthority(address(depositVault.authority())).setRoleCapability(
            ADMIN_ROLE, mockTarget, targetfunctionSig, true
        );
    }

    function test_ManageSingleCall_Success() public {
        depositVault.manage(mockTarget, data, value);
        uint256 result = MockTarget(mockTarget).value();
        assertEq(result, 42, "Function was not called correctly.");
    }

    function test_ManageSingleCall_Revert_Unauthorized() public {
        vm.startPrank({ msgSender: users.bob }); // Stop acting as the owner
        vm.expectRevert("UNAUTHORIZED");
        depositVault.manage(mockTarget, data, value);
    }

    function test_ManageSingleCall_Revert_TargetMethodNotAuthorized() public {
        // Remove the capability
        MockAuthority(address(depositVault.authority())).setRoleCapability(
            ADMIN_ROLE, mockTarget, targetfunctionSig, false
        );
        vm.expectRevert(
            abi.encodeWithSelector(Errors.TargetMethodNotAuthorized.selector, mockTarget, targetfunctionSig)
        );
        depositVault.manage(mockTarget, data, value);
    }

    function test_ManageSingleCall_revert_if_funds_not_available() public {
        uint256 amount = 100 * 1e6;

        vm.startPrank({ msgSender: users.alice });

        depositVault.deposit(amount, users.alice);
        depositVault.requestRedeem(depositVault.balanceOf(users.alice), users.alice, users.alice);

        vm.startPrank({ msgSender: users.admin });

        bytes memory transferData = abi.encodeWithSelector(IERC20.transfer.selector, users.bob, amount);

        MockAuthority(address(depositVault.authority())).setRoleCapability(
            ADMIN_ROLE, address(usdc), IERC20.transfer.selector, true
        );

        uint256 bobBalanceBefore = usdc.balanceOf(users.bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientAssetsLeftToCoverClaimable.selector));
        depositVault.manage(address(usdc), transferData, 0);
        uint256 bobBalanceAfter = usdc.balanceOf(users.bob);
        assertEq(bobBalanceAfter, bobBalanceBefore, "Bob's balance should not have changed");

        // Pause the vault to allow the transfer to go through
        depositVault.pause();

        depositVault.manage(address(usdc), transferData, 0);
        bobBalanceAfter = usdc.balanceOf(users.bob);

        assertEq(bobBalanceAfter, bobBalanceBefore + amount, "Bob's balance should have changed");
    }
}
