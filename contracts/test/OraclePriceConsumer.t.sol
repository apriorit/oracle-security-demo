// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockOracle} from "../src/MockOracle.sol";
import {NaivePriceConsumer} from "../src/NaivePriceConsumer.sol";
import {OraclePriceConsumer} from "../src/OraclePriceConsumer.sol";

contract OraclePriceConsumerTest is Test {
    // Illustrative defaults used only in tests.
    uint256 internal constant MAX_AGE = 1 hours;
    uint256 internal constant MAX_DEVIATION_BPS = 500; // 5%

    MockOracle internal oracle;
    OraclePriceConsumer internal consumer;
    NaivePriceConsumer internal naive;

    function setUp() public {
        oracle = new MockOracle();
        consumer = new OraclePriceConsumer(address(oracle), MAX_AGE, MAX_DEVIATION_BPS);
        naive = new NaivePriceConsumer(address(oracle));
        vm.warp(1_700_000_000);
    }

    // --- Naive consumer: no validation ---

    function test_naive_acceptsZeroPrice() public {
        oracle.setPrice(0, block.timestamp);

        uint256 price = naive.readPrice();

        assertEq(price, 0);
    }

    function test_naive_acceptsStalePrice() public {
        uint256 updatedAt = block.timestamp - MAX_AGE - 1;
        oracle.setPrice(100e8, updatedAt);

        uint256 price = naive.readPrice();

        assertEq(price, 100e8);
    }

    // --- Validated consumer: happy path and rejection cases ---

    function test_readValidatedPrice_happyPath() public {
        oracle.setPrice(100e8, block.timestamp);

        uint256 price = consumer.readValidatedPrice();

        assertEq(price, 100e8);
        assertEq(consumer.lastAcceptedPrice(), 100e8);
        assertTrue(consumer.hasLastAcceptedPrice());
    }

    function test_readValidatedPrice_rejectsZeroPrice() public {
        oracle.setPrice(0, block.timestamp);

        vm.expectRevert(abi.encodeWithSelector(OraclePriceConsumer.InvalidPrice.selector, int256(0)));
        consumer.readValidatedPrice();
    }

    function test_readValidatedPrice_rejectsNegativePrice() public {
        oracle.setPrice(-1, block.timestamp);

        vm.expectRevert(abi.encodeWithSelector(OraclePriceConsumer.InvalidPrice.selector, int256(-1)));
        consumer.readValidatedPrice();
    }

    function test_readValidatedPrice_rejectsStalePrice() public {
        uint256 updatedAt = block.timestamp - MAX_AGE - 1;
        oracle.setPrice(100e8, updatedAt);

        vm.expectRevert(
            abi.encodeWithSelector(OraclePriceConsumer.StalePrice.selector, updatedAt, MAX_AGE)
        );
        consumer.readValidatedPrice();
    }

    function test_readValidatedPrice_acceptsAtExactMaxAgeBoundary() public {
        uint256 updatedAt = block.timestamp - MAX_AGE;
        oracle.setPrice(100e8, updatedAt);

        uint256 price = consumer.readValidatedPrice();

        assertEq(price, 100e8);
    }

    function test_readValidatedPrice_rejectsFutureTimestamp() public {
        uint256 updatedAt = block.timestamp + 1;
        oracle.setPrice(100e8, updatedAt);

        vm.expectRevert(
            abi.encodeWithSelector(OraclePriceConsumer.InvalidTimestamp.selector, updatedAt)
        );
        consumer.readValidatedPrice();
    }

    function test_readValidatedPrice_rejectsZeroTimestamp() public {
        oracle.setPrice(100e8, 0);

        vm.expectRevert(abi.encodeWithSelector(OraclePriceConsumer.InvalidTimestamp.selector, uint256(0)));
        consumer.readValidatedPrice();
    }

    function test_readValidatedPrice_firstAcceptedSkipsDeviation() public {
        // First read: a large absolute price is accepted because there is no prior baseline.
        // Deviation is not a primary trust mechanism for the first accepted value.
        oracle.setPrice(1_000_000e8, block.timestamp);

        uint256 price = consumer.readValidatedPrice();

        assertEq(price, 1_000_000e8);
        assertTrue(consumer.hasLastAcceptedPrice());
    }

    function test_readValidatedPrice_rejectsLargeDeviation() public {
        oracle.setPrice(100e8, block.timestamp);
        consumer.readValidatedPrice();

        // 6% jump exceeds illustrative 5% max deviation.
        uint256 jumped = 106e8;
        oracle.setPrice(int256(jumped), block.timestamp);

        vm.expectRevert(
            abi.encodeWithSelector(
                OraclePriceConsumer.PriceDeviationTooHigh.selector,
                jumped,
                uint256(100e8),
                MAX_DEVIATION_BPS
            )
        );
        consumer.readValidatedPrice();
    }

    function test_readValidatedPrice_acceptsWithinDeviation() public {
        oracle.setPrice(100e8, block.timestamp);
        consumer.readValidatedPrice();

        // 4% jump is within illustrative 5% max deviation.
        oracle.setPrice(104e8, block.timestamp);
        uint256 price = consumer.readValidatedPrice();

        assertEq(price, 104e8);
    }

    function test_readValidatedPrice_twoSequentialValidUpdates() public {
        oracle.setPrice(100e8, block.timestamp);
        assertEq(consumer.readValidatedPrice(), 100e8);

        oracle.setPrice(103e8, block.timestamp);
        assertEq(consumer.readValidatedPrice(), 103e8);

        oracle.setPrice(101e8, block.timestamp);
        assertEq(consumer.readValidatedPrice(), 101e8);
        assertEq(consumer.lastAcceptedPrice(), 101e8);
    }

    function test_readValidatedPrice_rejectsRoundMismatch() public {
        oracle.setRoundData({
            roundId_: 5,
            answer_: 100e8,
            startedAt_: block.timestamp,
            updatedAt_: block.timestamp,
            answeredInRound_: 4
        });

        vm.expectRevert(
            abi.encodeWithSelector(OraclePriceConsumer.RoundMismatch.selector, uint80(5), uint80(4))
        );
        consumer.readValidatedPrice();
    }

    function test_readValidatedPrice_oracleCallFailed() public {
        oracle.setPrice(100e8, block.timestamp);
        oracle.setShouldRevert(true);

        vm.expectRevert(OraclePriceConsumer.OracleCallFailed.selector);
        consumer.readValidatedPrice();
    }

    function test_constructor_rejectsZeroOracle() public {
        vm.expectRevert(OraclePriceConsumer.ZeroAddress.selector);
        new OraclePriceConsumer(address(0), MAX_AGE, MAX_DEVIATION_BPS);
    }

    function test_naive_constructor_rejectsZeroOracle() public {
        vm.expectRevert(NaivePriceConsumer.ZeroAddress.selector);
        new NaivePriceConsumer(address(0));
    }
}
