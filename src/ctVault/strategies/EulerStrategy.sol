// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseStrategy } from "./BaseStrategy.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract EulerStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    IERC4626 public immutable euler;

    IERC20 private immutable _asset;

    constructor(address _vault, address _owner, address _eulerAddress) BaseStrategy(_vault, _owner) {
        euler = IERC4626(_eulerAddress);
        _asset = IERC20(euler.asset());

        _asset.forceApprove(_eulerAddress, type(uint256).max);
    }

    function _invest(uint256 _amount) internal override {
        _asset.safeTransferFrom(msg.sender, address(this), _amount);
        euler.deposit(_amount, address(this));
    }

    function _divest(uint256 _amount) internal override {
        euler.withdraw(_amount, vault, msg.sender);
    }

    function _claimRewards() internal override {
        // euler does not have a claim function
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
