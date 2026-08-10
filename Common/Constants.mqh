//+------------------------------------------------------------------+
//|                                         Common/Constants.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_CONSTANTS_MQH
#define FENX_COMMON_CONSTANTS_MQH

//--- Framework identifiers and conservative Phase3-1 limits
#define FENX_EA_NAME           "GaRXY FeNX"
#define FENX_MAX_ENGINES       32
#define FENX_DATABUS_CAPACITY  1024
#define FENX_MARKET_SELECTION_MAX_SYMBOLS 5
#define FENX_PAIR_RANKING_COMPARE_EPSILON 0.0001

//--- Startup capacity model audited in Phase4-Core Task003.
//--- Execution publishes one current-symbol snapshot outside the configured
//--- market list, so its eighteen fields are included in the fixed component.
#define FENX_DATABUS_BASELINE_FIXED_ENTRIES       89
#define FENX_DATABUS_BASELINE_PER_SYMBOL_ENTRIES  59

//--- Environment Engine DataBus keys
#define FENX_DATABUS_KEY_ENVIRONMENT_ATR               "Environment.Volatility.ATR"
#define FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE  "Environment.Volatility.Score"
#define FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_LEVEL  "Environment.Volatility.Level"

//--- Typed-only Common Volatility snapshot contract. No new DataBus key is
//--- introduced; legacy Environment.Volatility.* remains authoritative.
#define FENX_COMMON_VOLATILITY_SNAPSHOT_VERSION         "1.0"

//--- Environment range-analysis DataBus keys
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPPER          "Environment.Range.Upper"
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_LOWER          "Environment.Range.Lower"
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_WIDTH_POINTS   "Environment.Range.WidthPoints"
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_MIDPOINT       "Environment.Range.Midpoint"
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_POSITION       "Environment.Range.Position"
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE          "Environment.Range.Score"
#define FENX_DATABUS_KEY_ENVIRONMENT_IS_RANGE             "Environment.Range.IsRange"
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID     "Environment.Range.IsDataValid"
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPDATED_AT     "Environment.Range.UpdatedAt"
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_CLOSED_BAR_TIME "Environment.Range.ClosedBarTime"

//--- Typed-only Common Range snapshot contract. Existing
//--- Environment.Range.* keys remain the authoritative trading interface.
#define FENX_COMMON_RANGE_SNAPSHOT_VERSION                "1.0"

//--- Environment trend-analysis DataBus keys
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_DIRECTION      "Environment.Trend.Direction"
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_STRENGTH       "Environment.Trend.Strength"
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_SCORE          "Environment.Trend.Score"
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_SLOPE          "Environment.Trend.Slope"
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_CONFIDENCE     "Environment.Trend.Confidence"
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_ADX            "Environment.Trend.ADX"
#define FENX_DATABUS_KEY_ENVIRONMENT_IS_TREND             "Environment.Trend.IsTrend"
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_DATA_VALID     "Environment.Trend.IsDataValid"
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_UPDATED_AT     "Environment.Trend.UpdatedAt"

//--- Typed-only Common Trend snapshot contract. Existing
//--- Environment.Trend.* keys remain the authoritative trading interface.
#define FENX_COMMON_TREND_SNAPSHOT_VERSION                "1.0"

//--- Unified market-state DataBus keys
#define FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE         "Environment.Market.State"
#define FENX_DATABUS_KEY_ENVIRONMENT_MARKET_CONFIDENCE    "Environment.Market.Confidence"
#define FENX_DATABUS_KEY_ENVIRONMENT_RECOMMENDED_STYLE    "Environment.Market.RecommendedTradingStyle"
#define FENX_DATABUS_KEY_ENVIRONMENT_RECOMMENDED_RISK     "Environment.Market.RecommendedRiskLevel"
#define FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT    "Environment.Market.UpdatedAt"

//--- Shadow-only Common Environment snapshot contract
#define FENX_COMMON_ENVIRONMENT_SNAPSHOT_VERSION                  "1.0"
#define FENX_COMMON_ENVIRONMENT_KEY_COUNT                         32
#define FENX_DATABUS_NAMESPACE_COMMON_ENVIRONMENT                 "CommonEnvironment"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_VALID               "Valid"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_FRESH               "Fresh"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_VERSION             "Version"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_UPDATED_AT          "UpdatedAt"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_INVALID_REASON      "InvalidReason"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_SYMBOL              "Symbol"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_TIMEFRAME           "Timeframe"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_VOLATILITY_VALID    "VolatilityValid"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RANGE_VALID         "RangeValid"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_TREND_VALID         "TrendValid"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_MARKET_STATE_VALID  "MarketStateValid"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_ATR                 "ATR"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_VOLATILITY_SCORE    "VolatilityScore"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_VOLATILITY_LEVEL    "VolatilityLevel"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RANGE_UPPER         "RangeUpper"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RANGE_LOWER         "RangeLower"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RANGE_MIDPOINT      "RangeMidpoint"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RANGE_WIDTH_POINTS  "RangeWidthPoints"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RANGE_POSITION      "RangePosition"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RANGE_SCORE         "RangeScore"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_IS_RANGE            "IsRange"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_TREND_DIRECTION     "TrendDirection"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_TREND_STRENGTH      "TrendStrength"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_TREND_SCORE         "TrendScore"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_TREND_SLOPE         "TrendSlope"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_TREND_CONFIDENCE    "TrendConfidence"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_ADX                 "ADX"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_IS_TREND            "IsTrend"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_MARKET_STATE        "MarketState"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_MARKET_CONFIDENCE   "MarketConfidence"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RECOMMENDED_STYLE   "RecommendedStyle"
#define FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RECOMMENDED_RISK    "RecommendedRisk"

//--- Shadow-only Common Confidence summary contract. Detailed source facts
//--- remain in CCommonSnapshotStore; DataBus receives only bounded summaries.
#define FENX_COMMON_CONFIDENCE_SNAPSHOT_VERSION                   "1.1"
#define FENX_COMMON_CONFIDENCE_EXPECTED_SOURCE_COUNT              8
#define FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE             6
#define FENX_COMMON_CONFIDENCE_FULL_COMPLETENESS_THRESHOLD        99.999
#define FENX_COMMON_CONFIDENCE_GLOBAL_KEY_COUNT                   0
#define FENX_COMMON_CONFIDENCE_PER_SYMBOL_KEY_COUNT               16
#define FENX_DATABUS_NAMESPACE_COMMON_CONFIDENCE                  "CommonConfidence"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_VALID                "Valid"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_FRESH                "Fresh"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_VERSION              "Version"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_UPDATED_AT           "UpdatedAt"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_AVERAGE              "Average"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_MINIMUM              "Minimum"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_MAXIMUM              "Maximum"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_VARIANCE             "Variance"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_COMPLETENESS         "Completeness"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_VALID_SOURCE_COUNT   "ValidSourceCount"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_MISSING_SOURCE_COUNT "MissingSourceCount"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_BOTTLENECK_STAGE     "BottleneckStage"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_TRANSITION            "CompletenessTransition"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_TRANSITION_WINDOW     "TransitionWindowCount"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_TRANSITION_VALID      "TransitionValid"
#define FENX_DATABUS_FIELD_COMMON_CONFIDENCE_TRANSITION_UPDATED_AT "TransitionUpdatedAt"

//--- Shadow-only Common Decision Score summary contract. The detailed,
//--- source-level contract is retained in CCommonSnapshotStore; DataBus only
//--- exposes the bounded descriptive summary used by diagnostics.
#define FENX_COMMON_DECISION_SNAPSHOT_VERSION                     "1.0"
#define FENX_COMMON_DECISION_EXPECTED_SOURCE_COUNT                5
#define FENX_COMMON_DECISION_GLOBAL_KEY_COUNT                     0
#define FENX_COMMON_DECISION_PER_SYMBOL_KEY_COUNT                 13
#define FENX_COMMON_DECISION_COMPARE_EPSILON                      0.000000001
#define FENX_DATABUS_NAMESPACE_COMMON_DECISION                    "CommonDecision"
#define FENX_DATABUS_FIELD_COMMON_DECISION_VALID                  "Valid"
#define FENX_DATABUS_FIELD_COMMON_DECISION_FRESH                  "Fresh"
#define FENX_DATABUS_FIELD_COMMON_DECISION_STATE                  "State"
#define FENX_DATABUS_FIELD_COMMON_DECISION_VERSION                "Version"
#define FENX_DATABUS_FIELD_COMMON_DECISION_UPDATED_AT             "UpdatedAt"
#define FENX_DATABUS_FIELD_COMMON_DECISION_TIMEFRAME              "Timeframe"
#define FENX_DATABUS_FIELD_COMMON_DECISION_AVERAGE                "Average"
#define FENX_DATABUS_FIELD_COMMON_DECISION_MINIMUM                "Minimum"
#define FENX_DATABUS_FIELD_COMMON_DECISION_MAXIMUM                "Maximum"
#define FENX_DATABUS_FIELD_COMMON_DECISION_VARIANCE               "Variance"
#define FENX_DATABUS_FIELD_COMMON_DECISION_COMPLETENESS           "Completeness"
#define FENX_DATABUS_FIELD_COMMON_DECISION_BOTTLENECK_STAGE       "BottleneckStage"
#define FENX_DATABUS_FIELD_COMMON_DECISION_STRONGEST_STAGE        "StrongestStage"

//--- Per-symbol Market Selection DataBus namespace and field names
#define FENX_DATABUS_NAMESPACE_MARKET_SELECTION           "MarketSelection"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_SYMBOL        "Symbol"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_IS_ELIGIBLE   "IsMarketEligible"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_SCORE         "MarketSelectionScore"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_CONFIDENCE    "MarketSelectionConfidence"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_POINTS "SpreadPoints"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_ATR    "SpreadToATRRatio"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_REJECTION     "RejectionReason"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT    "MarketSelectionUpdatedAt"

//--- Per-symbol Pair Ranking DataBus namespace and field names
#define FENX_DATABUS_NAMESPACE_PAIR_RANKING                "PairRanking"
#define FENX_DATABUS_FIELD_PAIR_RANKING_SYMBOL             "Symbol"
#define FENX_DATABUS_FIELD_PAIR_RANKING_RANK               "PairRank"
#define FENX_DATABUS_FIELD_PAIR_RANKING_SCORE              "PairRankingScore"
#define FENX_DATABUS_FIELD_PAIR_RANKING_CONFIDENCE         "PairRankingConfidence"
#define FENX_DATABUS_FIELD_PAIR_RANKING_IS_RANKED          "IsPairRanked"
#define FENX_DATABUS_FIELD_PAIR_RANKING_REASON             "PairRankingReason"
#define FENX_DATABUS_FIELD_PAIR_RANKING_UPDATED_AT         "PairRankingUpdatedAt"

//--- Global Pair Ranking DataBus keys
#define FENX_DATABUS_KEY_PAIR_RANKING_SYMBOL_COUNT         "PairRanking.RankedSymbolCount"
#define FENX_DATABUS_KEY_PAIR_RANKING_TOP_SYMBOL           "PairRanking.TopRankedSymbol"
#define FENX_DATABUS_KEY_PAIR_RANKING_TOP_SCORE            "PairRanking.TopRankingScore"
#define FENX_DATABUS_KEY_PAIR_RANKING_DATA_VALID           "PairRanking.RankingDataValid"
#define FENX_DATABUS_KEY_PAIR_RANKING_UPDATED_AT           "PairRanking.RankingUpdatedAt"

//--- Per-symbol Capital Allocation DataBus namespace and field names
#define FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION              "CapitalAllocation"
#define FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_SYMBOL           "Symbol"
#define FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_IS_ALLOCATED     "IsCapitalAllocated"
#define FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_PERCENT          "CapitalAllocationPercent"
#define FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_SCORE            "CapitalAllocationScore"
#define FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_CONFIDENCE       "CapitalAllocationConfidence"
#define FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_REASON           "CapitalAllocationReason"
#define FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_UPDATED_AT       "CapitalAllocationUpdatedAt"

//--- Global Capital Allocation DataBus keys
#define FENX_DATABUS_KEY_CAPITAL_ALLOCATION_SYMBOL_COUNT        "CapitalAllocation.AllocatedSymbolCount"
#define FENX_DATABUS_KEY_CAPITAL_ALLOCATION_TOTAL_PERCENT       "CapitalAllocation.TotalAllocatedPercent"
#define FENX_DATABUS_KEY_CAPITAL_ALLOCATION_UNALLOCATED_PERCENT "CapitalAllocation.UnallocatedPercent"
#define FENX_DATABUS_KEY_CAPITAL_ALLOCATION_TOP_SYMBOL          "CapitalAllocation.TopAllocatedSymbol"
#define FENX_DATABUS_KEY_CAPITAL_ALLOCATION_DATA_VALID          "CapitalAllocation.AllocationDataValid"
#define FENX_DATABUS_KEY_CAPITAL_ALLOCATION_UPDATED_AT          "CapitalAllocation.AllocationUpdatedAt"

//--- Per-symbol Trading Style DataBus namespace and field names
#define FENX_DATABUS_NAMESPACE_TRADING_STYLE                    "TradingStyle"
#define FENX_DATABUS_FIELD_TRADING_STYLE                        "TradingStyle"
#define FENX_DATABUS_FIELD_TRADING_STYLE_SCORE                  "TradingStyleScore"
#define FENX_DATABUS_FIELD_TRADING_STYLE_CONFIDENCE             "TradingStyleConfidence"
#define FENX_DATABUS_FIELD_TRADING_STYLE_REASON                 "TradingStyleReason"
#define FENX_DATABUS_FIELD_TRADING_STYLE_UPDATED_AT             "TradingStyleUpdatedAt"
#define FENX_DATABUS_FIELD_TRADING_STYLE_IS_VALID               "IsTradingStyleValid"

//--- Global Trading Style DataBus keys
#define FENX_DATABUS_KEY_TRADING_STYLE_ACTIVE_COUNT             "TradingStyle.ActiveTradingStyleCount"
#define FENX_DATABUS_KEY_TRADING_STYLE_DATA_VALID               "TradingStyle.StyleDataValid"
#define FENX_DATABUS_KEY_TRADING_STYLE_UPDATED_AT               "TradingStyle.TradingStyleUpdatedAt"

//--- Per-symbol Strategy Selection DataBus namespace and field names
#define FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION                "StrategySelection"
#define FENX_DATABUS_FIELD_SELECTED_STRATEGY                     "SelectedStrategy"
#define FENX_DATABUS_FIELD_STRATEGY_SELECTION_SCORE              "StrategySelectionScore"
#define FENX_DATABUS_FIELD_STRATEGY_SELECTION_CONFIDENCE         "StrategySelectionConfidence"
#define FENX_DATABUS_FIELD_STRATEGY_SELECTION_REASON             "StrategySelectionReason"
#define FENX_DATABUS_FIELD_STRATEGY_SELECTION_IS_VALID           "IsStrategySelectionValid"
#define FENX_DATABUS_FIELD_STRATEGY_SELECTION_UPDATED_AT         "StrategySelectionUpdatedAt"

//--- Global Strategy Selection DataBus keys
#define FENX_DATABUS_KEY_STRATEGY_SELECTION_ACTIVE_COUNT         "StrategySelection.ActiveStrategyCount"
#define FENX_DATABUS_KEY_STRATEGY_SELECTION_NO_TRADE_COUNT       "StrategySelection.NoTradeSymbolCount"
#define FENX_DATABUS_KEY_STRATEGY_SELECTION_DATA_VALID           "StrategySelection.StrategySelectionDataValid"
#define FENX_DATABUS_KEY_STRATEGY_SELECTION_UPDATED_AT           "StrategySelection.StrategySelectionUpdatedAt"

//--- Per-symbol Standby Engine DataBus namespace and field names
#define FENX_DATABUS_NAMESPACE_STANDBY                             "Standby"
#define FENX_DATABUS_FIELD_STANDBY_STATE                           "StandbyState"
#define FENX_DATABUS_FIELD_STANDBY_IS_ACTIVE                       "IsStandbyActive"
#define FENX_DATABUS_FIELD_STANDBY_NEW_ENTRIES_ALLOWED            "AreNewEntriesAllowed"
#define FENX_DATABUS_FIELD_STANDBY_PRESERVE_POSITIONS              "PreserveExistingPositions"
#define FENX_DATABUS_FIELD_STANDBY_REASON                          "StandbyReason"
#define FENX_DATABUS_FIELD_STANDBY_CONFIDENCE                      "StandbyConfidence"
#define FENX_DATABUS_FIELD_STANDBY_ENTERED_AT                      "StandbyEnteredAt"
#define FENX_DATABUS_FIELD_STANDBY_DURATION_SECONDS                "StandbyDurationSeconds"
#define FENX_DATABUS_FIELD_STANDBY_RECOVERY_PROGRESS               "RecoveryProgress"
#define FENX_DATABUS_FIELD_STANDBY_ESCALATION_SCORE                "EscalationScore"
#define FENX_DATABUS_FIELD_STANDBY_RECOMMENDED_NEXT_STATE          "RecommendedNextState"
#define FENX_DATABUS_FIELD_STANDBY_DATA_VALID                      "StandbyDataValid"
#define FENX_DATABUS_FIELD_STANDBY_UPDATED_AT                      "StandbyUpdatedAt"

//--- Global Standby Engine DataBus keys
#define FENX_DATABUS_KEY_STANDBY_ACTIVE_SYMBOL_COUNT               "Standby.ActiveStandbySymbolCount"
#define FENX_DATABUS_KEY_STANDBY_RECOVERY_PENDING_COUNT            "Standby.RecoveryPendingCount"
#define FENX_DATABUS_KEY_STANDBY_ESCALATION_PENDING_COUNT          "Standby.EscalationPendingCount"
#define FENX_DATABUS_KEY_STANDBY_RISK_STOP_PENDING_COUNT           "Standby.RiskStopPendingCount"
#define FENX_DATABUS_KEY_STANDBY_SYSTEM_VALID                      "Standby.StandbySystemValid"
#define FENX_DATABUS_KEY_STANDBY_SYSTEM_UPDATED_AT                 "Standby.StandbySystemUpdatedAt"

//--- Per-symbol Risk Engine DataBus namespace and field names
#define FENX_DATABUS_NAMESPACE_RISK                                "Risk"
#define FENX_DATABUS_FIELD_SYMBOL_RISK_STATE                       "SymbolRiskState"
#define FENX_DATABUS_FIELD_RISK_ACTION                             "RiskAction"
#define FENX_DATABUS_FIELD_IS_RISK_APPROVED                        "IsRiskApproved"
#define FENX_DATABUS_FIELD_NEW_ENTRIES_RISK_APPROVED               "AreNewEntriesRiskApproved"
#define FENX_DATABUS_FIELD_RECOMMENDED_ALLOCATION_MULTIPLIER       "RecommendedAllocationMultiplier"
#define FENX_DATABUS_FIELD_RISK_SCORE                              "RiskScore"
#define FENX_DATABUS_FIELD_RISK_CONFIDENCE                         "RiskConfidence"
#define FENX_DATABUS_FIELD_RISK_REASON                             "RiskReason"
#define FENX_DATABUS_FIELD_RISK_PRESERVE_POSITIONS                 "PreserveExistingPositions"
#define FENX_DATABUS_FIELD_RISK_ESCALATION_REQUIRED                "RiskEscalationRequired"
#define FENX_DATABUS_FIELD_RISK_DATA_VALID                         "RiskDataValid"
#define FENX_DATABUS_FIELD_RISK_UPDATED_AT                         "RiskUpdatedAt"

//--- Global Risk Engine DataBus keys
#define FENX_DATABUS_KEY_RISK_SYSTEM_STATE                         "Risk.SystemRiskState"
#define FENX_DATABUS_KEY_RISK_SYSTEM_SCORE                         "Risk.SystemRiskScore"
#define FENX_DATABUS_KEY_RISK_SYSTEM_CONFIDENCE                    "Risk.SystemRiskConfidence"
#define FENX_DATABUS_KEY_RISK_SYSTEM_TRADING_ALLOWED               "Risk.SystemTradingAllowed"
#define FENX_DATABUS_KEY_RISK_SYSTEM_NEW_ENTRIES_ALLOWED           "Risk.SystemNewEntriesAllowed"
#define FENX_DATABUS_KEY_RISK_SYSTEM_ALLOCATION_MULTIPLIER         "Risk.SystemAllocationMultiplier"
#define FENX_DATABUS_KEY_RISK_SUSPENDED_SYMBOL_COUNT               "Risk.SuspendedSymbolCount"
#define FENX_DATABUS_KEY_RISK_STOP_REQUIRED_COUNT                  "Risk.RiskStopRequiredCount"
#define FENX_DATABUS_KEY_RISK_INVALID_SYMBOL_COUNT                 "Risk.InvalidRiskSymbolCount"
#define FENX_DATABUS_KEY_RISK_SYSTEM_REASON                        "Risk.SystemRiskReason"
#define FENX_DATABUS_KEY_RISK_SYSTEM_DATA_VALID                    "Risk.SystemRiskDataValid"
#define FENX_DATABUS_KEY_RISK_SYSTEM_UPDATED_AT                    "Risk.SystemRiskUpdatedAt"

//--- Per-symbol Minimal Execution System DataBus namespace and field names
#define FENX_DATABUS_NAMESPACE_EXECUTION                           "Execution"
#define FENX_DATABUS_FIELD_EXECUTION_GATE_ALLOWED                  "ExecutionGateAllowed"
#define FENX_DATABUS_FIELD_EXECUTION_GATE_REASON                   "ExecutionGateReason"
#define FENX_DATABUS_FIELD_ENTRY_SIGNAL                            "EntrySignal"
#define FENX_DATABUS_FIELD_ENTRY_SIGNAL_SCORE                      "EntrySignalScore"
#define FENX_DATABUS_FIELD_ENTRY_SIGNAL_CONFIDENCE                 "EntrySignalConfidence"
#define FENX_DATABUS_FIELD_REQUESTED_DIRECTION                     "RequestedDirection"
#define FENX_DATABUS_FIELD_REQUESTED_VOLUME                        "RequestedVolume"
#define FENX_DATABUS_FIELD_REQUESTED_ENTRY_PRICE                   "RequestedEntryPrice"
#define FENX_DATABUS_FIELD_REQUESTED_STOP_LOSS                     "RequestedStopLoss"
#define FENX_DATABUS_FIELD_REQUESTED_TAKE_PROFIT                   "RequestedTakeProfit"
#define FENX_DATABUS_FIELD_DUPLICATE_ORDER_BLOCKED                 "DuplicateOrderBlocked"
#define FENX_DATABUS_FIELD_EXISTING_POSITION_DETECTED              "ExistingPositionDetected"
#define FENX_DATABUS_FIELD_LAST_ORDER_REQUEST_AT                   "LastOrderRequestAt"
#define FENX_DATABUS_FIELD_LAST_EXECUTION_RESULT                   "LastExecutionResult"
#define FENX_DATABUS_FIELD_LAST_EXECUTION_RETCODE                  "LastExecutionRetcode"
#define FENX_DATABUS_FIELD_LAST_EXECUTION_DEAL_TICKET               "LastExecutionDealTicket"
#define FENX_DATABUS_FIELD_EXECUTION_DATA_VALID                    "ExecutionDataValid"
#define FENX_DATABUS_FIELD_EXECUTION_UPDATED_AT                    "ExecutionUpdatedAt"

//--- Global Minimal Execution System DataBus keys
#define FENX_DATABUS_KEY_EXECUTION_SYSTEM_ENABLED                  "Execution.SystemEnabled"
#define FENX_DATABUS_KEY_EXECUTION_SYSTEM_READY                    "Execution.SystemReady"
#define FENX_DATABUS_KEY_EXECUTION_SYSTEM_VALID                    "Execution.SystemValid"
#define FENX_DATABUS_KEY_EXECUTION_OPEN_POSITION_COUNT             "Execution.OpenFeNXPositionCount"
#define FENX_DATABUS_KEY_EXECUTION_SUCCESSFUL_ORDER_COUNT          "Execution.SuccessfulOrderCount"
#define FENX_DATABUS_KEY_EXECUTION_FAILED_ORDER_COUNT              "Execution.FailedOrderCount"
#define FENX_DATABUS_KEY_EXECUTION_BLOCKED_ORDER_COUNT             "Execution.BlockedOrderCount"
#define FENX_DATABUS_KEY_EXECUTION_LAST_GLOBAL_AT                  "Execution.LastGlobalExecutionAt"

#endif // FENX_COMMON_CONSTANTS_MQH
