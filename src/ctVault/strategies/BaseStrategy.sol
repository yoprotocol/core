// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "../libraries/Errors.sol";

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract BaseStrategy is IStrategy, Ownable2Step {
    using SafeERC20 for IERC20;

    address public immutable vault;
    address public rewardsHarvester;

    constructor(address _vault, address _owner) Ownable(_owner) {
        vault = _vault;
    }

    modifier onlyVault() {
        require(msg.sender == vault, Errors.Common__OnlyVault());
        _;
    }

    modifier onlyHarvester() {
        require(msg.sender == rewardsHarvester, Errors.Common__OnlyHarvester());
        _;
    }

    function invest(uint256 _amount) public onlyVault returns (uint256) {
        require(_amount > 0, Errors.Common__ZeroAmount());
        return _invest(_amount);
    }

    function divest(uint256 _amount) public onlyVault returns (uint256) {
        require(_amount > 0, Errors.Common__ZeroAmount());

        uint256 idleAssets = idle();
        uint256 divestAmount = _amount;

        // if idle assets are less than the divestment, we need to divest the difference
        if (idleAssets < _amount) {
            divestAmount = _amount - idleAssets;
        }
        // if idle assets are enough to cover the divestment, we don't need to divest
        else {
            divestAmount = 0;
            // we update the idle assets to the amount of the divestment to avoid divesting more than requested
            idleAssets = _amount;
        }

        uint256 divested;
        if (divestAmount > 0) {
            divested = _divest(divestAmount);
        }

        // if there are idle assets, we transfer them to the vault
        if (idleAssets > 0) {
            IERC20(asset()).safeTransfer(vault, idleAssets);
        }

        return divested + idleAssets;
    }

    function divestAll() public onlyVault {
        uint256 amount = totalAssets();
        if (amount > 0) {
            _divest(amount);
        }
    }

    function claimRewards() public onlyHarvester {
        _claimRewards();
    }

    function setRewardsHarvester(address _harvester) public onlyOwner {
        require(_harvester != address(0), Errors.Common__ZeroAddress());
        rewardsHarvester = _harvester;
    }

    function idle() public view virtual returns (uint256);
    function asset() public view virtual returns (address);
    function totalAssets() public view virtual returns (uint256);
    function totalInvested() public view virtual returns (uint256);

    function _claimRewards() internal virtual;
    function _invest(uint256 _amount) internal virtual returns (uint256);
    function _divest(uint256 _amount) internal virtual returns (uint256);
}
