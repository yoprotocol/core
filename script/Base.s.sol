// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28 <0.9.0;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

abstract contract BaseScript is Script {
    /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

    /// @dev Needed for the deterministic deployments.
    bytes32 internal constant ZERO_SALT = bytes32(0);

    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /// @dev Used to derive the broadcaster's address if $PRIVATE_KEY is not defined.
    string internal mnemonic;

    /// @dev Initializes the transaction broadcaster like this:
    ///
    /// - If $PRIVATE_KEY is defined, use it.
    /// - Otherwise, derive the broadcaster address from $MNEMONIC.
    /// - If $MNEMONIC is not defined, default to a test mnemonic.
    constructor() {
        uint256 deployerPrivateKey = uint256(vm.envOr({ name: "PRIVATE_KEY", defaultValue: bytes32(0) }));
        console.log("deployerPrivateKey", deployerPrivateKey);
        if (deployerPrivateKey != 0) {
            broadcaster = vm.rememberKey(deployerPrivateKey);
        } else {
            mnemonic = vm.envOr({ name: "MNEMONIC", defaultValue: TEST_MNEMONIC });
            (broadcaster,) = deriveRememberKey({ mnemonic: mnemonic, index: 0 });
        }

        bool dryRun = vm.envOr({ name: "DRY_RUN", defaultValue: true });
        if (dryRun) {
            vm.deal({ account: broadcaster, newBalance: 100 ether });
        }

        console.log("Deployer address: ", broadcaster);
        console.log("Deployer balance: ", broadcaster.balance);
        console.log("ChainId: ", getChainId());
    }

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }

    function getChainId() public view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    // add this to be excluded from coverage report
    function test() public { }
}
