// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Authority } from "@solmate/auth/Auth.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @notice Upgradable fork of (https://github.com/transmissions11/solmate/blob/main/src/auth/Auth.sol)
abstract contract AuthUpgradeable is Initializable {
    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event AuthorityUpdated(address indexed user, Authority indexed newAuthority);

    /// @custom:storage-location erc7201:auth.storage
    struct AuthStorage {
        address owner;
        Authority authority;
    }

    // keccak256(abi.encode(uint256(keccak256("auth.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AuthStorageLocation = 0xdd3fd67aef415aded9493b31ad20a02d2991d4bb2760431cc729821271eaea00;

    function _getAuthStorage() private pure returns (AuthStorage storage $) {
        assembly {
            $.slot := AuthStorageLocation
        }
    }

    function __Auth_init(address _owner, Authority _authority) internal onlyInitializing {
        AuthStorage storage $ = _getAuthStorage();
        $.owner = _owner;
        $.authority = _authority;
        emit OwnershipTransferred(msg.sender, _owner);
        emit AuthorityUpdated(msg.sender, _authority);
    }

    modifier requiresAuth() virtual {
        require(isAuthorized(msg.sender, msg.sig), "UNAUTHORIZED");

        _;
    }

    function isAuthorized(address user, bytes4 functionSig) public view virtual returns (bool) {
        AuthStorage storage $ = _getAuthStorage();
        Authority auth = $.authority;
        return (address(auth) != address(0) && auth.canCall(user, address(this), functionSig)) || user == $.owner;
    }

    function owner() public view virtual returns (address) {
        return _getAuthStorage().owner;
    }

    function authority() public view virtual returns (Authority) {
        return _getAuthStorage().authority;
    }

    function setAuthority(Authority newAuthority) public virtual {
        AuthStorage storage $ = _getAuthStorage();
        // We check if the caller is the owner first because we want to ensure they can
        // always swap out the authority even if it's reverting or using up a lot of gas.
        require(msg.sender == $.owner || $.authority.canCall(msg.sender, address(this), msg.sig));

        $.authority = newAuthority;

        emit AuthorityUpdated(msg.sender, newAuthority);
    }

    function transferOwnership(address newOwner) public virtual requiresAuth {
        AuthStorage storage $ = _getAuthStorage();
        $.owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }
}
