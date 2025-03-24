// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "./Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract Redeem_Unit_Concrete_Test is Base_Test {
    using Math for uint256;

    uint256 internal aliceShares = 100 * 1e6;

    function setUp() public override {
        Base_Test.setUp();
    }

    function test_redeem_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UseRequestRedeem.selector));
        depositVault.redeem(aliceShares, users.alice, users.alice);
    }
}
