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
    address OWNER = address(0); // Owner of the vault
    address ASSET = address(0x4200000000000000000000000000000000000006); // Underlying asset

    string constant SHARE_NAME = "yoVaultETH"; // Name of the token shares
    string constant SHARE_SYMBOL = "yoETH"; // Symbol of the token shares
    uint256 constant INITIAL_LOCK_DEPOSIT = 1e16; // Initial deposit on behalf of the vault

    function run() public broadcast returns (yoVault vault, RolesAuthority authority) {
        OWNER = address(broadcaster);

        require(OWNER != address(0), "No Owner address set");
        require(ASSET != address(0), "Asset address not set");
        require(INITIAL_LOCK_DEPOSIT != 0, "Initial deposit not set");

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

        IWETH9 weth = IWETH9(ASSET);
        weth.deposit{ value: INITIAL_LOCK_DEPOSIT }();

        IERC20(ASSET).approve(address(vault), INITIAL_LOCK_DEPOSIT);

        console.log("Allowance for vault: ", IERC20(ASSET).allowance(broadcaster, address(vault)));

        vault.deposit(INITIAL_LOCK_DEPOSIT, broadcaster);

        console.log("\nVault data:");
        console.log("Underlying asset:", address(vault.asset()));
        console.log("Name:", vault.name());
        console.log("Symbol:", vault.symbol());
        console.log("Owner:", vault.owner());
        console.log("Total Supply:", vault.totalSupply());
        console.log("Authority:", address(vault.authority()));
        console.log("Deposit Fee:", vault.feeOnDeposit());
        console.log("Withdraw Fee:", vault.feeOnDeposit());
        console.log("FeeRecipient:", vault.feeRecipient());
    }
}

// forge script script/Deploy_Base_WETH.sol:Deploy --rpc-url
// https://base-mainnet.g.alchemy.com/v2/<KEY> -vvvv --json --broadcast --verify
