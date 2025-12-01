// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IYoOracle} from "./interfaces/IYoOracle.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title YoOracle
 * @author Yo
 * @notice This contract is used to manage the oracle data for the Yo protocol.
 *         It is used to store the latest price and anchor price for a given vault.
 *         Every new price is pushed by the updater and is validated against the anchor price and the window seconds.
 *         For example, we do not allow a price to be pushed that is more than 1% different from the anchor price.
 *         The anchor price is updated every window seconds (e.g. once every 24 hours).
 */
contract YoOracle is Ownable2Step, IYoOracle {
    uint64 public immutable DEFAULT_WINDOW_SECONDS;
    uint64 public immutable DEFAULT_MAX_CHANGE_BPS;

    uint64 public constant BPS_DENOMINATOR = 1_000_000_000;

    address public updater;
    mapping(address => AssetOracleData) public oracleData;

    constructor(address _updater, uint64 _defaultWindowSeconds, uint64 _defaultMaxChangeBps) Ownable(msg.sender) {
        require(_updater != address(0), InvalidConfig());
        updater = _updater;

        DEFAULT_WINDOW_SECONDS = _defaultWindowSeconds;
        DEFAULT_MAX_CHANGE_BPS = _defaultMaxChangeBps;
    }

    /// @notice Get the latest price for a given vault.
    /// @param _vault The address of the vault.
    /// @return price The latest price.
    /// @return timestamp The timestamp of the latest price.
    function getLatestPrice(address _vault) external view returns (uint256 price, uint64 timestamp) {
        AssetOracleData storage d = oracleData[_vault];
        return (d.latestPrice, d.latestTimestamp);
    }

    /// @notice Get the anchor price for a given vault.
    /// @param _vault The address of the vault.
    /// @return price The anchor price.
    /// @return timestamp The timestamp of the anchor price.
    function getAnchor(address _vault) external view returns (uint256 price, uint64 timestamp) {
        AssetOracleData storage d = oracleData[_vault];
        return (d.anchorPrice, d.anchorTimestamp);
    }

    /// @notice Set the updater for the oracle. The updater is the address that can update the share price for a given vault.
    /// @param _updater The address of the updater.
    function setUpdater(address _updater) external onlyOwner {
        require(_updater != address(0), InvalidConfig());
        emit UpdaterChanged(updater, _updater);
        updater = _updater;
    }

    /// @notice Set the asset config for a given vault. The config will be used to validate the share price updates.
    /// @param _vault The address of the vault.
    /// @param _windowSeconds The window seconds.
    /// @param _maxChangeBps The max change bps.
    function setAssetConfig(address _vault, uint32 _windowSeconds, uint32 _maxChangeBps) external onlyOwner {
        AssetOracleData storage d = oracleData[_vault];

        d.windowSeconds = _windowSeconds;
        d.maxChangeBps = _maxChangeBps;

        emit AssetConfigUpdated(_vault, _windowSeconds, _maxChangeBps);
    }

    /// @notice Update the share price for a given vault. The update will fail if the share price is different than the anchor price by more than the max change bps. The anchor price is updated if the window seconds have passed.
    /// @param _vault The address of the vault.
    /// @param _sharePrice The new share price.
    /// @dev The update will fail if the sender is not the updater.
    function updateSharePrice(address _vault, uint256 _sharePrice) external {
        require(msg.sender == updater, NotUpdater());

        AssetOracleData storage d = oracleData[_vault];
        uint64 windowSeconds = d.windowSeconds != 0 ? d.windowSeconds : DEFAULT_WINDOW_SECONDS;
        uint64 maxChangeBps = d.maxChangeBps != 0 ? d.maxChangeBps : DEFAULT_MAX_CHANGE_BPS;

        uint64 nowTs = uint64(block.timestamp);

        // first update
        if (d.latestPrice == 0) {
            d.latestPrice = _sharePrice;
            d.latestTimestamp = nowTs;
            d.anchorPrice = _sharePrice;
            d.anchorTimestamp = nowTs;

            emit SharePriceUpdated(_vault, _sharePrice, nowTs);
            return;
        }

        // this check should never fail
        if (d.anchorPrice > 0) {
            uint256 ref = d.anchorPrice;
            uint256 diff = _sharePrice > ref ? _sharePrice - ref : ref - _sharePrice;
            uint256 diffBps = (diff * BPS_DENOMINATOR) / ref;

            if (diffBps > maxChangeBps) {
                revert PriceChangeTooBig(_vault, _sharePrice, ref, diffBps, maxChangeBps);
            }
        }

        d.latestPrice = _sharePrice;
        d.latestTimestamp = nowTs;

        // rotate anchor if window passed
        if (nowTs - d.anchorTimestamp >= windowSeconds) {
            d.anchorPrice = _sharePrice;
            d.anchorTimestamp = nowTs;
        }

        emit SharePriceUpdated(_vault, _sharePrice, nowTs);
    }
}
