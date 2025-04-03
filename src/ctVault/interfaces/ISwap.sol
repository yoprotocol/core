// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ISwap {
    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum
    )
        external
        payable
        returns (uint256 amountOut);
}
