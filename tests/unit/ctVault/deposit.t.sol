// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "./Base.t.sol";
import { IStrategy } from "src/ctVault/interfaces/IStrategy.sol";
import { ILendingAdapter } from "src/ctVault/interfaces/ILendingAdapter.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { console } from "forge-std/console.sol";

contract Deposit_Unit_Concrete_Test is Base_Test {
    using Math for uint256;

    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.alice });
    }

    function test_deposit_success() public {
        uint256 amount = 1 * 1e6;
        vault.deposit(amount, users.alice);

        ILendingAdapter adapter = ILendingAdapter(vault.lendingAdaptersAt(0));

        console.log("====================Lending Adapter============================");
        uint256 collateral = adapter.getCollateral();
        console.log("collateral", collateral);
        uint256 borrowed = adapter.getBorrowed();
        console.log("borrowed", borrowed);
        uint256 supplyAPY = adapter.getSupplyAPY();
        console.log("supplyAPY", supplyAPY);
        uint256 borrowAPY = adapter.getBorrowAPY();
        console.log("borrowAPY", borrowAPY);
        uint256 healthFactor = adapter.getHealthFactor();
        console.log("healthFactor", healthFactor);

        uint256 vaultLTV = vault.getVaultLTV();
        console.log("vaultLTV", vaultLTV);

        uint256 totalCollateral = vault.getTotalCollateral();
        console.log("totalCollateral", totalCollateral);
        uint256 totalBorrowed = vault.getTotalBorrowed();
        console.log("totalBorrowed", totalBorrowed);

        console.log("===================Strategy=============================");
        IStrategy strategy = IStrategy(vault.investQueueAt(0));

        console.log("strategy", address(strategy));
        uint256 strategyTotalAssets = strategy.totalAssets();
        console.log("strategyTotalAssets", strategyTotalAssets);

        uint256 strategyInvested = strategy.totalInvested();
        console.log("strategyInvested", strategyInvested);

        uint256 strategyIdle = strategy.idle();
        console.log("strategyIdle", strategyIdle);
    }
}
