// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import "forge-std/Script.sol";
import { yoVault } from "src/yoVault/yoVault.sol";

import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { BaseScript } from "./Base.s.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

contract Upgrade is BaseScript {
    using Address for address;

    address public yoProxy = address(0x3A43AEC53490CB9Fa922847385D82fe25d0E9De7);
    address public admin = address(0xd460CF1f5D764acAD1c3276c549EE5f1BB671473);

    function run() public broadcast returns (yoVault vault) {
        vault = new yoVault();
        console.log("New vault deployed at: ", address(vault));
        ProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(yoProxy), address(vault), "");
    }
}
