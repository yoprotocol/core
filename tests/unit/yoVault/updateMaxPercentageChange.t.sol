// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../../Base.t.sol";

import { Errors } from "src/libraries/Errors.sol";

contract UpdateMaxPercentageChange_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.admin });
    }

    function test_UpdateMaxPercentageChange_Success() public {
        depositVault.updateMaxPercentageChange(1e16);
        assertEq(depositVault.maxPercentageChange(), 1e16, "percentage change was not updated.");
    }

    function test_UpdateMaxPercentageChange_Revert_Max_Threshold() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidMaxPercentage.selector));
        depositVault.updateMaxPercentageChange(MAX_PERCENTAGE_THRESHOLD);
    }

    function test_UpdateMaxPercentageChange_NotAuthorized() public {
        vm.stopPrank();
        vm.expectRevert("UNAUTHORIZED");
        depositVault.updateMaxPercentageChange(MAX_PERCENTAGE_THRESHOLD);
    }
}
