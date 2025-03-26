// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseLendingAdapter } from "../lendingAdapters/BaseLendingAdapter.sol";
import { Errors } from "../../libraries/Errors.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IIrm } from "@morpho-blue/interfaces/IIrm.sol";
import { IOracle } from "@morpho-blue/interfaces/IOracle.sol";
import { IMorpho, Id, MarketParams, Market } from "@morpho-blue/interfaces/IMorpho.sol";

import { MathLib } from "@morpho-blue/libraries/MathLib.sol";
import { SharesMathLib } from "@morpho-blue/libraries/SharesMathLib.sol";
import { MorphoLib } from "@morpho-blue/libraries/periphery/MorphoLib.sol";
import { MarketParamsLib } from "@morpho-blue/libraries/MarketParamsLib.sol";
import { MorphoStorageLib } from "@morpho-blue/libraries/periphery/MorphoStorageLib.sol";
import { MorphoBalancesLib } from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";

contract MorphoAdapter is BaseLendingAdapter {
    using MathLib for uint256;
    using MorphoLib for IMorpho;
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    uint256 constant ORACLE_PRICE_SCALE = 1e36;

    IMorpho public immutable morpho;

    /// @notice The Morpho market parameters
    MarketParams public marketParams;

    constructor(address _vault, address _morphoAddress, MarketParams memory _marketParams) BaseLendingAdapter(_vault) {
        morpho = IMorpho(_morphoAddress);
        marketParams = _marketParams;

        IERC20(marketParams.loanToken).forceApprove(_morphoAddress, type(uint256).max);
        IERC20(marketParams.collateralToken).forceApprove(_morphoAddress, type(uint256).max);
    }

    function _addCollateral(uint256 _amount) internal override {
        IERC20(marketParams.collateralToken).safeTransferFrom(msg.sender, address(this), _amount);
        morpho.supplyCollateral(marketParams, _amount, address(this), hex"");
    }

    function _removeCollateral(uint256 _amount) internal override {
        morpho.withdrawCollateral(marketParams, _amount, address(this), address(this));
    }

    function _borrow(uint256 _amount) internal override returns (uint256) {
        (uint256 assetsBorrowed,) = morpho.borrow(marketParams, _amount, 0, address(this), address(this));
        return assetsBorrowed;
    }

    function _repay(uint256 _amount) internal override returns (uint256) {
        IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), _amount);
        (uint256 assetsRepaid,) = morpho.repay(marketParams, _amount, 0, address(this), hex"");
        return assetsRepaid;
    }

    function _repayAll() internal override returns (uint256) {
        Id marketId = marketParams.id();

        (,, uint256 totalBorrowAssets, uint256 totalBorrowShares) = morpho.expectedMarketBalances(marketParams);

        uint256 borrowShares = morpho.position(marketId, msg.sender).borrowShares;
        uint256 repaidAmount = borrowShares.toAssetsUp(totalBorrowAssets, totalBorrowShares);

        IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), repaidAmount);
        (uint256 assetsRepaid,) = morpho.repay(marketParams, repaidAmount, 0, address(this), hex"");
        return assetsRepaid;
    }

    function getCollateral() public view override returns (uint256) {
        Id marketId = marketParams.id();
        bytes32[] memory slots = new bytes32[](1);
        slots[0] = MorphoStorageLib.positionBorrowSharesAndCollateralSlot(marketId, address(this));
        bytes32[] memory values = morpho.extSloads(slots);
        uint256 totalCollateralAssets = uint256(values[0] >> 128);
        return totalCollateralAssets;
    }

    function getBorrowLimit() public view override returns (uint256) {
        Id marketId = marketParams.id();
        Market memory market = morpho.market(marketId);
        uint256 maxBorrowable = market.totalSupplyAssets - market.totalBorrowAssets;
        return maxBorrowable;
    }

    function getBorrowed() public view override returns (uint256) {
        uint256 totalBorrowAssets = morpho.expectedBorrowAssets(marketParams, address(this));
        return totalBorrowAssets;
    }

    function getSupplyAPY() public view override returns (uint256) {
        uint256 supplyApy = 0;

        if (marketParams.irm != address(0)) {
            Id marketId = marketParams.id();
            Market memory market = morpho.market(marketId);

            (uint256 totalSupplyAssets,, uint256 totalBorrowAssets,) = morpho.expectedMarketBalances(marketParams);
            uint256 utilization = totalBorrowAssets == 0 ? 0 : totalBorrowAssets.wDivUp(totalSupplyAssets);
            supplyApy = _getBorrowAPY().wMulDown(1 ether - market.fee).wMulDown(utilization);
        }

        return supplyApy;
    }

    function getBorrowAPY() public view override returns (uint256) {
        return _getBorrowAPY();
    }

    function getHealthFactor() public view override returns (uint256) {
        Id marketId = marketParams.id();

        address user = address(this);
        uint256 collateral = morpho.collateral(marketId, user);
        uint256 collateralPrice = IOracle(marketParams.oracle).price();
        uint256 borrowed = morpho.expectedBorrowAssets(marketParams, user);

        uint256 maxBorrow = collateral.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(marketParams.lltv);

        if (borrowed == 0) {
            return type(uint256).max;
        }

        return maxBorrow.wDivDown(borrowed);
    }

    function _getBorrowAPY() internal view returns (uint256) {
        uint256 borrowApy = 0;
        if (marketParams.irm != address(0)) {
            Id marketId = marketParams.id();
            Market memory market = morpho.market(marketId);
            borrowApy = IIrm(marketParams.irm).borrowRateView(marketParams, market).wTaylorCompounded(365 days);
        }
        return borrowApy;
    }
}
