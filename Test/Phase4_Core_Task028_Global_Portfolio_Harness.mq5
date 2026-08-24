//+------------------------------------------------------------------+
//| Phase4-Core Task028 Global Portfolio Synthetic Harness          |
//+------------------------------------------------------------------+
#property strict
#property version "1.028"

#include "../Config/ParameterManager.mqh"
#include "../Core/DataBus.mqh"
#include "../Common/CommonSnapshotStore.mqh"
#include "../Portfolio/GlobalPortfolioSnapshotStore.mqh"
#include "../PairRanking/PairRankingEngine.mqh"
#include "../CapitalAllocation/CapitalAllocationEngine.mqh"

#define TASK028_SYNTHETIC_TEST_COUNT 20

class CTask028SyntheticFixture
  {
private:
   CParameterManager               m_parameters;
   CDataBus                        m_bus;
   CCommonSnapshotStore            m_common;
   CGlobalPortfolioSnapshotStore   m_portfolio;
   CPairRankingEngine              m_ranking;
   CCapitalAllocationEngine        m_allocation;
   SPortfolioContextDefinition     m_contexts[];
   bool                            m_initialized;

   void              FillContext(const int index,const string symbol,
                                 const ENUM_TIMEFRAMES timeframe,
                                 const ENUM_FENX_CONTEXT_ROLE role,
                                 const bool trade_enabled,const bool available)
     {
      ResetRuntimeContextConfig(m_contexts[index].config);
      m_contexts[index].config.id.symbol=symbol;
      m_contexts[index].config.id.timeframe=timeframe;
      m_contexts[index].config.enabled=true;
      m_contexts[index].config.required=(index==0);
      m_contexts[index].config.trade_enabled=trade_enabled;
      m_contexts[index].config.role=role;
      m_contexts[index].config.magic=93095+index;
      m_contexts[index].config.parameter_profile_id="task028-synthetic";
      m_contexts[index].available=available;
      m_contexts[index].registration_order=index;
     }

   bool              SetLegacy(const string key,const string value)
     {
      return(m_bus.SetText(key,value));
     }

   bool              SeedLegacyPrimary(const datetime observed_at)
     {
      const string stamp=TimeToString(observed_at,TIME_DATE|TIME_SECONDS);
      const string symbol=_Symbol;
      bool ok=true;
      ok=(ok && SetLegacy(FENX_DATABUS_KEY_ENVIRONMENT_ATR,"1.00000"));
      ok=(ok && SetLegacy(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,"50.00"));
      ok=(ok && SetLegacy(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,"80.00"));
      ok=(ok && SetLegacy(FENX_DATABUS_KEY_ENVIRONMENT_TREND_SCORE,"0.00"));
      ok=(ok && SetLegacy(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_CONFIDENCE,"80.00"));
      ok=(ok && SetLegacy(FENX_DATABUS_KEY_ENVIRONMENT_IS_RANGE,"true"));
      ok=(ok && SetLegacy(FENX_DATABUS_KEY_ENVIRONMENT_IS_TREND,"false"));
      ok=(ok && SetLegacy(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,"true"));
      ok=(ok && SetLegacy(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DATA_VALID,"true"));
      ok=(ok && SetLegacy(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE,"RANGING"));
      ok=(ok && SetLegacy(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT,stamp));
      ok=(ok && m_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
         FENX_DATABUS_FIELD_MARKET_SELECTION_SYMBOL,symbol));
      ok=(ok && m_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
         FENX_DATABUS_FIELD_MARKET_SELECTION_IS_ELIGIBLE,"true"));
      ok=(ok && m_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
         FENX_DATABUS_FIELD_MARKET_SELECTION_SCORE,"80.00"));
      ok=(ok && m_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
         FENX_DATABUS_FIELD_MARKET_SELECTION_CONFIDENCE,"80.00"));
      ok=(ok && m_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
         FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_POINTS,"5.00"));
      ok=(ok && m_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
         FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_ATR,"0.0500"));
      ok=(ok && m_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
         FENX_DATABUS_FIELD_MARKET_SELECTION_REJECTION,""));
      ok=(ok && m_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
         FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT,stamp));
      return(ok);
     }

   bool              SeedContext(const int index,const datetime observed_at,
                                 const bool market_eligible)
     {
      const SRuntimeContextId id=m_contexts[index].config.id;
      const string stamp=TimeToString(observed_at,TIME_DATE|TIME_SECONDS);
      bool ok=true;
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,id,
                                     "ATR","1.00000"));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,id,
                                     "Score","50.00"));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_RANGE,id,
                                     "Score","80.00"));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_RANGE,id,
                                     "IsRange","true"));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_RANGE,id,
                                     "IsDataValid","true"));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_RANGE,id,
                                     "UpdatedAt",stamp));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,id,
                                     "Score","0.00"));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,id,
                                     "IsTrend","false"));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,id,
                                     "IsDataValid","true"));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,id,
                                     "UpdatedAt",stamp));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,id,
                                     "Confidence","80.00"));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,id,
                                     "State","RANGING"));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,id,
                                     "UpdatedAt",stamp));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,id,
                                     FENX_DATABUS_FIELD_MARKET_SELECTION_SYMBOL,
                                     id.symbol));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,id,
                                     FENX_DATABUS_FIELD_MARKET_SELECTION_IS_ELIGIBLE,
                                     (market_eligible ? "true" : "false")));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,id,
                                     FENX_DATABUS_FIELD_MARKET_SELECTION_SCORE,
                                     "80.00"));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,id,
                                     FENX_DATABUS_FIELD_MARKET_SELECTION_CONFIDENCE,
                                     "80.00"));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,id,
                                     FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_POINTS,
                                     "5.00"));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,id,
                                     FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_ATR,
                                     "0.0500"));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,id,
                                     FENX_DATABUS_FIELD_MARKET_SELECTION_REJECTION,
                                     (market_eligible ? "" : "SYNTHETIC_INELIGIBLE")));
      ok=(ok && m_bus.SetContextText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,id,
                                     FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT,
                                     stamp));

      SEnvironmentSnapshot environment;
      environment.symbol=id.symbol;
      environment.timeframe=EnumToString(id.timeframe);
      environment.snapshot_version=FENX_COMMON_ENVIRONMENT_SNAPSHOT_VERSION;
      environment.updated_at=observed_at;
      environment.is_valid=true;
      environment.is_fresh=true;
      environment.invalid_reason="";
      environment.atr=1.0;
      environment.volatility_score=50.0;
      environment.volatility_level="NORMAL";
      environment.volatility_updated_at=observed_at;
      environment.volatility_valid=true;
      environment.range_upper=151.0;
      environment.range_lower=149.0;
      environment.range_midpoint=150.0;
      environment.range_width_points=200.0;
      environment.range_position=0.5;
      environment.range_score=80.0;
      environment.is_range=true;
      environment.range_updated_at=observed_at;
      environment.range_valid=true;
      environment.trend_direction="NEUTRAL";
      environment.trend_strength=0.0;
      environment.trend_score=0.0;
      environment.trend_slope=0.0;
      environment.trend_confidence=80.0;
      environment.adx=20.0;
      environment.is_trend=false;
      environment.trend_updated_at=observed_at;
      environment.trend_valid=true;
      environment.market_state="RANGING";
      environment.market_confidence=80.0;
      environment.recommended_style="RANGE";
      environment.recommended_risk="NORMAL";
      environment.market_state_updated_at=observed_at;
      environment.market_state_valid=true;
      return(ok && m_common.SetEnvironmentSnapshot(id.symbol,id.timeframe,environment));
     }

public:
                     CTask028SyntheticFixture(void)
     {
      m_initialized=false;
     }

   bool              Initialize(const int unavailable_index=-1,
                                const int ineligible_index=-1)
     {
      if(!m_parameters.Load() || ArrayResize(m_contexts,5)!=5)
         return(false);
      FillContext(0,"USDJPY",PERIOD_H1,FENX_CONTEXT_ROLE_PRIMARY_TRADING,true,true);
      FillContext(1,"EURUSD",PERIOD_H1,FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,
                  unavailable_index!=1);
      FillContext(2,"GBPUSD",PERIOD_H1,FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,
                  unavailable_index!=2);
      FillContext(3,"AUDUSD",PERIOD_H1,FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,
                  unavailable_index!=3);
      FillContext(4,"USDJPY",PERIOD_M15,FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,
                  unavailable_index!=4);
      if(!m_ranking.SetGlobalPortfolio(m_portfolio,m_common,m_contexts) ||
         !m_allocation.SetGlobalPortfolio(m_portfolio) ||
         !m_ranking.Initialize(m_bus,m_parameters) ||
         !m_allocation.Initialize(m_bus,m_parameters))
         return(false);
      const datetime now=TimeCurrent();
      if(!SeedLegacyPrimary(now))
         return(false);
      for(int index=0;index<5;index++)
         if(!SeedContext(index,now,index!=ineligible_index))
            return(false);
      m_initialized=true;
      return(Update());
     }

   bool              Update(void)
     {
      if(!m_initialized)
         return(false);
      m_ranking.Update();
      m_allocation.Update();
      SGlobalPortfolioSnapshot snapshot;
      SPortfolioCandidateSnapshot candidates[];
      return(m_portfolio.GetLatest(snapshot,candidates));
     }

   bool              Latest(SGlobalPortfolioSnapshot &snapshot,
                            SPortfolioCandidateSnapshot &candidates[])
     {
      return(m_portfolio.GetLatest(snapshot,candidates));
     }

   bool              LegacyRanking(double &score,string &top_symbol)
     {
      string text="";
      if(!m_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,_Symbol,
                                 FENX_DATABUS_FIELD_PAIR_RANKING_SCORE,text))
         return(false);
      score=StringToDouble(text);
      return(m_bus.TryGetText(FENX_DATABUS_KEY_PAIR_RANKING_TOP_SYMBOL,top_symbol));
     }

   bool              LegacyAllocation(double &score,double &percent)
     {
      string text="";
      if(!m_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,_Symbol,
                                 FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_SCORE,text))
         return(false);
      score=StringToDouble(text);
      if(!m_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,_Symbol,
                                 FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_PERCENT,text))
         return(false);
      percent=StringToDouble(text);
      return(true);
     }

   CGlobalPortfolioSnapshotStore *Store(void) { return(GetPointer(m_portfolio)); }
   CDataBus *Bus(void) { return(GetPointer(m_bus)); }

   void              Shutdown(void)
     {
      m_allocation.Shutdown();
      m_ranking.Shutdown();
      m_initialized=false;
     }
  };

CTask028SyntheticFixture g_full;
CTask028SyntheticFixture g_unavailable;
CTask028SyntheticFixture g_ineligible;
string g_names[TASK028_SYNTHETIC_TEST_COUNT];
bool g_results[TASK028_SYNTHETIC_TEST_COUNT];

void Record(const int index,const string name,const bool passed)
  {
   g_names[index]=name;
   g_results[index]=passed;
   PrintFormat("[TASK028 SYNTHETIC] %02d %s: %s",index+1,name,
               (passed ? "PASS" : "FAIL"));
  }

int FindCandidate(SPortfolioCandidateSnapshot &candidates[],
                  const string symbol,const ENUM_TIMEFRAMES timeframe)
  {
   for(int index=0;index<ArraySize(candidates);index++)
      if(candidates[index].context_id.symbol==symbol &&
         candidates[index].context_id.timeframe==timeframe)
         return(index);
   return(-1);
  }

int OnInit(void)
  {
   const bool full_ok=g_full.Initialize();
   SGlobalPortfolioSnapshot full;
   SPortfolioCandidateSnapshot candidates[];
   const bool latest_ok=(full_ok && g_full.Latest(full,candidates));
   Record(0,"Five Context Evaluation",latest_ok && full.context_count==5);
   Record(1,"Four Unique Candidates",latest_ok && full.candidate_count==4 &&
          full.duplicate_symbol_context_count==1 &&
          full.duplicate_symbol_candidate_count==0);

   const int usd_h1=FindCandidate(candidates,"USDJPY",PERIOD_H1);
   const int usd_m15=FindCandidate(candidates,"USDJPY",PERIOD_M15);
   Record(2,"Primary Symbol Candidate",usd_h1>=0 && candidates[usd_h1].is_candidate);
   Record(3,"Auxiliary Timeframe Excluded",usd_m15>=0 &&
          !candidates[usd_m15].is_candidate &&
          candidates[usd_m15].allocation_percent==0.0);

   const int aud=FindCandidate(candidates,"AUDUSD",PERIOD_H1);
   const int eur=FindCandidate(candidates,"EURUSD",PERIOD_H1);
   const int gbp=FindCandidate(candidates,"GBPUSD",PERIOD_H1);
   Record(4,"Existing Alphabetical Tie-break",aud>=0 && eur>=0 && gbp>=0 &&
          candidates[aud].rank==1 && candidates[eur].rank==2 &&
          candidates[gbp].rank==3 && candidates[usd_h1].rank==4);
   Record(5,"Allocation Funded Limit",full.allocated_count==3 &&
          candidates[aud].is_allocated && candidates[eur].is_allocated &&
          candidates[gbp].is_allocated && !candidates[usd_h1].is_allocated);
   Record(6,"Total Allocation Integrity",MathAbs(full.total_allocation-100.0)<0.001);

   double legacy_rank=0.0;
   string legacy_top="";
   const bool legacy_rank_ok=g_full.LegacyRanking(legacy_rank,legacy_top);
   Record(7,"Primary Legacy Ranking Preserved",legacy_rank_ok &&
          legacy_top==_Symbol && MathAbs(legacy_rank-candidates[usd_h1].ranking_score)<0.011);
   double legacy_allocation_score=0.0;
   double legacy_allocation_percent=0.0;
   const bool legacy_allocation_ok=g_full.LegacyAllocation(
      legacy_allocation_score,legacy_allocation_percent);
   Record(8,"Primary Legacy Allocation Preserved",legacy_allocation_ok &&
          MathAbs(legacy_allocation_percent-40.0)<0.001 &&
          MathAbs(legacy_allocation_score-
                  candidates[usd_h1].allocation_score)<0.011);

   const bool second_update=g_full.Update();
   SGlobalPortfolioSnapshot second;
   SPortfolioCandidateSnapshot second_candidates[];
   g_full.Latest(second,second_candidates);
   Record(9,"Evaluation Sequence",second_update && second.evaluation_sequence==2 &&
          g_full.Store().EvaluationCount()==2 &&
          g_full.Store().SequenceGapCount()==0 &&
          g_full.Store().SequenceDuplicateCount()==0);
   Record(10,"Context Linkage",g_full.Store().WrongContextLinkageCount()==0);
   Record(11,"Data Leak Audit",g_full.Store().FutureSourceCount()==0);
   Record(12,"Bounded History",g_full.Store().EvaluationHistoryCount()==2 &&
          g_full.Store().CandidateHistoryCount()==10);

   const bool unavailable_ok=g_unavailable.Initialize(2,-1);
   SGlobalPortfolioSnapshot unavailable;
   SPortfolioCandidateSnapshot unavailable_candidates[];
   g_unavailable.Latest(unavailable,unavailable_candidates);
   const int unavailable_gbp=FindCandidate(unavailable_candidates,"GBPUSD",PERIOD_H1);
   Record(13,"Unavailable Context Excluded",unavailable_ok &&
          unavailable.candidate_count==3 && unavailable_gbp>=0 &&
          !unavailable_candidates[unavailable_gbp].is_candidate &&
          unavailable_candidates[unavailable_gbp].allocation_percent==0.0);

   const bool ineligible_ok=g_ineligible.Initialize(-1,1);
   SGlobalPortfolioSnapshot ineligible;
   SPortfolioCandidateSnapshot ineligible_candidates[];
   g_ineligible.Latest(ineligible,ineligible_candidates);
   const int ineligible_eur=FindCandidate(ineligible_candidates,"EURUSD",PERIOD_H1);
   Record(14,"Market Ineligible Excluded",ineligible_ok &&
          ineligible.candidate_count==3 && ineligible_eur>=0 &&
          !ineligible_candidates[ineligible_eur].is_candidate &&
          ineligible_candidates[ineligible_eur].allocation_percent==0.0);
   Record(15,"Allocation Non-negative",full.total_allocation>=0.0 &&
          g_full.Store().AllocationInvariantCount()==0);
   Record(16,"No Duplicate Allocation",
          g_full.Store().DuplicateSymbolCandidateCount()==0);
   Record(17,"Secondary Remains Non-trading",candidates[eur].trade_enabled==false &&
          candidates[gbp].trade_enabled==false && candidates[aud].trade_enabled==false);
   Record(18,"Typed Store Only",g_full.Bus().LegacySchemaKeyCount()==0 &&
          g_full.Bus().LegacyWriteAttemptCount()==0 &&
          g_full.Bus().LegacyReadAttemptCount()==0);
   Record(19,"Final Snapshot Valid",full.ranking_valid && full.allocation_valid &&
          full.is_valid && full.is_fresh);
   return(INIT_SUCCEEDED);
  }

double OnTester(void)
  {
   int passed=0;
   for(int index=0;index<TASK028_SYNTHETIC_TEST_COUNT;index++)
     {
      if(g_results[index]) passed++;
      PrintFormat("[TASK028 SYNTHETIC FINAL] %02d %s: %s",index+1,g_names[index],
                  (g_results[index] ? "PASS" : "FAIL"));
     }
   PrintFormat("[TASK028 SYNTHETIC SUMMARY] %d/%d PASS",passed,
               TASK028_SYNTHETIC_TEST_COUNT);
   return(passed==TASK028_SYNTHETIC_TEST_COUNT ? 1.0 : 0.0);
  }

void OnDeinit(const int reason)
  {
   g_full.Shutdown();
   g_unavailable.Shutdown();
   g_ineligible.Shutdown();
  }
