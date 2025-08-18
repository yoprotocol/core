// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "../libraries/Errors.sol";
import { IYoVault } from "../interfaces/IYoVault.sol";

import { Compatible } from "../base/Compatible.sol";
import { AuthUpgradeable, Authority } from "../base/AuthUpgradeable.sol";

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
/// @title yoVault - A simple vault contract that allows for an operator to manage the vault.
/// @dev This contract is based on the ERC4626 standard and uses the Auth contract for access control.
/// It provides an asynchronous redeem mechanism that allows users to request a redeem and the operator to fulfill it.
/// This would allow the operator to move funds to a different chain or strategy before the user can claim the assets.
/// If the vault has enough assets to fulfill the request, the assets are withdrawn and returned to the owner
/// immediately. Otherwise, the assets are transferred to the vault and the request is stored until the operator
/// fulfills it.

contract yoVault is ERC4626Upgradeable, Compatible, IYoVault, AuthUpgradeable, PausableUpgradeable {
    using Math for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    /// @dev Assume requests are non-fungible and all have ID = 0, so we can differentiate between a request ID and the
    /// assets amount.
    uint256 internal constant REQUEST_ID = 0;
    /// @dev The denominator used for precision calculations.
    uint256 internal constant DENOMINATOR = 1e18;
    /// @dev The maximum fee that can be set for the vault operations. 1e17 = 10%.
    uint256 internal constant MAX_FEE = 1e17;
    /// @dev The maximum percentage that can be set as a threshold for the percentage change. 1e17 = 10%
    uint256 internal constant MAX_PERCENTAGE_THRESHOLD = 1e17;

    /// @dev the aggregated underlying balances across all strategies/chains, reported by an oracle
    uint256 public aggregatedUnderlyingBalances;
    /// @dev the last block number when the aggregated underlying balances were updated
    uint256 public lastBlockUpdated;
    /// @dev the last price per share calculated after the aggregated underlying balances are reported
    uint256 public lastPricePerShare;
    /// @dev the total amount of assets that are pending redemption
    uint256 public totalPendingAssets;
    /// @dev the maximum percentage change allowed before the vault is paused. It can be updated by the owner.
    /// 1e18 = 100%. It's value depends on the frequency of the oracle updates.
    uint256 public maxPercentageChange;
    /// @dev the fee charged for the withdraws, it's a percentage of the assets redeemed
    uint256 public feeOnWithdraw;
    /// @dev the fee charged for the deposits, it's a percentage of the assets deposited
    uint256 public feeOnDeposit;
    /// @dev the address that receives the fees for the vault operations, if it's zero, no fees are charged
    address public feeRecipient;

    /// @dev used to store the amount of shares that are pending redemption, it must be fulfilled by the vault operator
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
        maxPercentageChange = 1e16; // 1%
    }

    // ========================================= PUBLIC FUNCTIONS =========================================

    /// @notice Allows the vault operator to manage the vault.
    /// @param target The target contract to make a call to.
    /// @param data The data to send to the target contract.
    /// @param value The amount of native assets to send with the call.
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

    /// @notice Same as `manage` but allows for multiple calls in a single transaction.
    /// @param targets The target contracts to make calls to.
    /// @param data The data to send to the target contracts.
    /// @param values The amounts of native assets to send with the calls.
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

    /// @notice Pause the contract to prevent any further deposits, withdrawals, or transfers.
    function pause() public requiresAuth {
        _pause();
    }

    /// @notice Unpause the contract to allow deposits, withdrawals, and transfers.
    function unpause() public requiresAuth {
        _unpause();
    }

    /// @notice If the vault has enough assets to fulfill the request,
    /// withdraw the assets and return them to the owner.
    /// Otherwise, transfer the shares to the vault and store the request.
    /// The shares are burned when the request is fulfilled and the assets are transferred to the owner.
    /// @param shares The amount of shares to redeem.
    /// @param receiver The address of the receiver of the assets.
    /// @param owner The address of the owner.
    /// @return The ID of the request which is always 0 or the assets amount if the request is immediately
    /// processed.
    function requestRedeem(uint256 shares, address receiver, address owner) external whenNotPaused returns (uint256) {
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

    /// @notice The operator can fulfill a redeem request. Requires authorization.
    /// @param receiver The address of the receiver of the assets.
    /// @param shares The amount of shares to fulfil.
    /// @param assetsWithFee The amount of assets to fulfil including the fee.
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

    /// @notice The operator can cancel a redeem request in case of an black swan event.
    /// @param receiver The address of the receiver of the assets.
    /// @param shares The amount of shares to cancel.
    /// @param assetsWithFee The amount of assets to cancel including the fee.
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

    /// @notice The oracle can update the aggregated underlying balances across all strategies/chains.
    /// @dev Can be called only once per block to prevent oracle abuse and flash loan attacks.
    /// @param newAggregatedBalance The new aggregated underlying balances.
    function onUnderlyingBalanceUpdate(uint256 newAggregatedBalance) external requiresAuth {
        require(block.number > lastBlockUpdated, Errors.UpdateAlreadyCompletedInThisBlock());

        /// @dev the price per share is calculated taking into account the new aggregated underlying balances
        uint256 newPricePerShare = _totalAssets(newAggregatedBalance).mulDiv(DENOMINATOR, totalSupply());
        uint256 percentageChange = _calculatePercentageChange(lastPricePerShare, newPricePerShare);

        /// @dev Pause the vault if the percentage change is greater than the threshold (works in both directions)
        if (percentageChange > maxPercentageChange) {
            _pause();
            return;
        }

        emit UnderlyingBalanceUpdated(aggregatedUnderlyingBalances, newAggregatedBalance);
        aggregatedUnderlyingBalances = newAggregatedBalance;

        lastPricePerShare = newPricePerShare;
        lastBlockUpdated = block.number;
    }

    /// @notice Update the maximum percentage change allowed before the vault is paused.
    /// @param newMaxPercentageChange The new maximum percentage change. Max value is 1e17 (10%).
    function updateMaxPercentageChange(uint256 newMaxPercentageChange) external requiresAuth {
        require(newMaxPercentageChange < MAX_PERCENTAGE_THRESHOLD, Errors.InvalidMaxPercentage());
        emit MaxPercentageUpdated(maxPercentageChange, newMaxPercentageChange);
        maxPercentageChange = newMaxPercentageChange;
    }

    /// @notice Update the fee charged for the vault operations.
    /// @param newFee The new fee charged for the vault operations.
    function updateWithdrawFee(uint256 newFee) external requiresAuth {
        require(newFee < MAX_FEE, Errors.InvalidFee());
        emit WithdrawFeeUpdated(feeOnWithdraw, newFee);
        feeOnWithdraw = newFee;
    }

    /// @notice Update the fee charged for the vault operations.
    /// @param newFee The new fee charged for the vault operations.
    function updateDepositFee(uint256 newFee) external requiresAuth {
        require(newFee < MAX_FEE, Errors.InvalidFee());
        emit DepositFeeUpdated(feeOnDeposit, newFee);
        feeOnDeposit = newFee;
    }

    /// @notice Update the address that receives the fees for the vault operations.
    /// @param newFeeRecipient The new address that receives the fees for the vault operations.
    function updateFeeRecipient(address newFeeRecipient) external requiresAuth {
        emit FeeRecipientUpdated(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    //============================== VIEW FUNCTIONS ===============================

    /// @notice Get the amount of assets and shares that are pending redemption.
    /// @param user The address of the user.
    function pendingRedeemRequest(address user) public view returns (uint256 assets, uint256 pendingShares) {
        return (_pendingRedeem[user].assets, _pendingRedeem[user].shares);
    }

    //============================== OVERRIDES ===============================

    /// @notice Override the default `totalAssets` function to return the total assets held by the vault and the
    /// aggregated underlying balances across all strategies/chains.
    function totalAssets() public view override returns (uint256) {
        return _totalAssets(aggregatedUnderlyingBalances);
    }

    /// @dev Override the default `deposit` function to add the `whenNotPaused` modifier.
    function deposit(uint256 assets, address receiver) public override whenNotPaused returns (uint256) {
        return super.deposit(assets, receiver);
    }

    /// @dev Override the default `mint` function to add the `whenNotPaused` modifier.
    function mint(uint256 shares, address receiver) public override whenNotPaused returns (uint256) {
        return super.mint(shares, receiver);
    }

    /// @notice It allows the controller to withdraw assets from the vault and burn the shares. A claimable redeem is
    /// required which is created when a redeem request is fulfilled by the operator.
    function withdraw(uint256, address, address) public override whenNotPaused returns (uint256) {
        revert Errors.UseRequestRedeem();
    }

    /// @notice It allows the controller to redeem shares from the vault and transfer the assets to the receiver. A
    /// claimable redeem is required which is created when a redeem request is fulfilled by the operator.
    function redeem(uint256, address, address) public override whenNotPaused returns (uint256) {
        revert Errors.UseRequestRedeem();
    }

    /// @dev Override the default `_update` function to add the `whenNotPaused` modifier.
    /// The _update function is called on all transfers, mints and burns.
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }

    /// @dev Preview taking an entry fee on deposit. See {IERC4626-previewDeposit}.
    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        uint256 fee = _feeOnTotal(assets, feeOnDeposit);
        return super.previewDeposit(assets - fee);
    }

    /// @dev Preview adding an entry fee on mint. See {IERC4626-previewMint}.
    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        uint256 assets = super.previewMint(shares);
        return assets + _feeOnRaw(assets, feeOnDeposit);
    }

    /// @dev Preview adding an exit fee on withdraw. See {IERC4626-previewWithdraw}.
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        uint256 fee = _feeOnRaw(assets, feeOnWithdraw);
        return super.previewWithdraw(assets + fee);
    }

    /// @dev Preview taking an exit fee on redeem. See {IERC4626-previewRedeem}.
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        uint256 assets = super.previewRedeem(shares);
        return assets - _feeOnTotal(assets, feeOnWithdraw);
    }

    function maxDeposit(address receiver) public view virtual override returns (uint256) {
        if (paused()) {
            return 0;
        }
        return super.maxDeposit(receiver);
    }

    function maxMint(address receiver) public view virtual override returns (uint256) {
        if (paused()) {
            return 0;
        }
        return super.maxMint(receiver);
    }

    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        if (paused()) {
            return 0;
        }
        return super.maxWithdraw(owner);
    }

    function maxRedeem(address owner) public view virtual override returns (uint256) {
        if (paused()) {
            return 0;
        }
        return super.maxRedeem(owner);
    }

    /// @dev Account for the fee charged for the vault operations if the fee recipient and fee are set.
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

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        uint256 feeAmount = _feeOnTotal(assets, feeOnDeposit);
        address recipient = feeRecipient;

        super._deposit(caller, receiver, assets, shares);

        if (feeAmount > 0 && recipient != address(0)) {
            IERC20(asset()).safeTransfer(recipient, feeAmount);
        }
    }

    function _totalAssets(uint256 _underlyingBalances) internal view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this)) + _underlyingBalances;
    }

    //============================== PRIVATE FUNCTIONS ===============================

    /// @dev Used to calculate the percentage change between two prices. 1e18 = 100%.
    /// @param oldPrice The old price.
    /// @param newPrice The new price.
    /// @return The percentage change. 1e18 = 100%.
    function _calculatePercentageChange(uint256 oldPrice, uint256 newPrice) private pure returns (uint256) {
        if (oldPrice == 0) {
            return 0;
        }
        uint256 diff = newPrice > oldPrice ? newPrice - oldPrice : oldPrice - newPrice;
        return diff.mulDiv(DENOMINATOR, oldPrice, Math.Rounding.Ceil);
    }

    /// @dev Calculates the fees that should be added to an amount `assets` that does not already include fees.
    /// Used in {IERC4626-mint} and {IERC4626-withdraw} operations.
    function _feeOnRaw(uint256 assets, uint256 feeBasisPoints) private pure returns (uint256) {
        return assets.mulDiv(feeBasisPoints, DENOMINATOR, Math.Rounding.Ceil);
    }

    /// @dev Calculates the fee part of an amount `assets` that already includes fees.
    /// Used in {IERC4626-deposit} and {IERC4626-redeem} operations.
    function _feeOnTotal(uint256 assets, uint256 feeBasisPoints) private pure returns (uint256) {
        return assets.mulDiv(feeBasisPoints, feeBasisPoints + DENOMINATOR, Math.Rounding.Ceil);
    }

    /// @dev The available balance is the balance of the vault minus the total pending assets.
    /// @return The available balance.
    function _getAvailableBalance() internal view returns (uint256) {
        uint256 balance = IERC20(asset()).balanceOf(address(this));
        return balance > totalPendingAssets ? balance - totalPendingAssets : 0;
    }
}
