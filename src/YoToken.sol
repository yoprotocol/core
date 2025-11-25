// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AuthUpgradeable, Authority} from "./base/AuthUpgradeable.sol";

// __     _________    _
// \ \   / /__   __|  | |
//  \ \_/ /__ | | ___ | | _____ _ __
//   \   / _ \| |/ _ \| |/ / _ \ '_ \
//    | | (_) | | (_) |   <  __/ | | |
//    |_|\___/|_|\___/|_|\_\___|_| |_|
/// @title YoToken
/// @dev This contract is based on the ERC20 standard and uses the Auth contract for access control.
contract YoToken is ERC20Upgradeable, AuthUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, string memory _name, string memory _symbol) public initializer {
        __ERC20_init(_name, _symbol);
        __Auth_init(_owner, Authority(address(0)));
        _mint(msg.sender, 1_000_000_000 * (10 ** uint256(decimals())));
    }

    function _update(address from, address to, uint256 value) internal virtual override requiresAuth {
        super._update(from, to, value);
    }

    // `burn` is added to the external interface
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
