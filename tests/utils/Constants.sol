// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract Constants {
    uint8 internal constant ADMIN_ROLE = 1;

    uint256 internal constant MAX_FEE = 1e17;

    uint256 internal constant MAX_PERCENTAGE_THRESHOLD = 1e17;

    uint256 internal constant DENOMINATOR = 1e18;
}
