// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "../libraries/Errors.sol";

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

abstract contract BaseStrategy is Ownable2Step {
    address public immutable vault;
    address public rewardsHarvester;

    constructor(address _vault, address _owner) Ownable(_owner) {
        vault = _vault;
    }

    modifier onlyVault() {
        require(msg.sender == vault, Errors.OnlyVault());
        _;
    }

    modifier onlyHarvester() {
        require(msg.sender == rewardsHarvester, Errors.OnlyHarvester());
        _;
    }

    function invest(uint256 _amount) public onlyVault {
        require(_amount > 0, Errors.ZeroAmount());
        _invest(_amount);
    }

    function divest(uint256 _amount) public onlyVault {
        require(_amount > 0, Errors.ZeroAmount());
        _divest(_amount);
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
        rewardsHarvester = _harvester;
    }

    function idle() public view virtual returns (uint256);
    function asset() public view virtual returns (address);
    function totalAssets() public view virtual returns (uint256);
    function totalInvested() public view virtual returns (uint256);

    function _claimRewards() internal virtual;
    function _invest(uint256 _amount) internal virtual;
    function _divest(uint256 _amount) internal virtual;
}
