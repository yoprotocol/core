// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../../Base.t.sol";

contract TotalAssets_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.alice });
    }

    function test_totalAssets_success() public {
        uint256 amount = 100 * 1e6;

        uint256 totalAssetsBefore = depositVault.totalAssets();
        assertTrue(totalAssetsBefore == 0, "Total assets before is not 0");

        usdc.transfer(address(depositVault), amount);

        uint256 totalAssetsAfter = depositVault.totalAssets();
        assertTrue(totalAssetsAfter == amount, "Total assets after is not the amount");
    }
}
