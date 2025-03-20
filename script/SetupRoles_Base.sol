// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import "forge-std/Script.sol";
import { IWETH9 } from "src/interfaces/IWETH9.sol";
import { RolesAuthority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { BaseScript } from "./Base.s.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

uint8 constant TEST_ROLE = 12;
uint8 constant TEST_ORACLE_ROLE = 13;

contract Deploy is BaseScript {
    IWETH9 public weth = IWETH9(0x4200000000000000000000000000000000000006);
    address public authority = address(0x9524e25079b1b04D904865704783A5aA0202d44D);
    address payable public vault = payable(address(0x3A43AEC53490CB9Fa922847385D82fe25d0E9De7));

    function run() public broadcast {
        // // set oracle role to the vault itself to allow it to update the oracle

        // RolesAuthority(authority).setUserRole(
        //     address(0xd7A77013933A97A2c08dad7d59937119E76C879a), TEST_ORACLE_ROLE, false
        // );

        // RolesAuthority(authority).setUserRole(address(0xd7A77013933A97A2c08dad7d59937119E76C879a), TEST_ROLE, true);

        // // allow the vault operator to update the oracle through 'manage'
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(vault), yoVault.onUnderlyingBalanceUpdate.selector, true
        // );

        // // allow the vault operator to call depositV3 of Across' SpokePool
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64), bytes4(0x7b939232), true
        // );

        // // allow the oracle operator to update the oracle through 'manage'
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ORACLE_ROLE, address(vault), yoVault.onUnderlyingBalanceUpdate.selector, true
        // );

        // allow the vault operator to withdraw from escrow
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0xd00F80195c22D26eE3b2CDAc53FA2A82D5818a4B), bytes4(0xf3fef3a3), true
        // );

        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x5A32099837D89E3a794a44fb131CBbAD41f87a8C), yoVault.deposit.selector, true
        // );

        // // cbETH approve
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22), IERC20.approve.selector, true
        // );

        // weth approve
        // RolesAuthority(authority).setRoleCapability(TEST_ROLE, address(weth), IERC20.approve.selector, true);

        // universal router execute (0x24856bc3)
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x6Cb442acF35158D5eDa88fe602221b67B400Be3E), bytes4(0x24856bc3), true
        // );

        // // nft pool cbeth-weth mint (0xb5007d1f)
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x827922686190790b37229fd06084350E74485b72), bytes4(0xb5007d1f), true
        // );

        // nft position
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0xAADf01DD90aE0A6Bb9Eb908294658037096E0404), IERC20.approve.selector, true
        // );

        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0xb592c1539AC22EdD9784eA4d6a22199C16314498), bytes4(0xadc9772e), true
        // );

        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0xb592c1539AC22EdD9784eA4d6a22199C16314498), bytes4(0xc5285794), true
        // );

        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0xb592c1539AC22EdD9784eA4d6a22199C16314498), bytes4(0xead5d359), true
        // );

        // // deposit gauge
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0xF5550F8F0331B8CAA165046667f4E6628E9E3Aac), bytes4(0xb6b55f25), true
        // );

        // withdraw Gauge
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0xF5550F8F0331B8CAA165046667f4E6628E9E3Aac), bytes4(0x2e1a7d4d), true
        // );

        // decrease liquidityx
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x827922686190790b37229fd06084350E74485b72), bytes4(0x0c49ccbe), true
        // );

        // collect
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x827922686190790b37229fd06084350E74485b72), bytes4(0xfc6f7865), true
        // );

        // RolesAuthority(authority).setRoleCapability(TEST_ROLE, address(weth), IERC20.transfer.selector, true);
        // RolesAuthority(authority).setRoleCapability(TEST_ROLE, address(vault), yoVault.fulfillRedeem.selector, true);

        // RolesAuthority(authority).setUserRole(address(0x93e5260Ac975B475aF8BF818c14DEEE7fEfd5927), TEST_ROLE, true);

        // RolesAuthority(authority).setRoleCapability(TEST_ROLE, address(vault), bytes4(0x224d8703), true);

        // // allow to deposit tokemak BaseETH
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0xAADf01DD90aE0A6Bb9Eb908294658037096E0404), yoVault.deposit.selector, true
        // );

        // // allow to withdraw from tokemak BaseETH
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0xAADf01DD90aE0A6Bb9Eb908294658037096E0404), yoVault.withdraw.selector, true
        // );

        // RolesAuthority(authority).setUserRole(
        //     address(0xd3EA509FBC35c4357C8E4abd4F742dbC16ba0a5C), TEST_ORACLE_ROLE, true
        // );

        // // deposit gauge
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x0b537aC41400433F09d97Cd370C1ea9CE78D8a74), bytes4(0xb6b55f25), true
        // );

        // // withdraw Gauge
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x0b537aC41400433F09d97Cd370C1ea9CE78D8a74), bytes4(0x2e1a7d4d), true
        // );

        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0xCb327b99fF831bF8223cCEd12B1338FF3aA322Ff), IERC20.approve.selector, true
        // );

        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0xfCfEE5f453728BaA5ffDA151f25A0e53B8C5A01C), bytes4(0xb6b55f25), true
        // );

        // // withdraw Gauge
        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0xfCfEE5f453728BaA5ffDA151f25A0e53B8C5A01C), bytes4(0x2e1a7d4d), true
        // );

        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A), IERC20.approve.selector, true
        // );

        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x111111125421cA6dc452d289314280a0f8842A65), bytes4(0x07ed2379), true
        // );

        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x940181a94A35A4569E4529A3CDfB74e38FD98631), IERC20.approve.selector, true
        // );

        // RolesAuthority(authority).setRoleCapability(
        //     TEST_ROLE, address(0x223C0d94dbc8c0E5df1f6B2C75F06c0229c91950), IERC20.approve.selector, true
        // );

        RolesAuthority(authority).setRoleCapability(
            TEST_ROLE, address(0x827922686190790b37229fd06084350E74485b72), bytes4(0x42966c68), true
        );
    }
}
