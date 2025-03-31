// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "forge-std/console.sol";

import { Strategy, LendingConfig, LendingAction, LendingActionType } from "./Types.sol";

import { IctVault } from "./interfaces/IctVault.sol";
import { IStrategy } from "./interfaces/IStrategy.sol";
import { ILendingAdapter } from "./interfaces/ILendingAdapter.sol";

import { LendingModule } from "./modules/LendingModule.sol";
import { Compatible } from "../base/Compatible.sol";
import { AuthUpgradeable, Authority } from "../base/AuthUpgradable.sol";

import { Errors } from "./libraries/Errors.sol";
import { Events } from "./libraries/Events.sol";

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
contract ctVault is IctVault, AuthUpgradeable, LendingModule, ERC4626Upgradeable, Compatible, PausableUpgradeable {
    using Math for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    /// @notice the maximum number of strategies that can be used
    uint256 public constant MAX_STRATEGIES = 20;
    /// @notice the maximum number of lending protocols that can be used
    uint256 public constant MAX_LENDING_PROTOCOLS = 5;

    /// @notice total amount of assets invested
    uint256 public totalInvested;
    /// @notice total amount of assets borrowed
    uint256 public totalBorrowed;
    /// @notice total amount of assets collateralized
    uint256 public totalCollateral;

    /// @dev Packed in a single storage slot (96 + 40 + 40 + 8 = 184 bits)
    /// @notice fee minted to the treasury and deducted from the earnings
    uint96 public performanceFee;
    /// @notice cooldown period for the sync function
    uint40 public syncCooldown;
    /// @notice timestamp of the last sync
    uint40 public lastSyncTimestamp;
    /// @notice whether to automatically invest the assets on deposit or not
    bool public autoInvest;

    /// @notice the address that receives the fees
    address public feeRecipient;

    /// @notice the address of the investment token
    address public investmentAsset;

    /// @notice state of each strategy
    mapping(address strategy => Strategy state) public strategies;
    mapping(ILendingAdapter adapter => LendingConfig config) public lendingAdaptersConfig;

    /// @notice the list of lending protocols
    ILendingAdapter[] public lendingAdapters;
    // @notice the list of strategies used to invest the assets
    address[] public investQueue;
    // @notice the list of strategies used to divest the assets
    address[] public divestQueue;

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
        address _investmentAsset
    )
        public
        initializer
    {
        __ERC20_init(_name, _symbol);
        __ERC4626_init(_asset);
        __Auth_init(_owner, Authority(address(0)));
        __Pausable_init();

        autoInvest = true;
        investmentAsset = _investmentAsset;
    }

    function setLendingProtocol(
        uint256 _index,
        ILendingAdapter _adapter,
        LendingConfig calldata _config
    )
        external
        requiresAuth
    {
        if (_index >= MAX_LENDING_PROTOCOLS) {
            revert Errors.MaxQueueLengthExceeded();
        }

        if (_index == lendingAdapters.length) {
            lendingAdapters.push(_adapter);
        } else {
            lendingAdapters[_index] = _adapter;
        }

        lendingAdaptersConfig[_adapter] = _config;

        emit Events.LendingAdapterUpdated(msg.sender, address(_adapter), _index);
    }

    /// @inheritdoc IctVault
    function setInvestQueue(address[] calldata _investQueue) external requiresAuth {
        uint256 length = _investQueue.length;

        if (length > MAX_STRATEGIES) {
            revert Errors.MaxQueueLengthExceeded();
        }

        for (uint256 i; i < length; ++i) {
            if (strategies[_investQueue[i]].maxAllocation == 0) {
                revert Errors.UnauthorizedStrategy(_investQueue[i]);
            }
        }

        investQueue = _investQueue;

        emit Events.UpdateInvestQueue(msg.sender, _investQueue);
    }

    /// @inheritdoc IctVault
    function updateDivestQueue(uint256[] calldata _indices) external requiresAuth {
        uint256 newLength = _indices.length;
        uint256 length = divestQueue.length;

        if (newLength > MAX_STRATEGIES) {
            revert Errors.MaxQueueLengthExceeded();
        }

        bool[] memory seen = new bool[](length);
        address[] memory newDivestQueue = new address[](newLength);

        for (uint256 i; i < newLength; ++i) {
            uint256 prevIndex = _indices[i];

            address strategy = divestQueue[prevIndex];
            if (seen[prevIndex]) {
                revert Errors.DuplicatedStrategy(strategy);
            }
            seen[prevIndex] = true;
            newDivestQueue[i] = strategy;
        }

        for (uint256 i; i < length; ++i) {
            if (!seen[i]) {
                address strategy = divestQueue[i];
                Strategy memory strategyState = strategies[strategy];

                if (strategyState.allocated > 0) {
                    revert Errors.StrategyHasAssets(strategy);
                }

                if (strategyState.maxAllocation != 0) {
                    revert Errors.CannotRemoveActiveStrategy(strategy);
                }

                delete strategies[strategy];
            }
        }

        divestQueue = newDivestQueue;
        emit Events.UpdateDivestQueue(msg.sender, newDivestQueue);
    }

    /// @inheritdoc IctVault
    function addStrategy(address _strategy, uint248 _maxAllocation) external requiresAuth {
        if (strategies[_strategy].maxAllocation != 0) {
            revert Errors.StrategyAlreadyExists(_strategy);
        }

        if (_maxAllocation == 0) {
            revert Errors.InvalidMaxAllocation();
        }

        strategies[_strategy] = Strategy({ maxAllocation: _maxAllocation, enabled: true, allocated: 0 });

        investQueue.push(_strategy);
        if (investQueue.length > MAX_STRATEGIES) {
            revert Errors.MaxQueueLengthExceeded();
        }

        divestQueue.push(_strategy);
        if (divestQueue.length > MAX_STRATEGIES) {
            revert Errors.MaxQueueLengthExceeded();
        }

        emit Events.StrategyAdded(msg.sender, _strategy, _maxAllocation);
    }

    // TODO: max deposit must be the value of the remaining allocation across all lending strategies
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        _sync();
        super._deposit(caller, receiver, assets, shares);

        uint256 remaining = assets;
        uint256 _totalBorrowed = 0;
        uint256 _totalCollateral = 0;
        console.log("VAULT:: total collateral", remaining);
        for (uint256 i; i < lendingAdapters.length && remaining > 0; i++) {
            ILendingAdapter adapter = ILendingAdapter(lendingAdapters[i]);
            LendingConfig memory config = lendingAdaptersConfig[adapter];

            uint256 currentCollateral = adapter.getCollateral();
            uint256 maxAllowedCollateral = config.maxAllocation;

            // If the adapter is already full, skip it
            if (currentCollateral >= maxAllowedCollateral) {
                continue;
            }

            uint256 capacity;
            uint256 depositAmount;
            unchecked {
                capacity = maxAllowedCollateral - currentCollateral;
                depositAmount = remaining > capacity ? capacity : remaining;
                remaining -= depositAmount;
            }
            console.log("VAULT:: remaining to supply collateral", remaining);

            IERC20(asset()).forceApprove(address(adapter), depositAmount);
            _totalCollateral += depositAmount;
            adapter.addCollateral(depositAmount);

            uint256 desiredBorrowAmount = calculateBorrowAmount(depositAmount, config.targetLTV);
            console.log("VAULT:: target LTV", config.targetLTV);
            uint256 borrowLimit = adapter.getBorrowLimit();

            uint256 borrowAmount = desiredBorrowAmount > borrowLimit ? borrowLimit : desiredBorrowAmount;
            _totalBorrowed += adapter.borrow(borrowAmount);
            console.log("VAULT:: totalInvestAmount (borrowed)", _totalBorrowed);
        }
        totalBorrowed = _totalBorrowed;
        totalCollateral = _totalCollateral;

        if (autoInvest) {
            uint256 remainingToInvest = _totalBorrowed;
            for (uint256 i; i < investQueue.length; i++) {
                address strategy = investQueue[i];
                Strategy memory strategyState = strategies[strategy];

                // If the strategy is not enabled, skip it
                if (!strategyState.enabled) {
                    continue;
                }

                uint256 investCapacity = strategyState.maxAllocation - strategyState.allocated;
                uint256 investAmount = remainingToInvest > investCapacity ? investCapacity : remainingToInvest;
                remainingToInvest -= investAmount;

                IERC20(investmentAsset).forceApprove(address(strategy), investAmount);
                IStrategy(strategy).invest(investAmount);
                strategyState.allocated += investAmount;

                console.log("VAULT:: remainingToInvest", remainingToInvest);
            }
            totalInvested = _totalBorrowed - remainingToInvest;
        }

        console.log("VAULT:: totalInvested", totalInvested);
        console.log("VAULT:: totalCollateral", totalCollateral);
        console.log("VAULT:: totalBorrowed", totalBorrowed);
    }

    function sync() external returns (bool) {
        return _sync();
    }

    function _sync() internal returns (bool) {
        if (syncCooldown == 0 || (lastSyncTimestamp + syncCooldown > block.timestamp)) {
            return false;
        }
        lastSyncTimestamp = uint40(block.timestamp);

        uint256 _totalInvested = 0;
        uint256 _totalBorrowed = 0;
        uint256 _totalCollateral = 0;

        for (uint256 i; i < lendingAdapters.length; i++) {
            ILendingAdapter adapter = ILendingAdapter(lendingAdapters[i]);
            _totalBorrowed += adapter.getBorrowed();
            _totalCollateral += adapter.getCollateral();
        }

        for (uint256 i; i < investQueue.length; i++) {
            IStrategy strategy = IStrategy(investQueue[i]);
            Strategy memory strategyState = strategies[address(strategy)];
            _totalInvested += strategy.totalAssets();

            uint256 gains = 0;
            uint256 losses = 0;
            if (_totalInvested != strategyState.allocated) {
                // we have gains (yield)
                if (_totalInvested > strategyState.allocated) {
                    unchecked {
                        gains += _totalInvested - strategyState.allocated;
                    }
                }
                // we have losses
                else {
                    unchecked {
                        losses += strategyState.allocated - _totalInvested;
                    }
                }
                strategyState.allocated += gains - losses;
            }
        }

        totalInvested = _totalInvested;
        totalBorrowed = _totalBorrowed;
        totalCollateral = _totalCollateral;

        return true;
    }

    function getTotalInvested() public view returns (uint256) {
        uint256 _totalInvested = 0;
        for (uint256 i; i < investQueue.length; i++) {
            address strategy = investQueue[i];
            _totalInvested += strategies[strategy].allocated;
        }
        return _totalInvested;
    }
}
