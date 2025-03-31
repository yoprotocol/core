// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "../libraries/Errors.sol";
import { Events } from "../libraries/Events.sol";
import { ILendingAdapter } from "../interfaces/ILendingAdapter.sol";

abstract contract BaseLendingAdapter is ILendingAdapter {
    address public immutable vault;

    modifier onlyVault() {
        require(msg.sender == vault, Errors.OnlyVault());
        _;
    }

    constructor(address _vault) {
        vault = _vault;
    }

    function addCollateral(uint256 _amount) external onlyVault {
        require(_amount > 0, Errors.ZeroAmount());
        _addCollateral(_amount);
        emit Events.AddCollateral(_amount);
    }

    function removeCollateral(uint256 _amount) external onlyVault {
        require(_amount > 0, Errors.ZeroAmount());
        _removeCollateral(_amount);
        emit Events.RemoveCollateral(_amount);
    }

    function borrow(uint256 _amount) external onlyVault returns (uint256) {
        require(_amount > 0, Errors.ZeroAmount());
        uint256 borrowed = _borrow(_amount);
        emit Events.Borrow(_amount);
        return borrowed;
    }

    function repay(uint256 _amount) external onlyVault returns (uint256) {
        require(_amount > 0, Errors.ZeroAmount());
        uint256 repaid = _repay(_amount);
        emit Events.Repay(_amount, repaid);
        return repaid;
    }

    function repayAll() external onlyVault returns (uint256) {
        uint256 repaid = _repayAll();
        emit Events.Repay(type(uint256).max, repaid);
        return repaid;
    }

    function logStats() external {
        uint256 collateral = getCollateral();
        uint256 borrowed = getBorrowed();
        uint256 supplyAPY = getSupplyAPY();
        uint256 borrowAPY = getBorrowAPY();
        uint256 healthFactor = getHealthFactor();
        emit Events.LendingStrategyStats(collateral, borrowed, supplyAPY, borrowAPY, healthFactor);
    }

    function getCollateral() public view virtual returns (uint256);
    function getBorrowLimit() public view virtual returns (uint256);
    function getBorrowed() public view virtual returns (uint256);
    function getSupplyAPY() public view virtual returns (uint256);
    function getBorrowAPY() public view virtual returns (uint256);
    function getHealthFactor() public view virtual returns (uint256);

    function _addCollateral(uint256 _amount) internal virtual;
    function _removeCollateral(uint256 _amount) internal virtual;
    function _borrow(uint256 _amount) internal virtual returns (uint256);
    function _repay(uint256 _amount) internal virtual returns (uint256);
    function _repayAll() internal virtual returns (uint256);
}
