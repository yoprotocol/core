// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { StrategyConfig, LendingConfig } from "./Types.sol";

import { IctVault } from "./interfaces/IctVault.sol";
import { ILendingAdapter } from "./interfaces/ILendingAdapter.sol";

import { LTVModule } from "./modules/LTVModule.sol";
import { Compatible } from "../base/Compatible.sol";
import { AuthUpgradeable, Authority } from "../base/AuthUpgradable.sol";

import { Errors } from "../libraries/Errors.sol";
import { Events } from "../libraries/Events.sol";

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
contract ctVault is IctVault, LTVModule, ERC4626Upgradeable, Compatible, AuthUpgradeable, PausableUpgradeable {
    using Math for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    uint256 public constant MAX_STRATEGIES = 20;
    uint256 public constant MAX_LENDING_PROTOCOLS = 5;

    /// @notice the target Loan-to-Value ratio for the vault
    uint256 public vaultTargetLtv;

    /// @notice fee minted to the treasury and deducted from the earnings
    uint256 public performanceFee;

    /// @notice the amount of assets lost due to bad investments
    uint256 investedAssetsLost;

    /// @notice stores the total borrowed assets (idle + invested) since the last update
    uint256 lastTotalInvestedAssets;

    /// @notice the address that receives the fees
    address public feeRecipient;

    bool public autoInvest;

    /// @notice configuration of each strategy
    mapping(address strategy => StrategyConfig config) public strategiesConfig;
    mapping(ILendingAdapter adapter => LendingConfig config) public lendingAdaptersConfig;

    /// @notice the list of lending protocols
    ILendingAdapter[] lendingAdapters;
    // @notice the list of strategies used to invest the assets
    address[] investQueue;
    // @notice the list of strategies used to divest the assets
    address[] divestQueue;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() LTVModule(address(0), address(0)) {
        _disableInitializers();
    }

    //============================== INITIALIZER ===============================
    function initialize(IERC20 _asset, address _owner, string memory _name, string memory _symbol) public initializer {
        __ERC20_init(_name, _symbol);
        __ERC4626_init(_asset);
        __Auth_init(_owner, Authority(address(0)));
        __Pausable_init();

        autoInvest = true;
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
            if (strategiesConfig[_investQueue[i]].maxAllocation == 0) {
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

                if (strategiesConfig[strategy].maxAllocation != 0) {
                    revert Errors.CannotRemoveActiveStrategy(strategy);
                }

                // TODO: check if the strategy has assets
                delete strategiesConfig[strategy];
            }
        }

        divestQueue = newDivestQueue;
        emit Events.UpdateDivestQueue(msg.sender, newDivestQueue);
    }

    /// @inheritdoc IctVault
    function addStrategy(address _strategy, uint248 _maxAllocation) external requiresAuth {
        if (strategiesConfig[_strategy].maxAllocation != 0) {
            revert Errors.StrategyAlreadyExists(_strategy);
        }

        if (_maxAllocation == 0) {
            revert Errors.InvalidMaxAllocation();
        }

        strategiesConfig[_strategy] = StrategyConfig({ maxAllocation: _maxAllocation, enabled: true });

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
        super._deposit(caller, receiver, assets, shares);

        uint256 remaining = assets;
        for (uint256 i; i < lendingAdapters.length && remaining > 0; i++) {
            ILendingAdapter adapter = ILendingAdapter(lendingAdapters[i]);
            uint256 currentCollateral = adapter.getCollateral();
            uint256 maxAllowedCollateral = lendingAdaptersConfig[lendingAdapters[i]].maxAllocation;

            // If the adapter is already full, skip it
            if (currentCollateral >= maxAllowedCollateral) {
                continue;
            }

            //TODO: see if we can use `unchecked` here
            uint256 capacity = maxAllowedCollateral - currentCollateral;
            uint256 depositAmount = remaining > capacity ? capacity : remaining;
            remaining -= depositAmount;
            adapter.addCollateral(depositAmount);

            uint256 desiredBorrowAmount = calculateBorrowAmount(depositAmount, vaultTargetLtv);
            uint256 borrowLimit = adapter.getBorrowLimit();

            uint256 borrowAmount = desiredBorrowAmount > borrowLimit ? borrowLimit : desiredBorrowAmount;
            adapter.borrow(borrowAmount);
        }

        if (autoInvest) { }
    }
}
