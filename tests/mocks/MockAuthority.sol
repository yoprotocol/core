// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Authority } from "@solmate/auth/Auth.sol";
import { RolesAuthority } from "@solmate/auth/authorities/RolesAuthority.sol";

contract MockAuthority is RolesAuthority {
    constructor(address _owner, Authority _authority) RolesAuthority(_owner, _authority) { }
}
