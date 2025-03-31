// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseStrategy } from "./BaseStrategy.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IRewardDistributor {
    function toggleOperator(address user, address operator) external;
    function operators(address user, address operator) external view returns (uint256);
}

contract EulerStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    IERC20 private immutable _asset;

    IERC4626 public immutable euler;
    IRewardDistributor public rewardDistributor;

    constructor(
        address _vault,
        address _owner,
        address _eulerAddress,
        address _rewardDistributor
    )
        BaseStrategy(_vault, _owner)
    {
        euler = IERC4626(_eulerAddress);
        _asset = IERC20(euler.asset());

        _asset.forceApprove(_eulerAddress, type(uint256).max);

        rewardDistributor = IRewardDistributor(_rewardDistributor);
    }

    function setRewardDistributor(address _rewardDistributor) external onlyOwner {
        rewardDistributor = IRewardDistributor(_rewardDistributor);
    }

    function _invest(uint256 _amount) internal override {
        _asset.safeTransferFrom(msg.sender, address(this), _amount);
        euler.deposit(_amount, address(this));
    }

    function _divest(uint256 _amount) internal override {
        euler.withdraw(_amount, vault, msg.sender);
    }

    function _claimRewards() internal override {
        if (rewardDistributor.operators(address(this), rewardsHarvester) == 0) {
            rewardDistributor.toggleOperator(address(this), rewardsHarvester);
        }
    }

    function totalAssets() public view override returns (uint256) {
        uint256 idleAssets = _asset.balanceOf(address(this));
        uint256 investedAssets = euler.maxWithdraw(address(this));
        return idleAssets + investedAssets;
    }

    function totalInvested() public view override returns (uint256) {
        return euler.maxWithdraw(address(this));
    }

    function idle() public view override returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    function asset() public view override returns (address) {
        return address(_asset);
    }
}
