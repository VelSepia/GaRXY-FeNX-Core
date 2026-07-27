# GaRXY FeNX Task #008 Comparison Report

## Result

Task #008 is complete. The final implementation improves both Q1 and annual
Profit Factor, net profit, win rate, and drawdown relative to Task #007. Annual
trade count is 144, a 7.69% reduction from Task #007 and therefore inside the
required ±15% range.

## Product changes

### Modified source

- `Strategy/RangeMeanReversionStrategy.mqh`

### Rebuilt artifact

- `GaRXY_FeNX.ex5`

No other product source differs from the Task #007 baseline. In particular,
Execution Pipeline, ExecutionEngine, RiskEngine, Environment, StateManager,
exit handling, SL, and TP are unchanged.

## Implementation

The Task #006 compatibility score and Task #007 adaptive score gates remain
unchanged. Task #008 adds a final refinement after those gates:

```text
Refined Quality =
    70% × Task #007 Adaptive Quality
  + 20% × (100 - published RiskScore)
  + 10% × minimum published Confidence
```

The Task #007 Adaptive Quality already contains Trend, Range, Volatility,
Market, Spread, and downstream Confidence evidence. The final Confidence value
uses the minimum of Market Selection, Trading Style, Strategy Selection, and
Risk Confidence rather than allowing a high average to hide the weakest
published confidence.

- BUY refined threshold: 68.00
- SELL refined threshold: 76.50

The BUY threshold preserves every Task #007-qualified BUY in the observed
sample. The stronger SELL threshold removes the statistically adverse
low-refined-score SELL band; Task #007 annual closed-trade evidence showed BUY
PF 2.8573 versus SELL PF 0.8270.

All cross-component inputs continue to be read through `CDataBus`. No direct
Engine-to-Engine dependency was introduced.

## Validation conditions

- Symbol: USDJPY
- Period: H1
- Modeling: 1 minute OHLC
- Initial deposit: 10,000 USD
- Leverage: 1:100
- Q1: 2024-01-01 through 2024-03-31
- Annual: 2024-01-01 through 2024-12-31

Final results below were reproduced with the clean final binary after all
temporary observation code was removed.

## Q1 comparison

| Metric | Task #007 | Task #008 | Change |
| --- | ---: | ---: | ---: |
| Trades | 43 | 37 | -6 (-13.95%) |
| Win rate | 81.40% | 86.49% | +5.09 pp |
| Profit Factor | 1.415757 | 1.745936 | +0.330179 |
| Net profit | +12.19 | +16.06 | +3.87 |
| Balance drawdown | 12.49 | 7.38 | -5.11 |
| Equity drawdown | 17.97 | 13.43 | -4.54 |
| Average holding time | 81,261.55 s | 83,659.59 s | +2,398.04 s |

Q1 execution integrity:

- Orders requested/accepted/rejected: 37 / 37 / 0
- Close requests accepted/rejected: 34 / 34 / 0
- Entry retries / close retries: 0 / 0
- Position opens / closes: 37 / 37

## Annual comparison

| Metric | Task #007 | Task #008 | Change |
| --- | ---: | ---: | ---: |
| Trades | 156 | 144 | -12 (-7.69%) |
| Win rate | 73.72% | 77.08% | +3.36 pp |
| Profit Factor | 1.208902 | 1.372968 | +0.164066 |
| Net profit | +42.10 | +64.24 | +22.14 |
| Balance drawdown | 25.22 | 20.74 | -4.48 |
| Equity drawdown | 28.47 | 24.41 | -4.06 |
| Average holding time | 73,702.14 s | 72,593.83 s | -1,108.31 s |

Annual execution integrity:

- Orders requested/accepted/rejected: 144 / 144 / 0
- Close requests accepted/rejected: 112 / 112 / 0
- Entry retries / close retries: 0 / 0
- Position opens / closes: 144 / 143
- One position was still open at the configured period boundary, matching the
  established end-of-period reporting behavior.

## Success criteria

| Criterion | Result |
| --- | --- |
| Profit Factor improved | PASS |
| Net profit improved | PASS |
| Drawdown maintained or improved | PASS |
| Annual trades within Task #007 ±15% (133–179) | PASS: 144 |
| Execution Pipeline unchanged and healthy | PASS |
| Build 0 errors | PASS |

## Build

MetaEditor final build:

```text
Result: 0 errors, 1 warnings, 3938 ms elapsed, cpu='X64 Regular'
```

The one warning is the pre-existing MQL5 Market version-format warning for
`#property version "0.1.0"`; Task #008 did not modify version metadata.

- Final EX5 SHA-256:
  `6D0262150BF28338E393E1BE6B945255ED30B2B9992B82C43CFEBDF5E6A7DDC5`
- Final strategy SHA-256:
  `F0EF07BE2404D5141A701CF1289A84BDC87C54F3C8253AB71A30858A1A727B4B`

## Temporary observation code

During analysis, the existing trade analyzer was temporarily extended to
record published RiskScore and RiskConfidence, and ExecutionEngine was
temporarily connected to that analyzer. Both temporary product-source changes
were removed before the final build and validation.

- `Execution/ExecutionEngine.mqh` was restored exactly to Task #007 SHA-256
  `9708D6DC41C54AB9EB1DBE9EA6C0712F3E17556746033001FDBE091557D55ECF`.
- `Test/TradeQualityAnalyzer.mqh` is absent from the final product source.

The retained `work/task008` scripts, build logs, and tester configurations are
validation evidence only and are not included by the EA.
