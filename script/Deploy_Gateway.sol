// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import "forge-std/Script.sol";
import { YoGateway } from "src/YoGateway.sol";
import { YoRegistry } from "src/YoRegistry.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { BaseScript } from "./Base.s.sol";

import { RolesAuthority } from "@solmate/auth/authorities/RolesAuthority.sol";

contract Deploy is BaseScript {
    function run() public broadcast returns (YoGateway gateway, YoRegistry registry) {
        YoRegistry registryImpl = new YoRegistry();
        console.log("Registry implementation address", address(registryImpl));

        bytes memory data =
            abi.encodeWithSelector(YoRegistry.initialize.selector, broadcaster, RolesAuthority(address(0)));
        registry = YoRegistry(payable(new TransparentUpgradeableProxy(address(registryImpl), broadcaster, data)));

        YoGateway gatewayImpl = new YoGateway();
        data = abi.encodeWithSelector(YoGateway.initialize.selector, address(registry));
        console.log("Gateway implementation address", address(gatewayImpl));
        gateway = YoGateway(payable(new TransparentUpgradeableProxy(address(gatewayImpl), broadcaster, data)));

        console.log("Gateway address", address(gateway));
        console.log("Registry address", address(registry));
    }
}
