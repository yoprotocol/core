// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "./Base.t.sol";

contract Mint_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.alice });
    }

    function test_mint_success() public {
        uint256 shares = 100 * 1e6;
        uint256 aliceBalanceBefore = depositVault.balanceOf(users.alice);
        assertEq(aliceBalanceBefore, 0);

        vm.expectCall(address(usdc), abi.encodeCall(usdc.transferFrom, (users.alice, address(depositVault), shares)));
        depositVault.mint(shares, users.alice);

        uint256 aliceBalanceAfter = depositVault.balanceOf(users.alice);
        assertEq(aliceBalanceAfter, shares);
    }
}
