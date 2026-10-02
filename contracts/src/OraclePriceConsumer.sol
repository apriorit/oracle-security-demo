// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IOracle} from "./IOracle.sol";

/// @notice Educational single-feed consumer with a few consumer-side checks.
/// @dev Intentionally incomplete. Not a production oracle adapter and not "secure by default".
///      Covers selected checks only (round consistency for round-shaped APIs, positivity,
///      freshness including future/zero timestamps, deviation vs last accepted, fail-closed call).
///      Does not cover wrong feed/decimals, market manipulation, correlated sources, gradual
///      drift, confidence, malicious first baseline, or multi-source aggregation.
///      Parameters below are illustrative example defaults.
contract OraclePriceConsumer {
    error InvalidPrice(int256 price);
    error InvalidTimestamp(uint256 updatedAt);
    error StalePrice(uint256 updatedAt, uint256 maxAge);
    error PriceDeviationTooHigh(uint256 price, uint256 lastPrice, uint256 maxBps);
    error RoundMismatch(uint80 roundId, uint80 answeredInRound);
    error OracleCallFailed();
    error ZeroAddress();

    IOracle public immutable oracle;

    /// @notice Illustrative: max age of `updatedAt` relative to `block.timestamp`.
    uint256 public immutable maxAge;

    /// @notice Illustrative: max absolute move vs last accepted price, in basis points (10_000 = 100%).
    uint256 public immutable maxDeviationBps;

    uint256 public lastAcceptedPrice;
    bool public hasLastAcceptedPrice;

    constructor(address oracle_, uint256 maxAge_, uint256 maxDeviationBps_) {
        if (oracle_ == address(0)) revert ZeroAddress();
        oracle = IOracle(oracle_);
        maxAge = maxAge_;
        maxDeviationBps = maxDeviationBps_;
    }

    /// @notice Fetch, validate, and persist a price so later calls can apply a deviation check.
    /// @dev Name says "read" for article familiarity; the call mutates `lastAcceptedPrice`.
    ///      Persistence exists only to illustrate deviation vs an accepted baseline.
    /// @return price Validated non-zero price as uint256.
    function readValidatedPrice() external returns (uint256 price) {
        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = _fetchLatestRound();

        _requireRoundConsistency(roundId, answeredInRound);
        _requirePositivePrice(answer);
        _requireFresh(updatedAt);

        price = uint256(answer);
        _requireDeviationOk(price);

        lastAcceptedPrice = price;
        hasLastAcceptedPrice = true;
    }

    /// @dev Fail closed when the feed call reverts (availability axis).
    function _fetchLatestRound()
        internal
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        try oracle.latestRoundData() returns (
            uint80 roundId_,
            int256 answer_,
            uint256 startedAt_,
            uint256 updatedAt_,
            uint80 answeredInRound_
        ) {
            return (roundId_, answer_, startedAt_, updatedAt_, answeredInRound_);
        } catch {
            revert OracleCallFailed();
        }
    }

    function _requireRoundConsistency(uint80 roundId, uint80 answeredInRound) internal pure {
        if (answeredInRound < roundId) {
            revert RoundMismatch(roundId, answeredInRound);
        }
    }

    function _requirePositivePrice(int256 answer) internal pure {
        if (answer <= 0) {
            revert InvalidPrice(answer);
        }
    }

    /// @dev Rejects zero and future timestamps, then applies maxAge against wall time.
    function _requireFresh(uint256 updatedAt) internal view {
        if (updatedAt == 0 || updatedAt > block.timestamp) {
            revert InvalidTimestamp(updatedAt);
        }
        if (block.timestamp - updatedAt > maxAge) {
            revert StalePrice(updatedAt, maxAge);
        }
    }

    /// @dev Sanity filter vs last accepted baseline only. Skipped on the first accept.
    ///      Does not establish trust in the first baseline itself.
    function _requireDeviationOk(uint256 price) internal view {
        if (!hasLastAcceptedPrice) {
            return;
        }

        uint256 last = lastAcceptedPrice;
        uint256 absDiff = price > last ? price - last : last - price;
        // Compare absDiff/last to maxDeviationBps/10_000 without absDiff * last style products.
        if ((absDiff * 10_000) / last > maxDeviationBps) {
            revert PriceDeviationTooHigh(price, last, maxDeviationBps);
        }
    }
}
