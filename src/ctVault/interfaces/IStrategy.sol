// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IStrategy {
    function invest(uint256 _amount) external;
    function divest(uint256 _amount) external;
    function divestAll() external;

    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function idle() external view returns (uint256);
    function totalInvested() external view returns (uint256);
}
