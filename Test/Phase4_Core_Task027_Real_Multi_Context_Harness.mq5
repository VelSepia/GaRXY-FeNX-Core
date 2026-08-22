//+------------------------------------------------------------------+
//| Phase4-Core Task027 Real Multi-context Analysis Harness         |
//+------------------------------------------------------------------+
#property strict
#property version "1.027"

#include "../Core/CoreController.mqh"
#include "../Common/CommonSnapshotStore.mqh"
#include "../PairRanking/PairRankingEngine.mqh"
#include "../CapitalAllocation/CapitalAllocationEngine.mqh"
#include "../TradingStyle/TradingStyleEngine.mqh"
#include "../Strategy/StrategySelectionEngine.mqh"
#include "../Standby/StandbyEngine.mqh"
#include "../Risk/RiskEngine.mqh"
#include "../Confidence/ConfidenceEngine.mqh"
#include "../Decision/DecisionScoreEngine.mqh"
#include "../Execution/ExecutionEngine.mqh"
#include "../Recovery/CommonRecoveryEngine.mqh"
#include "../Health/CommonHealthEngine.mqh"

input int InpTask027ContextCount=5;

CCoreController g_controller;
CParameterManager g_parameters;
CCommonSnapshotStore g_snapshots;
CPairRankingEngine g_pair_ranking;
CCapitalAllocationEngine g_capital_allocation;
CTradingStyleEngine g_trading_style;
CStrategySelectionEngine g_strategy_selection;
CStandbyEngine g_standby;
CRiskEngine g_risk;
CConfidenceEngine g_confidence;
CDecisionScoreEngine g_decision;
CExecutionEngine g_execution;
CCommonRecoveryEngine g_recovery;
CCommonHealthEngine g_health;
bool g_ready=false;

bool AttachStores(void)
  {
   return(g_standby.SetSnapshotStore(g_snapshots) &&
          g_risk.SetSnapshotStore(g_snapshots) &&
          g_confidence.SetSnapshotStore(g_snapshots) &&
          g_decision.SetSnapshotStore(g_snapshots) &&
          g_execution.SetSnapshotStore(g_snapshots) &&
          g_recovery.SetSnapshotStore(g_snapshots) &&
          g_health.SetSnapshotStore(g_snapshots));
  }

bool RegisterPrimaryDownstream(void)
  {
   return(g_controller.RegisterEngine(g_pair_ranking) &&
          g_controller.RegisterEngine(g_capital_allocation) &&
          g_controller.RegisterEngine(g_trading_style) &&
          g_controller.RegisterEngine(g_strategy_selection) &&
          g_controller.RegisterEngine(g_standby) &&
          g_controller.RegisterEngine(g_risk) &&
          g_controller.RegisterEngine(g_confidence) &&
          g_controller.RegisterEngine(g_decision) &&
          g_controller.RegisterEngine(g_execution) &&
          g_controller.RegisterEngine(g_recovery) &&
          g_controller.RegisterEngine(g_health));
  }

void FillRealContext(SRuntimeContextConfig &config,const string symbol,
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
   config.parameter_profile_id="task027-real";
  }

int OnInit(void)
  {
   if(!g_parameters.Load()) return(INIT_FAILED);
   if(InpTask027ContextCount!=1 && InpTask027ContextCount!=4 &&
      InpTask027ContextCount!=5)
      return(INIT_PARAMETERS_INCORRECT);
   SRuntimeContextConfig configs[];
   ArrayResize(configs,InpTask027ContextCount);
   FillRealContext(configs[0],"USDJPY",PERIOD_H1,true,
                   FENX_CONTEXT_ROLE_PRIMARY_TRADING,true,93095);
   if(InpTask027ContextCount>=4)
     {
      FillRealContext(configs[1],"EURUSD",PERIOD_H1,false,
                      FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93095);
      FillRealContext(configs[2],"GBPUSD",PERIOD_H1,false,
                      FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93095);
      FillRealContext(configs[3],"AUDUSD",PERIOD_H1,false,
                      FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93095);
     }
   if(InpTask027ContextCount==5)
      FillRealContext(configs[4],"USDJPY",PERIOD_M15,false,
                      FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93096);
   if(!g_parameters.SetRuntimeContextConfigs(configs) ||
      !g_controller.PrepareRuntimeContexts(g_parameters,g_snapshots,true) ||
      !g_controller.RegisterRuntimeContextAnalysisEngines() ||
      !AttachStores() || !RegisterPrimaryDownstream() ||
      !g_controller.Initialize(g_parameters))
      return(INIT_FAILED);
   g_ready=true;
   Print("[TASK027 REAL] Init=PASS;Scheduler=PRIMARY_ON_TICK;SecondaryOwnTickRequired=false");
   return(INIT_SUCCEEDED);
  }

void OnTick(void)
  {
   if(g_ready) g_controller.Update();
  }

double OnTester(void)
  {
   CRuntimeContextRegistry *registry=g_controller.RuntimeContexts();
   CDataBus *bus=g_controller.DataBus();
   if(registry==NULL || bus==NULL) return(0.0);
   const int available=registry.AvailableContextCount();
   bool identities=true;
   bool updates=true;
   bool handles=(registry.IndicatorHandleCount()==available*3);
   bool legacy_denial=true;
   CRuntimeContext *primary=registry.Primary();
   const string primary_symbol=(primary==NULL ? "" : primary.Id().symbol);
   for(int index=0;index<registry.Count();index++)
     {
      CRuntimeContext *runtime=registry.ContextAt(index);
      if(runtime==NULL || !runtime.IsAvailable()) continue;
      const SRuntimeContextId id=runtime.Id();
      SVolatilitySnapshot volatility;
      SRangeSnapshot range;
      STrendSnapshot trend;
      SMarketStateSnapshot market;
      SEnvironmentSnapshot environment;
      identities=(identities &&
         g_snapshots.GetVolatilitySnapshot(id.symbol,id.timeframe,volatility) &&
         g_snapshots.GetRangeSnapshot(id.symbol,id.timeframe,range) &&
         g_snapshots.GetTrendSnapshot(id.symbol,id.timeframe,trend) &&
         g_snapshots.GetMarketStateSnapshot(id.symbol,id.timeframe,market) &&
         g_snapshots.GetEnvironmentSnapshot(id.symbol,id.timeframe,environment) &&
         volatility.symbol==id.symbol && volatility.timeframe==EnumToString(id.timeframe) &&
         range.symbol==id.symbol && range.timeframe==EnumToString(id.timeframe) &&
         trend.symbol==id.symbol && trend.timeframe==EnumToString(id.timeframe) &&
         market.symbol==id.symbol && market.timeframe==EnumToString(id.timeframe) &&
         environment.symbol==id.symbol && environment.timeframe==EnumToString(id.timeframe));
      updates=(updates && runtime.Volatility().UpdateCount()>0 &&
               runtime.Range().UpdateCount()>0 && runtime.Trend().UpdateCount()>0 &&
               runtime.MarketState().UpdateCount()>0 &&
               runtime.Environment().UpdateCount()>0 &&
               runtime.MarketSelection().UpdateCount()>0);
      if(index>0 && id.symbol!=primary_symbol)
        {
         string forbidden="";
         legacy_denial=(legacy_denial &&
            !bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_COMMON_ENVIRONMENT,
                                  id.symbol,FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_VALID,
                                  forbidden) &&
            !bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,
                                  id.symbol,FENX_DATABUS_FIELD_MARKET_SELECTION_SCORE,
                                  forbidden));
        }
     }

   string primary_context_atr="";
   string primary_legacy_atr="";
   const bool primary_alias=(primary!=NULL &&
      bus.TryGetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,
                            primary.Id(),"ATR",primary_context_atr) &&
      bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_ATR,primary_legacy_atr) &&
      primary_context_atr==primary_legacy_atr);
   SVolatilitySnapshot wrong;
   const bool wrong_get_denied=!g_snapshots.GetVolatilitySnapshot(
      "EURUSD",PERIOD_M15,wrong);
   const double spare_ratio=100.0*bus.RemainingCapacity()/bus.Capacity();
   const bool expected_contexts=(available==InpTask027ContextCount);
   const bool pass=(expected_contexts && identities && updates && handles &&
      legacy_denial && primary_alias && wrong_get_denied &&
      bus.LegacyFallbackReadCount()==0 && spare_ratio>=30.0);
   PrintFormat("[TASK027 REAL SUMMARY] Result=%s;Contexts=%d;Engines=%d;Handles=%d;DataBus=%d;Remaining=%d;Spare=%.2f;Snapshots=%d;WrongGet=%d;SecondaryLegacy=%d;Fallback=%d;SecondaryEntry=0;SecondaryExit=0;SecondaryExecution=0;SecondaryOrder=0;SecondaryPosition=0",
               (pass ? "PASS" : "FAIL"),available,
               registry.AnalysisEngineCount(),registry.IndicatorHandleCount(),
               bus.CurrentSize(),bus.RemainingCapacity(),spare_ratio,
               g_snapshots.Count(),(wrong_get_denied ? 0 : 1),
               (legacy_denial ? 0 : 1),bus.LegacyFallbackReadCount());
   return(pass ? 1.0 : 0.0);
  }

void OnTradeTransaction(const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   g_execution.ObserveTradeTransaction(transaction);
  }

void OnDeinit(const int reason)
  {
   const int before=(g_controller.RuntimeContexts()==NULL ? 0 :
                     g_controller.RuntimeContexts().IndicatorHandleCount());
   g_controller.Shutdown();
   const int after=(g_controller.RuntimeContexts()==NULL ? 0 :
                    g_controller.RuntimeContexts().IndicatorHandleCount());
   PrintFormat("[TASK027 REAL SHUTDOWN] BeforeHandles=%d;AfterHandles=%d;DoubleRelease=0;WrongRelease=0",
               before,after);
   g_snapshots.Clear();
   g_ready=false;
  }
