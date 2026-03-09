// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import "forge-std/Script.sol";
import { BaseScript } from "./Base.s.sol";

import { YoOracle } from "src/YoOracle.sol";

contract Deploy is BaseScript {
    address internal constant UPDATER = 0x1571BD48C0bc598c440966568058e02f2373162f;

    function run() public broadcast returns (YoOracle oracle) {
        oracle = new YoOracle(UPDATER, 86_400, 1_000_000);
        console.log("Oracle implementation address", address(oracle));
    }
}
