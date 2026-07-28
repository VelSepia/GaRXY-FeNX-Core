# GaRXY FeNX Task #005 比較・検証レポート

## 1. 結論

Task #005 の完了条件をすべて満たした。

- 年間 Profit Factor: **1.143492**（目標 `> 1.00`）
- 年間 Net Profit: **+32.92**（プラス）
- 年間 Trades: **181**（目安150件以上）
- Build: **0 errors**
- Architecture / Engine構造 / Risk Engine / Environment / StateManager / Execution Pipeline: **変更なし**
- SL / TP / Exit判定: **変更なし**

最終製品ソースの変更は `Strategy/RangeMeanReversionStrategy.mqh` のみである。

## 2. 検証条件

Task #004 と同一条件を使用した。

| 項目 | 値 |
|---|---:|
| Symbol | USDJPY |
| Period | H1 |
| Model | 1 |
| Deposit | 10,000 |
| Leverage | 1:100 |
| Q1 | 2024-01-01 ～ 2024-03-31 |
| 年間 | 2024-01-01 ～ 2024-12-31 |
| Execution設定 | Task #004 と同一 `.set` |

分析用ログだけを追加したTask #004互換版を最初に通年実行し、Task #004の `220 trades / PF 0.960139 / net -12.71` を完全再現してから分析した。

## 3. 統計分析

### 3.1 分析方法

Task #004年間取引の受理済みエントリー220件に、発注時点の既存情報を記録した。

- server hour / day of week
- BUY / SELL
- TrendScore / TrendStrength
- RangeScore / Range width
- ATR / VolatilityScore
- MarketConfidence
- Spread
- range boundary / midpoint までの距離
- allocation multiplier

一時的な観測コードで、エントリー約定と決済約定を `DEAL_POSITION_ID` で結合し、損益・保有時間・決済理由を各エントリーへ帰属した。使用した履歴APIの意味はMQL5公式の [Deal Properties](https://www.mql5.com/en/docs/constants/tradingconstants/dealproperties)、[HistorySelect](https://www.mql5.com/en/docs/trading/historyselect)、[HistoryDealGetTicket](https://www.mql5.com/en/docs/trading/historydealgetticket) に従った。

観測コードは分析終了後にすべて除去した。最終製品にExecution観測フックは残っていない。

### 3.2 主な結果

| 特徴 | Trades | Win rate | PF | Net |
|---|---:|---:|---:|---:|
| 全クローズ済み | 219 | 68.04% | 0.977085 | -7.18 |
| BUY | 111 | 72.97% | 1.421742 | +43.49 |
| SELL | 108 | 62.96% | 0.758955 | -50.67 |
| 月曜日 | 48 | 75.00% | 1.042740 | +2.34 |
| **火曜日** | **50** | **56.00%** | **0.470345** | **-61.44** |
| 水曜日 | 41 | 75.61% | 1.297266 | +15.22 |
| 木曜日 | 35 | 54.29% | 0.699391 | -17.27 |
| 金曜日 | 45 | 77.78% | 2.590628 | +53.97 |

火曜日はBUYとSELLの双方で悪化していた。

| 火曜日の方向 | Trades | PF | Net |
|---|---:|---:|---:|
| BUY | 28 | 0.582880 | -23.00 |
| SELL | 22 | 0.368386 | -38.44 |

また、火曜日は12か月中9か月でNetがマイナスだった。単一方向や単月だけの偏りではないため、最も再現性の高いEntry Quality要因と判断した。

時間帯では5時、19時、20時が弱かったが、件数が小さく方向との交互作用も大きかったため、追加フィルタは実装しなかった。

| Server hour | Trades | PF | Net |
|---|---:|---:|---:|
| 5 | 20 | 0.383890 | -25.47 |
| 19 | 7 | 0.165897 | -21.67 |
| 20 | 8 | 0.474242 | -10.41 |

連続値の単変量相関は弱かった。

| 特徴 | 勝敗との相関 | 損益との相関 |
|---|---:|---:|
| TrendScore | -0.151412 | -0.065302 |
| Range width | -0.069846 | -0.041551 |
| VolatilityScore | +0.026728 | +0.014460 |
| Spread | +0.037282 | -0.028105 |
| Boundary distance | -0.031245 | +0.008116 |

このためTrend・Range・Volatility・Spreadの閾値変更は行わなかった。

### 3.3 Exit分析

| Close reason | Trades | PF | Net |
|---|---:|---:|---:|
| Expert midpoint exit | 166 | 17.288737 | +238.63 |
| Stop Loss | 45 | 0 | -298.68 |
| Take Profit | 8 | ∞ | +52.87 |

損失の中心はSL到達だったが、エントリー時の既存連続値だけでは「早く切るべき場面」を十分に分離できなかった。結果を見た後の早期決済条件は過学習になるため、Exit判定・SL・TPは変更しなかった。

## 4. 実装内容

`Strategy/RangeMeanReversionStrategy.mqh` に、発注時のサーバー曜日が火曜日の場合のみRange Mean Reversionエントリーを見送るカテゴリフィルタを追加した。

- Environment、Market、Strategy Selectionの値は変更しない
- Range境界、score、ATR等の閾値は変更しない
- BUY/SELLの既存シグナル計算は変更しない
- SL / TP / midpoint Exitは変更しない
- Risk / State / Executionには影響しない

## 5. Task #004 比較

### Q1

| 指標 | Task #004 | Task #005 | 差 |
|---|---:|---:|---:|
| Trades | 63 | 51 | -12 (-19.05%) |
| Win rate | 74.60% | 78.43% | +3.83 pt |
| Profit Factor | 0.938957 | 1.288944 | +0.349987 (+37.27%) |
| Net Profit | -3.51 | +10.48 | +13.99 |
| Balance DD | 23.64 (0.24%) | 11.67 (0.12%) | -11.97 |
| Equity DD | 24.64 (0.25%) | 17.13 (0.17%) | -7.51 |
| Avg holding | 66,710.10 sec | 71,274.92 sec | +4,564.82 sec (+6.84%) |

Q1 Execution:

- Orders: 51 requested / 51 accepted / 0 rejected
- Explicit closes: 45 requested / 45 accepted / 0 rejected
- Entry retries: 0
- Close retries: 0

### 年間

| 指標 | Task #004 | Task #005 | 差 |
|---|---:|---:|---:|
| Trades | 220 | 181 | -39 (-17.73%) |
| Win rate | 68.64% | 71.27% | +2.63 pt |
| Profit Factor | 0.960139 | 1.143492 | +0.183353 (+19.10%) |
| Net Profit | -12.71 | +32.92 | +45.63 |
| Balance DD | 40.08 (0.40%) | 35.90 (0.36%) | -4.18 |
| Equity DD | 43.07 (0.43%) | 39.52 (0.39%) | -3.55 |
| Avg holding | 63,066.00 sec | 66,232.19 sec | +3,166.19 sec (+5.02%) |

年間 Execution:

- Orders: 181 requested / 181 accepted / 0 rejected
- Explicit closes: 140 requested / 140 accepted / 0 rejected
- Entry retries: 0
- Close retries: 0
- Close attribution: 32 SL / 8 TP / 140 Expert
- Closed positions: 180
- テスト境界で既存同様に1ポジションがopen

## 6. ビルド結果

- MetaEditor: **0 errors, 1 warning**
- Warning: 既存の `#property version "0.1.0"` 形式に関する warning 68
- 最終EX5 SHA-256: `76EB8C913F35E6320395996C51483FBF778CE05898E00C2F7B0FB146503F49A0`

## 7. 変更ファイルと制約監査

最終製品ソース:

- `Strategy/RangeMeanReversionStrategy.mqh`

生成物:

- `GaRXY_FeNX.ex5`

Task #004ソースとの全ファイルSHA-256比較結果は上記2ファイルのみ差分あり。EX5を除く製品ソース差分は `Strategy/RangeMeanReversionStrategy.mqh` だけだった。

分析中に一時追加した以下は最終製品から除去済み:

- `Execution/ExecutionEngine.mqh` の観測呼び出し
- `Test/TradeQualityAnalyzer.mqh`

Risk Engine、Environment、StateManager、Execution Pipeline、Engine構造に最終差分はない。

## 8. 今後の提案（未実装）

1. 2023年・2025年など未使用期間で火曜日フィルタをout-of-sample検証する。
2. rolling / walk-forwardで曜日効果の安定性を確認する。
3. 木曜日とSELLの弱さは独立検証する。ただし今回以上の除外は取引数減少と過学習リスクがある。
4. Exit改善には、エントリー後のMAE/MFEや時間経過別の条件付き期待値を新たに記録してから判断する。

本結果は2024年の同一ヒストリカル条件に対する検証結果であり、将来利益を保証するものではない。
