// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28 <0.9.0;

import { RolesAuthority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { YoVault } from "src/YoVault.sol";

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface TokemakAutoPool {
    function rewarder() external view returns (address);
}

abstract contract BaseScript is Script {
    uint8 public constant TEST_ROLE = 12;
    uint8 public constant TEST_ORACLE_ROLE = 13;

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

    function enableERC4626(address authority, uint8 role, address vault, bool _calldata) public {
        if (_calldata) {
            bytes memory depositData = abi.encodeWithSelector(
                RolesAuthority.setRoleCapability.selector, role, vault, YoVault.deposit.selector, true
            );
            bytes memory withdrawData = abi.encodeWithSelector(
                RolesAuthority.setRoleCapability.selector, role, vault, YoVault.withdraw.selector, true
            );
            console.log("depositData");
            console.logBytes(depositData);
            console.log("withdrawData");
            console.logBytes(withdrawData);
        } else {
            RolesAuthority(authority).setRoleCapability(role, address(vault), YoVault.deposit.selector, true);
            RolesAuthority(authority).setRoleCapability(role, address(vault), YoVault.withdraw.selector, true);
        }
    }

    function enableTokemakAutoPool(address authority, uint8 role, address pool) public {
        enableERC4626(authority, role, pool, true);

        bytes memory approveData = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector, role, address(pool), IERC20.approve.selector, true
        );

        address rewarder = TokemakAutoPool(pool).rewarder();

        bytes memory data1 = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector, role, address(rewarder), bytes4(0xadc9772e), true
        );

        bytes memory data2 = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector, role, address(rewarder), bytes4(0xead5d359), true
        );

        bytes memory data3 = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector, role, address(rewarder), bytes4(0xc5285794), true
        );

        console.log("approveData");
        console.logBytes(approveData);
        console.log("data1");
        console.logBytes(data1);
        console.log("data2");
        console.logBytes(data2);
        console.log("data3");
        console.logBytes(data3);

        // stake
        // RolesAuthority(authority).setRoleCapability(role, address(rewarder), bytes4(0xadc9772e), true);
        // // withdraw
        // RolesAuthority(authority).setRoleCapability(role, address(rewarder), bytes4(0xead5d359), true);
        // // getReward
        // RolesAuthority(authority).setRoleCapability(role, address(rewarder), bytes4(0xc5285794), true);
    }

    function approveErc20(address authority, uint8 role, address[] memory token, bool _calldata) public {
        if (_calldata) {
            for (uint256 i = 0; i < token.length; i++) {
                bytes memory approveData = abi.encodeWithSelector(
                    RolesAuthority.setRoleCapability.selector, role, address(token[i]), IERC20.approve.selector, true
                );
                console.log("approveData");
                console.logBytes(approveData);
            }
        } else {
            for (uint256 i = 0; i < token.length; i++) {
                RolesAuthority(authority).setRoleCapability(role, address(token[i]), IERC20.approve.selector, true);
            }
        }
    }

    function enableConvexPool(address authority, uint8 role, address pool, address rewarder, bool _calldata) public {
        if (_calldata) {
            bytes memory approveData = abi.encodeWithSelector(
                RolesAuthority.setRoleCapability.selector, role, pool, IERC20.approve.selector, true
            );
            console.log("approveData");
            console.logBytes(approveData);

            bytes memory withdrawAndUnwrap = abi.encodeWithSelector(
                RolesAuthority.setRoleCapability.selector, role, address(rewarder), bytes4(0xc32e7202), true
            );
            console.log("withdrawAndUnwrap");
            console.logBytes(withdrawAndUnwrap);

            bytes memory getReward = abi.encodeWithSelector(
                RolesAuthority.setRoleCapability.selector, role, address(rewarder), bytes4(0x7050ccd9), true
            );
            console.log("getReward");
            console.logBytes(getReward);
        } else {
            RolesAuthority(authority).setRoleCapability(role, pool, IERC20.approve.selector, true);
            RolesAuthority(authority).setRoleCapability(role, address(rewarder), bytes4(0xc32e7202), true);
            RolesAuthority(authority).setRoleCapability(role, address(rewarder), bytes4(0x7050ccd9), true);
        }
    }

    // add this to be excluded from coverage report
    function test() public { }
}
