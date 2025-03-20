// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import "forge-std/Script.sol";
import { yoVault } from "src/yoVault.sol";
import { RolesAuthority } from "src/RolesAuthority.sol";
import { TimelockController } from "src/TimelockController.sol";
import { IWETH9 } from "src/interfaces/IWETH9.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Escrow } from "src/Escrow.sol";

import { BaseScript } from "./Base.s.sol";

contract Deploy is BaseScript {
    address VAULT = address(0);

    function run() public broadcast returns (Escrow escrow) {
        require(VAULT != address(0), "No vault address set");
        escrow = new Escrow(VAULT);
    }
}
