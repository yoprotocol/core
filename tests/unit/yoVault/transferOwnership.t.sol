// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../../Base.t.sol";

/// @notice Base test contract with common logic needed by all tests.

contract TransferOwnership_Unit_Concrete_Test is Base_Test {
    // ====================================== TEST CONTRACTS =======================================

    // ====================================== SET-UP FUNCTION ======================================
    function setUp() public override {
        super.setUp();
    }

    function test_transferOwnership() public {
        vm.startPrank({ msgSender: users.admin });
        depositVault.transferOwnership(users.bob);
        assertEq(depositVault.owner(), users.bob);
    }
}
