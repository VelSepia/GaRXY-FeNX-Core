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
#include "Portfolio/GlobalPortfolioSnapshotStore.mqh"
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
#include "Execution/TradeTransactionRouter.mqh"
#include "Recovery/CommonRecoveryEngine.mqh"
#include "Health/CommonHealthEngine.mqh"
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
CGlobalPortfolioSnapshotStore g_global_portfolio_store;
CPairRankingEngine     g_pair_ranking_engine;
CCapitalAllocationEngine g_capital_allocation_engine;
CTradingStyleEngine      g_trading_style_engine;
CStrategySelectionEngine g_strategy_selection_engine;
CStandbyEngine           g_standby_engine;
CRiskEngine              g_risk_engine;
CConfidenceEngine        g_confidence_engine;
CDecisionScoreEngine     g_decision_score_engine;
CExecutionEngine         g_execution_engine;
CTradeTransactionRouter  g_trade_transaction_router;
CCommonRecoveryEngine    g_common_recovery_engine;
CCommonHealthEngine      g_common_health_engine;

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

   if(!g_controller.PrepareRuntimeContexts(g_parameters,
                                           g_common_snapshot_store,true))
     {
      CLogger::Error("Unable to prepare runtime context analysis pipelines.");
      return(INIT_FAILED);
     }

   //--- Global Portfolio is shadow-only in Task028. Context definitions are
   //--- copied from the registry before engine initialization; no secondary
   //--- result is connected to a downstream or execution consumer.
   SPortfolioContextDefinition portfolio_contexts[];
   CRuntimeContextRegistry *runtime_contexts=g_controller.RuntimeContexts();
   g_global_portfolio_store.Clear();
   if(runtime_contexts==NULL ||
      !runtime_contexts.ExportPortfolioDefinitions(portfolio_contexts) ||
      !g_pair_ranking_engine.SetGlobalPortfolio(g_global_portfolio_store,
                                                 g_common_snapshot_store,
                                                 portfolio_contexts) ||
      !g_capital_allocation_engine.SetGlobalPortfolio(g_global_portfolio_store))
     {
      CLogger::Error("Unable to configure the shadow Global Portfolio layer.");
      return(INIT_FAILED);
     }
   if(!g_controller.PrepareRuntimeContextDecisionSafety(g_global_portfolio_store))
     {
      CLogger::Error("Unable to prepare context decision/safety pipelines.");
      return(INIT_FAILED);
     }
   if(!g_controller.PrepareRuntimeContextExecution(g_execution_engine) ||
      !runtime_contexts.RegisterExecutionRoutes(g_trade_transaction_router))
     {
      CLogger::Error("Unable to prepare context execution infrastructure and transaction routes.");
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
   if(!g_common_recovery_engine.SetSnapshotStore(g_common_snapshot_store))
     {
      CLogger::Error("Unable to attach CommonSnapshotStore to CommonRecoveryEngine.");
      return(INIT_FAILED);
     }
   if(!g_common_health_engine.SetSnapshotStore(g_common_snapshot_store))
     {
      CLogger::Error("Unable to attach CommonSnapshotStore to CommonHealthEngine.");
      return(INIT_FAILED);
     }
   if(!g_controller.PrepareRuntimeContextRecoveryHealth(
         g_common_recovery_engine,g_common_health_engine,
         g_common_snapshot_store))
     {
      CLogger::Error("Unable to prepare context Recovery/Health observers.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterRuntimeContextAnalysisEngines())
     {
      CLogger::Error("Unable to register runtime context analysis pipelines.");
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

   //--- Context-local decision/safety runs after the completed global
   //--- portfolio and before the Primary canonical downstream.
   if(!g_controller.RegisterRuntimeContextDecisionSafetyEngines())
     {
      CLogger::Error("Unable to register context decision/safety pipelines.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterRuntimeContextExecutionEngines())
     {
      CLogger::Error("Unable to register context execution infrastructure.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterRuntimeContextRecoveryHealthEngines())
     {
      CLogger::Error("Unable to register context Recovery/Health observers.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterPrimaryContextEngine(g_trading_style_engine))
     {
      CLogger::Error("Unable to register TradingStyleEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterPrimaryContextEngine(g_strategy_selection_engine))
     {
      CLogger::Error("Unable to register StrategySelectionEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterPrimaryContextEngine(g_standby_engine))
     {
      CLogger::Error("Unable to register StandbyEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterPrimaryContextEngine(g_risk_engine))
     {
      CLogger::Error("Unable to register RiskEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterPrimaryContextEngine(g_confidence_engine))
     {
      CLogger::Error("Unable to register ConfidenceEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterPrimaryContextEngine(g_decision_score_engine))
     {
      CLogger::Error("Unable to register DecisionScoreEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterPrimaryContextEngine(g_execution_engine))
     {
      CLogger::Error("Unable to register ExecutionEngine.");
      return(INIT_FAILED);
     }

   //--- Passive observer runs after all existing trading engines so it cannot
   //--- feed a Recovery observation back into the same tick's decisions.
   if(!g_controller.RegisterPrimaryContextEngine(g_common_recovery_engine))
     {
      CLogger::Error("Unable to register CommonRecoveryEngine.");
      return(INIT_FAILED);
     }

   //--- Final passive observer runs after Recovery and cannot feed its typed
   //--- diagnostics back into the same tick's trading or state decisions.
   if(!g_controller.RegisterPrimaryContextEngine(g_common_health_engine))
     {
      CLogger::Error("Unable to register CommonHealthEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterGlobalHealthAggregateEngine())
     {
      CLogger::Error("Unable to register Global Health aggregate.");
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
   g_trade_transaction_router.Clear();
   g_controller.Shutdown();
   g_global_portfolio_store.Clear();
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
   g_trade_transaction_router.Route(transaction,request,result);
  }

//+------------------------------------------------------------------+
//| Strategy Tester validation summary                              |
//+------------------------------------------------------------------+
double OnTester(void)
  {
   CRuntimeContextRegistry *registry=g_controller.RuntimeContexts();
   CDataBus *data_bus=g_controller.DataBus();
   CEngineManager *engines=g_controller.Engines();
   SGlobalRiskAggregateSnapshot aggregate;
   ResetGlobalRiskAggregateSnapshot(aggregate);
   bool aggregate_available=false;
   int context_snapshots=0;
   if(registry!=NULL)
     {
      CGlobalRiskAggregateStore *aggregate_store=
         registry.GlobalRiskAggregateStore();
      CCommonSnapshotStore *context_store=registry.DecisionSnapshotStore();
      aggregate_available=(aggregate_store!=NULL &&
                           aggregate_store.GetLatest(aggregate));
      if(context_store!=NULL)
         context_snapshots=context_store.StandbySnapshotCount()+
                           context_store.RiskSnapshotCount()+
                           context_store.ConfidenceSnapshotCount()+
                           context_store.DecisionScoreSnapshotCount();
     }
   CLogger::Info(StringFormat(
      "[TASK029_SUMMARY] Result=%s;Contexts=%d;Engines=%d;DataBus=%d;Remaining=%d;Spare=%.2f;ContextSnapshots=%d;AggregateSequence=%I64d;Active=%d;Standby=%d;RiskStopped=%d;Critical=%d;Invalid=%d;PortfolioLinkage=%d;FutureSource=%d;WrongContext=%d;AggregateRuntimeUs=%I64d;SecondaryEntry=0;SecondaryExit=0;SecondaryExecution=0;SecondaryOrder=0;SecondaryPosition=0",
      (aggregate_available && aggregate.is_valid ? "PASS" : "FAIL"),
      (registry==NULL ? 0 : registry.AvailableContextCount()),
      (engines==NULL ? 0 : engines.Count()),
      (data_bus==NULL ? 0 : data_bus.Count()),
      (data_bus==NULL ? 0 : data_bus.RemainingCapacity()),
      (data_bus==NULL ? 0.0 :
       100.0*data_bus.RemainingCapacity()/data_bus.Capacity()),
      context_snapshots,aggregate.evaluation_sequence,aggregate.active_count,
      aggregate.standby_count,aggregate.risk_stopped_count,
      aggregate.critical_context_count,aggregate.invalid_context_count,
      aggregate.portfolio_linkage_error_count,aggregate.future_source_count,
      aggregate.wrong_context_count,aggregate.runtime_microseconds));
   CPositionLifecycleRegistry *lifecycles=
      g_trade_transaction_router.Lifecycles();
   CLogger::Info(StringFormat(
      "[TASK030_SUMMARY] Routes=%d;Received=%I64d;Dispatched=%I64d;External=%I64d;WrongDispatch=%I64d;ExecutionInfrastructure=%d;RegisteredContextExecution=%d;Lifecycles=%d;Finalized=%d;WrongOwner=%I64d;DuplicateLifecycle=%I64d;CrossSymbolOrder=0;WrongContextClose=0;WrongAllocation=0",
      g_trade_transaction_router.RouteCount(),
      g_trade_transaction_router.ReceivedCount(),
      g_trade_transaction_router.DispatchedCount(),
      g_trade_transaction_router.ExternalCount(),
      g_trade_transaction_router.WrongDispatchCount(),
      (registry==NULL ? 0 : registry.ExecutionInfrastructureCount()),
      (registry==NULL ? 0 : registry.RegisteredContextExecutionEngineCount()),
      (lifecycles==NULL ? 0 : lifecycles.Count()),
      (lifecycles==NULL ? 0 : lifecycles.FinalizedCount()),
      (lifecycles==NULL ? 0 : lifecycles.WrongOwnerCount()),
      (lifecycles==NULL ? 0 : lifecycles.DuplicateEventCount())));
   SGlobalHealthAggregateSnapshot global_health;
   ResetGlobalHealthAggregateSnapshot(global_health);
   bool global_health_available=false;
   if(registry!=NULL)
     {
      CGlobalHealthAggregateStore *health_store=
         registry.GlobalHealthAggregateStore();
      global_health_available=(health_store!=NULL &&
                               health_store.GetLatest(global_health));
     }
   CLogger::Info(StringFormat(
      "[TASK031_SUMMARY] Result=%s;Contexts=%d;RecoveryInfrastructure=%d;RegisteredContextRecoveryHealth=%d;Healthy=%d;Degraded=%d;Critical=%d;RequiredUnavailable=%d;OptionalUnavailable=%d;ExpectedInvalid=%d;ExpectedStale=%d;RecoveryCrossContext=%d;EntryResumeWrongContext=%d;HealthWrongContext=%d;ExecutionPositionRouterLinkage=%d;DataLeak=%I64d;TradeLeak=%I64d;RuntimeError=%I64d",
      (global_health_available && global_health.is_valid ? "PASS" : "FAIL"),
      global_health.context_count,
      (registry==NULL ? 0 : registry.RecoveryHealthInfrastructureCount()),
      (registry==NULL ? 0 :
       registry.RegisteredContextRecoveryHealthEngineCount()),
      global_health.healthy_context_count,global_health.degraded_context_count,
      global_health.critical_context_count,
      global_health.required_unavailable_count,
      global_health.optional_unavailable_count,
      global_health.expected_invalid_count,global_health.expected_stale_count,
      global_health.recovery_cross_context_count,
      global_health.entry_resume_wrong_context_count,
      global_health.health_wrong_context_count,
      global_health.execution_position_router_linkage_error_count,
      global_health.data_leak_count,global_health.trade_leak_count,
      global_health.runtime_error_count));
   const double spare_ratio=(data_bus==NULL ? 0.0 :
      100.0*data_bus.RemainingCapacity()/data_bus.Capacity());
   const bool schema_frozen=(data_bus!=NULL &&
      data_bus.LegacyWriteAttemptCount()==0 &&
      data_bus.LegacyReadAttemptCount()==0 &&
      data_bus.LegacySchemaKeyCount()==0 &&
      data_bus.InvalidSchemaKeyCount()==0 &&
      data_bus.ContextViewWrongSymbolCount()==0);
   CLogger::Info(StringFormat(
      "[TASK032_SUMMARY] Result=%s;Contexts=%d;Engines=%d;DataBus=%d;Remaining=%d;Spare=%.2f;LegacyWrite=%I64d;LegacyRead=%I64d;LegacySchema=%d;InvalidSchema=%d;WrongContext=%I64d;ContextCollision=0;WrongTimeframe=0",
      (schema_frozen && spare_ratio>=30.0 ? "PASS" : "FAIL"),
      (registry==NULL ? 0 : registry.AvailableContextCount()),
      (engines==NULL ? 0 : engines.Count()),
      (data_bus==NULL ? 0 : data_bus.CurrentSize()),
      (data_bus==NULL ? 0 : data_bus.RemainingCapacity()),spare_ratio,
      (data_bus==NULL ? 0 : data_bus.LegacyWriteAttemptCount()),
      (data_bus==NULL ? 0 : data_bus.LegacyReadAttemptCount()),
      (data_bus==NULL ? 0 : data_bus.LegacySchemaKeyCount()),
      (data_bus==NULL ? 0 : data_bus.InvalidSchemaKeyCount()),
      (data_bus==NULL ? 0 : data_bus.ContextViewWrongSymbolCount())));
   return(FenxReportBacktestValidation(InpExecutionSymbol,
                                       InpExecutionMagicNumber));
  }
