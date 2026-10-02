// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IOracle} from "./IOracle.sol";

/// @notice Blindly trusts `latestRoundData()` with no validation.
/// @dev Contrast demo only. Shows why zero, stale, and inconsistent answers reach business logic.
contract NaivePriceConsumer {
    error ZeroAddress();

    IOracle public immutable oracle;

    constructor(address oracle_) {
        if (oracle_ == address(0)) revert ZeroAddress();
        oracle = IOracle(oracle_);
    }

    /// @notice Returns the raw answer cast to uint256. No freshness, positivity, or round checks.
    function readPrice() external view returns (uint256 price) {
        (, int256 answer,,,) = oracle.latestRoundData();
        price = uint256(answer);
    }
}
