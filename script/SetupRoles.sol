// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import "forge-std/Script.sol";
import { YoEscrow } from "src/YoEscrow.sol";
import { IWETH9 } from "src/interfaces/IWETH9.sol";
import { RolesAuthority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { BaseScript } from "./Base.s.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { YoVault } from "src/YoVault.sol";

contract Deploy is BaseScript {
    IWETH9 public weth = IWETH9(0x4200000000000000000000000000000000000006);

    address public authority = address(0x9524e25079b1b04D904865704783A5aA0202d44D);

    address payable public yoETH = payable(address(0x3A43AEC53490CB9Fa922847385D82fe25d0E9De7));
    address payable public yoBTC = payable(address(0xbCbc8cb4D1e8ED048a6276a5E94A3e952660BcbC));
    address payable public yoUSD = payable(address(0x0000000f2eB9f69274678c76222B35eEc7588a65));

    function run() public broadcast { }
}
