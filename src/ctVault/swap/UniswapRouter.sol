// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IQuoter } from "./uniswap/IQuoter.sol";
import { ISwapRouter } from "./uniswap/ISwapRouter.sol";

import { ISwap } from "../interfaces/ISwap.sol";

contract UniswapRouter is ISwap {
    uint24 public immutable fee;

    IQuoter public immutable quoter;
    ISwapRouter public immutable router;

    constructor(uint24 _fee, address _quoter, address _router) {
        fee = _fee;

        quoter = IQuoter(_quoter);
        router = ISwapRouter(_router);
    }

    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum
    )
        external
        payable
        override
        returns (uint256 amountOut)
    {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        return router.exactInputSingle(params);
    }
}
