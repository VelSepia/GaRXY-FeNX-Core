# GaRXY FeNX Task #004 Validation Report
【GaRXY FeNX Task #004】

■目的

Task #003で特定した最重要ボトルネックを改善する。

新しい売買ロジックや戦略は追加しない。

Execution Pipeline・Environment・Strategy・Entry条件は変更せず、
現状EAが正常に継続運転できる状態を目指す。

────────────────────

■最優先改善

① Risk STOP復帰経路

現在

NORMAL
↓
RISK_STOP
↓
EA再初期化まで復帰不可

となっている。

これを

NORMAL
↓
RISK_STOP
↓
STANDBY
↓
NORMAL

へ復帰可能な状態遷移へ改善する。

復帰条件はRisk Engineが安全を確認した場合のみ許可する。

────────────────────

■第二優先

Execution Volume

最小ロット未満となる注文をブローカー仕様へ適応する。

ロット丸め・配分改善を行う。

売買判断ロジックは変更しない。

────────────────────

■第三優先

Risk Input Freshness

invalid / missing / stale upstream を分析し、
不要なRisk STOPを削減する。

────────────────────

■検証

改善後

・四半期バックテスト
・通年バックテスト

を再実行し、

Task #003との比較を行う。

────────────────────

■制約

・新しい売買ロジックは禁止
・Entry条件変更禁止
・Strategy変更禁止
・Environment変更禁止
・Architecture変更禁止

改善対象は

Risk Engine
StateManager
Execution Volume
Risk Input管理

のみ。

────────────────────

■完了条件

・通年テストでRisk STOP固定が解消される
・四半期テスト以上の取引数を維持
・Execution Pipelineは引き続き正常
・Build 0 errors
## Baseline and scope

- Baseline: merged `main` commit `5710deb033ce235283b93ff3f26b43f9564a1bee`
- Task #003 PR #3 was confirmed merged before implementation.
- Product-source changes are limited to:
  - `Risk/RiskEngine.mqh`
  - `Execution/OrderExecutor.mqh`
  - `Execution/ExecutionEngine.mqh`
- `StateManager`, Environment, Strategy, entry conditions, and execution-pipeline ordering are unchanged.

## Implementation

### Risk STOP recovery

- A core `RISK_STOP` can now leave only after the Risk Engine's existing hysteresis and cooldown have produced a final `SYSTEM_SAFE` snapshot.
- Recovery additionally requires valid system data, trading and new-entry permission, no invalid or Risk-Stop symbols, no dynamic escalation, and no entry block.
- The transition path is intentionally two-step:
  - `RISK_STOP -> STANDBY`
  - `STANDBY -> NORMAL`
- The existing `StateManager` transition rules already permitted this path, so no StateManager edit was required.
- The system Risk-Stop state comparison was corrected from `SYSTEM_RISK_STOP` to the actually published `SYSTEM_RISK_STOP_REQUIRED`.

### Risk input handling

- Field-level diagnostics distinguish missing/invalid flags from stale or future timestamps.
- The reproduced global input failure was `pipeline.standby_valid=false`; no timestamp was stale at the recorded episode start.
- Invalid/missing input now fails closed at `SUSPENDED`, blocking all new entries without inventing a critical Risk-Stop event.
- Explicit `RISK_STOP_PENDING` / `RISK_STOP` recommendations remain critical and still trigger Risk Stop.

### Execution volume

- Broker minimum, maximum, and step are applied before submission.
- A reduced allocation below broker minimum is raised to broker minimum only when that minimum does not exceed the configured fixed-lot ceiling.
- Other representable values are rounded down to avoid increasing recommended risk.
- `COrderExecutor::Configure()` adds the ceiling as a trailing argument with a default value, preserving existing three-argument callers.
- Backtest telemetry records each broker-minimum adjustment.

## Build

- MetaEditor full EA build: **0 errors, 1 warning**
- The warning is the pre-existing version-format warning for `#property version "0.1.0"`.
- Final EX5 SHA-256 used for validation:
  `E69AD71F2DCF3F8A8DCAC923FA2BB5BAD21D8E07CB09C99766550E90E815A3D9`

## Final Strategy Tester validation

Configuration was the Task #003 validation set: USDJPY H1, 1-minute OHLC model, execution enabled, fixed 0.01 lot, and unchanged strategy/entry/environment settings.

### Q1 2024

| Metric | Task #003 | Task #004 |
| --- | ---: | ---: |
| Trades | 1 | 63 |
| Wins / losses | 0 / 1 | 47 / 16 |
| Win rate | 0.00% | 74.60% |
| Profit factor | 0.000000 | 0.938957 |
| Net profit | -7.01 | -3.51 |
| Balance drawdown | 7.01 (0.07%) | 23.64 (0.24%) |
| Equity drawdown | 8.86 (0.09%) | 24.64 (0.25%) |
| Average holding time | 106,000 s | 66,710.10 s |
| Orders accepted / rejected | 1 / 0 | 63 / 0 |
| Explicit closes accepted / failed | 0 / 0 | 54 / 0 |
| Broker-minimum adjustments | 0 | 15 |
| Core Risk Stops / recoveries | 1 / 0 in the continuous baseline | 5 / 5 |

Q1 ended with the core in `NORMAL` before tester shutdown. One final position was still open at the test boundary; 62 of 63 opened positions had already closed.

### Full year 2024

| Metric | Task #003 | Task #004 |
| --- | ---: | ---: |
| Trades | 1 | 220 |
| Wins / losses | 0 / 1 | 151 / 69 |
| Win rate | 0.00% | 68.64% |
| Profit factor | 0.000000 | 0.960139 |
| Net profit | -7.01 | -12.71 |
| Balance drawdown | 7.01 (0.07%) | 40.08 (0.40%) |
| Equity drawdown | 8.86 (0.09%) | 43.07 (0.43%) |
| Average holding time | 106,000 s | 63,066 s |
| Orders accepted / rejected | 1 / 0 | 220 / 0 |
| Explicit closes accepted / failed | 0 / 0 | 166 / 0 |
| Retries | 0 | 0 |
| Broker-minimum adjustments | 0 | 55 |
| Risk-blocked ticks | 1,447,159 | 197,939 |
| Risk-blocked share | 98.68% | 13.50% |
| Core Risk Stops / recoveries | 1 / 0 | 23 / 23 |

Risk-blocked ticks decreased by 1,249,220, or 86.32%. The first Risk Stop on 2024-01-05 recovered on 2024-01-08. The last Risk Stop on 2024-12-11 recovered on 2024-12-12. The final operating state before tester shutdown was `NORMAL`.

The annual run opened 220 positions and observed 219 closes: 166 explicit EA closes, 45 stop-loss closes, and 8 take-profit closes. One final position remained open at the test boundary.

## Completion assessment

- Full-year Risk STOP latch: **resolved**
- Quarterly trade count maintained: **yes** (`1 -> 63` for Q1)
- Full-year continuous trade count: **220**
- Execution pipeline: **normal**; entry, open-position tracking, management, explicit close, SL close, and TP close were all observed
- Order rejects: **0**
- Failed explicit closes: **0**
- Build: **0 errors**

## Remaining observations

- The 1,109 annual invalid-input episodes remain upstream and consistently identify `pipeline.standby_valid=false`. They no longer create an unconfirmed Risk Stop, but the Standby validity source should be investigated separately without weakening its safety conditions.
- Broker-minimum quantization is bounded by the configured fixed lot. A future risk-sizing phase could calculate executable lot from stop distance, tick value, and account risk before allocation, instead of quantizing a fixed lot.
- Profit factor remains below 1.0 and the annual result remains negative. This is a strategy-performance issue and was intentionally not changed in Task #004.
- No commit, branch, push, or pull request was created because Task #004 did not request publication and the local source is a non-Git workspace snapshot.
