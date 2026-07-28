# GaRXY FeNX Task #007 — Adaptive Entry Scoring

## 1. 結論

Task #006の総合Scoreを後方互換gateとして残し、既存Engineが発行するTrend Confidence、Spread、Market Scoreを使って重みを動的に配分するAdaptive Entry Scoreを追加した。

年間Strategy Testerでは以下を達成した。

- Profit Factor: **1.174413 → 1.208902**
- Net Profit: **+38.65 → +42.10**
- Balance Drawdown: **35.90 / 0.36% → 25.22 / 0.25%**
- Equity Drawdown: **39.52 / 0.39% → 28.47 / 0.28%**
- Trades: **166 → 156（93.98%維持）**
- Build: **0 errors**

年間のProfit Factor、純利益、Drawdownをすべて改善し、取引数の減少を6.02%に留めたため、年間を対象とするTask #007の完了条件を満たす。

Q1ではDrawdownを維持した一方、Profit Factorと純利益はTask #006を下回った。このトレードオフは成果として隠さず、後述の比較へ記録する。

## 2. 分析結果

Task #006の年間実行を観測コード付きで再現し、166 Entry / 165 Closed PositionのEntry時Engine値と最終損益を対応付けた。

Task #006合格取引を方向別に分析すると、以下の非対称性が確認された。

| Direction | Closed trades | Win Rate | Profit Factor | Deal profit合計 |
|---|---:|---:|---:|---:|
| BUY | 72 | 87.50% | 2.864293 | +74.87 |
| SELL | 93 | 63.44% | 0.825536 | -30.69 |

Task #006の同一最低ScoreをBUYとSELLへ適用すると、BUY側では良好に損失を分離できていたが、SELL側では低品質Entryが残っていた。

また、固定の追加Spread条件だけでは、Spread正常化後に同一局面へ再Entryするため年間結果を改善できなかった。このため、単純AND条件は追加せず、既存Scoreと方向別の最低品質を含む二段階の総合評価とした。

## 3. 実装内容

変更対象は既存の `Strategy/RangeMeanReversionStrategy.mqh` のみ。

新しいEngine、指標、Entry方向、Exit、SL、TPは追加していない。

### 3.1 Task #006互換gate

Task #006のScore計算をそのまま維持した。

```text
BaseQuality =
    ContrarianTrendQuality * 0.20
  + RangeEdgeQuality       * 0.15
  + RangeStrength          * 0.15
  + MarketScore            * 0.15
  + Volatility             * 0.10
  + ConfidenceConsensus    * 0.10
  + TrendCalmness          * 0.15
```

最低品質:

- BUY: **66.50**（Task #006と同値）
- SELL: **69.25**

Task #006で不合格だったEntryをTask #007が再許可することはない。

### 3.2 Adaptive Entry Score

Task #006 gate通過後、既存Engineの以下の値を0～100へ正規化して再評価する。

- Environment
  - Trend Score
  - Trend ADX
  - Trend Confidence
  - Range Position
  - Range Strength
  - Volatility Score
- Market Selection
  - Market Score
  - Market Confidence
  - Spread Points
  - Spread-to-ATR Ratio
- Trading Style Confidence
- Strategy Selection Confidence

Trend Confidenceを `t = TrendConfidence / 100` としたとき、Adaptive Scoreは次の重みを使用する。

| 要素 | 重み |
|---|---:|
| Contrarian Trend Quality | `0.10 + 0.10t` |
| Trend Calmness | `0.10 + 0.05t` |
| Range Edge Quality | `0.10` |
| Range Strength | `0.10` |
| Volatility | `0.10` |
| Market Score | `0.20 - 0.05t` |
| Spread Quality | `0.15 - 0.05t` |
| Confidence Consensus | `0.15 - 0.05t` |

重み合計はTrend Confidenceにかかわらず常に1.0となる。

- Trend Confidenceが高い場合はTrend evidenceへ最大15ポイントを配分する。
- Trend Confidenceが低い場合は、その比重をMarket Score、Spread、Engine間Confidenceへ移す。
- Adaptive Scoreの最低品質は **64.50**。

Spread QualityはMarket Selectionが既に発行しているSpread PointsとSpread-to-ATR Ratioを使用する。Market Selectionの既存eligibility scaleである30 points / 0.30を使って0～100へ正規化しており、新しいSpread filterは追加していない。

## 4. 候補比較

| 候補 | Q1 | 年間 | 判定 |
|---|---|---|---|
| Adaptive 60.0 | Task #006と同値 | 1時間後に同一局面へ再Entryし、Task #006とほぼ同値 | 不採用 |
| Adaptive 64.5のみ | Task #006と同値 | 2時間後に同一局面へ再Entryし、Task #006と同値 | 不採用 |
| SELL Base 69.5 | PF 1.382333 / Net +11.21 | PF 1.204039 / Net +41.12 | 年間良好だがQ1低下が大きい |
| SELL Base 69.25 | PF 1.415757 / Net +12.19 | PF 1.208902 / Net +42.10 | **採用** |

69.25は69.5よりQ1と年間の両方で取引、PF、純利益が良好で、年間Drawdownも同等以上だった。

## 5. Q1比較

| 指標 | Task #006 | Task #007 | 差分 |
|---|---:|---:|---:|
| Trades | 46 | 43 | -3 (-6.52%) |
| Win Rate | 82.61% | 81.40% | -1.21 pt |
| Profit Factor | 1.597203 | 1.415757 | -0.181446 (-11.36%) |
| Net Profit | +17.51 | +12.19 | -5.32 (-30.38%) |
| Balance Drawdown | 12.49 / 0.12% | 12.49 / 0.12% | 変更なし |
| Equity Drawdown | 17.97 / 0.18% | 17.97 / 0.18% | 変更なし |
| Average Holding Time | 76,859.69 sec | 81,261.55 sec | +4,401.86 sec |

Q1では3 Entryを削減したが、除外されたEntryの合計効果は正ではなく、Profit Factorと純利益が低下した。Drawdownは金額・割合ともTask #006と同値だった。

Q1 execution:

- Orders accepted: 43 / 43
- Position closes: 38 / 38
- Rejected orders: 0
- Retry count: 0
- Closed positions: 42
- SL closes: 4
- TP closes: 0
- Expert closes: 38

## 6. 年間比較

| 指標 | Task #006 | Task #007 | 差分 |
|---|---:|---:|---:|
| Trades | 166 | 156 | -10 (-6.02%) |
| Win Rate | 73.49% | 73.72% | +0.23 pt |
| Profit Factor | 1.174413 | 1.208902 | +0.034489 (+2.94%) |
| Net Profit | +38.65 | +42.10 | +3.45 (+8.93%) |
| Balance Drawdown | 35.90 / 0.36% | 25.22 / 0.25% | -10.68 / -0.11 pt |
| Equity Drawdown | 39.52 / 0.39% | 28.47 / 0.28% | -11.05 / -0.11 pt |
| Average Holding Time | 71,003.96 sec | 73,702.14 sec | +2,698.18 sec |

年間では取引数を93.98%維持し、Profit Factor、純利益、Balance / Equity Drawdownをすべて改善した。

年間 execution:

- Orders accepted: 156 / 156
- Position closes: 120 / 120
- Rejected orders: 0
- Retry count: 0
- Closed positions: 155
- SL closes: 28
- TP closes: 7
- Expert closes: 120

期間終了時に1 PositionがOpenのため、Trades 156に対してClosed positionsは155となった。注文失敗またはClose失敗ではない。

## 7. Execution Pipeline確認

年間最終テスト:

| Stage | Blocked ticks | Block events |
|---|---:|---:|
| Environment | 559,236 | 573 |
| Market Selection | 4,756 | 241 |
| Pair Rank | 0 | 0 |
| Capital Allocation | 0 | 0 |
| Trading Style | 0 | 0 |
| Strategy Selection | 0 | 0 |
| Standby | 0 | 0 |
| Risk | 208,926 | 937 |
| Execution | 1,659 | 205 |

Pipelineの順序、Engine構成、Risk、State、Executionには変更を加えていない。Entry、Order、Position管理、Closeは正常に継続した。

## 8. Build結果

MetaEditor compile result:

```text
Result: 0 errors, 1 warnings, 3844 ms
```

Warningは既存の `#property version "0.1.0"` の形式に対するものであり、Task #007の変更によるcompile errorはない。

観測コードを除去したクリーンEX5でQ1・年間テストを再実行し、候補版と同一結果を再現した。

## 9. 変更ファイル

製品ソース:

- `Strategy/RangeMeanReversionStrategy.mqh`

ビルド成果物:

- `GaRXY_FeNX.ex5`

Task #006との全ファイルSHA-256比較では、上記ソースと対応するEX5以外に差分はない。

## 10. 制約確認

| 制約 | 結果 |
|---|---|
| Architecture変更禁止 | 変更なし |
| Execution Pipeline変更禁止 | 変更なし |
| Risk変更禁止 | 変更なし |
| StateManager変更禁止 | 変更なし |
| 新Engine追加禁止 | 追加なし |
| Exit変更禁止 | 変更なし |
| SL/TP変更禁止 | 変更なし |
| 既存Engine情報だけを使用 | 適合 |
| Build 0 errors | 適合 |

## 11. 一時解析コード

分析中のみ、以下を使用した。

- `Test/TradeQualityAnalyzer.mqh`
- `Execution/ExecutionEngine.mqh` の観測用hook
- `work/task007/optimize-adaptive-score.ps1`

AnalyzerとExecution hookは最終製品ソースおよびTester用EAコピーから完全に除去した。最終 `Execution/ExecutionEngine.mqh` はTask #006と同一SHA-256である。

PowerShell分析スクリプトは製品へincludeされないローカル解析成果物であり、EAのBuildまたは実行には含まれない。

## 12. 今後の改善提案（未実装）

- Q1で除外された3 Entryを別年度のQ1でも検証し、SELL最低Scoreの季節依存性を確認する。
- 2023年・2025年などOut-of-Sample期間で69.25とAdaptive 64.5の安定性を確認する。
- Average Holding Time増加による資金効率への影響を、Exitを変更せず評価する。
- 将来Market SelectionのSpread eligibility scaleを設定可能にする場合、Adaptive Scoreにも同じ設定値を渡せる既存Config経路を検討する。

本結果は指定期間のStrategy Tester結果であり、将来の収益性を保証するものではない。
