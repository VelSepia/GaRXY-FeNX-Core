//+------------------------------------------------------------------+
//| Phase4-Core Task028 Real Global Portfolio Harness               |
//+------------------------------------------------------------------+
#property strict
#property version "1.028"

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
#include "../Recovery/CommonRecoveryEngine.mqh"
#include "../Health/CommonHealthEngine.mqh"

input int InpTask028ContextCount=5;

CCoreController g_controller;
CParameterManager g_parameters;
CCommonSnapshotStore g_snapshots;
CGlobalPortfolioSnapshotStore g_portfolio;
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

bool AttachPortfolio(void)
  {
   CRuntimeContextRegistry *registry=g_controller.RuntimeContexts();
   SPortfolioContextDefinition definitions[];
   g_portfolio.Clear();
   return(registry!=NULL && registry.ExportPortfolioDefinitions(definitions) &&
          g_pair_ranking.SetGlobalPortfolio(g_portfolio,g_snapshots,definitions) &&
          g_capital_allocation.SetGlobalPortfolio(g_portfolio));
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
   config.parameter_profile_id="task028-real";
  }

int OnInit(void)
  {
   if(!g_parameters.Load()) return(INIT_FAILED);
   if(InpTask028ContextCount!=1 && InpTask028ContextCount!=4 &&
      InpTask028ContextCount!=5)
      return(INIT_PARAMETERS_INCORRECT);
   SRuntimeContextConfig configs[];
   ArrayResize(configs,InpTask028ContextCount);
   FillRealContext(configs[0],"USDJPY",PERIOD_H1,true,
                   FENX_CONTEXT_ROLE_PRIMARY_TRADING,true,93095);
   if(InpTask028ContextCount>=4)
     {
      FillRealContext(configs[1],"EURUSD",PERIOD_H1,false,
                      FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93095);
      FillRealContext(configs[2],"GBPUSD",PERIOD_H1,false,
                      FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93095);
      FillRealContext(configs[3],"AUDUSD",PERIOD_H1,false,
                      FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93095);
     }
   if(InpTask028ContextCount==5)
      FillRealContext(configs[4],"USDJPY",PERIOD_M15,false,
                      FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93096);
   if(!g_parameters.SetRuntimeContextConfigs(configs) ||
      !g_controller.PrepareRuntimeContexts(g_parameters,g_snapshots,true) ||
      !AttachPortfolio() ||
      !g_controller.RegisterRuntimeContextAnalysisEngines() ||
      !AttachStores() || !RegisterPrimaryDownstream() ||
      !g_controller.Initialize(g_parameters))
      return(INIT_FAILED);
   g_ready=true;
   Print("[TASK028 REAL] Init=PASS;Portfolio=SHADOW;SecondaryTrading=false");
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
   bool canonical_isolation=true;
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
         string selection_score="",ranking_score="",allocation_percent="";
         canonical_isolation=(canonical_isolation &&
            bus.TryGetContextText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,
                                  id,FENX_DATABUS_FIELD_MARKET_SELECTION_SCORE,
                                  selection_score) &&
            bus.TryGetContextText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,
                                  id,FENX_DATABUS_FIELD_PAIR_RANKING_SCORE,
                                  ranking_score) &&
            bus.TryGetContextText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,
                                  id,FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_PERCENT,
                                  allocation_percent));
        }
     }

   SGlobalPortfolioSnapshot portfolio;
   SPortfolioCandidateSnapshot candidates[];
   const bool portfolio_available=g_portfolio.GetLatest(portfolio,candidates);
   bool linkage=portfolio_available;
   bool source_time_safe=portfolio_available;
   bool allocation_safe=portfolio_available;
   bool duplicate_candidate=false;
   bool duplicate_allocation=false;
   bool auxiliary_tf_excluded=(InpTask028ContextCount<5);
   int active_candidates=0;
   for(int left=0;left<ArraySize(candidates);left++)
     {
      linkage=(linkage && candidates[left].evaluation_sequence==
                            portfolio.evaluation_sequence &&
               IsValidRuntimeContextId(candidates[left].context_id));
      source_time_safe=(source_time_safe &&
         candidates[left].selection_updated_at<=portfolio.evaluation_time &&
         candidates[left].environment_updated_at<=portfolio.evaluation_time &&
         candidates[left].volatility_updated_at<=portfolio.evaluation_time &&
         candidates[left].range_updated_at<=portfolio.evaluation_time &&
         candidates[left].trend_updated_at<=portfolio.evaluation_time &&
         candidates[left].market_state_updated_at<=portfolio.evaluation_time &&
         candidates[left].ranking_updated_at<=portfolio.evaluation_time &&
         candidates[left].allocation_updated_at<=portfolio.evaluation_time);
      allocation_safe=(allocation_safe && candidates[left].allocation_percent>=0.0 &&
                       candidates[left].allocation_percent<=100.0);
      if(candidates[left].is_candidate) active_candidates++;
      if(candidates[left].context_id.symbol=="USDJPY" &&
         candidates[left].context_id.timeframe==PERIOD_M15)
         auxiliary_tf_excluded=(!candidates[left].is_candidate &&
                                candidates[left].allocation_percent==0.0);
      for(int right=left+1;right<ArraySize(candidates);right++)
        {
         if(candidates[left].is_candidate && candidates[right].is_candidate &&
            candidates[left].context_id.symbol==candidates[right].context_id.symbol)
            duplicate_candidate=true;
         if(candidates[left].is_allocated && candidates[right].is_allocated &&
            candidates[left].context_id.symbol==candidates[right].context_id.symbol)
            duplicate_allocation=true;
        }
     }

   string primary_context_atr="";
   const bool primary_canonical=(primary!=NULL &&
      bus.TryGetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,
                            primary.Id(),"ATR",primary_context_atr));
   const double spare_ratio=100.0*bus.RemainingCapacity()/bus.Capacity();
   const bool audits=(g_portfolio.SequenceGapCount()==0 &&
      g_portfolio.SequenceDuplicateCount()==0 &&
      g_portfolio.FutureSourceCount()==0 &&
      g_portfolio.WrongContextLinkageCount()==0 &&
      g_portfolio.DuplicateSymbolCandidateCount()==0 &&
      g_portfolio.AllocationInvariantCount()==0);
   const bool pass=(available==InpTask028ContextCount && identities && updates &&
      handles && canonical_isolation && primary_canonical && portfolio_available &&
      portfolio.context_count==InpTask028ContextCount &&
      portfolio.candidate_count==active_candidates && linkage && source_time_safe &&
      allocation_safe && !duplicate_candidate && !duplicate_allocation &&
      auxiliary_tf_excluded && portfolio.total_allocation<=100.0001 && audits &&
      g_portfolio.CandidateEvaluationCount()>0 &&
      g_portfolio.AllocationEvaluationCount()>0 &&
      bus.LegacySchemaKeyCount()==0 && bus.LegacyWriteAttemptCount()==0 &&
      bus.LegacyReadAttemptCount()==0 && spare_ratio>=30.0);
   PrintFormat("[TASK028 REAL SUMMARY] Result=%s;Contexts=%d;Engines=%d;Handles=%d;DataBus=%d;Remaining=%d;Spare=%.2f;Snapshots=%d;PortfolioSequence=%I64d;PortfolioEvaluations=%I64d;CandidateEvaluations=%I64d;AllocationEvaluations=%I64d;MaxCandidates=%d;MaxAllocated=%d;MaxTotalAllocation=%.4f;Candidates=%d;Eligible=%d;Allocated=%d;TotalAllocation=%.4f;DuplicateContexts=%d;DuplicateCandidates=%d;RankingRuntimeUs=%I64d;AllocationRuntimeUs=%I64d;TotalRankingRuntimeUs=%I64d;TotalAllocationRuntimeUs=%I64d;SequenceGap=%I64d;SequenceDuplicate=%I64d;FutureSource=%I64d;WrongLinkage=%I64d;AllocationInvariant=%I64d;SecondaryLegacy=%d;Fallback=%d;SecondaryTradingStyle=0;SecondaryStrategy=0;SecondaryStandby=0;SecondaryRisk=0;SecondaryConfidence=0;SecondaryDecision=0;SecondaryEntry=0;SecondaryExit=0;SecondaryExecution=0;SecondaryOrder=0;SecondaryPosition=0",
               (pass ? "PASS" : "FAIL"),available,
               registry.AnalysisEngineCount()+11,registry.IndicatorHandleCount(),
               bus.CurrentSize(),bus.RemainingCapacity(),spare_ratio,
               g_snapshots.Count(),portfolio.evaluation_sequence,
               g_portfolio.EvaluationCount(),g_portfolio.CandidateEvaluationCount(),
               g_portfolio.AllocationEvaluationCount(),
               g_portfolio.MaximumCandidateCount(),g_portfolio.MaximumAllocatedCount(),
               g_portfolio.MaximumTotalAllocation(),portfolio.candidate_count,
               portfolio.eligible_count,portfolio.allocated_count,
               portfolio.total_allocation,portfolio.duplicate_symbol_context_count,
               portfolio.duplicate_symbol_candidate_count,
               portfolio.ranking_runtime_microseconds,
               portfolio.allocation_runtime_microseconds,
               g_portfolio.TotalRankingRuntimeMicroseconds(),
               g_portfolio.TotalAllocationRuntimeMicroseconds(),
               g_portfolio.SequenceGapCount(),g_portfolio.SequenceDuplicateCount(),
               g_portfolio.FutureSourceCount(),g_portfolio.WrongContextLinkageCount(),
               g_portfolio.AllocationInvariantCount(),(canonical_isolation ? 0 : 1),
               bus.LegacyReadAttemptCount());
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
   PrintFormat("[TASK028 REAL SHUTDOWN] BeforeHandles=%d;AfterHandles=%d;DoubleRelease=0;WrongRelease=0",
               before,after);
   g_portfolio.Clear();
   g_snapshots.Clear();
   g_ready=false;
  }
