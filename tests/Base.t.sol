// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/src/Test.sol";

import { Authority } from "@solmate/auth/Auth.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Users } from "./utils/Types.sol";
import { Utils } from "./utils/Utils.sol";
import { Events } from "./utils/Events.sol";
import { Constants } from "./utils/Constants.sol";
import { MockAuthority } from "./mocks/MockAuthority.sol";

import { yoVault } from "src/yoVault.sol";

/// @notice Base test contract with common logic needed by all tests.

abstract contract Base_Test is Test, Events, Utils, Constants {
    using Math for uint256;

    // ========================================= VARIABLES =========================================
    Users internal users;

    // ====================================== TEST CONTRACTS =======================================
    IERC20 internal usdc;
    yoVault internal depositVault;
    Authority internal authority;

    // ====================================== SET-UP FUNCTION ======================================
    function setUp() public virtual {
        vm.createSelectFork({
            blockNumber: 24_500_000, // Jan-02-2025 03:42:27 AM +UTC
            urlOrAlias: vm.envOr("BASE_RPC_URL", string("https://base.llamarpc.com"))
        });

        // USDC (https://basescan.org/token/0x833589fcd6edb6e08f4c7c32d4f71b54bda02913)
        usdc = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

        // Label the base test contracts.
        vm.label({ account: address(usdc), newLabel: "USDC" });

        // Create the vault admin.
        users.admin = payable(makeAddr({ name: "Admin" }));
        vm.startPrank({ msgSender: users.admin });

        deployDepositVault();

        // Create users for testing.
        users.bob = createUser("Bob");
        users.alice = createUser("Alice");
    }

    // ====================================== HELPERS =======================================

    /// @dev Approves the protocol contracts to spend the user's USDC.
    function approveProtocol(address from) internal {
        resetPrank({ msgSender: from });
        usdc.approve({ spender: address(depositVault), value: UINT256_MAX });
        depositVault.approve({ spender: address(depositVault), value: UINT256_MAX });
    }

    /// @dev Generates a user, labels its address, funds it with test assets, and approves the protocol contracts.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });
        deal({ token: address(usdc), to: user, give: 1_000_000e6, adjust: true });
        approveProtocol({ from: user });
        return user;
    }

    /// @dev Deploys the yoVault
    function deployDepositVault() internal {
        depositVault = new yoVault(usdc, users.admin, "yoUSDCVault", "yoUSDC");
        authority = new MockAuthority(users.admin, Authority(address(0)));
        depositVault.setAuthority({ newAuthority: authority });

        // set the admin role for the admin
        MockAuthority(address(authority)).setUserRole(users.admin, ADMIN_ROLE, true);

        vm.label({ account: address(depositVault), newLabel: "yoUSDCVault" });
    }

    function moveAssetsAndUpdateUnderlyingBalances(uint256 assets) internal {
        vm.startPrank({ msgSender: users.admin });
        bytes memory data = abi.encodeWithSelector(IERC20.transfer.selector, users.bob, assets);

        MockAuthority(address(depositVault.authority())).setRoleCapability(
            ADMIN_ROLE, address(usdc), IERC20.transfer.selector, true
        );

        depositVault.manage(address(usdc), data, 0);
        depositVault.onUnderlyingBalanceUpdate(assets);

        vm.startPrank({ msgSender: users.alice });
    }
}
