// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Repayment } from "./Types.sol";
import { ISwap } from "./interfaces/ISwap.sol";

import { AuthUpgradeable, Authority } from "../base/AuthUpgradable.sol";

import { ConfigModule } from "./modules/ConfigModule.sol";
import { LendingModule } from "./modules/LendingModule.sol";
import { InvestmentModule } from "./modules/InvestmentModule.sol";

import { Events } from "./libraries/Events.sol";
import { Errors } from "./libraries/Errors.sol";
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
    AuthUpgradeable,
    ConfigModule,
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
        ISwap _swapRouter,
        uint256 _harvestThreshold,
        uint40 _slippageTolerance
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
        $.harvestThreshold = _harvestThreshold;
        $.slippageTolerance = _slippageTolerance;
    }

    function mint(uint256 shares, address receiver) public override whenNotPaused returns (uint256) {
        _sync();
        return super.mint(shares, receiver);
    }

    function deposit(uint256 assets, address receiver) public override whenNotPaused returns (uint256) {
        _sync();
        return super.deposit(assets, receiver);
    }

    function redeem(uint256 shares, address receiver, address owner) public override whenNotPaused returns (uint256) {
        _sync();
        return super.redeem(shares, receiver, owner);
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

    function totalAssetsSynced() public view returns (uint256) {
        uint256 invested = getTotalInvested();
        (uint256 borrowed, uint256 collateral) = getState();
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
        return collateral + idleCollateral + earnings - losses;
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

        return collateral + idleCollateral + earnings - losses;
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

        // if idle assets is less than the requested assets, we must divest from strategies
        if (idleCollateral < assets) {
            Repayment[] memory repayments = _getRepayments(assets - idleCollateral);

            for (uint256 i; i < repayments.length; i++) {
                Repayment memory repayment = repayments[i];
                if (repayment.amount > 0) {
                    // divest the assets from strategies to repay the debt
                    uint256 divested = InvestmentModule._divestUpTo(repayment.amount);

                    // repay the debt
                    IERC20($.investmentAsset).forceApprove(address(repayment.adapter), divested);
                    uint256 repaid = repayment.adapter.repay(divested);
                    $.totalBorrowed -= repaid;

                    // remove the collateral
                    $.totalCollateral -= repayment.collateral;
                    repayment.adapter.removeCollateral(repayment.collateral);
                }
            }
        }

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /// @notice Syncs the vault's state with the lending and investment modules.
    function sync() external {
        _sync();
    }

    // TODO: max deposit must be the value of the remaining allocation across all lending strategies
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        super._deposit(caller, receiver, assets, shares);

        (uint256 totalBorrowed,) = LendingModule._onDeposit(assets);

        if ($.autoInvest) {
            InvestmentModule._investOnDeposit(totalBorrowed);
        }
    }

    function _sync() internal override(InvestmentModule, LendingModule) {
        LendingModule._sync();
        InvestmentModule._sync();
    }

    function rescueFunds(address token, uint256 amount) external requiresAuth {
        if (token == address(0)) {
            (bool success,) = payable(msg.sender).call{ value: amount }("");
            require(success, Errors.Common_CannotRescueFunds(address(0)));
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }
    }

    /// @notice Harvests earnings from investments if they exceed the threshold
    /// @return The amount of earnings harvested
    function harvest(bool addToCollateral) external requiresAuth returns (uint256) {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        uint256 invested = getTotalInvested();
        uint256 borrowed = getTotalBorrowed();

        // check if we have any earnings to harvest
        if (invested <= borrowed) {
            return 0;
        }

        uint256 earnings = invested - borrowed;
        if (earnings < $.harvestThreshold) {
            return 0;
        }

        uint256 divestedEarnings = InvestmentModule._divestUpTo(earnings);
        uint256 earningsValue = bOracle.getValue(divestedEarnings);
        uint256 expectedOutput = cOracle.getAmount(earningsValue);
        uint256 minOutput = expectedOutput.mulDiv(SLIPPAGE_PRECISION - $.slippageTolerance, SLIPPAGE_PRECISION);

        IERC20($.investmentAsset).forceApprove(address($.swapRouter), earnings);
        uint256 harvestedAmount =
            $.swapRouter.swapExactTokensForTokens(address($.investmentAsset), address(asset()), earnings, minOutput);

        if (addToCollateral) {
            // add the harvested amount to the collateral and borrow assets
            (uint256 totalBorrowed,) = LendingModule._onDeposit(harvestedAmount);
            if ($.autoInvest) {
                InvestmentModule._investOnDeposit(totalBorrowed);
            }
        }

        emit Events.Harvest(earnings, harvestedAmount, addToCollateral);
        return harvestedAmount;
    }
}
