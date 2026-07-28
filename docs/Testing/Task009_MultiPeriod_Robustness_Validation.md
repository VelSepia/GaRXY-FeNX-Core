# GaRXY FeNX Task #009 Multi-Period Robustness Validation Report

## 結論

Task #008完成版は、注文、position追跡、close、Risk STOP復帰を含む
Execution Pipelineを10年間継続して実行できた。一方、利益面の期間外再現性は
確認できなかった。

- 2021～2025の独立年別testでは、黒字かつPF 1.0超は2024年だけだった。
- 2016～2025の連続10年testは、1,714 trades、PF 0.836516、
  Net Profit -401.56だった。
- 連続10年の年別損益は黒字2年、赤字8年だった。
- Task #008の改善基準期間である2024年は、5年中で唯一の黒字年かつ最高PFだった。

したがって、Task #008には特定期間への過剰最適化を疑う強い客観的根拠がある。
Task #009では仕様どおり修正、再最適化、閾値変更を行っていない。

## 固定した検証対象

- 基準Git commit: `3dc9b777738f282aae55280a8f3a150d0a2410fd`
- 基準branch: `feature/task008-recovery`
- Task #008 source: MQLファイル31件
- Task #008 sourceとportable test sourceの不一致: 0件
- `Strategy/RangeMeanReversionStrategy.mqh` SHA-256:
  `F0EF07BE2404D5141A701CF1289A84BDC87C54F3C8253AB71A30858A1A727B4B`
- testに使用した再build後EX5 SHA-256:
  `47330D8C88AD9F5B636F1F414155B837CE21E30EA4BB129835078D53811FFFBD`
- 入力set SHA-256:
  `381B4F4D774329FBC062E0D62C30C552A3B8C1C67049E2756CD553CD1699282F`

6本のtester configは、`FromDate`、`ToDate`、`Report`以外が同一である。
固定部分のSHA-256はすべて
`9E6F8A53D777BBAA34987C7CF768ECBF697913FC3C29315483E880485F8C1AF8`
だった。

検証条件:

- Symbol: USDJPY
- Period: H1
- Modeling: 1 minute OHLC
- Initial deposit: 10,000 USD
- Leverage: 1:100
- Execution mode: no artificial delay
- Optimization: disabled
- Local agent: enabled
- Task #008 input parameters: unchanged

## Build

固定したTask #008 sourceを、test開始前にMetaEditorで再buildした。

```text
Result: 0 errors, 1 warnings, 5413 ms elapsed, cpu='X64 Regular'
```

warning 1件は既存の`#property version "0.1.0"`に対するMQL5 Market形式警告であり、
Task #009によるsource変更ではない。

## 実行したtest

| Run | From | To | Native report | 結果 |
| --- | --- | --- | --- | --- |
| 2021 | 2021-01-01 | 2021-12-31 | generated | successfully finished |
| 2022 | 2022-01-01 | 2022-12-31 | generated | successfully finished |
| 2023 | 2023-01-01 | 2023-12-31 | generated | successfully finished |
| 2024 | 2024-01-01 | 2024-12-31 | generated | successfully finished |
| 2025 | 2025-01-01 | 2025-12-31 | generated | successfully finished |
| Long | 2016-01-01 | 2025-12-31 | generated | successfully finished |

2024年runはTask #008報告値を完全再現した。

## 独立年別結果

| Year | Trades | Win rate | PF | Net profit | Balance DD | Equity DD | Avg holding (s) | Max wins | Max losses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2021 | 221 | 68.78% | 0.826350 | -37.01 | 66.47 | 70.88 | 91,440.61 | 15 | 6 |
| 2022 | 148 | 59.46% | 0.585784 | -142.95 | 147.65 | 151.98 | 78,268.52 | 8 | 9 |
| 2023 | 154 | 67.53% | 0.912018 | -22.57 | 40.42 | 47.52 | 64,984.16 | 10 | 6 |
| 2024 | 144 | 77.08% | 1.372968 | +64.24 | 20.74 | 24.41 | 72,593.83 | 15 | 3 |
| 2025 | 128 | 64.84% | 0.785776 | -52.44 | 106.80 | 112.30 | 68,994.62 | 9 | 5 |

独立年別trade数は128～221であり、取引停止年度はなかった。ただし最大／最小比は
1.727で、期間によるentry頻度差はある。

## 独立年別Execution整合性

| Year | Risk STOP | Recoveries | Orders rejected | Failed closes | Entry retries | Close retries | Open events | Close events |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2021 | 10 | 10 | 0 | 0 | 0 | 0 | 221 | 220 |
| 2022 | 19 | 19 | 0 | 0 | 0 | 0 | 148 | 148 |
| 2023 | 23 | 23 | 0 | 0 | 0 | 0 | 154 | 153 |
| 2024 | 23 | 23 | 0 | 0 | 0 | 0 | 144 | 143 |
| 2025 | 10 | 10 | 0 | 0 | 0 | 0 | 128 | 128 |

2021、2023、2024のopen/close差1件は、期間終了時に開いていたpositionをnative
testerが精算する既存のperiod-boundary挙動である。native reportの最終損益には
精算結果が含まれ、custom reporterと一致した。

## 2016～2025連続test

| Metric | Result |
| --- | ---: |
| Trades | 1,714 |
| Wins / losses | 1,177 / 537 |
| Win rate | 68.67% |
| Profit Factor | 0.836516 |
| Net profit | -401.56 |
| Balance drawdown | 430.07 (4.30%) |
| Equity drawdown | 436.19 (4.36%) |
| Average holding time | 79,790.02 s |
| Maximum consecutive wins | 17 |
| Maximum consecutive losses | 9 |
| Risk STOP activations / recoveries | 159 / 159 |
| Orders requested / accepted / rejected | 1,714 / 1,714 / 0 |
| Closes requested / accepted / rejected | 1,442 / 1,442 / 0 |
| Entry retries / close retries | 0 / 0 |
| Position opens / closes | 1,714 / 1,714 |

連続10年でもRisk STOP固定は発生せず、すべてSTANDBYへ復帰した。entry、position
open、position管理、closeの各stageは期間末まで継続動作した。

## 連続test内の年別損益

| Year | Trades | Win rate | PF | Net profit |
| --- | ---: | ---: | ---: | ---: |
| 2016 | 132 | 66.67% | 0.709357 | -88.03 |
| 2017 | 151 | 65.56% | 0.792602 | -55.96 |
| 2018 | 194 | 67.01% | 0.743505 | -68.02 |
| 2019 | 208 | 75.48% | 1.177546 | +27.01 |
| 2020 | 234 | 70.09% | 0.878094 | -28.47 |
| 2021 | 221 | 69.23% | 0.828314 | -36.60 |
| 2022 | 148 | 59.46% | 0.585610 | -143.01 |
| 2023 | 153 | 67.32% | 0.910147 | -23.05 |
| 2024 | 145 | 77.24% | 1.387140 | +67.01 |
| 2025 | 128 | 64.84% | 0.785776 | -52.44 |

独立年別runとの差は年境界positionと連続状態の持越しによる小差であり、方向性は
一致している。連続testの年別合計は1,714 trades、-401.56となり、全体reportと
一致した。

## 月別分布

連続10年の120か月は、黒字56か月、赤字64か月だった。最悪10か月の合計は
-321.99で、全赤字月損失826.12の38.98%を占めた。

最悪月:

| Month | Trades | PF | Net profit |
| --- | ---: | ---: | ---: |
| 2022-03 | 10 | 0.063218 | -45.64 |
| 2016-07 | 12 | 0.293178 | -34.50 |
| 2025-05 | 6 | 0.035128 | -33.51 |
| 2016-11 | 9 | 0.261752 | -33.45 |
| 2023-03 | 10 | 0.290504 | -32.80 |
| 2025-10 | 12 | 0.202256 | -31.83 |
| 2017-01 | 12 | 0.402458 | -31.12 |
| 2016-02 | 10 | 0.363202 | -28.00 |
| 2022-10 | 8 | 0.235780 | -25.93 |
| 2021-11 | 11 | 0.095118 | -25.21 |

全月データは`task009-monthly-profit.csv`に保存した。

## Pipeline継続動作

連続10年のfinal pipeline counters:

| Stage | Blocked ticks | Block events |
| --- | ---: | ---: |
| Environment | 4,939,866 | 4,435 |
| Market Selection | 28,020 | 1,748 |
| Pair Ranking | 0 | 0 |
| Capital Allocation | 0 | 0 |
| Trading Style | 0 | 0 |
| Strategy Selection | 0 | 0 |
| Standby | 0 | 0 |
| Risk | 1,600,946 | 8,901 |
| Execution | 8,005 | 803 |

これらはblock理由の集計であり、pipeline停止を意味しない。全期間で注文とcloseが
継続し、最終的に1,714 positionsをopen/closeした。

## 過剰最適化評価

評価: **高リスク**

根拠:

1. Task #008調整期間の2024年だけが、2021～2025独立runでPF 1.0超かつ黒字だった。
2. 2021、2022、2023、2025を連続reportから合算すると、650 trades、
   PF 0.759251、Net -255.10だった。
3. 2024年PF 1.372968は、上記4年の独立run PF中央値0.806063を70.33%上回った。
4. 10年では黒字年2、赤字年8で、PF 0.836516、Net -401.56だった。
5. 損失は単一年だけではなく2016、2017、2018、2020、2021、2022、2023、2025へ
   分散している。

以上から、Task #008の2024年改善は長期的な汎化改善ではなく、期間固有のentry
selectionへ適合した可能性が高い。

## 市場環境分類の限界

Task #008最終版は、accepted entryごとのEnvironment、Trend、Range、
Volatility、Spread、Confidenceを永続ログへ出力しない。native Strategy Tester
reportは時刻、注文、deal、損益を保持するが、entry時点のEngine snapshotは保持しない。

そのため、PFが崩れた月を時系列で特定することはできたが、それを
「上昇trend」「下降trend」「高volatility」などへ客観的に分類することは、
現在の成果物だけではできない。Task #009の「推測しない」方針に従い、価格動向の
印象だけでregime名を付けていない。

## Bottleneck report

| Component | Reason from evidence | Proposed Task #010 direction | Estimated impact |
| --- | --- | --- | --- |
| Range Mean Reversion entry quality | 2024以外の独立4年がすべて赤字。連続10年PF 0.836516 | まず既存DataBus snapshotをentry/closeへvalidation-only記録し、regime別損益を確定する | 原因切分け: high、利益改善: 未評価 |
| Environment/quality observability | accepted entry時点のTrend/Range/Volatility等が最終版ログにない | 売買判断を変えず、検証telemetryだけを追加する | 市場環境別原因の特定: high |
| Risk/Standby recovery | 159 STOPに対して159復帰。固定なし | 修正不要。回帰testを維持する | pipeline reliability維持 |
| Execution | 10年で拒否0、failed close 0、retry 0 | 修正不要。回帰testを維持する | pipeline reliability維持 |

利益改善策や新しい閾値はTask #009では提案値を作成していない。具体的な売買変更は、
既存Engine snapshotと損益の関係を取得した後にTask #010で判断する。

## Temporary modifications

product sourceへの一時変更は0件だった。

追加したものは、Task #009専用のtester config、既存setの複製、解析script、
compact evidence、CSV集計、本文書だけである。EA、Engine、Strategy、Risk、
Environment、Execution Pipeline、SL/TP、Entry閾値は変更していない。

## Retained validation artifacts

- `task009-summary.csv`
- `task009-long-run-yearly-profit.csv`
- `task009-monthly-profit.csv`
- `task009-pipeline.csv`
- `task009-evidence-checksums.csv`
- 6本のtester config
- Task #008と同一内容のtester set
- compact evidence 6本
- build log
- aggregation script

native HTML reportsとその画像は、ローカル検証workspaceに保持した。Gitには、
重複する大容量生成物ではなく、再検証用config、集計script、compact evidence、
checksums、CSV、本文書を含める。
