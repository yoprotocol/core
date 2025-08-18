// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { Errors } from "./libraries/Errors.sol";
import { IYoVault } from "./interfaces/IYoVault.sol";
import { IYoGateway } from "./interfaces/IYoGateway.sol";
import { IYoRegistry } from "./interfaces/IYoRegistry.sol";

/// __     __    _____       _
/// \ \   / /   / ____|     | |
///  \ \_/ /__ | |  __  __ _| |_ _____      ____ _ _   _
///   \   / _ \| | |_ |/ _` | __/ _ \ \ /\ / / _` | | | |
///    | | (_) | |__| | (_| | ||  __/\ V  V / (_| | |_| |
///    |_|\___/ \_____|\__,_|\__\___| \_/\_/ \__,_|\__, |
///                                                 __/ |
///                                                |___/
/// @title YoGateway
/// @notice Single entrypoint for deposits and redemption requests across allow-listed YO ERC-4626 vaults.
///         - deposit(assets→shares) and redeem(shares→assets).
///         - Emits partnerId for attribution; does NOT manage partner registries or fees.
///         - Uses YoRegistry to manage allow-listed vaults.
///
/// Assumptions:
///  - redeem may be async (returns 0 when routed to the vault's requestRedeem). Gateway is oblivious; assets are
/// delivered by the vault.
///  - For third-party redemption (owner != sender), owner must approve the gateway to transfer shares.

contract YoGateway is ReentrancyGuardUpgradeable, IYoGateway {
    using SafeERC20 for IERC20;

    IYoRegistry public registry;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _registry) public initializer {
        registry = IYoRegistry(_registry);
    }

    function deposit(
        address yoVault,
        uint256 assets,
        uint256 minSharesOut,
        address receiver,
        uint32 partnerId
    )
        external
        nonReentrant
        returns (uint256 sharesOut)
    {
        require(assets > 0, Errors.Gateway__ZeroAmount());
        require(receiver != address(0), Errors.Gateway__ZeroReceiver());
        require(registry.isYoVault(yoVault), Errors.Gateway__VaultNotAllowed());

        address asset = IERC4626(yoVault).asset();
        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);
        IERC20(asset).forceApprove(yoVault, assets);

        sharesOut = IERC4626(yoVault).deposit(assets, receiver);

        if (sharesOut < minSharesOut) {
            revert Errors.Gateway__InsufficientSharesOut(sharesOut, minSharesOut);
        }

        emit YoGatewayDeposit(partnerId, yoVault, msg.sender, receiver, assets, sharesOut);
    }

    function redeem(
        address yoVault,
        uint256 shares,
        uint256 minAssetsOut,
        address receiver,
        uint32 partnerId
    )
        external
        nonReentrant
        returns (uint256 assetsOrRequestId)
    {
        require(shares > 0, Errors.Gateway__ZeroAmount());
        require(receiver != address(0), Errors.Gateway__ZeroReceiver());
        require(registry.isYoVault(yoVault), Errors.Gateway__VaultNotAllowed());

        IERC20(yoVault).safeTransferFrom(receiver, address(this), shares);
        assetsOrRequestId = IYoVault(yoVault).requestRedeem(shares, receiver, address(this));

        bool instant = assetsOrRequestId > 0;

        // If the redemption is instant, we need to check if the assets out is greater than the minimum assets out
        if (instant && assetsOrRequestId < minAssetsOut) {
            revert Errors.Gateway__InsufficientAssetsOut(assetsOrRequestId, minAssetsOut);
        }

        emit YoGatewayRedeem(partnerId, yoVault, receiver, shares, assetsOrRequestId, instant);
    }

    function quoteConvertToShares(address yoVault, uint256 assets) external view returns (uint256) {
        require(registry.isYoVault(yoVault), Errors.Gateway__VaultNotAllowed());
        return IERC4626(yoVault).convertToShares(assets);
    }

    function quoteConvertToAssets(address yoVault, uint256 shares) external view returns (uint256) {
        require(registry.isYoVault(yoVault), Errors.Gateway__VaultNotAllowed());
        return IERC4626(yoVault).convertToAssets(shares);
    }

    function quotePreviewDeposit(address yoVault, uint256 assets) external view returns (uint256) {
        require(registry.isYoVault(yoVault), Errors.Gateway__VaultNotAllowed());
        return IERC4626(yoVault).previewDeposit(assets);
    }

    function quotePreviewRedeem(address yoVault, uint256 shares) external view returns (uint256) {
        require(registry.isYoVault(yoVault), Errors.Gateway__VaultNotAllowed());
        return IERC4626(yoVault).previewRedeem(shares);
    }

    /// @notice Returns the current allowance of `owner` for shares of the given yoVault to this gateway.
    function getShareAllowance(address yoVault, address owner) external view returns (uint256) {
        return IERC20(yoVault).allowance(owner, address(this));
    }

    /// @notice Returns the current allowance of `owner` for the underlying asset of the given yoVault to this gateway.
    function getAssetAllowance(address yoVault, address owner) external view returns (uint256) {
        require(registry.isYoVault(yoVault), Errors.Gateway__VaultNotAllowed());
        address asset = IERC4626(yoVault).asset();
        return IERC20(asset).allowance(owner, address(this));
    }
}
