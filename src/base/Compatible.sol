// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Compatible
/// @notice Abstract contract that allows the contract to receive ether and ERC721/1155 tokens
abstract contract Compatible {
    /// @notice Emitted when the contract receives ether
    /// @param sender The address that sent the ether
    /// @param amount The amount of ether received
    event Received(address sender, uint256 amount);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    )
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }
}
