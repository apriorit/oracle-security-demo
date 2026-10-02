// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal price-feed interface shaped like a round-based oracle.
/// @dev Not a vendor binding. Field names mirror common round APIs for illustration.
interface IOracle {
    /// @notice Latest reported round.
    /// @return roundId Round identifier.
    /// @return answer Price (can be negative in the raw feed; consumer rejects non-positive).
    /// @return startedAt Round start timestamp (unused by the demo consumer).
    /// @return updatedAt Timestamp of the latest answer.
    /// @return answeredInRound Round in which the answer was computed (for consistency checks).
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}
