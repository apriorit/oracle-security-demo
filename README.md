# Oracle validation demo

Educational demonstration of single-feed price consumption with a few consumer-side checks. **Not production-ready oracle integration.** Do not paste into a live protocol.

The validated consumer is intentionally incomplete. It does not cover wrong feed/decimals, market manipulation, correlated sources, gradual drift, confidence, or a trusted first baseline.

## Naive vs validated

| Contract | Behavior |
|----------|----------|
| `NaivePriceConsumer` | Blind `latestRoundData()` → `uint256(answer)`. Accepts zero, stale, and inconsistent rounds. |
| `OraclePriceConsumer` | Fail-closed read: round consistency, positive price, freshness (incl. zero/future `updatedAt`), deviation vs last accepted, and `OracleCallFailed` if the feed reverts. |

`MockOracle` lets tests drive price, timestamp, broken rounds, and feed unavailability.

`readValidatedPrice` mutates `lastAcceptedPrice` solely to illustrate deviation checks.

Thresholds are **example defaults** only.

## Layout

```
src/
  IOracle.sol
  MockOracle.sol
  NaivePriceConsumer.sol
  OraclePriceConsumer.sol
test/
  OraclePriceConsumer.t.sol
```

## Run tests

Requires [Foundry](https://book.getfoundry.sh/getting-started/installation).

```bash
cd contracts
forge install foundry-rs/forge-std --no-git --shallow
forge test -vv
```

## Out of scope

- Multi-source aggregation / outlier filtering
- Pause, governance, or upgrade patterns
- Vendor-specific Chainlink/Pyth/Tellor bindings beyond a simplified round API shape
- Decimals auto-discovery or scaling helpers
- Confidence / uncertainty fields
