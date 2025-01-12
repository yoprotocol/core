// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../../Base.t.sol";

/// @notice Base test contract with common logic needed by all tests.

contract IsAuthorized_Unit_Concrete_Test is Base_Test {
    // ====================================== TEST CONTRACTS =======================================

    // ====================================== SET-UP FUNCTION ======================================
    function setUp() public override {
        super.setUp();
    }

    function test_isAuthorized() public {
        vm.startPrank({ msgSender: users.admin });

        bool res = depositVault.isAuthorized(users.admin, msg.sig);
        assertTrue(res);
    }
}
