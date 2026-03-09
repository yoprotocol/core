// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "./Base.t.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract TotalAssets_Unit_Concrete_Test is Base_Test {
    using Math for uint256;

    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.alice });
    }

    function test_totalAssets_zero_supply() public view {
        uint256 totalAssets = depositVault.totalAssets();
        assertEq(totalAssets, 0, "Total assets should be 0 with no supply");
    }

    function test_totalAssets_reflects_oracle_price() public {
        uint256 amount = 100 * 1e6;
        depositVault.deposit(amount, users.alice);

        uint256 supply = depositVault.totalSupply();
        uint256 decimals = depositVault.decimals();

        // Oracle is mocked at 1e6 (1:1), so totalAssets == supply
        uint256 totalAssets = depositVault.totalAssets();
        uint256 expected = uint256(1e6).mulDiv(supply, 10 ** decimals, Math.Rounding.Floor);
        assertEq(totalAssets, expected, "Total assets should reflect oracle price");
    }

    function test_totalAssets_updates_with_oracle() public {
        uint256 amount = 100 * 1e6;
        depositVault.deposit(amount, users.alice);

        // Double the oracle price
        setOraclePrice(2e6);

        uint256 supply = depositVault.totalSupply();
        uint256 decimals = depositVault.decimals();
        uint256 totalAssets = depositVault.totalAssets();
        uint256 expected = uint256(2e6).mulDiv(supply, 10 ** decimals, Math.Rounding.Floor);
        assertEq(totalAssets, expected, "Total assets should double with doubled price");
    }
}
