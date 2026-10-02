// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IOracle} from "./IOracle.sol";

/// @notice Controllable oracle for Foundry tests. Not for production.
contract MockOracle is IOracle {
    error FeedUnavailable();

    uint80 public roundId;
    int256 public answer;
    uint256 public startedAt;
    uint256 public updatedAt;
    uint80 public answeredInRound;
    bool public shouldRevert;

    function setRoundData(
        uint80 roundId_,
        int256 answer_,
        uint256 startedAt_,
        uint256 updatedAt_,
        uint80 answeredInRound_
    ) external {
        roundId = roundId_;
        answer = answer_;
        startedAt = startedAt_;
        updatedAt = updatedAt_;
        answeredInRound = answeredInRound_;
    }

    /// @notice Convenience setter: consistent round fields, custom price and timestamp.
    function setPrice(int256 answer_, uint256 updatedAt_) external {
        roundId += 1;
        answer = answer_;
        startedAt = updatedAt_;
        updatedAt = updatedAt_;
        answeredInRound = roundId;
    }

    /// @notice When true, `latestRoundData` reverts (simulates feed unavailability).
    function setShouldRevert(bool shouldRevert_) external {
        shouldRevert = shouldRevert_;
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        if (shouldRevert) revert FeedUnavailable();
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
