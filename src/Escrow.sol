// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "./libraries/Errors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Escrow {
    using SafeERC20 for IERC20;

    address public immutable VAULT;

    constructor(address _vault) {
        VAULT = _vault;
    }

    function withdraw(address asset, uint256 amount) external {
        require(msg.sender == VAULT, Errors.Escrow__OnlyVault());
        require(amount > 0, Errors.Escrow__AmountZero());
        IERC20(asset).safeTransfer(VAULT, amount);
    }
}
