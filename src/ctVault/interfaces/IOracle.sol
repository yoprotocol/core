// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IOracle {
    function scale() external view returns (uint256);
    function price() external view returns (uint256);
}
