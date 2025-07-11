// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ISwap } from "../interfaces/ISwap.sol";
import { ISwapRouter } from "./uniswap/ISwapRouter.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UniswapRouter is ISwap {
    using SafeERC20 for IERC20;

    uint24 public immutable fee;
    ISwapRouter public immutable router;

    constructor(uint24 _fee, address _router) {
        fee = _fee;
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
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).forceApprove(address(router), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        return router.exactInputSingle(params);
    }
}
