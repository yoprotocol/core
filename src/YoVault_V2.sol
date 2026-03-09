// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "./libraries/Errors.sol";
import { IYoVault } from "./interfaces/IYoVault.sol";
import { IYoOracle } from "./interfaces/IYoOracle.sol";

import { Compatible } from "./base/Compatible.sol";
import { AuthUpgradeable, Authority } from "./base/AuthUpgradeable.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// __   __    ____            _                  _
// \ \ / /__ |  _ \ _ __ ___ | |_ ___   ___ ___ | |
//  \ V / _ \| |_) | '__/ _ \| __/ _ \ / __/ _ \| |
//   | | (_) |  __/| | | (_) | || (_) | (_| (_) | |
//   |_|\___/|_|   |_|  \___/ \__\___/ \___\___/|_|
/// @title YoVault_V2 - Operator-managed ERC4626 vault with asynchronous redemptions.
/// @dev Extends ERC4626 with role-based access control and an async redeem mechanism.
/// Users call `requestRedeem` — if the vault holds enough assets the withdrawal is instant,
/// otherwise shares are escrowed until the operator calls `fulfillRedeem`.
/// Oracle-driven pricing: share conversions query `_oracleAsset()` via `ORACLE_ADDRESS`,
/// which subclasses can override to price against a different asset.

contract YoVault_V2 is ERC4626Upgradeable, Compatible, IYoVault, AuthUpgradeable, PausableUpgradeable {
    using Math for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    /// @dev Helper struct for reading an address from a storage slot.
    struct AddressSlot {
        address value;
    }

    /// @dev ERC-1967 implementation slot.
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev Non-fungible request sentinel — all pending redeems share ID 0.
    uint256 internal constant REQUEST_ID = 0;
    /// @dev 1e18 precision denominator for fee and percentage calculations.
    uint256 internal constant DENOMINATOR = 1e18;
    /// @dev Maximum allowed fee (10%).
    uint256 internal constant MAX_FEE = 1e17;
    /// @dev YoOracle contract used for share-price lookups.
    address public constant ORACLE_ADDRESS = 0x6E879d0CcC85085A709eBf5539224f53d0D396B0;

    /// @dev Deprecated — preserved for storage-layout compatibility.
    uint256 private deprecated_aggregatedUnderlyingBalances;
    /// @dev Deprecated — preserved for storage-layout compatibility.
    uint256 private deprecated_lastBlockUpdated;
    /// @dev Deprecated — preserved for storage-layout compatibility.
    uint256 private deprecated_lastPricePerShare;
    /// @notice Total assets locked in pending redemption requests.
    uint256 public totalPendingAssets;
    /// @dev Deprecated — preserved for storage-layout compatibility.
    uint256 private deprecated_maxPercentageChange;
    /// @notice Withdrawal fee as an 18-decimal fraction (e.g. 1e16 = 1%).
    uint256 public feeOnWithdraw;
    /// @notice Deposit fee as an 18-decimal fraction (e.g. 1e16 = 1%).
    uint256 public feeOnDeposit;
    /// @notice Recipient of collected fees. No fees are collected when zero.
    address public feeRecipient;

    /// @dev Per-user pending redemption state, fulfilled by the vault operator.
    mapping(address user => PendingRedeem redeem) internal _pendingRedeem;

    //============================== CONSTRUCTOR ===============================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    //============================== INITIALIZER ===============================
    function initialize(IERC20 _asset, address _owner, string memory _name, string memory _symbol) public initializer {
        __Context_init();
        __ERC20_init(_name, _symbol);
        __ERC4626_init(_asset);
        __Auth_init(_owner, Authority(address(0)));
        __Pausable_init();
    }

    // ========================================= PUBLIC FUNCTIONS =========================================

    /// @notice Execute an authorized call to an external contract.
    /// @param target Contract to call.
    /// @param data Calldata forwarded to `target`.
    /// @param value Native currency (wei) sent with the call.
    function manage(
        address target,
        bytes calldata data,
        uint256 value
    )
        external
        requiresAuth
        returns (bytes memory result)
    {
        bytes4 functionSig = bytes4(data);
        require(
            authority().canCall(msg.sender, target, functionSig), Errors.TargetMethodNotAuthorized(target, functionSig)
        );

        result = target.functionCallWithValue(data, value);
    }

    /// @notice Batch version of {manage} — execute multiple authorized calls atomically.
    /// @param targets Contracts to call.
    /// @param data Calldata arrays forwarded to each `target`.
    /// @param values Native currency (wei) sent with each call.
    function manage(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata values
    )
        external
        requiresAuth
        returns (bytes[] memory results)
    {
        uint256 targetsLength = targets.length;
        results = new bytes[](targetsLength);
        for (uint256 i; i < targetsLength; ++i) {
            bytes4 functionSig = bytes4(data[i]);
            require(
                authority().canCall(msg.sender, targets[i], functionSig),
                Errors.TargetMethodNotAuthorized(targets[i], functionSig)
            );
            results[i] = targets[i].functionCallWithValue(data[i], values[i]);
        }
    }

    /// @notice Pause deposits, withdrawals, and transfers.
    function pause() public requiresAuth {
        _pause();
    }

    /// @notice Resume deposits, withdrawals, and transfers.
    function unpause() public requiresAuth {
        _unpause();
    }

    /// @notice Request an asynchronous redemption of `shares`.
    /// If the vault holds enough liquid assets the withdrawal is executed instantly and the
    /// returned value equals the redeemed asset amount. Otherwise the shares are escrowed and
    /// `REQUEST_ID` (0) is returned — the operator must later call {fulfillRedeem}.
    /// @param shares Amount of shares to redeem.
    /// @param receiver Address that will receive the underlying assets.
    /// @param owner Share holder (must equal `msg.sender`).
    /// @return Asset amount on instant redemption, or `REQUEST_ID` (0) when queued.
    function requestRedeem(uint256 shares, address receiver, address owner) public whenNotPaused returns (uint256) {
        require(receiver != address(0), Errors.ZeroReceiver());
        require(shares > 0, Errors.SharesAmountZero());
        require(owner == msg.sender, Errors.NotSharesOwner());
        require(balanceOf(owner) >= shares, Errors.InsufficientShares());

        uint256 assetsWithFee = super.previewRedeem(shares);

        // instant redeem if the vault has enough assets
        if (_getAvailableBalance() >= assetsWithFee) {
            _withdraw(owner, receiver, owner, assetsWithFee, shares);
            emit RedeemRequest(receiver, owner, assetsWithFee, shares, true);
            return assetsWithFee;
        }

        emit RedeemRequest(receiver, owner, assetsWithFee, shares, false);
        // transfer the shares to the vault and store the request
        _transfer(owner, address(this), shares);

        totalPendingAssets += assetsWithFee;
        PendingRedeem storage pending = _pendingRedeem[receiver];
        pending.shares += shares;
        pending.assets += assetsWithFee;

        return REQUEST_ID;
    }

    /// @notice Fulfill a pending redemption — burns escrowed shares and transfers assets.
    /// @param receiver Address whose pending request is being fulfilled.
    /// @param shares Amount of escrowed shares to burn.
    /// @param assetsWithFee Gross asset amount (including withdrawal fee).
    function fulfillRedeem(address receiver, uint256 shares, uint256 assetsWithFee) external requiresAuth {
        PendingRedeem storage pending = _pendingRedeem[receiver];
        require(pending.shares != 0 && shares <= pending.shares, Errors.InvalidSharesAmount());
        require(pending.assets != 0 && assetsWithFee <= pending.assets, Errors.InvalidAssetsAmount());

        pending.shares -= shares;
        pending.assets -= assetsWithFee;
        totalPendingAssets -= assetsWithFee;

        emit RequestFulfilled(receiver, shares, assetsWithFee);
        // burn the shares from the vault and transfer the assets to the receiver
        _withdraw(address(this), receiver, address(this), assetsWithFee, shares);
    }

    /// @notice Cancel a pending redemption — returns escrowed shares to the receiver.
    /// @param receiver Address whose pending request is being cancelled.
    /// @param shares Amount of escrowed shares to return.
    /// @param assetsWithFee Gross asset amount to release from the pending total.
    function cancelRedeem(address receiver, uint256 shares, uint256 assetsWithFee) external requiresAuth {
        PendingRedeem storage pending = _pendingRedeem[receiver];
        require(pending.shares != 0 && shares <= pending.shares, Errors.InvalidSharesAmount());
        require(pending.assets != 0 && assetsWithFee <= pending.assets, Errors.InvalidAssetsAmount());

        pending.shares -= shares;
        pending.assets -= assetsWithFee;
        totalPendingAssets -= assetsWithFee;

        emit RequestCancelled(receiver, shares, assetsWithFee);
        // transfer the shares back to the owner
        _transfer(address(this), receiver, shares);
    }

    /// @notice Set the withdrawal fee. Must be below {MAX_FEE}.
    /// @param newFee New withdrawal fee as an 18-decimal fraction.
    function updateWithdrawFee(uint256 newFee) external requiresAuth {
        require(newFee < MAX_FEE, Errors.InvalidFee());
        emit WithdrawFeeUpdated(feeOnWithdraw, newFee);
        feeOnWithdraw = newFee;
    }

    /// @notice Set the deposit fee. Must be below {MAX_FEE}.
    /// @param newFee New deposit fee as an 18-decimal fraction.
    function updateDepositFee(uint256 newFee) external requiresAuth {
        require(newFee < MAX_FEE, Errors.InvalidFee());
        emit DepositFeeUpdated(feeOnDeposit, newFee);
        feeOnDeposit = newFee;
    }

    /// @notice Set the fee recipient. Pass `address(0)` to disable fee collection.
    /// @param newFeeRecipient Address that will receive future fees.
    function updateFeeRecipient(address newFeeRecipient) external requiresAuth {
        emit FeeRecipientUpdated(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    //============================== VIEW FUNCTIONS ===============================

    /// @notice Total assets under management, derived from oracle price and total share supply.
    function totalAssets() public view override returns (uint256) {
        (uint256 price,) = IYoOracle(ORACLE_ADDRESS).getLatestPrice(_oracleAsset());
        return price.mulDiv(super.totalSupply(), 10 ** decimals(), Math.Rounding.Floor);
    }

    /// @notice Oracle price per share, normalized to 18 decimals.
    function lastPricePerShare() public view returns (uint256 price) {
        (price,) = IYoOracle(ORACLE_ADDRESS).getLatestPrice(_oracleAsset());
        return price * (10 ** (18 - decimals()));
    }

    /// @notice Pending redemption state for a given user.
    /// @param user Address to query.
    function pendingRedeemRequest(address user) public view returns (uint256 assets, uint256 pendingShares) {
        return (_pendingRedeem[user].assets, _pendingRedeem[user].shares);
    }

    //============================== OVERRIDES ===============================

    /// @inheritdoc ERC4626Upgradeable
    /// @dev Reverts when paused.
    function deposit(uint256 assets, address receiver) public override whenNotPaused returns (uint256) {
        return super.deposit(assets, receiver);
    }

    /// @inheritdoc ERC4626Upgradeable
    /// @dev Reverts when paused.
    function mint(uint256 shares, address receiver) public override whenNotPaused returns (uint256) {
        return super.mint(shares, receiver);
    }

    /// @notice Disabled — always reverts. Use {requestRedeem} or {redeem} instead.
    function withdraw(uint256, address, address) public override whenNotPaused returns (uint256) {
        revert Errors.UseRequestRedeem();
    }

    /// @notice Delegates to {requestRedeem}.
    function redeem(uint256 shares, address receiver, address owner) public override whenNotPaused returns (uint256) {
        return requestRedeem(shares, receiver, owner);
    }

    /// @dev Enforces pause on all token movements (transfers, mints, burns).
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }

    /// @dev Oracle-driven asset→share conversion (ignores totalSupply/totalAssets).
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 pricePerShare,) = IYoOracle(ORACLE_ADDRESS).getLatestPrice(_oracleAsset());
        require(pricePerShare > 0, Errors.InvalidPrice());
        return assets.mulDiv(10 ** decimals(), pricePerShare, rounding);
    }

    /// @dev Oracle-driven share→asset conversion (ignores totalSupply/totalAssets).
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 pricePerShare,) = IYoOracle(ORACLE_ADDRESS).getLatestPrice(_oracleAsset());
        require(pricePerShare > 0, Errors.InvalidPrice());
        return shares.mulDiv(pricePerShare, 10 ** decimals(), rounding);
    }

    /// @notice Returns the ERC-1967 implementation address.
    function getImplementation() external view returns (address) {
        AddressSlot storage r;
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            r.slot := _IMPLEMENTATION_SLOT
        }
        return r.value;
    }

    /// @dev Fee-adjusted deposit preview. See {IERC4626-previewDeposit}.
    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        uint256 fee = _feeOnTotal(assets, feeOnDeposit);
        return super.previewDeposit(assets - fee);
    }

    /// @dev Fee-adjusted mint preview. See {IERC4626-previewMint}.
    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        uint256 assets = super.previewMint(shares);
        return assets + _feeOnRaw(assets, feeOnDeposit);
    }

    /// @dev Fee-adjusted withdraw preview. See {IERC4626-previewWithdraw}.
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        uint256 fee = _feeOnRaw(assets, feeOnWithdraw);
        return super.previewWithdraw(assets + fee);
    }

    /// @dev Fee-adjusted redeem preview. See {IERC4626-previewRedeem}.
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        uint256 assets = super.previewRedeem(shares);
        return assets - _feeOnTotal(assets, feeOnWithdraw);
    }

    /// @dev Returns 0 when paused. See {IERC4626-maxDeposit}.
    function maxDeposit(address receiver) public view virtual override returns (uint256) {
        if (paused()) {
            return 0;
        }
        return super.maxDeposit(receiver);
    }

    /// @dev Returns 0 when paused. See {IERC4626-maxMint}.
    function maxMint(address receiver) public view virtual override returns (uint256) {
        if (paused()) {
            return 0;
        }
        return super.maxMint(receiver);
    }

    /// @dev Returns 0 when paused. See {IERC4626-maxWithdraw}.
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        if (paused()) {
            return 0;
        }
        return super.maxWithdraw(owner);
    }

    /// @dev Returns 0 when paused. See {IERC4626-maxRedeem}.
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        if (paused()) {
            return 0;
        }
        return super.maxRedeem(owner);
    }

    /// @dev Deducts the withdrawal fee from `assetsWithFee` and transfers it to {feeRecipient}.
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assetsWithFee,
        uint256 shares
    )
        internal
        override
    {
        uint256 feeAmount = _feeOnTotal(assetsWithFee, feeOnWithdraw);
        uint256 assets = assetsWithFee - feeAmount;
        address recipient = feeRecipient;

        super._withdraw(caller, receiver, owner, assets, shares);

        if (feeAmount > 0 && recipient != address(0)) {
            IERC20(asset()).safeTransfer(recipient, feeAmount);
        }
    }

    /// @dev Deducts the deposit fee from `assets` and transfers it to {feeRecipient}.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual override {
        uint256 feeAmount = _feeOnTotal(assets, feeOnDeposit);
        address recipient = feeRecipient;

        super._deposit(caller, receiver, assets, shares);

        if (feeAmount > 0 && recipient != address(0)) {
            IERC20(asset()).safeTransfer(recipient, feeAmount);
        }
    }

    //============================== INTERNAL FUNCTIONS ===============================

    /// @dev Address passed to the oracle for share-price lookups.
    /// Override to price shares against a different asset (see {yoUSDT}).
    function _oracleAsset() internal view virtual returns (address) {
        return address(this);
    }

    /// @dev Fee to add on top of a raw (fee-exclusive) amount. Used by {previewMint} and {previewWithdraw}.
    function _feeOnRaw(uint256 assets, uint256 feeBasisPoints) internal pure returns (uint256) {
        return assets.mulDiv(feeBasisPoints, DENOMINATOR, Math.Rounding.Ceil);
    }

    /// @dev Fee portion already embedded in a gross (fee-inclusive) amount. Used by {previewDeposit} and
    /// {previewRedeem}.
    function _feeOnTotal(uint256 assets, uint256 feeBasisPoints) internal pure returns (uint256) {
        return assets.mulDiv(feeBasisPoints, feeBasisPoints + DENOMINATOR, Math.Rounding.Ceil);
    }

    /// @dev Liquid balance available for instant redemptions (total balance minus pending claims).
    function _getAvailableBalance() internal view returns (uint256) {
        uint256 balance = IERC20(asset()).balanceOf(address(this));
        return balance > totalPendingAssets ? balance - totalPendingAssets : 0;
    }
}
