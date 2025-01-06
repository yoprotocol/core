// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "./libraries/Errors.sol";
import { IyoVault } from "./interfaces/IyoVault.sol";

import { Auth, Authority } from "@solmate/auth/Auth.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

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
contract yoVault is ERC4626, IyoVault, Auth, Pausable {
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
    /// @dev the last price per share calculated after the aggregated underlying balances are reported
    uint256 public lastPricePerShare;
    /// @dev the maximum percentage change allowed before the vault is paused. It can be updated by the owner.
    /// 1e18 = 100%. It's value depends on the frequency of the oracle updates.
    uint256 public maxPercentageChange;
    /// @dev the fee charged for the vault operations, it's a percentage of the assets redeemed
    uint256 public fee;
    /// @dev the address that receives the fees for the vault operations, if it's zero, no fees are charged
    address public feeRecipient;

    /// @dev used to store the amount of shares that are pending redemption, it must be fulfilled by the vault operator
    mapping(address user => PendingRedeem redeem) internal _pendingRedeem;
    /// @dev used to store the amount of shares and assets that are claimable by the controller through withdraw or
    /// redeem
    mapping(address user => ClaimableRedeem claimable) internal _claimableRedeem;

    //============================== CONSTRUCTOR ===============================

    /// @dev the authority is set later by the owner through setAuthority
    constructor(
        IERC20 _asset,
        address _owner,
        string memory _name,
        string memory _symbol
    )
        ERC4626(_asset)
        ERC20(_name, _symbol)
        Auth(_owner, Authority(address(0)))
    {
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
            Authority(authority).canCall(msg.sender, target, functionSig),
            Errors.TargetMethodNotAuthorized(target, functionSig)
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
                Authority(authority).canCall(msg.sender, targets[i], functionSig),
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
    /// @param controller The address of the controller. The controller can withdraw the
    /// assets once the request is fulfilled.
    /// @param owner The address of the owner.
    /// @return requestId The ID of the request which is always 0 or the assets amount if the request is fulfilled
    /// immediately.
    function requestRedeem(
        uint256 shares,
        address controller,
        address owner
    )
        external
        whenNotPaused
        returns (uint256 requestId)
    {
        require(shares > 0, Errors.SharesAmountZero());
        require(owner == msg.sender, Errors.NotSharesOwner());
        require(balanceOf(owner) >= shares, Errors.InsufficientShares());

        uint256 assets = previewRedeem(shares);
        if (IERC20(asset()).balanceOf(address(this)) >= assets) {
            _withdraw(msg.sender, owner, owner, assets, shares);
            return assets;
        }

        emit RedeemRequest(controller, owner, 0, msg.sender, shares);

        IERC20(address(this)).safeTransferFrom(owner, address(this), shares);

        _pendingRedeem[controller] = PendingRedeem(shares + _pendingRedeem[controller].shares);

        return REQUEST_ID;
    }

    /// @notice The operator can fulfill a redeem request. Requires authorization.
    /// @param controller The address of the controller (can initiate the withdraw).
    /// @param shares The amount of shares to redeem.
    /// @return assets The amount of assets redeemed.
    function fulfillRedeem(address controller, uint256 shares) external requiresAuth returns (uint256 assets) {
        PendingRedeem storage pending = _pendingRedeem[controller];
        require(pending.shares != 0 && shares <= pending.shares, Errors.InvalidSharesAmount());

        assets = convertToAssets(shares);

        _claimableRedeem[controller] =
            ClaimableRedeem(_claimableRedeem[controller].assets + assets, _claimableRedeem[controller].shares + shares);

        pending.shares -= shares;
    }

    /// @notice The oracle can update the aggregated underlying balances across all strategies/chains.
    /// @param newAggregatedBalance The new aggregated underlying balances.
    function onUnderlyingBalanceUpdate(uint256 newAggregatedBalance) external requiresAuth {
        emit UnderlyingBalanceUpdated(aggregatedUnderlyingBalances, newAggregatedBalance);
        aggregatedUnderlyingBalances = newAggregatedBalance;

        /// @dev the price per share is calculated taking into account the new aggregated underlying balances
        uint256 newPricePerShare = totalAssets().mulDiv(DENOMINATOR, totalSupply());
        uint256 percentageChange = _calculatePercentageChange(lastPricePerShare, newPricePerShare);

        /// @dev Pause the vault if the percentage change is greater than the threshold (works in both directions)
        if (percentageChange > maxPercentageChange) {
            _pause();
        } else {
            lastPricePerShare = newPricePerShare;
        }
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
    function updateFee(uint256 newFee) external requiresAuth {
        require(newFee < MAX_FEE, Errors.InvalidFee());
        emit FeeUpdated(fee, newFee);
        fee = newFee;
    }

    /// @notice Update the address that receives the fees for the vault operations.
    /// @param newFeeRecipient The new address that receives the fees for the vault operations.
    function updateFeeRecipient(address newFeeRecipient) external requiresAuth {
        emit FeeRecipientUpdated(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    //============================== VIEW FUNCTIONS ===============================

    /// @notice Get the amount of shares that are pending redemption.
    /// @param controller The address of the controller.
    function pendingRedeemRequest(address controller) public view returns (uint256 pendingShares) {
        return _pendingRedeem[controller].shares;
    }

    /// @notice Get the amount of shares and assets that are claimable.
    /// @param controller The address of the controller.
    function claimableRedeemRequest(address controller) public view returns (uint256 shares, uint256 assets) {
        return (_claimableRedeem[controller].shares, _claimableRedeem[controller].assets);
    }

    //============================== OVERRIDES ===============================

    /// @notice Override the default `totalAssets` function to return the total assets held by the vault and the
    /// aggregated underlying balances across all strategies/chains.
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this)) + aggregatedUnderlyingBalances;
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
    /// @param assets The amount of assets to withdraw.
    /// @param receiver The address to receive the assets.
    /// @param controller The address of the controller.
    function withdraw(
        uint256 assets,
        address receiver,
        address controller
    )
        public
        override
        whenNotPaused
        returns (uint256)
    {
        require(assets != 0, Errors.AssetsAmountZero());
        require(controller == msg.sender, Errors.NotSharesOwner());

        ClaimableRedeem storage claimable = _claimableRedeem[controller];
        require(claimable.assets >= assets, Errors.InsufficientAssets());

        uint256 shares = assets.mulDiv(claimable.shares, claimable.assets, Math.Rounding.Floor);
        uint256 sharesUp = assets.mulDiv(claimable.shares, claimable.assets, Math.Rounding.Ceil);

        claimable.assets -= assets;
        // handle partial withdraw and prevent underflow in case of precision loss with the ceil rounding
        // we want to burn floor shares but reduce the claimable shares by the ceil value
        claimable.shares = claimable.shares > sharesUp ? claimable.shares - sharesUp : 0;

        _withdraw(address(this), receiver, address(this), assets, shares);

        return shares;
    }

    /// @notice It allows the controller to redeem shares from the vault and transfer the assets to the receiver. A
    /// claimable redeem is required which is created when a redeem request is fulfilled by the operator.
    /// @param shares The amount of shares to redeem.
    /// @param receiver The address to receive the assets.
    /// @param controller The address of the controller.
    function redeem(
        uint256 shares,
        address receiver,
        address controller
    )
        public
        override
        whenNotPaused
        returns (uint256)
    {
        require(shares != 0, Errors.SharesAmountZero());
        require(controller == msg.sender, Errors.NotSharesOwner());

        ClaimableRedeem storage claimable = _claimableRedeem[controller];
        require(claimable.shares >= shares, Errors.InsufficientShares());

        uint256 assets = shares.mulDiv(claimable.assets, claimable.shares, Math.Rounding.Floor);
        uint256 assetsUp = shares.mulDiv(claimable.assets, claimable.shares, Math.Rounding.Ceil);

        // handle partial redeem and prevent underflow in case of precision loss with the ceil rounding
        // we want to send floor assets but reduce the claimable assets by the ceil value
        claimable.assets = claimable.assets > assetsUp ? claimable.assets - assetsUp : 0;
        claimable.shares -= shares;

        _withdraw(address(this), receiver, address(this), assets, shares);

        return assets;
    }

    /// @dev Override the default `_update` function to add the `whenNotPaused` modifier.
    /// The _update function is called on all transfers, mints and burns.
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }

    /// @dev Account for the fee charged for the vault operations if the fee recipient and fee are set.
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    )
        internal
        override
    {
        uint256 feeAmount = 0;
        if (feeRecipient != address(0) && fee != 0) {
            feeAmount = assets.mulDiv(fee, DENOMINATOR, Math.Rounding.Floor);
            IERC20(asset()).safeTransfer(feeRecipient, feeAmount);
        }
        super._withdraw(caller, receiver, owner, assets - feeAmount, shares);
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

    //============================== RECEIVE ===============================

    /// @notice Fallback function to receive native assets.
    receive() external payable { }
}
