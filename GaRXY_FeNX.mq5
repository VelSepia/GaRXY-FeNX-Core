//+------------------------------------------------------------------+
//|                                                   GaRXY_FeNX.mq5 |
//|                    Phase3-1 framework for the GaRXY FeNX Expert |
//+------------------------------------------------------------------+
#property copyright "VelSepia"
#property version   "0.1.0"
#property strict

#include "Core/CoreController.mqh"
#include "Core/DataBusCapacityPlan.mqh"
#include "Common/CommonSnapshotStore.mqh"
#include "Environment/MarketStateIntegrator.mqh"
#include "Environment/EnvironmentEngine.mqh"
#include "Environment/RangeDetector.mqh"
#include "Environment/TrendDetector.mqh"
#include "Environment/VolatilityAnalyzer.mqh"
#include "MarketSelection/MarketSelectionEngine.mqh"
#include "PairRanking/PairRankingEngine.mqh"
#include "CapitalAllocation/CapitalAllocationEngine.mqh"
#include "TradingStyle/TradingStyleEngine.mqh"
#include "Strategy/StrategySelectionEngine.mqh"
#include "Standby/StandbyEngine.mqh"
#include "Risk/RiskEngine.mqh"
#include "Confidence/ConfidenceEngine.mqh"
#include "Decision/DecisionScoreEngine.mqh"
#include "Execution/ExecutionEngine.mqh"
#include "Test/BacktestValidationReporter.mqh"

//--- Phase3-9.5 execution inputs. Execution remains opt-in for tester safety.
input bool   InpExecutionEnabled                    = false;
input string InpExecutionSymbol                     = "USDJPY";
input long   InpExecutionMagicNumber                = 93095;
input double InpExecutionFixedLot                   = 0.01;
input double InpExecutionMaximumSpreadPoints        = 20.0;
input double InpExecutionEntryBoundaryDistancePoints= 20.0;
input double InpExecutionEntryBoundaryDistanceAtrRatio = 0.15;
input string InpExecutionExitMode                   = "RANGE_BASED";
input double InpExecutionFixedTakeProfitPoints      = 30.0;
input double InpExecutionFixedStopLossPoints        = 30.0;
input double InpExecutionRangeStopBufferPoints      = 10.0;
input double InpExecutionMinimumRangeScore          = 70.0;
input double InpExecutionMinimumStrategyConfidence  = 65.0;
input double InpExecutionMinimumRiskConfidence      = 60.0;
input int    InpExecutionOrderCooldownSeconds       = 60;
input bool   InpExecutionOneOrderPerBar             = true;
input int    InpExecutionMaximumOpenPositionsPerSymbol = 1;
input bool   InpExecutionAllowBuy                   = true;
input bool   InpExecutionAllowSell                  = true;
input int    InpExecutionMaximumSlippagePoints      = 10;
input int    InpExecutionTransientRetryLimit        = 1;
input string InpExecutionTradeComment               = "GaRXY_FeNX_Core_v1";

//--- Framework-wide services
CParameterManager g_parameters;
CCoreController   g_controller;
CCommonSnapshotStore g_common_snapshot_store;
CVolatilityAnalyzer g_volatility_analyzer;
CRangeDetector      g_range_detector;
CTrendDetector      g_trend_detector;
CMarketStateIntegrator g_market_state_integrator;
CEnvironmentEngine     g_environment_engine;
CMarketSelectionEngine g_market_selection_engine;
CPairRankingEngine     g_pair_ranking_engine;
CCapitalAllocationEngine g_capital_allocation_engine;
CTradingStyleEngine      g_trading_style_engine;
CStrategySelectionEngine g_strategy_selection_engine;
CStandbyEngine           g_standby_engine;
CRiskEngine              g_risk_engine;
CConfidenceEngine        g_confidence_engine;
CDecisionScoreEngine     g_decision_score_engine;
CExecutionEngine         g_execution_engine;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!g_parameters.Load())
     {
      CLogger::Error("Unable to load framework parameters.");
      return(INIT_FAILED);
     }
   if(!g_parameters.ConfigureExecution(InpExecutionEnabled,InpExecutionSymbol,
                                       InpExecutionMagicNumber,InpExecutionFixedLot,
                                       InpExecutionMaximumSpreadPoints,
                                       InpExecutionEntryBoundaryDistancePoints,
                                       InpExecutionEntryBoundaryDistanceAtrRatio,
                                       InpExecutionExitMode,InpExecutionFixedTakeProfitPoints,
                                       InpExecutionFixedStopLossPoints,
                                       InpExecutionRangeStopBufferPoints,
                                       InpExecutionMinimumRangeScore,
                                       InpExecutionMinimumStrategyConfidence,
                                       InpExecutionMinimumRiskConfidence,
                                       InpExecutionOrderCooldownSeconds,
                                       InpExecutionOneOrderPerBar,
                                       InpExecutionMaximumOpenPositionsPerSymbol,
                                       InpExecutionAllowBuy,InpExecutionAllowSell,
                                       InpExecutionMaximumSlippagePoints,
                                       InpExecutionTransientRetryLimit,
                                       InpExecutionTradeComment))
     {
      CLogger::Error("Unable to configure minimal execution parameters.");
      return(INIT_FAILED);
     }

   CDataBusCapacityPlan capacity_plan;
   if(!capacity_plan.Build(g_parameters.MarketSelectionSymbolCount(),
                           FENX_COMMON_ENVIRONMENT_KEY_COUNT,
                           FENX_COMMON_CONFIDENCE_GLOBAL_KEY_COUNT+
                           FENX_COMMON_DECISION_GLOBAL_KEY_COUNT,
                           FENX_COMMON_CONFIDENCE_PER_SYMBOL_KEY_COUNT+
                           FENX_COMMON_DECISION_PER_SYMBOL_KEY_COUNT) ||
      !capacity_plan.Validate(g_controller.DataBus()))
     {
      CLogger::Error("Unable to satisfy the startup DataBus capacity plan.");
      return(INIT_FAILED);
     }

   if(!g_volatility_analyzer.SetSnapshotStore(g_common_snapshot_store))
     {
      CLogger::Error("Unable to attach CommonSnapshotStore to VolatilityAnalyzer.");
      return(INIT_FAILED);
     }
   if(!g_range_detector.SetSnapshotStore(g_common_snapshot_store))
     {
      CLogger::Error("Unable to attach CommonSnapshotStore to RangeDetector.");
      return(INIT_FAILED);
     }
   if(!g_trend_detector.SetSnapshotStore(g_common_snapshot_store))
     {
      CLogger::Error("Unable to attach CommonSnapshotStore to TrendDetector.");
      return(INIT_FAILED);
     }
   if(!g_market_state_integrator.SetSnapshotStore(g_common_snapshot_store))
     {
      CLogger::Error("Unable to attach CommonSnapshotStore to MarketStateIntegrator.");
      return(INIT_FAILED);
     }
   if(!g_environment_engine.SetSnapshotStore(g_common_snapshot_store))
     {
      CLogger::Error("Unable to attach CommonSnapshotStore to EnvironmentEngine.");
      return(INIT_FAILED);
     }
   if(!g_standby_engine.SetSnapshotStore(g_common_snapshot_store))
     {
      CLogger::Error("Unable to attach CommonSnapshotStore to StandbyEngine.");
      return(INIT_FAILED);
     }
   if(!g_risk_engine.SetSnapshotStore(g_common_snapshot_store))
     {
      CLogger::Error("Unable to attach CommonSnapshotStore to RiskEngine.");
      return(INIT_FAILED);
     }
   if(!g_confidence_engine.SetSnapshotStore(g_common_snapshot_store))
     {
      CLogger::Error("Unable to attach CommonSnapshotStore to ConfidenceEngine.");
      return(INIT_FAILED);
     }
   if(!g_decision_score_engine.SetSnapshotStore(g_common_snapshot_store))
     {
      CLogger::Error("Unable to attach CommonSnapshotStore to DecisionScoreEngine.");
      return(INIT_FAILED);
     }
   if(!g_execution_engine.SetSnapshotStore(g_common_snapshot_store))
     {
      CLogger::Error("Unable to attach CommonSnapshotStore to Common Entry, Exit, and Execution adapters.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_volatility_analyzer))
     {
      CLogger::Error("Unable to register VolatilityAnalyzer.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_range_detector))
     {
      CLogger::Error("Unable to register RangeDetector.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_trend_detector))
     {
      CLogger::Error("Unable to register TrendDetector.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_market_state_integrator))
     {
      CLogger::Error("Unable to register MarketStateIntegrator.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_environment_engine))
     {
      CLogger::Error("Unable to register EnvironmentEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_market_selection_engine))
     {
      CLogger::Error("Unable to register MarketSelectionEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_pair_ranking_engine))
     {
      CLogger::Error("Unable to register PairRankingEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_capital_allocation_engine))
     {
      CLogger::Error("Unable to register CapitalAllocationEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_trading_style_engine))
     {
      CLogger::Error("Unable to register TradingStyleEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_strategy_selection_engine))
     {
      CLogger::Error("Unable to register StrategySelectionEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_standby_engine))
     {
      CLogger::Error("Unable to register StandbyEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_risk_engine))
     {
      CLogger::Error("Unable to register RiskEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_confidence_engine))
     {
      CLogger::Error("Unable to register ConfidenceEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_decision_score_engine))
     {
      CLogger::Error("Unable to register DecisionScoreEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_execution_engine))
     {
      CLogger::Error("Unable to register ExecutionEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.Initialize(g_parameters))
      return(INIT_FAILED);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_controller.Shutdown();
   g_common_snapshot_store.Clear();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_controller.Update();
  }

//+------------------------------------------------------------------+
//| Passive trade-transaction observer for Common Exit lifecycle     |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   g_execution_engine.ObserveTradeTransaction(transaction);
  }

//+------------------------------------------------------------------+
//| Strategy Tester validation summary                              |
//+------------------------------------------------------------------+
double OnTester(void)
  {
   return(FenxReportBacktestValidation(InpExecutionSymbol,
                                       InpExecutionMagicNumber));
  }
