//+------------------------------------------------------------------+
//| Phase4-Core Task029 Real Decision/Safety Harness                |
//+------------------------------------------------------------------+
#property strict
#property version "1.029"

#include "../Core/CoreController.mqh"
#include "../Common/CommonSnapshotStore.mqh"
#include "../Portfolio/GlobalPortfolioSnapshotStore.mqh"
#include "../PairRanking/PairRankingEngine.mqh"
#include "../CapitalAllocation/CapitalAllocationEngine.mqh"
#include "../TradingStyle/TradingStyleEngine.mqh"
#include "../Strategy/StrategySelectionEngine.mqh"
#include "../Standby/StandbyEngine.mqh"
#include "../Risk/RiskEngine.mqh"
#include "../Confidence/ConfidenceEngine.mqh"
#include "../Decision/DecisionScoreEngine.mqh"
#include "../Execution/ExecutionEngine.mqh"
#include "../Execution/TradeTransactionRouter.mqh"
#include "../Recovery/CommonRecoveryEngine.mqh"
#include "../Health/CommonHealthEngine.mqh"

input int InpTask029ContextCount=5;

CCoreController g_controller;
CParameterManager g_parameters;
CCommonSnapshotStore g_analysis_snapshots;
CGlobalPortfolioSnapshotStore g_portfolio;
CPairRankingEngine g_pair_ranking;
CCapitalAllocationEngine g_capital_allocation;
CTradingStyleEngine g_primary_trading_style;
CStrategySelectionEngine g_primary_strategy_selection;
CStandbyEngine g_primary_standby;
CRiskEngine g_primary_risk;
CConfidenceEngine g_primary_confidence;
CDecisionScoreEngine g_primary_decision;
CExecutionEngine g_primary_execution;
CTradeTransactionRouter g_transaction_router;
CCommonRecoveryEngine g_primary_recovery;
CCommonHealthEngine g_primary_health;
bool g_ready=false;

bool AttachPrimaryStores(void)
  {
   return(g_primary_standby.SetSnapshotStore(g_analysis_snapshots) &&
          g_primary_risk.SetSnapshotStore(g_analysis_snapshots) &&
          g_primary_confidence.SetSnapshotStore(g_analysis_snapshots) &&
          g_primary_decision.SetSnapshotStore(g_analysis_snapshots) &&
          g_primary_execution.SetSnapshotStore(g_analysis_snapshots) &&
          g_primary_recovery.SetSnapshotStore(g_analysis_snapshots) &&
          g_primary_health.SetSnapshotStore(g_analysis_snapshots));
  }

bool RegisterPrimaryPipeline(void)
  {
   return(g_controller.RegisterEngine(g_primary_trading_style) &&
          g_controller.RegisterEngine(g_primary_strategy_selection) &&
          g_controller.RegisterEngine(g_primary_standby) &&
          g_controller.RegisterEngine(g_primary_risk) &&
          g_controller.RegisterEngine(g_primary_confidence) &&
          g_controller.RegisterEngine(g_primary_decision) &&
          g_controller.RegisterEngine(g_primary_execution) &&
          g_controller.RegisterEngine(g_primary_recovery) &&
          g_controller.RegisterEngine(g_primary_health));
  }

void FillContext(SRuntimeContextConfig &config,const string symbol,
                 const ENUM_TIMEFRAMES timeframe,const bool required,
                 const ENUM_FENX_CONTEXT_ROLE role,const bool trade_enabled,
                 const long magic)
  {
   ResetRuntimeContextConfig(config);
   config.id.symbol=symbol;
   config.id.timeframe=timeframe;
   config.enabled=true;
   config.required=required;
   config.role=role;
   config.trade_enabled=trade_enabled;
   config.magic=magic;
   config.parameter_profile_id="task029-real";
  }

int OnInit(void)
  {
   if(!g_parameters.Load() ||
      (InpTask029ContextCount!=1 && InpTask029ContextCount!=4 &&
       InpTask029ContextCount!=5))
      return(INIT_PARAMETERS_INCORRECT);

   SRuntimeContextConfig configs[];
   if(ArrayResize(configs,InpTask029ContextCount)!=InpTask029ContextCount)
      return(INIT_FAILED);
   FillContext(configs[0],"USDJPY",PERIOD_H1,true,
               FENX_CONTEXT_ROLE_PRIMARY_TRADING,true,93095);
   if(InpTask029ContextCount>=4)
     {
      FillContext(configs[1],"EURUSD",PERIOD_H1,false,
                  FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93095);
      FillContext(configs[2],"GBPUSD",PERIOD_H1,false,
                  FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93095);
      FillContext(configs[3],"AUDUSD",PERIOD_H1,false,
                  FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93095);
     }
   if(InpTask029ContextCount==5)
      FillContext(configs[4],"USDJPY",PERIOD_M15,false,
                  FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93096);

   if(!g_parameters.SetRuntimeContextConfigs(configs) ||
      !g_controller.PrepareRuntimeContexts(g_parameters,g_analysis_snapshots,true))
      return(INIT_FAILED);

   CRuntimeContextRegistry *registry=g_controller.RuntimeContexts();
   SPortfolioContextDefinition definitions[];
   if(registry==NULL || !registry.ExportPortfolioDefinitions(definitions) ||
      !g_pair_ranking.SetGlobalPortfolio(g_portfolio,g_analysis_snapshots,definitions) ||
      !g_capital_allocation.SetGlobalPortfolio(g_portfolio) ||
      !g_controller.PrepareRuntimeContextDecisionSafety(g_portfolio) ||
      !g_controller.PrepareRuntimeContextExecution(g_primary_execution) ||
      !registry.RegisterExecutionRoutes(g_transaction_router) ||
      !AttachPrimaryStores() ||
      !g_controller.PrepareRuntimeContextRecoveryHealth(
         g_primary_recovery,g_primary_health,g_analysis_snapshots) ||
      !g_controller.RegisterRuntimeContextAnalysisEngines() ||
      !g_controller.RegisterEngine(g_pair_ranking) ||
      !g_controller.RegisterEngine(g_capital_allocation) ||
      !g_controller.RegisterRuntimeContextDecisionSafetyEngines() ||
      !g_controller.RegisterRuntimeContextExecutionEngines() ||
      !g_controller.RegisterRuntimeContextRecoveryHealthEngines() ||
      !RegisterPrimaryPipeline() ||
      !g_controller.RegisterGlobalHealthAggregateEngine() ||
      !g_controller.Initialize(g_parameters))
      return(INIT_FAILED);

   g_ready=true;
   Print("[TASK031 REAL] Init=PASS;SecondaryTrading=false;HealthAuthority=false");
   return(INIT_SUCCEEDED);
  }

void OnTick(void)
  {
   if(g_ready)
      g_controller.Update();
  }

bool ContextField(CDataBus *bus,const string name_space,
                  const SRuntimeContextId &id,const string field)
  {
   string value="";
   return(bus!=NULL && bus.TryGetContextText(name_space,id,field,value));
  }

double OnTester(void)
  {
   CRuntimeContextRegistry *registry=g_controller.RuntimeContexts();
   CDataBus *bus=g_controller.DataBus();
   CEngineManager *manager=g_controller.Engines();
   if(registry==NULL || bus==NULL || manager==NULL)
      return(0.0);

   CCommonSnapshotStore *store=registry.DecisionSnapshotStore();
   CGlobalRiskAggregateStore *aggregate_store=registry.GlobalRiskAggregateStore();
   CCommonSnapshotStore *recovery_health_store=
      registry.RecoveryHealthSnapshotStore();
   CGlobalHealthAggregateStore *global_health_store=
      registry.GlobalHealthAggregateStore();
   bool contexts_complete=(store!=NULL);
   bool state_isolated=true;
   bool source_time_safe=true;
   bool secondary_non_trading=true;
   bool execution_initialized=true;
   bool strategy_capability=true;
   long secondary_orders=0;
   long secondary_positions=0;
   int checked=0;
   bool recovery_isolated=true;
   bool entry_resume_isolated=true;
   bool health_isolated=true;
   for(int index=0;index<registry.Count();index++)
     {
      CRuntimeContext *runtime=registry.ContextAt(index);
      if(runtime==NULL || !runtime.IsAvailable())
         continue;
      checked++;
      const SRuntimeContextConfig config=runtime.Config();
      const SRuntimeContextId id=config.id;
      SStandbySnapshot standby;
      SRiskSnapshot risk;
      SConfidenceSnapshot confidence;
      SDecisionScoreSnapshot decision;
      contexts_complete=(contexts_complete &&
         ContextField(bus,FENX_DATABUS_NAMESPACE_TRADING_STYLE,id,
                      FENX_DATABUS_FIELD_TRADING_STYLE_UPDATED_AT) &&
         ContextField(bus,FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,id,
                      FENX_DATABUS_FIELD_STRATEGY_SELECTION_UPDATED_AT) &&
         store.GetStandbySnapshot(id.symbol,id.timeframe,standby) &&
         store.GetRiskSnapshot(id.symbol,id.timeframe,risk) &&
         store.GetConfidenceSnapshot(id.symbol,id.timeframe,confidence) &&
         store.GetDecisionScoreSnapshot(id.symbol,id.timeframe,decision) &&
         standby.symbol==id.symbol && standby.timeframe==EnumToString(id.timeframe) &&
         risk.symbol==id.symbol && risk.timeframe==EnumToString(id.timeframe) &&
         confidence.symbol==id.symbol && confidence.timeframe==EnumToString(id.timeframe) &&
         decision.symbol==id.symbol && decision.timeframe==EnumToString(id.timeframe));
      const datetime now=TimeCurrent();
      source_time_safe=(source_time_safe && standby.updated_at<=now &&
         risk.updated_at<=now && confidence.updated_at<=now && decision.updated_at<=now);
      CStateManager *local_state=runtime.StateManager();
      state_isolated=(state_isolated && local_state!=NULL &&
                      local_state.IsContextLocal());
      CCommonSnapshotStore *observer_store=(index==registry.PrimaryIndex() ?
         GetPointer(g_analysis_snapshots) : recovery_health_store);
      SCommonRecoverySnapshot recovery;
      SCommonHealthSnapshot health;
      const bool recovery_available=(observer_store!=NULL &&
         observer_store.GetRecoverySnapshot(id.symbol,id.timeframe,recovery));
      const bool health_available=(observer_store!=NULL &&
         observer_store.GetHealthSnapshot(id.symbol,id.timeframe,health));
      recovery_isolated=(recovery_isolated && recovery_available &&
         RuntimeContextEquals(recovery.runtime_context_id,id));
      health_isolated=(health_isolated && health_available &&
         RuntimeContextEquals(health.runtime_context_id,id));
      entry_resume_isolated=(entry_resume_isolated && recovery_available &&
         (!recovery.entry_resume_allowed ||
          (recovery.entry_snapshot_available &&
           RuntimeContextEquals(recovery.entry_context_id,id))));
      if(index>0)
        {
         secondary_non_trading=(secondary_non_trading && !config.trade_enabled);
         CExecutionEngine *execution=runtime.Execution();
         execution_initialized=(execution_initialized && execution!=NULL);
         if(execution!=NULL)
           {
            strategy_capability=(strategy_capability &&
                                 !execution.StrategySupportsContext() &&
                                 !execution.ContextExecutionPermitted());
            secondary_orders+=execution.SuccessfulOrderCount();
            secondary_positions+=execution.ManagedPositionCount();
           }
         execution_initialized=(execution_initialized &&
            ContextField(bus,FENX_DATABUS_NAMESPACE_EXECUTION,id,
                         FENX_DATABUS_FIELD_EXECUTION_UPDATED_AT) &&
            ContextField(bus,FENX_DATABUS_NAMESPACE_CONTEXT_EXECUTION_GLOBAL,id,
                         "SystemReady"));
        }
      else
        {
         CExecutionEngine *execution=runtime.Execution();
         execution_initialized=(execution_initialized && execution!=NULL);
         strategy_capability=(strategy_capability && execution!=NULL &&
                              execution.StrategySupportsContext() &&
                              execution.ContextExecutionPermitted());
        }
     }

   string forbidden="";
   // The unchanged Primary compatibility pipeline intentionally owns these
   // aliases. Context view writes are proved absent by the isolation harness,
   // zero fallback reads, and zero wrong-context accesses below.
   const bool primary_legacy_available=
      bus.TryGetText(FENX_DATABUS_KEY_TRADING_STYLE_UPDATED_AT,forbidden) &&
      bus.TryGetText(FENX_DATABUS_KEY_STRATEGY_SELECTION_UPDATED_AT,forbidden) &&
      bus.TryGetText(FENX_DATABUS_KEY_STANDBY_SYSTEM_UPDATED_AT,forbidden) &&
      bus.TryGetText(FENX_DATABUS_KEY_RISK_SYSTEM_UPDATED_AT,forbidden);
   SGlobalRiskAggregateSnapshot aggregate;
   ResetGlobalRiskAggregateSnapshot(aggregate);
   const bool aggregate_ok=(aggregate_store!=NULL &&
      aggregate_store.GetLatest(aggregate) && aggregate.is_valid &&
      aggregate.context_count==InpTask029ContextCount &&
      aggregate.active_count==InpTask029ContextCount &&
      aggregate.portfolio_linkage_error_count==0 &&
      aggregate.future_source_count==0 && aggregate.wrong_context_count==0 &&
      aggregate_store.SequenceGapCount()==0 &&
      aggregate_store.SequenceDuplicateCount()==0);
   SGlobalHealthAggregateSnapshot global_health;
   ResetGlobalHealthAggregateSnapshot(global_health);
   const bool global_health_ok=(global_health_store!=NULL &&
      global_health_store.GetLatest(global_health) && global_health.is_valid &&
      global_health.context_count==InpTask029ContextCount &&
      global_health.available_context_count==InpTask029ContextCount &&
      global_health.required_unavailable_count==0 &&
      global_health.optional_unavailable_count==0 &&
      global_health.recovery_cross_context_count==0 &&
      global_health.entry_resume_wrong_context_count==0 &&
      global_health.health_wrong_context_count==0 &&
      global_health.execution_position_router_linkage_error_count==0 &&
      global_health.data_leak_count==0 && global_health.trade_leak_count==0 &&
      global_health.runtime_error_count==0 &&
      global_health_store.SequenceGapCount()==0 &&
      global_health_store.SequenceDuplicateCount()==0);
   const int expected_engines=15*InpTask029ContextCount+10;
   const double spare=100.0*bus.RemainingCapacity()/bus.Capacity();
   const bool counts=(checked==InpTask029ContextCount &&
      registry.AnalysisEngineCount()==6*InpTask029ContextCount &&
      registry.DecisionSafetyEngineCount()==6*InpTask029ContextCount &&
      registry.ExecutionInfrastructureCount()==InpTask029ContextCount &&
      registry.RegisteredContextExecutionEngineCount()==
         (InpTask029ContextCount>1 ? InpTask029ContextCount-1 : 0) &&
      registry.RecoveryHealthInfrastructureCount()==InpTask029ContextCount &&
      registry.RegisteredContextRecoveryHealthEngineCount()==
         (InpTask029ContextCount>1 ? 2*(InpTask029ContextCount-1) : 0) &&
      manager.Count()==expected_engines && store!=NULL &&
      store.StandbySnapshotCount()==InpTask029ContextCount &&
      store.RiskSnapshotCount()==InpTask029ContextCount &&
      store.ConfidenceSnapshotCount()==InpTask029ContextCount &&
      store.DecisionScoreSnapshotCount()==InpTask029ContextCount);
   const bool pass=(contexts_complete && state_isolated && source_time_safe &&
      secondary_non_trading && execution_initialized && strategy_capability &&
      secondary_orders==0 && secondary_positions==0 &&
      primary_legacy_available && aggregate_ok && global_health_ok && counts &&
      recovery_isolated && entry_resume_isolated && health_isolated &&
      bus.LegacyFallbackReadCount()==0 && bus.ContextViewWrongSymbolCount()==0 &&
      spare>=30.0);
   PrintFormat("[TASK031 REAL SUMMARY] Result=%s;Contexts=%d;Engines=%d;DataBus=%d;Remaining=%d;Spare=%.2f;RecoveryInfrastructure=%d;RegisteredContextRecoveryHealth=%d;RecoveryCrossContext=%d;EntryResumeWrongContext=%d;HealthWrongContext=%d;ExecutionPositionRouterLinkage=%d;DataLeak=%I64d;TradeLeak=%I64d;RuntimeError=%I64d;RequiredUnavailable=%d;OptionalUnavailable=%d;ExpectedInvalid=%d;ExpectedStale=%d;SecondaryOrder=%I64d;SecondaryPosition=%I64d",
      (pass ? "PASS" : "FAIL"),checked,manager.Count(),bus.CurrentSize(),
      bus.RemainingCapacity(),spare,registry.RecoveryHealthInfrastructureCount(),
      registry.RegisteredContextRecoveryHealthEngineCount(),
      global_health.recovery_cross_context_count,
      global_health.entry_resume_wrong_context_count,
      global_health.health_wrong_context_count,
      global_health.execution_position_router_linkage_error_count,
      global_health.data_leak_count,global_health.trade_leak_count,
      global_health.runtime_error_count,
      global_health.required_unavailable_count,
      global_health.optional_unavailable_count,
      global_health.expected_invalid_count,global_health.expected_stale_count,
      secondary_orders,secondary_positions);
   return(pass ? 1.0 : 0.0);
  }

void OnDeinit(const int reason)
  {
   g_transaction_router.Clear();
   g_controller.Shutdown();
   g_portfolio.Clear();
   g_analysis_snapshots.Clear();
   g_ready=false;
  }

void OnTradeTransaction(const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   g_transaction_router.Route(transaction,request,result);
  }
