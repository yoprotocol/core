// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { Authority } from "src/base/AuthUpgradeable.sol";
import { Users } from "../../utils/Types.sol";
import { Utils } from "../../utils/Utils.sol";
import { Events } from "../../utils/Events.sol";
import { Constants } from "../../utils/Constants.sol";
import { MockAuthority } from "../../mocks/MockAuthority.sol";
import { YoRegistry } from "src/YoRegistry.sol";

/// @notice Base test contract with common logic needed by all YoRegistry tests.
abstract contract Registry_Base_Test is Test, Events, Utils, Constants {
    // ========================================= VARIABLES =========================================
    Users internal users;

    // ====================================== TEST CONTRACTS =======================================
    YoRegistry internal registry;
    Authority internal authority;

    // ====================================== SET-UP FUNCTION ======================================
    function setUp() public virtual {
        vm.createSelectFork({
            blockNumber: 24_500_000, // Jan-02-2025 03:42:27 AM +UTC
            urlOrAlias: vm.envOr("BASE_RPC_URL", string("https://base.llamarpc.com"))
        });

        // Create the registry admin.
        users.admin = payable(makeAddr({ name: "Admin" }));
        vm.startPrank({ msgSender: users.admin });

        deployRegistry();

        // Create users for testing.
        (users.bob, users.bobKey) = createUser("Bob");
        (users.alice, users.aliceKey) = createUser("Alice");
    }

    // ====================================== HELPERS =======================================

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable, uint256) {
        (address user, uint256 key) = makeAddrAndKey(name);
        vm.deal({ account: user, newBalance: 100 ether });
        return (payable(user), key);
    }

    /// @dev Deploys the YoRegistry
    function deployRegistry() internal {
        YoRegistry registryImpl = new YoRegistry();

        bytes memory data = abi.encodeWithSelector(YoRegistry.initialize.selector, users.admin, Authority(address(0)));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(registryImpl), users.admin, data);
        registry = YoRegistry(payable(address(proxy)));

        authority = new MockAuthority(users.admin, Authority(address(0)));
        registry.setAuthority({ newAuthority: authority });

        MockAuthority(address(authority)).setUserRole(users.admin, ADMIN_ROLE, true);

        vm.label({ account: address(registry), newLabel: "YoRegistry" });
    }

    /// @dev Creates a mock ERC4626 vault for testing
    function createMockVault(address asset) internal returns (address) {
        MockERC4626Vault vault = new MockERC4626Vault(asset);
        vm.label({ account: address(vault), newLabel: "MockERC4626Vault" });
        return address(vault);
    }
}

/// @dev Mock ERC4626 vault for testing
contract MockERC4626Vault {
    address public immutable asset;

    constructor(address _asset) {
        asset = _asset;
    }
}
