// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "forge-std/console.sol";

import { Repayment } from "./Types.sol";
import { ISwap } from "./interfaces/ISwap.sol";

import { LendingModule } from "./modules/LendingModule.sol";
import { InvestmentModule } from "./modules/InvestmentModule.sol";
import { Compatible } from "../base/Compatible.sol";
import { AuthUpgradeable, Authority } from "../base/AuthUpgradable.sol";
import { CtVaultStorage, CtVaultStorageLib } from "./libraries/Storage.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

//  ██████╗████████╗██╗   ██╗ █████╗ ██╗   ██╗██╗     ████████╗
// ██╔════╝╚══██╔══╝██║   ██║██╔══██╗██║   ██║██║     ╚══██╔══╝
// ██║        ██║   ██║   ██║███████║██║   ██║██║        ██║
// ██║        ██║   ╚██╗ ██╔╝██╔══██║██║   ██║██║        ██║
// ╚██████╗   ██║    ╚████╔╝ ██║  ██║╚██████╔╝███████╗   ██║
//  ╚═════╝   ╚═╝     ╚═══╝  ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝
contract ctVault is
    Compatible,
    AuthUpgradeable,
    LendingModule,
    InvestmentModule,
    ERC4626Upgradeable,
    PausableUpgradeable
{
    using Math for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    /// @param _bOracle The address of the borrowed asset oracle
    /// @param _cOracle The address of the collateral asset oracle
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _bOracle, address _cOracle) LendingModule(_bOracle, _cOracle) {
        _disableInitializers();
    }

    //============================== INITIALIZER ===============================
    function initialize(
        IERC20 _asset,
        address _owner,
        string memory _name,
        string memory _symbol,
        IERC20 _investmentAsset,
        ISwap _swapRouter
    )
        public
        initializer
    {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        __ERC20_init(_name, _symbol);
        __ERC4626_init(_asset);
        __Auth_init(_owner, Authority(address(0)));
        __Pausable_init();

        $.autoInvest = true;
        $.investmentAsset = _investmentAsset;
        $.swapRouter = _swapRouter;
    }

    function totalAssets() public view override returns (uint256) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        uint256 invested = $.totalInvested;
        uint256 borrowed = $.totalBorrowed;
        uint256 collateral = $.totalCollateral;
        uint256 idleCollateral = super.totalAssets();

        uint256 losses;
        uint256 earnings;
        if (invested > borrowed) {
            earnings = invested - borrowed;
            earnings = convertToCollateral(earnings);
        } else {
            losses = borrowed - invested;
            losses = convertToCollateral(losses);
        }

        console.log("totalAssets:: invested", invested);
        console.log("totalAssets:: borrowed", borrowed);
        console.log("totalAssets:: losses", losses);
        console.log("totalAssets:: earnings", earnings);
        console.log("totalAssets:: collateral", collateral);
        console.log("totalAssets:: idleCollateral", idleCollateral);
        return collateral + idleCollateral + earnings - losses;
    }

    function deposit(uint256 assets, address receiver) public override whenNotPaused returns (uint256) {
        _sync();
        return super.deposit(assets, receiver);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        override
        whenNotPaused
        returns (uint256)
    {
        _sync();
        return super.withdraw(assets, receiver, owner);
    }

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
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        uint256 idleCollateral = super.totalAssets();
        console.log("VAULT::withdraw::idleCollateral", idleCollateral);
        // if idle assets is less than the requested assets, we must divest from strategies
        if (idleCollateral < assets) {
            Repayment[] memory repayments = _getRepayments(assets - idleCollateral);

            for (uint256 i; i < repayments.length; i++) {
                Repayment memory repayment = repayments[i];
                console.log("VAULT::withdraw::repayment", repayment.amount, repayment.collateral);
                if (repayment.amount > 0) {
                    uint256 divested = InvestmentModule._divestUpTo(repayment.amount);
                    console.log("VAULT::withdraw::divested", divested);
                    IERC20($.investmentAsset).forceApprove(address(repayment.adapter), divested);
                    repayment.adapter.repay(divested);
                    console.log("VAULT::withdraw::repayment.adapter.getCollateral()", repayment.collateral);
                    repayment.adapter.removeCollateral(repayment.collateral);
                }
            }
        }

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    // TODO: max deposit must be the value of the remaining allocation across all lending strategies
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        super._deposit(caller, receiver, assets, shares);

        (uint256 totalBorrowed,) = LendingModule._onDeposit(assets);

        if ($.autoInvest) {
            InvestmentModule._investOnDeposit(totalBorrowed);
        }

        console.log("VAULT:: totalInvested", $.totalInvested);
        console.log("VAULT:: totalCollateral", $.totalCollateral);
        console.log("VAULT:: totalBorrowed", $.totalBorrowed);
    }

    /// @notice Syncs the vault's state with the lending and investment modules.
    /// @return True if the sync was successful, false otherwise.
    function sync() external returns (bool) {
        return _sync();
    }

    function _sync() internal override(InvestmentModule, LendingModule) returns (bool) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        // we need to sync every time so we always have the latest debt and collateral values
        LendingModule._sync();

        if ($.lastSyncTimestamp + $.syncCooldown > block.timestamp) {
            return false;
        }
        $.lastSyncTimestamp = uint40(block.timestamp);

        return InvestmentModule._sync();
    }
}
