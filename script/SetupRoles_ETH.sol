// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import "forge-std/Script.sol";
import { RolesAuthority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { IWETH9 } from "src/interfaces/IWETH9.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BaseScript } from "./Base.s.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

uint8 constant TEST_ROLE = 12;
uint8 constant TEST_ORACLE_ROLE = 13;

contract Deploy is BaseScript {
    IWETH9 public weth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public authority = address(0x9524e25079b1b04D904865704783A5aA0202d44D);
    address payable public vault = payable(address(0x3A43AEC53490CB9Fa922847385D82fe25d0E9De7));

    function run() public broadcast {
        // RolesAuthority(authority).setUserRole(
        // address(0xd7A77013933A97A2c08dad7d59937119E76C879a), TEST_ORACLE_ROLE, false
        // );

        // RolesAuthority(authority).setUserRole(address(0x93e5260Ac975B475aF8BF818c14DEEE7fEfd5927), TEST_ROLE, true);

        // RolesAuthority(authority).setUserRole(address(0xd7A77013933A97A2c08dad7d59937119E76C879a), TEST_ROLE, true);

        // // set oracle role to the vault itself to allow it to update the oracle
        // RolesAuthority(authority).setUserRole(address(broadcaster), TEST_ROLE, true);

        // // allow the vault operator to update the oracle through 'manage'
        // RolesAuthority(authority).setRoleCapability(TEST_ROLE, address(weth), IERC20.approve.selector, true);

        // // allow the vault operator to call `exchange` method of Curve
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e), bytes4(0x371dc447), true
        // );

        // allow to approve dgnETH
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x005F893EcD7bF9667195642f7649DA8163e23658), IERC20.approve.selector, true
        // );

        // allow to deposit dgnETH
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x5BDd1fA233843Bfc034891BE8a6769e58F1e1346), yoVault.deposit.selector, true
        // );

        // allow to withdraw from sdgnETH
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x5BDd1fA233843Bfc034891BE8a6769e58F1e1346), yoVault.withdraw.selector, true
        // );

        // allow the vault operator to call depositV3 of Across' SpokePool
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5), bytes4(0x7b939232), true
        // );

        // RolesAuthority(authority).setRoleCapability(TEST_ROLE, address(vault), bytes4(0x224d8703), true);

        // allow deposits to tokemak dineroETH
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x35911af1B570E26f668905595dEd133D01CD3E5a), yoVault.deposit.selector, true
        // );

        // allow to withdraw from tokemak dineroETH
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x35911af1B570E26f668905595dEd133D01CD3E5a), yoVault.withdraw.selector, true
        // );

        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x35911af1B570E26f668905595dEd133D01CD3E5a), IERC20.approve.selector, true
        // );

        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x9ABE58Bc98Ae95296434AB8f57915c1068354404), bytes4(0xadc9772e), true
        // );

        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x9ABE58Bc98Ae95296434AB8f57915c1068354404), bytes4(0xc5285794), true
        // );

        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x9ABE58Bc98Ae95296434AB8f57915c1068354404), bytes4(0xead5d359), true
        // );

        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x111111125421cA6dc452d289314280a0f8842A65), bytes4(0x07ed2379), true
        // );

        RolesAuthority(authority).setRoleCapability(
            TEST_ROLE, address(0x2e9d63788249371f1DFC918a52f8d799F4a38C94), IERC20.approve.selector, true
        );
    }
}
