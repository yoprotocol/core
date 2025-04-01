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
import { MarketParams } from "@morpho-blue/interfaces/IMorpho.sol";

import { ctVault } from "src/ctVault/ctVault.sol";
import { LendingConfig } from "src/ctVault/Types.sol";

import { IOracle } from "src/ctVault/interfaces/IOracle.sol";
import { UniswapRouter } from "src/ctVault/swap/UniswapRouter.sol";
import { EulerStrategy } from "src/ctVault/strategies/EulerStrategy.sol";
import { MorphoAdapter } from "src/ctVault/lendingAdapters/MorphoAdapter.sol";
import { FixedPriceOracle } from "src/ctVault/oracles/FixedPriceOracle.sol";
import { ctVaultAssetOracle } from "src/ctVault/oracles/ctVaultAssetOracle.sol";

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
        deployLendingAdapter();
        deployStrategies();

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

    function deployOracles() internal returns (IOracle usdcOracle, IOracle cbBTCOracle) {
        usdcOracle = new FixedPriceOracle(1e18, 6);
        address cbBTCUsdChainlinkFeed = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
        cbBTCOracle = new ctVaultAssetOracle(cbBTCUsdChainlinkFeed, 8);
    }

    function deployStrategies() internal {
        address euler = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;
        address rewardDistributor = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
        EulerStrategy strategy = new EulerStrategy(address(vault), users.admin, euler, rewardDistributor);
        vault.addStrategy(strategy, 100_000e6); // 100k USDC
    }

    function deployLendingAdapter() internal {
        address morpho = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

        MarketParams memory marketParams = MarketParams({
            loanToken: address(usdc),
            collateralToken: address(cbBTC),
            oracle: 0xA6D6950c9F177F1De7f7757FB33539e3Ec60182a,
            irm: 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC,
            lltv: 860_000_000_000_000_000
        });
        MorphoAdapter lendingAdapter = new MorphoAdapter(address(vault), morpho, marketParams);

        vault.setLendingProtocol(
            0,
            lendingAdapter,
            LendingConfig({
                maxAllocation: 1_000_000_000, // 10 cbBTC
                targetLTV: 600_000_000_000_000_000, // 60%
                minLTV: 250_000_000_000_000_000, // 25%
                maxLTV: 600_000_000_000_000_000 // 80%
             })
        );
    }

    function deploySwapRouter() internal returns (UniswapRouter) {
        uint24 fee = 3000;
        address uniswapV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
        return new UniswapRouter(fee, uniswapV3Router);
    }

    function deployVault() internal {
        (IOracle usdcOracle, IOracle cbBTCOracle) = deployOracles();

        ctVault impl = new ctVault(address(usdcOracle), address(cbBTCOracle));

        UniswapRouter swapRouter = deploySwapRouter();

        bytes memory data = abi.encodeWithSelector(
            ctVault.initialize.selector,
            cbBTC,
            users.admin,
            "ctBTCVault",
            "ctBTC",
            usdc,
            swapRouter,
            100e6, // 100 USDC
            0, // disable
            300 // 3%
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), users.admin, data);
        vault = ctVault(payable(address(proxy)));

        authority = new MockAuthority(users.admin, Authority(address(0)));
        vault.setAuthority({ newAuthority: authority });

        MockAuthority(address(authority)).setUserRole(users.admin, ADMIN_ROLE, true);
    }
}
