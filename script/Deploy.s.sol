// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import "forge-std/src/Script.sol";
import { yoVault } from "src/yoVault.sol";
import { RolesAuthority } from "src/RolesAuthority.sol";
import { TimelockController } from "src/TimelockController.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    address GNOSIS_SAFE = address(0);
    address TIMELOCK_PROPOSER = address(0);
    address TIMELOCK_EXECUTOR = address(0);

    address OWNER = address(0); // Owner of the vault (must be replaced by the timelock)
    address ASSET = address(0); // Underlying asset
    string constant SHARE_NAME = "yoVaultXXX"; // Name of the token shares
    string constant SHARE_SYMBOL = "yoXXX"; // Symbol of the token shares
    uint256 constant INITIAL_LOCK_DEPOSIT = 10 * 1e6; // Initial deposit on behalf of the vault

    function run() public broadcast returns (yoVault vault, TimelockController timelock, RolesAuthority authority) {
        console.log("Deployer address: ", broadcaster);
        console.log("Deployer balance: ", broadcaster.balance);
        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", getChainId());
        console.log("Deploying vault...");

        require(TIMELOCK_EXECUTOR != address(0), "No executors set for the timelock");
        require(TIMELOCK_PROPOSER != address(0), "No proposers set for the timelock");
        require(GNOSIS_SAFE != address(0), "No Gnosis Safe address set");

        address[] memory proposers = new address[](1);
        proposers[0] = TIMELOCK_PROPOSER;
        address[] memory executors = new address[](1);
        executors[0] = TIMELOCK_EXECUTOR;
        timelock = new TimelockController(0, proposers, executors, GNOSIS_SAFE);

        console.log("Timelock deployed at: ", address(timelock));
        console.log("\nTimelock data:");
        console.log("Minimum delay:", timelock.getMinDelay());

        authority = new RolesAuthority(GNOSIS_SAFE, RolesAuthority(address(0)));
        console.log("Authority deployed at: ", address(authority));

        require(
            INITIAL_LOCK_DEPOSIT != 0,
            "Initial deposit not set. This prevents a frontrunning attack, please set a non-trivial initial deposit."
        );

        require(ASSET != address(0), "Asset address not set");
        require(OWNER != address(0), "Owner address not set");

        yoVault impl = new yoVault();
        console.log("yoVault implementation deployed at: ", address(impl));

        bytes memory data =
            abi.encodeWithSelector(vault.initialize.selector, IERC20(ASSET), OWNER, SHARE_NAME, SHARE_SYMBOL);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), OWNER, data);

        vault = yoVault(payable(address(proxy)));
        console.log("yoVault proxy deployed at: ", address(vault));

        vault.setAuthority(authority);
        console.log("Authority set for vault");

        IERC20(ASSET).approve(address(vault), INITIAL_LOCK_DEPOSIT);

        console.log("Allowance for vault: ", IERC20(ASSET).allowance(broadcaster, address(vault)));

        vault.deposit(INITIAL_LOCK_DEPOSIT, broadcaster);

        console.log("\nVault data:");
        console.log("Underlying asset:", address(vault.asset()));
        console.log("Name:", vault.name());
        console.log("Symbol:", vault.symbol());
        console.log("Owner:", vault.owner());
        console.log("Fee:", vault.feeOnDeposit());
        console.log("FeeRecipient:", vault.feeRecipient());
    }

    function getChainId() public view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}
