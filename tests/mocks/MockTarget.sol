// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract MockTarget {
    uint256 public value;

    function someFunction(uint256 _value) external payable {
        value = _value;
    }
}
