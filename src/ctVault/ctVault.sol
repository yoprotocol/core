// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "forge-std/console.sol";

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
        IERC20 _investmentAsset
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
    }

    // TODO: max deposit must be the value of the remaining allocation across all lending strategies
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    )
        internal
        override
        whenNotPaused
    {
        CtVaultStorage storage $ = CtVaultStorageLib._getCtVaultStorage();

        _sync();

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

        if ($.syncCooldown == 0 || ($.lastSyncTimestamp + $.syncCooldown > block.timestamp)) {
            return false;
        }
        $.lastSyncTimestamp = uint40(block.timestamp);

        return LendingModule._sync() && InvestmentModule._sync();
    }
}
