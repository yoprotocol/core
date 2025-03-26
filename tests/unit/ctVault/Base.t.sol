// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";

import { Authority } from "src/base/AuthUpgradable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { Users } from "../../utils/Types.sol";
import { Utils } from "../../utils/Utils.sol";
import { Events } from "../../utils/Events.sol";
import { Constants } from "../../utils/Constants.sol";
import { MockAuthority } from "../../mocks/MockAuthority.sol";

import { ctVault } from "src/ctVault/ctVault.sol";
import { ctVaultChainlinkOracle } from "src/ctVault/oracles/ctVaultChainlinkOracle.sol";

/// @notice Base test contract with common logic needed by all tests.

abstract contract Base_Test is Test, Events, Utils, Constants {
    using Math for uint256;

    // ========================================= VARIABLES =========================================
    Users internal users;

    // ====================================== TEST CONTRACTS =======================================
    IERC20 internal usdc;
    IERC20 internal cbBTC;
    ctVault internal vault;
    Authority internal authority;

    // ====================================== SET-UP FUNCTION ======================================
    function setUp() public virtual {
        vm.createSelectFork({
            blockNumber: 22_117_100, // Mar-24-2025 01:35:47 PM +UTC
            urlOrAlias: vm.envOr("ETHEREUM_RPC_URL", string("https://eth.llamarpc.com"))
        });

        // cbBTC https://etherscan.io/token/0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf
        cbBTC = IERC20(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);

        // USDC https://etherscan.io/token/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
        usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

        // Label the base test contracts.
        vm.label({ account: address(usdc), newLabel: "USDC" });
        vm.label({ account: address(cbBTC), newLabel: "cbBTC" });

        // Create the vault admin.
        users.admin = payable(makeAddr({ name: "Admin" }));
        vm.startPrank({ msgSender: users.admin });

        deployVault();

        // Create users for testing.
        (users.bob, users.bobKey) = createUser("Bob");
        (users.alice, users.aliceKey) = createUser("Alice");
    }

    // ====================================== HELPERS =======================================

    /// @dev Approves the protocol contracts to spend the user's USDC.
    function approveProtocol(address from) internal {
        resetPrank({ msgSender: from });
        cbBTC.approve({ spender: address(vault), value: UINT256_MAX });
    }

    function createUser(string memory name) internal returns (address payable, uint256) {
        (address user, uint256 key) = makeAddrAndKey(name);

        vm.deal({ account: user, newBalance: 100 ether });

        deal({ token: address(usdc), to: user, give: 1_000_000e6, adjust: true }); // 1_000_000 USDC
        deal({ token: address(cbBTC), to: user, give: 1000e8, adjust: true }); // 1000 cbBTC

        approveProtocol({ from: user });

        return (payable(user), key);
    }

    function deployOracles() internal {
        address usdcUsdChainlinkFeed = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
        ctVaultChainlinkOracle usdcOracle = new ctVaultChainlinkOracle(usdcUsdChainlinkFeed, usdcUsdChainlinkFeed);
    }

    function deployVault() internal { }
}
