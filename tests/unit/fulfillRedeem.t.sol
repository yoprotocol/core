// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Fulfill_Unit_Concrete_Test is Base_Test {
    uint256 amount = 100 * 1e6;
    uint256 aliceShares;

    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.alice });

        depositVault.deposit(amount, users.alice);

        moveAssetsAndUpdateUnderlyingBalances(amount);
        aliceShares = depositVault.balanceOf(users.alice);
        depositVault.requestRedeem(aliceShares, users.alice, users.alice);
    }

    function test_fulfill_success() public {
        vm.startPrank({ msgSender: users.admin });
        depositVault.fulfillRedeem(users.alice, aliceShares);
        (uint256 shares, uint256 assets) = depositVault.claimableRedeemRequest(users.alice);
        assertEq(shares, aliceShares);
        assertEq(assets, amount);
    }

    function test_fulfill_revert_zero_shares() public {
        vm.startPrank({ msgSender: users.admin });
        depositVault.fulfillRedeem(users.alice, aliceShares);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidSharesAmount.selector));
        depositVault.fulfillRedeem(users.alice, aliceShares);
    }

    function test_fulfill_revert_invalid_shares() public {
        vm.startPrank({ msgSender: users.admin });
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidSharesAmount.selector));
        depositVault.fulfillRedeem(users.alice, aliceShares + 1);
    }
}
