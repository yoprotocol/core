// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import "forge-std/Script.sol";
import { YoVault } from "src/YoVault.sol";

import { console } from "forge-std/console.sol";

import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { BaseScript } from "./Base.s.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { YoGateway } from "src/YoGateway.sol";

contract Upgrade is BaseScript {
    using Address for address;

    ITransparentUpgradeableProxy public gateway =
        ITransparentUpgradeableProxy(0xF1EeE0957267b1A474323Ff9CfF7719E964969FA);
    ProxyAdmin public proxyAdmin = ProxyAdmin(0xB3C902F8fA46d7985efaB885105ae2d7b4976827);

    function run() public broadcast {
        YoGateway gatewayImpl = new YoGateway();
        proxyAdmin.upgradeAndCall(gateway, address(gatewayImpl), "");
    }
}
