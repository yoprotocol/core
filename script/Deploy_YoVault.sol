// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import "forge-std/Script.sol";
import { YoVault } from "src/YoVault.sol";
import { RolesAuthority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BaseScript } from "./Base.s.sol";

contract Deploy is BaseScript {
    function run(
        string memory _name,
        string memory _symbol,
        address _asset,
        address _owner,
        address _authority,
        address _vault
    )
        public
        broadcast
        returns (YoVault vault, RolesAuthority authority)
    {
        console.log("Deploying vault...");
        console.log("Name: ", _name);
        console.log("Symbol: ", _symbol);
        console.log("Asset: ", _asset);
        console.log("Owner: ", _owner);
        console.log("Authority: ", _authority);
        console.log("Vault: ", _vault);

        require(_owner != address(0), "No Owner address set");
        require(_asset != address(0), "Asset address not set");

        console.log("BlockNumber: ", block.number);

        if (_authority == address(0)) {
            authority = new RolesAuthority(_owner, RolesAuthority(address(0)));
            console.log("Authority deployed at: ", address(authority));
        } else {
            authority = RolesAuthority(_authority);
        }

        YoVault impl;
        if (_vault == address(0)) {
            impl = new YoVault();
            console.log("yoVault implementation deployed at: ", address(impl));
            return (impl, authority);
        } else {
            impl = YoVault(payable(_vault));
            console.log("yoVault implementation deployed at: ", address(impl));

            bytes memory data =
                abi.encodeWithSelector(vault.initialize.selector, IERC20(_asset), _owner, _name, _symbol);

            TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), _owner, data);

            vault = YoVault(payable(address(proxy)));
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
}

// forge script script/Deploy_InvestmentVault.sol:Deploy --fork-url
// https://arb-mainnet.g.alchemy.com/v2/B5NOppp7QFB18K4bPkrmmDFMjhgQEOST -vvvv --sig
// "run(string,string,address,address,address,address)" "yoVaultBTC" "yoBTC" 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf
// 0xd9C452E307A9521BAE23cb9E83bA71BE057207AE 0x9524e25079b1b04d904865704783a5aa0202d44d
// 0x0000000000000000000000000000000000000000

// forge script script/Deploy_InvestmentVault.sol:Deploy --fork-url
// https://arb-mainnet.g.alchemy.com/v2/B5NOppp7QFB18K4bPkrmmDFMjhgQEOST -vvvv --sig
// "run(string,string,address,address,address,address)" "yoVaultUSD" "yoUSD" 0xaf88d065e77c8cc2239327c5edb3a432268e5831
// 0x5641d005b8f541BDFdDBFACDc910f2aD5E0c3C21 0x9524e25079b1b04d904865704783a5aa0202d44d
// 0x0000000000000000000000000000000000000000
