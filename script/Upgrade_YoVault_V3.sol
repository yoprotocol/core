// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { YoVault_V3 } from "src/YoVault_V3.sol";
import { BaseScript } from "./Base.s.sol";

contract Upgrade_YoVault_V3 is BaseScript {
    function run(address _proxy, address _proxyAdmin, address _newAsset) public broadcast {
        require(_proxy != address(0), "Proxy address not set");
        require(_proxyAdmin != address(0), "ProxyAdmin address not set");
        require(_newAsset != address(0), "New asset address not set");

        console.log("Proxy:", _proxy);
        console.log("ProxyAdmin:", _proxyAdmin);
        console.log("New asset:", _newAsset);

        // Deploy new implementation
        YoVault_V3 impl = new YoVault_V3();
        console.log("V3 implementation deployed at:", address(impl));

        // Encode reinitializeAsset call
        bytes memory data = abi.encodeCall(YoVault_V3.reinitializeAsset, (IERC20(_newAsset)));

        // Upgrade proxy and call reinitializeAsset atomically
        ProxyAdmin(_proxyAdmin).upgradeAndCall(ITransparentUpgradeableProxy(_proxy), address(impl), data);

        // Verify
        YoVault_V3 vault = YoVault_V3(payable(_proxy));
        console.log("Asset after upgrade:", vault.asset());
        require(vault.asset() == _newAsset, "Asset mismatch after upgrade");
        console.log("Upgrade successful");
    }
}
