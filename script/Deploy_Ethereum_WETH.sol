// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import "forge-std/Script.sol";
import { yoVault } from "src/yoVault.sol";
import { RolesAuthority } from "src/RolesAuthority.sol";
import { TimelockController } from "src/TimelockController.sol";
import { IWETH9 } from "src/interfaces/IWETH9.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BaseScript } from "./Base.s.sol";

contract Deploy is BaseScript {
    address OWNER = address(0); // Owner of the vault
    address ASSET = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // Underlying asset

    string constant SHARE_NAME = "yoVaultETH"; // Name of the token shares
    string constant SHARE_SYMBOL = "yoETH"; // Symbol of the token shares

    function run() public broadcast returns (yoVault vault, RolesAuthority authority) {
        OWNER = address(broadcaster);

        require(OWNER != address(0), "No Owner address set");
        require(ASSET != address(0), "Asset address not set");

        console.log("BlockNumber: ", block.number);

        console.log("Deploying vault...");

        authority = new RolesAuthority(OWNER, RolesAuthority(address(0)));
        console.log("Authority deployed at: ", address(authority));

        yoVault impl = new yoVault();
        console.log("yoVault implementation deployed at: ", address(impl));

        bytes memory data =
            abi.encodeWithSelector(vault.initialize.selector, IERC20(ASSET), OWNER, SHARE_NAME, SHARE_SYMBOL);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), OWNER, data);

        vault = yoVault(payable(address(proxy)));
        console.log("yoVault proxy deployed at: ", address(vault));

        vault.setAuthority(authority);
        console.log("Authority set for vault");

        vault.pause();

        console.log("\nVault data:");
        console.log("Underlying asset:", address(vault.asset()));
        console.log("Name:", vault.name());
        console.log("Symbol:", vault.symbol());
        console.log("Owner:", vault.owner());
        console.log("Total Supply:", vault.totalSupply());
        console.log("Paused:", vault.paused());
        console.log("Authority:", address(vault.authority()));
        console.log("Deposit Fee:", vault.feeOnDeposit());
        console.log("Withdraw Fee:", vault.feeOnDeposit());
        console.log("FeeRecipient:", vault.feeRecipient());
    }
}

// forge script script/Deploy_Base_WETH.sol:Deploy --rpc-url
// https://base-mainnet.g.alchemy.com/v2/<KEY> -vvvv --json --broadcast --verify
// --private-keys $PRIVATE_KEY
