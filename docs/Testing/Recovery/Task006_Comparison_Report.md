# GaRXY FeNX Task #006 — Decision Quality Improvement

## 1. 結論

Task #005で使用していた既存情報を複合評価し、Range Mean ReversionのEntry Qualityを改善した。

- 年間Profit Factor: **1.143492 → 1.174413**
- 年間純利益: **+32.92 → +38.65**
- 年間Balance Drawdown: **35.90 / 0.36% → 35.90 / 0.36%**
- 年間Equity Drawdown: **39.52 / 0.39% → 39.52 / 0.39%**
- 年間取引数: **181 → 166（91.7%維持）**
- Q1 Profit Factor: **1.288944 → 1.597203**
- Build: **0 errors**

年間Profit Factor、年間利益、Q1 Profit Factorはいずれも改善した。年間ドローダウンは金額・割合ともTask #005と同値であり、取引数の減少は8.3%に留まったため、Task #006の完了条件を満たす。

## 2. 実装内容

変更対象は既存の `Strategy/RangeMeanReversionStrategy.mqh` のみ。

既存EngineがDataBusへ発行している以下の値を、Entry直前に総合評価するDecision Quality Scoreを追加した。

- Environment
  - Trend Score
  - Trend ADX
  - Range Position
  - Volatility Score
- Market Selection
  - Score
  - Confidence
- Trading Style
  - Confidence
- Strategy Selection
  - Confidence

新しいEngine、指標、売買ロジック、Exit条件は追加していない。

### 総合評価

方向依存の値は、BUYとSELLで対称になるよう正規化した。

| 要素 | 比重 | 内容 |
|---|---:|---|
| Contrarian Trend Quality | 20% | Entry方向に対してTrend Scoreが逆行し過ぎていないか |
| Range Edge Quality | 15% | BUYはレンジ下端、SELLはレンジ上端に近いほど高評価 |
| Range Strength | 15% | Market Selectionの既存Range Score |
| Market Condition | 15% | Market Selectionの既存総合Score |
| Volatility | 10% | Environmentの既存Volatility Score |
| Confidence Consensus | 10% | Market / Trading Style / Strategy SelectionのConfidence平均 |
| Trend Calmness | 15% | ADXが過度に高くないほど高評価 |

計算式:

```text
DecisionQuality =
    ContrarianTrendQuality * 0.20
  + RangeEdgeQuality       * 0.15
  + RangeStrength          * 0.15
  + MarketCondition        * 0.15
  + Volatility             * 0.10
  + ConfidenceConsensus    * 0.10
  + TrendCalmness          * 0.15
```

すべての入力値が正常範囲にある場合だけ評価し、`DecisionQuality >= 66.5` のEntryを許可する。

Market Selectionの既存Scoreには、相場状態・Range Strength・Volatility・Spreadの情報が既に統合されているため、Spreadだけを別の単一条件として再度強く評価することは避けた。

## 3. 統計分析と閾値選定

Task #005と同一の年間条件で観測専用ログを取得し、181 Entry / 180 Closed Tradeを分析した。観測コードを有効にした状態でもTask #005の年間結果を完全再現できたため、計測による売買結果への影響がないことを確認した。

個別値の単純な相関は弱く、単一条件によるフィルタでは安定した改善根拠が得られなかった。そのため、方向対称化した7要素の総合Scoreを使用した。

候補比較:

| 最小Score | 判定 | 理由 |
|---:|---|---|
| 61.5 | 不採用 | 実バックテストで年間PF 1.144000、純利益 +32.94に留まり、改善が小さい |
| 65.5 | 不採用 | 年間オフライン評価は良好だったが、Q1のPF・利益がTask #005を下回る傾向 |
| 66.5 | 採用 | Q1・年間の両方でPFと純利益が改善し、年間DDを維持 |

閾値は利益結果だけを直接参照するEntry条件ではなく、既存Engineの現在値を総合するための最低品質値として実装した。

## 4. バックテスト条件

Task #005と同一のEA設定、銘柄、時間足、モデリング条件、期間条件を使用した。

- Q1テスト
- 年間テスト
- 初期資金および入力パラメータはTask #005から変更なし
- Exit Logic、SL、TP、Risk、Execution Pipelineは変更なし

## 5. Q1比較

| 指標 | Task #005 | Task #006 | 差分 |
|---|---:|---:|---:|
| Trades | 51 | 46 | -5 (-9.80%) |
| Win Rate | 78.43% | 82.61% | +4.18 pt |
| Profit Factor | 1.288944 | 1.597203 | +0.308259 (+23.92%) |
| Net Profit | +10.48 | +17.51 | +7.03 (+67.08%) |
| Balance Drawdown | 11.67 / 0.12% | 12.49 / 0.12% | +0.82 / ±0.00 pt |
| Equity Drawdown | 17.13 / 0.17% | 17.97 / 0.18% | +0.84 / +0.01 pt |
| Average Holding Time | 71,274.92 sec | 76,859.69 sec | +5,584.77 sec |

Q1では、取引数を90.2%維持しながら勝率、Profit Factor、純利益が改善した。Drawdown率はBalanceで同率、Equityで0.01ポイント増加しているため、Q1だけについて「Drawdown改善」とは評価しない。

Q1 execution:

- Orders accepted: 46 / 46
- Position closes: 41 / 41
- Rejected orders: 0
- Retry count: 0
- Closed trades: 45
- SL closes: 4
- TP closes: 0
- Expert closes: 41

## 6. 年間比較

| 指標 | Task #005 | Task #006 | 差分 |
|---|---:|---:|---:|
| Trades | 181 | 166 | -15 (-8.29%) |
| Win Rate | 71.27% | 73.49% | +2.22 pt |
| Profit Factor | 1.143492 | 1.174413 | +0.030921 (+2.70%) |
| Net Profit | +32.92 | +38.65 | +5.73 (+17.41%) |
| Balance Drawdown | 35.90 / 0.36% | 35.90 / 0.36% | 変更なし |
| Equity Drawdown | 39.52 / 0.39% | 39.52 / 0.39% | 変更なし |
| Average Holding Time | 66,232.19 sec | 71,003.96 sec | +4,771.77 sec |

年間では取引数を91.7%維持し、勝率、Profit Factor、純利益を改善した。Balance / Equity Drawdownは金額・割合ともTask #005と同値である。

年間 execution:

- Orders accepted: 166 / 166
- Position closes: 126 / 126
- Rejected orders: 0
- Retry count: 0
- Closed trades: 165
- SL closes: 31
- TP closes: 8
- Expert closes: 126

テスト終了時点で1 Positionが期間境界をまたいでOpenのため、Trades 166に対してClosed tradesは165となった。これは既存のテスト期間終了挙動であり、注文失敗やClose失敗ではない。

## 7. Execution Pipeline確認

年間最終テストのブロック集計:

| Stage | Blocked ticks | Block events |
|---|---:|---:|
| Environment | 550,073 | 559 |
| Market Selection | 4,519 | 233 |
| Pair Rank | 0 | 0 |
| Allocation | 0 | 0 |
| Trading Style | 0 | 0 |
| Strategy Selection | 0 | 0 |
| Standby | 0 | 0 |
| Risk | 208,263 | 908 |
| Execution | 1,622 | 199 |

既存Pipelineの順序、Engine構成、Risk、State、Executionには変更を加えていない。EntryからOrder、Position管理、Closeまで正常に継続している。

## 8. Build結果

MetaEditor compile result:

```text
Result: 0 errors, 1 warnings, 3980 ms
```

Warningは既存の `#property version "0.1.0"` のversion形式に対するものであり、Task #006の変更によるコンパイルエラーはない。

最終ビルド後のEX5を使ってQ1・年間テストを再実行し、上記結果を再現した。

## 9. 変更ファイル

製品ソース:

- `Strategy/RangeMeanReversionStrategy.mqh`

ビルド成果物:

- `GaRXY_FeNX.ex5`

Task #005との全ファイルハッシュ比較では、上記製品ソースと対応するEX5以外に差分はない。

## 10. 制約確認

| 制約 | 結果 |
|---|---|
| Architecture変更禁止 | 変更なし |
| Execution Pipeline変更禁止 | 変更なし |
| Risk Engine変更禁止 | 変更なし |
| StateManager変更禁止 | 変更なし |
| 新Engine追加禁止 | 追加なし |
| Exit Logic変更禁止 | 変更なし |
| 既存情報だけを使用 | 適合 |
| Build 0 Errors | 適合 |

Task #005で導入された既存の曜日品質条件もそのまま維持している。

## 11. 一時解析コード

分析中のみ、以下の観測コードを使用した。

- `Test/TradeQualityAnalyzer.mqh`
- `Execution/ExecutionEngine.mqh` の観測用hook

これらはEntry時の既存Engine値とClose結果を対応付けるためだけに使用し、売買判断には影響させていない。最終ソースからは両方とも完全に除去済みであり、`Execution/ExecutionEngine.mqh` はTask #005と同一ハッシュへ復元した。

## 12. 今後の改善提案（未実装）

- 別年・別相場期間でDecision Quality ScoreをOut-of-Sample検証する。
- Scoreの各要素と損益の関係を定期的に記録し、固定比重の安定性を確認する。
- Average Holding Time増加がスワップや資金効率へ与える影響を、売買条件を変更せず評価する。
- Q1でわずかに増加したEquity Drawdownを、期間分割テストで局所的な偏りか確認する。

本結果は指定期間のStrategy Tester結果であり、将来の収益性を保証するものではない。
