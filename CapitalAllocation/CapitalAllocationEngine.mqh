//+------------------------------------------------------------------+
//|                 CapitalAllocation/CapitalAllocationEngine.mqh  |
//+------------------------------------------------------------------+
#ifndef FENX_CAPITAL_ALLOCATION_ENGINE_MQH
#define FENX_CAPITAL_ALLOCATION_ENGINE_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"
#include "../Portfolio/GlobalPortfolioSnapshotStore.mqh"

//--- Shared, factual Environment snapshot read through CDataBus.
struct SAllocationEnvironment
  {
   double   volatility_score;
   string   market_state;
   bool     range_data_valid;
   bool     trend_data_valid;
   datetime updated_at;
  };

//--- Global Pair Ranking validity and freshness facts read through CDataBus.
struct SAllocationRankingGlobal
  {
   bool     data_valid;
   datetime updated_at;
  };

//--- Per-symbol inputs supplied by Market Selection and Pair Ranking through CDataBus.
struct SCapitalAllocationInput
  {
   string   symbol;
   bool     is_market_eligible;
   bool     is_pair_ranked;
   int      pair_rank;
   double   pair_ranking_score;
   double   pair_ranking_confidence;
   datetime selection_updated_at;
   datetime ranking_updated_at;
  };

//--- Per-symbol allocation recommendation. Percentages are normalized units only.
struct SCapitalAllocationSnapshot
  {
   string   symbol;
   bool     is_allocated;
   double   allocation_percent;
   double   allocation_score;
   double   allocation_confidence;
   string   reason;
   datetime updated_at;
  };

//--- Candidate reference used while deterministically distributing the normalized budget.
struct SCapitalAllocationCandidate
  {
   int    snapshot_index;
   int    pair_rank;
  };

//--- Global allocation recommendation published after each allocation cycle.
struct SGlobalCapitalAllocationSnapshot
  {
   int      allocated_symbol_count;
   double   total_allocated_percent;
   double   unallocated_percent;
   string   top_allocated_symbol;
   bool     data_valid;
   datetime updated_at;
  };

//--- Distributes a normalized budget; it has no account, margin, lot-size, position, or order logic.
class CCapitalAllocationEngine : public CBaseEngine
  {
private:
   string m_symbols[];
   double m_total_budget;
   double m_max_per_symbol;
   double m_min_threshold;
   int    m_max_funded_symbols;
   double m_concentration_limit;
   double m_confidence_threshold;
   int    m_stale_data_limit_seconds;
   double m_volatility_penalty;
   double m_transition_penalty;
   double m_high_volatility_score;
   CGlobalPortfolioSnapshotStore *m_portfolio_store;

   void ResetSnapshot(SCapitalAllocationSnapshot &snapshot,const string symbol)
     {
      snapshot.symbol=symbol;
      snapshot.is_allocated=false;
      snapshot.allocation_percent=0.0;
      snapshot.allocation_score=0.0;
      snapshot.allocation_confidence=0.0;
      snapshot.reason="";
      snapshot.updated_at=TimeCurrent();
     }

   void ResetGlobalSnapshot(SGlobalCapitalAllocationSnapshot &snapshot)
     {
      snapshot.allocated_symbol_count=0;
      snapshot.total_allocated_percent=0.0;
      snapshot.unallocated_percent=100.0;
      snapshot.top_allocated_symbol="";
      snapshot.data_valid=false;
      snapshot.updated_at=TimeCurrent();
     }

   double ClampPercent(const double value)
     {
      return(MathMax(0.0,MathMin(100.0,value)));
     }

   bool ReadBooleanText(const string text,bool &value)
     {
      if(text=="true" || text=="TRUE")
        {
         value=true;
         return(true);
        }
      if(text=="false" || text=="FALSE")
        {
         value=false;
         return(true);
        }

      return(false);
     }

   bool ReadBoolean(const string key,bool &value)
     {
      if(m_data_bus==NULL)
         return(false);

      string text="";
      return(m_data_bus.TryGetText(key,text) && ReadBooleanText(text,value));
     }

   bool ReadDouble(const string key,double &value)
     {
      if(m_data_bus==NULL)
         return(false);

      string text="";
      if(!m_data_bus.TryGetText(key,text) || StringLen(text)==0)
         return(false);

      value=StringToDouble(text);
      return(true);
     }

   bool ReadTimestampText(const string text,datetime &value)
     {
      if(StringLen(text)==0)
         return(false);

      value=StringToTime(text);
      return(value>0);
     }

   bool ReadEnvironment(SAllocationEnvironment &environment)
     {
      if(m_data_bus==NULL)
         return(false);

      double volatility_score=0.0;
      string market_state="";
      bool range_data_valid=false;
      bool trend_data_valid=false;
      string updated_at_text="";
      datetime updated_at=0;
      if(!ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,volatility_score) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE,market_state) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,range_data_valid) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DATA_VALID,trend_data_valid) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT,
                                updated_at_text) ||
         !ReadTimestampText(updated_at_text,updated_at))
         return(false);

      environment.volatility_score=volatility_score;
      environment.market_state=market_state;
      environment.range_data_valid=range_data_valid;
      environment.trend_data_valid=trend_data_valid;
      environment.updated_at=updated_at;

      if(environment.volatility_score<0.0 || environment.volatility_score>100.0 ||
         !environment.range_data_valid || !environment.trend_data_valid)
         return(false);

      return(environment.market_state=="RANGING" || environment.market_state=="TRENDING" ||
             environment.market_state=="VOLATILE" || environment.market_state=="TRANSITION");
     }

   bool ReadRankingGlobal(SAllocationRankingGlobal &ranking)
     {
      if(m_data_bus==NULL)
         return(false);

      bool data_valid=false;
      string updated_at_text="";
      datetime updated_at=0;
      if(!ReadBoolean(FENX_DATABUS_KEY_PAIR_RANKING_DATA_VALID,data_valid) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_PAIR_RANKING_UPDATED_AT,updated_at_text) ||
         !ReadTimestampText(updated_at_text,updated_at))
         return(false);

      ranking.data_valid=data_valid;
      ranking.updated_at=updated_at;
      return(true);
     }

   bool ReadSymbolInput(const string symbol,SCapitalAllocationInput &source)
     {
      if(m_data_bus==NULL)
         return(false);

      string input_symbol="";
      string text="";
      string selection_updated_at_text="";
      string ranking_updated_at_text="";
      bool is_market_eligible=false;
      bool is_pair_ranked=false;
      datetime selection_updated_at=0;
      datetime ranking_updated_at=0;
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_MARKET_SELECTION_SYMBOL,input_symbol) ||
         input_symbol!=symbol ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_MARKET_SELECTION_IS_ELIGIBLE,text) ||
         !ReadBooleanText(text,is_market_eligible) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT,
                                      selection_updated_at_text) ||
         !ReadTimestampText(selection_updated_at_text,selection_updated_at) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_SYMBOL,text) ||
         text!=symbol ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_IS_RANKED,text) ||
         !ReadBooleanText(text,is_pair_ranked) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_RANK,text))
         return(false);

      source.symbol=input_symbol;
      source.is_market_eligible=is_market_eligible;
      source.selection_updated_at=selection_updated_at;
      source.is_pair_ranked=is_pair_ranked;
      source.pair_rank=(int)StringToInteger(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_SCORE,text))
         return(false);
      source.pair_ranking_score=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_CONFIDENCE,text))
         return(false);
      source.pair_ranking_confidence=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_UPDATED_AT,
                                      ranking_updated_at_text) ||
         !ReadTimestampText(ranking_updated_at_text,ranking_updated_at))
         return(false);

      source.ranking_updated_at=ranking_updated_at;
      return(source.pair_rank>=0 && source.pair_ranking_score>=0.0 &&
             source.pair_ranking_score<=100.0 && source.pair_ranking_confidence>=0.0 &&
             source.pair_ranking_confidence<=100.0);
     }

   bool CalculateFreshness(const datetime updated_at,double &freshness)
     {
      if(updated_at<=0 || m_stale_data_limit_seconds<=0)
         return(false);

      const long age_seconds=(long)(TimeCurrent()-updated_at);
      if(age_seconds<0 || age_seconds>m_stale_data_limit_seconds)
         return(false);

      freshness=ClampPercent(100.0*(1.0-((double)age_seconds/m_stale_data_limit_seconds)));
      return(true);
     }

   double CalculateVolatilityFactor(const double volatility_score)
     {
      if(m_high_volatility_score>=100.0 || volatility_score<=m_high_volatility_score)
         return(1.0);

      const double severity=(volatility_score-m_high_volatility_score)/
                            (100.0-m_high_volatility_score);
      return(MathMax(0.0,1.0-((m_volatility_penalty/100.0)*severity)));
     }

   double CalculateTransitionFactor(const string market_state)
     {
      if(market_state=="TRANSITION")
         return(MathMax(0.0,1.0-(m_transition_penalty/100.0)));

      return(1.0);
     }

   void BuildAllocationScore(const SCapitalAllocationInput &source,
                             const SAllocationEnvironment &environment,
                             const double freshness,SCapitalAllocationSnapshot &snapshot)
     {
      const double confidence_factor=source.pair_ranking_confidence/100.0;
      const double volatility_factor=CalculateVolatilityFactor(environment.volatility_score);
      const double transition_factor=CalculateTransitionFactor(environment.market_state);
      snapshot.allocation_score=ClampPercent(source.pair_ranking_score*confidence_factor*
                                              volatility_factor*transition_factor*(freshness/100.0));
      snapshot.allocation_confidence=ClampPercent(source.pair_ranking_confidence*(freshness/100.0));
      snapshot.reason="Allocation candidate accepted.";
     }

   bool HasHigherAllocationPriority(const SCapitalAllocationCandidate &left,
                                    const SCapitalAllocationCandidate &right,
                                    SCapitalAllocationSnapshot &snapshots[])
     {
      if(snapshots[left.snapshot_index].allocation_score>
         snapshots[right.snapshot_index].allocation_score+FENX_PAIR_RANKING_COMPARE_EPSILON)
         return(true);
      if(snapshots[right.snapshot_index].allocation_score>
         snapshots[left.snapshot_index].allocation_score+FENX_PAIR_RANKING_COMPARE_EPSILON)
         return(false);

      if(snapshots[left.snapshot_index].allocation_confidence>
         snapshots[right.snapshot_index].allocation_confidence+FENX_PAIR_RANKING_COMPARE_EPSILON)
         return(true);
      if(snapshots[right.snapshot_index].allocation_confidence>
         snapshots[left.snapshot_index].allocation_confidence+FENX_PAIR_RANKING_COMPARE_EPSILON)
         return(false);

      if(left.pair_rank<right.pair_rank)
         return(true);
      if(right.pair_rank<left.pair_rank)
         return(false);

      return(StringCompare(snapshots[left.snapshot_index].symbol,
                           snapshots[right.snapshot_index].symbol)<0);
     }

   void SortCandidates(SCapitalAllocationCandidate &candidates[],
                       SCapitalAllocationSnapshot &snapshots[])
     {
      for(int first=0;first<ArraySize(candidates)-1;first++)
        {
         int best=first;
         for(int next=first+1;next<ArraySize(candidates);next++)
           {
            if(HasHigherAllocationPriority(candidates[next],candidates[best],snapshots))
               best=next;
           }

         if(best!=first)
           {
            const int first_snapshot_index=candidates[first].snapshot_index;
            const int first_pair_rank=candidates[first].pair_rank;
            candidates[first].snapshot_index=candidates[best].snapshot_index;
            candidates[first].pair_rank=candidates[best].pair_rank;
            candidates[best].snapshot_index=first_snapshot_index;
            candidates[best].pair_rank=first_pair_rank;
           }
        }
     }

   void DistributeBudget(SCapitalAllocationCandidate &candidates[],const int candidate_count,
                         bool &funded[],SCapitalAllocationSnapshot &snapshots[],
                         const double effective_cap)
     {
      for(int index=0;index<candidate_count;index++)
        {
         const int snapshot_index=candidates[index].snapshot_index;
         snapshots[snapshot_index].allocation_percent=0.0;
        }

      for(int pass=0;pass<candidate_count;pass++)
        {
         double total_allocated=0.0;
         double available_weight=0.0;
         for(int index=0;index<candidate_count;index++)
           {
            const int snapshot_index=candidates[index].snapshot_index;
            total_allocated+=snapshots[snapshot_index].allocation_percent;
            if(funded[index] && snapshots[snapshot_index].allocation_percent<effective_cap-
               FENX_PAIR_RANKING_COMPARE_EPSILON)
               available_weight+=snapshots[snapshot_index].allocation_score;
           }

         const double remaining_budget=m_total_budget-total_allocated;
         if(remaining_budget<=FENX_PAIR_RANKING_COMPARE_EPSILON || available_weight<=0.0)
            return;

         bool capped_candidate=false;
         for(int index=0;index<candidate_count;index++)
           {
            const int snapshot_index=candidates[index].snapshot_index;
            if(!funded[index] || snapshots[snapshot_index].allocation_percent>=effective_cap-
               FENX_PAIR_RANKING_COMPARE_EPSILON)
               continue;

            const double suggested=remaining_budget*
                                   snapshots[snapshot_index].allocation_score/available_weight;
            const double capacity=effective_cap-snapshots[snapshot_index].allocation_percent;
            if(suggested>=capacity-FENX_PAIR_RANKING_COMPARE_EPSILON)
              {
               snapshots[snapshot_index].allocation_percent+=capacity;
               capped_candidate=true;
              }
           }

         if(!capped_candidate)
           {
            for(int index=0;index<candidate_count;index++)
              {
               const int snapshot_index=candidates[index].snapshot_index;
               if(funded[index] && snapshots[snapshot_index].allocation_percent<effective_cap-
                  FENX_PAIR_RANKING_COMPARE_EPSILON)
                  snapshots[snapshot_index].allocation_percent+=remaining_budget*
                    snapshots[snapshot_index].allocation_score/available_weight;
              }
            return;
           }
        }
     }

   void ApplyMinimumThreshold(SCapitalAllocationCandidate &candidates[],const int candidate_count,
                              bool &funded[],SCapitalAllocationSnapshot &snapshots[],
                              const double effective_cap)
     {
      for(int pass=0;pass<candidate_count;pass++)
        {
         DistributeBudget(candidates,candidate_count,funded,snapshots,effective_cap);
         bool removed_candidate=false;
         for(int index=0;index<candidate_count;index++)
           {
            const int snapshot_index=candidates[index].snapshot_index;
            if(funded[index] && snapshots[snapshot_index].allocation_percent<
               m_min_threshold-FENX_PAIR_RANKING_COMPARE_EPSILON)
              {
               funded[index]=false;
               snapshots[snapshot_index].allocation_percent=0.0;
               snapshots[snapshot_index].reason="Allocation is below the minimum threshold.";
               removed_candidate=true;
              }
           }

         if(!removed_candidate)
            return;
        }
     }

   bool PublishSnapshot(SCapitalAllocationSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      bool success=true;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_SYMBOL,snapshot.symbol))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_IS_ALLOCATED,
                                   (snapshot.is_allocated ? "true" : "false")))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_PERCENT,
                                   DoubleToString(snapshot.allocation_percent,2)))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_SCORE,
                                   DoubleToString(snapshot.allocation_score,2)))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_CONFIDENCE,
                                   DoubleToString(snapshot.allocation_confidence,2)))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_REASON,snapshot.reason))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_UPDATED_AT,
                                   TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS)))
         success=false;

      return(success);
     }

   bool PublishGlobalSnapshot(SGlobalCapitalAllocationSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      bool success=true;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_SYMBOL_COUNT,
                             IntegerToString(snapshot.allocated_symbol_count)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_TOTAL_PERCENT,
                             DoubleToString(snapshot.total_allocated_percent,2)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_UNALLOCATED_PERCENT,
                             DoubleToString(snapshot.unallocated_percent,2)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_TOP_SYMBOL,
                             snapshot.top_allocated_symbol))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_DATA_VALID,
                             (snapshot.data_valid ? "true" : "false")))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_UPDATED_AT,
                             TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS)))
         success=false;
      return(success);
     }

   bool LoadSymbols(CParameterManager &parameters)
     {
      const int symbol_count=parameters.MarketSelectionSymbolCount();
      if(symbol_count<1 || symbol_count>FENX_MARKET_SELECTION_MAX_SYMBOLS ||
         ArrayResize(m_symbols,symbol_count)!=symbol_count)
         return(false);

      for(int index=0;index<symbol_count;index++)
        {
         string configured_symbol="";
         if(!parameters.TryGetMarketSelectionSymbol(index,configured_symbol) ||
            StringLen(configured_symbol)==0)
            return(false);
         m_symbols[index]=configured_symbol;
        }
      return(true);
     }

   //--- Completes the pending shadow ranking with the existing allocation
   //--- score, threshold, sort, cap, and redistribution contract. Results stay
   //--- in the typed portfolio store and cannot enable secondary execution.
   void BuildShadowPortfolioAllocation(void)
     {
      if(m_portfolio_store==NULL)
         return;

      const ulong started=GetMicrosecondCount();
      SGlobalPortfolioSnapshot portfolio;
      SPortfolioCandidateSnapshot audits[];
      if(!m_portfolio_store.GetPendingEvaluation(portfolio,audits))
         return;

      const int context_count=ArraySize(audits);
      SCapitalAllocationSnapshot snapshots[];
      if(ArrayResize(snapshots,context_count)!=context_count)
         return;
      SCapitalAllocationCandidate candidates[];
      bool all_candidate_data_valid=true;
      for(int index=0;index<context_count;index++)
        {
         ResetSnapshot(snapshots[index],audits[index].context_id.symbol);
         snapshots[index].updated_at=portfolio.evaluation_time;
         audits[index].allocation_updated_at=portfolio.evaluation_time;
         if(!portfolio.ranking_valid || !audits[index].is_candidate)
            continue;

         SCapitalAllocationInput source;
         source.symbol=audits[index].context_id.symbol;
         source.is_market_eligible=audits[index].market_eligible;
         source.is_pair_ranked=audits[index].is_ranked;
         source.pair_rank=audits[index].rank;
         source.pair_ranking_score=audits[index].ranking_score;
         source.pair_ranking_confidence=audits[index].ranking_confidence;
         source.selection_updated_at=audits[index].selection_updated_at;
         source.ranking_updated_at=audits[index].ranking_updated_at;
         SAllocationEnvironment environment;
         environment.volatility_score=audits[index].environment_volatility_score;
         environment.market_state=audits[index].environment_market_state;
         environment.range_data_valid=true;
         environment.trend_data_valid=true;
         environment.updated_at=audits[index].environment_updated_at;

         double environment_freshness=0.0;
         double ranking_freshness=0.0;
         double selection_freshness=0.0;
         double symbol_ranking_freshness=0.0;
         if(!CalculateFreshness(environment.updated_at,environment_freshness) ||
            !CalculateFreshness(portfolio.evaluation_time,ranking_freshness) ||
            !CalculateFreshness(source.selection_updated_at,selection_freshness) ||
            !CalculateFreshness(source.ranking_updated_at,symbol_ranking_freshness))
           {
            audits[index].reason="Shadow allocation source is stale.";
            all_candidate_data_valid=false;
            continue;
           }
         if(!source.is_market_eligible || !source.is_pair_ranked ||
            source.pair_rank<=0)
           {
            audits[index].reason="Shadow ranking did not accept this context.";
            continue;
           }
         if(source.pair_ranking_confidence<m_confidence_threshold)
           {
            audits[index].reason="Pair Ranking confidence is below the allocation threshold.";
            continue;
           }
         if(environment.market_state=="VOLATILE")
           {
            audits[index].reason="Environment market state is VOLATILE.";
            continue;
           }

         const double freshness=MathMin(MathMin(environment_freshness,ranking_freshness),
                                        MathMin(selection_freshness,
                                                symbol_ranking_freshness));
         BuildAllocationScore(source,environment,freshness,snapshots[index]);
         if(snapshots[index].allocation_score<=0.0)
           {
            audits[index].reason="Allocation score is not positive.";
            continue;
           }
         audits[index].allocation_score=snapshots[index].allocation_score;
         audits[index].allocation_confidence=snapshots[index].allocation_confidence;
         const int candidate_index=ArraySize(candidates);
         if(ArrayResize(candidates,candidate_index+1)!=(candidate_index+1))
            return;
         candidates[candidate_index].snapshot_index=index;
         candidates[candidate_index].pair_rank=source.pair_rank;
        }

      SortCandidates(candidates,snapshots);
      int candidate_count=ArraySize(candidates);
      if(candidate_count>m_max_funded_symbols)
         candidate_count=m_max_funded_symbols;
      bool funded[];
      if(ArrayResize(funded,candidate_count)!=candidate_count)
         return;
      for(int index=0;index<candidate_count;index++)
         funded[index]=true;
      for(int index=candidate_count;index<ArraySize(candidates);index++)
         audits[candidates[index].snapshot_index].reason=
            "Candidate is outside the funded-symbol limit.";

      const double effective_cap=MathMin(m_max_per_symbol,
                                         m_total_budget*(m_concentration_limit/100.0));
      if(candidate_count>0)
         ApplyMinimumThreshold(candidates,candidate_count,funded,snapshots,effective_cap);

      portfolio.allocated_count=0;
      portfolio.total_allocation=0.0;
      for(int index=0;index<candidate_count;index++)
        {
         const int snapshot_index=candidates[index].snapshot_index;
         audits[snapshot_index].allocation_score=
            snapshots[snapshot_index].allocation_score;
         audits[snapshot_index].allocation_confidence=
            snapshots[snapshot_index].allocation_confidence;
         audits[snapshot_index].allocation_percent=
            snapshots[snapshot_index].allocation_percent;
         if(!funded[index] || snapshots[snapshot_index].allocation_percent<
            m_min_threshold-FENX_PAIR_RANKING_COMPARE_EPSILON)
            continue;
         audits[snapshot_index].is_allocated=true;
         audits[snapshot_index].reason="Capital allocation recommendation is active.";
         portfolio.allocated_count++;
         portfolio.total_allocation+=snapshots[snapshot_index].allocation_percent;
        }
      portfolio.total_allocation=ClampPercent(portfolio.total_allocation);
      portfolio.allocation_valid=(portfolio.ranking_valid &&
                                  all_candidate_data_valid);
      portfolio.allocation_runtime_microseconds=
         (long)(GetMicrosecondCount()-started);
      m_portfolio_store.CompleteAllocation(portfolio,audits);
     }

public:
                     CCapitalAllocationEngine(void)
     {
      SetName("CapitalAllocationEngine");
      m_total_budget=0.0;
      m_max_per_symbol=0.0;
      m_min_threshold=0.0;
      m_max_funded_symbols=0;
      m_concentration_limit=0.0;
      m_confidence_threshold=0.0;
      m_stale_data_limit_seconds=0;
      m_volatility_penalty=0.0;
      m_transition_penalty=0.0;
      m_high_volatility_score=0.0;
      m_portfolio_store=NULL;
     }

   //--- Optional Task028 shadow attachment. It does not replace or publish any
   //--- existing CapitalAllocation.* DataBus key.
   bool              SetGlobalPortfolio(CGlobalPortfolioSnapshotStore &portfolio_store)
     {
      if(m_initialized)
         return(false);
      m_portfolio_store=GetPointer(portfolio_store);
      return(true);
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_total_budget=parameters.CapitalAllocationTotalBudget();
      m_max_per_symbol=parameters.CapitalAllocationMaxPerSymbol();
      m_min_threshold=parameters.CapitalAllocationMinThreshold();
      m_max_funded_symbols=parameters.CapitalAllocationMaxFundedSymbols();
      m_concentration_limit=parameters.CapitalAllocationConcentrationLimit();
      m_confidence_threshold=parameters.CapitalAllocationConfidenceThreshold();
      m_stale_data_limit_seconds=parameters.CapitalAllocationStaleDataLimitSeconds();
      m_volatility_penalty=parameters.CapitalAllocationVolatilityPenalty();
      m_transition_penalty=parameters.CapitalAllocationTransitionPenalty();
      m_high_volatility_score=parameters.MarketSelectionMaxVolatilityScore();

      const double effective_cap=MathMin(m_max_per_symbol,
                                         m_total_budget*(m_concentration_limit/100.0));
      if(!LoadSymbols(parameters) || m_total_budget<=0.0 || m_total_budget>100.0 ||
         m_max_per_symbol<=0.0 || m_max_per_symbol>100.0 ||
         m_min_threshold<=0.0 || m_min_threshold>m_max_per_symbol ||
         m_max_funded_symbols<1 ||
         m_max_funded_symbols>FENX_MARKET_SELECTION_MAX_SYMBOLS ||
         m_concentration_limit<=0.0 || m_concentration_limit>=100.0 ||
         m_confidence_threshold<0.0 || m_confidence_threshold>100.0 ||
         m_stale_data_limit_seconds<1 || m_volatility_penalty<0.0 ||
         m_volatility_penalty>100.0 || m_transition_penalty<0.0 ||
         m_transition_penalty>100.0 || m_high_volatility_score<=0.0 ||
         m_high_volatility_score>100.0 || effective_cap<m_min_threshold)
        {
         CLogger::Error("CapitalAllocationEngine received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      CLogger::Info(StringFormat("CapitalAllocationEngine configured for %d symbol(s).",
                                 ArraySize(m_symbols)));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;

      SAllocationEnvironment environment;
      SAllocationRankingGlobal ranking_global;
      double environment_freshness=0.0;
      double ranking_freshness=0.0;
      bool environment_valid=ReadEnvironment(environment);
      bool ranking_global_valid=ReadRankingGlobal(ranking_global);
      if(environment_valid)
         environment_valid=CalculateFreshness(environment.updated_at,environment_freshness);
      if(ranking_global_valid)
         ranking_global_valid=(ranking_global.data_valid &&
                               CalculateFreshness(ranking_global.updated_at,ranking_freshness));
      if(!environment_valid || !ranking_global_valid)
         CLogger::Warning("CapitalAllocationEngine is waiting for valid, fresh upstream data.");

      const int symbol_count=ArraySize(m_symbols);
      SCapitalAllocationSnapshot snapshots[];
      if(ArrayResize(snapshots,symbol_count)!=symbol_count)
        {
         CLogger::Error("CapitalAllocationEngine could not allocate per-symbol snapshots.");
         return;
        }

      SCapitalAllocationCandidate candidates[];
      bool all_symbol_data_valid=true;
      for(int index=0;index<symbol_count;index++)
        {
         ResetSnapshot(snapshots[index],m_symbols[index]);
         if(!environment_valid || !ranking_global_valid)
           {
            snapshots[index].reason="Environment or Pair Ranking data is unavailable, invalid, or stale.";
            continue;
           }

         SCapitalAllocationInput source;
         if(!ReadSymbolInput(m_symbols[index],source))
           {
            snapshots[index].reason="Market Selection or Pair Ranking data is unavailable or invalid.";
            all_symbol_data_valid=false;
            continue;
           }

         double selection_freshness=0.0;
         double symbol_ranking_freshness=0.0;
         if(!CalculateFreshness(source.selection_updated_at,selection_freshness) ||
            !CalculateFreshness(source.ranking_updated_at,symbol_ranking_freshness))
           {
            snapshots[index].reason="Market Selection or Pair Ranking data is stale.";
            all_symbol_data_valid=false;
            continue;
           }

         if(!source.is_market_eligible)
           {
            snapshots[index].reason="Market Selection rejected this symbol.";
            continue;
           }
         if(!source.is_pair_ranked)
           {
            snapshots[index].reason="Pair Ranking did not rank this symbol.";
            continue;
           }
         if(source.pair_ranking_confidence<m_confidence_threshold)
           {
            snapshots[index].reason="Pair Ranking confidence is below the allocation threshold.";
            continue;
           }
         if(environment.market_state=="VOLATILE")
           {
            snapshots[index].reason="Environment market state is VOLATILE.";
            continue;
           }

         const double freshness=MathMin(MathMin(environment_freshness,ranking_freshness),
                                        MathMin(selection_freshness,
                                                symbol_ranking_freshness));
         BuildAllocationScore(source,environment,freshness,snapshots[index]);
         if(snapshots[index].allocation_score<=0.0)
           {
            snapshots[index].reason="Allocation score is not positive.";
            continue;
           }

         const int candidate_index=ArraySize(candidates);
         if(ArrayResize(candidates,candidate_index+1)!=(candidate_index+1))
           {
            snapshots[index].reason="Capital Allocation could not allocate a candidate.";
            all_symbol_data_valid=false;
            CLogger::Error("CapitalAllocationEngine could not allocate a candidate.");
            continue;
           }
         candidates[candidate_index].snapshot_index=index;
         candidates[candidate_index].pair_rank=source.pair_rank;
        }

      SortCandidates(candidates,snapshots);
      int candidate_count=ArraySize(candidates);
      if(candidate_count>m_max_funded_symbols)
         candidate_count=m_max_funded_symbols;

      bool funded[];
      if(ArrayResize(funded,candidate_count)!=candidate_count)
        {
         CLogger::Error("CapitalAllocationEngine could not allocate funding flags.");
         return;
        }
      for(int index=0;index<candidate_count;index++)
         funded[index]=true;
      for(int index=candidate_count;index<ArraySize(candidates);index++)
        {
         const int snapshot_index=candidates[index].snapshot_index;
         snapshots[snapshot_index].reason="Candidate is outside the funded-symbol limit.";
        }

      const double effective_cap=MathMin(m_max_per_symbol,
                                         m_total_budget*(m_concentration_limit/100.0));
      if(candidate_count>0)
         ApplyMinimumThreshold(candidates,candidate_count,funded,snapshots,effective_cap);

      SGlobalCapitalAllocationSnapshot global_snapshot;
      ResetGlobalSnapshot(global_snapshot);
      global_snapshot.data_valid=(environment_valid && ranking_global_valid &&
                                  all_symbol_data_valid);
      for(int index=0;index<candidate_count;index++)
        {
         const int snapshot_index=candidates[index].snapshot_index;
         if(!funded[index] ||
            snapshots[snapshot_index].allocation_percent<
               m_min_threshold-FENX_PAIR_RANKING_COMPARE_EPSILON)
            continue;

         snapshots[snapshot_index].is_allocated=true;
         snapshots[snapshot_index].reason="Capital allocation recommendation is active.";
         global_snapshot.allocated_symbol_count++;
         global_snapshot.total_allocated_percent+=
            snapshots[snapshot_index].allocation_percent;
         if(StringLen(global_snapshot.top_allocated_symbol)==0)
            global_snapshot.top_allocated_symbol=snapshots[snapshot_index].symbol;
        }
      global_snapshot.total_allocated_percent=
         ClampPercent(global_snapshot.total_allocated_percent);
      global_snapshot.unallocated_percent=
         ClampPercent(100.0-global_snapshot.total_allocated_percent);

      for(int index=0;index<symbol_count;index++)
        {
         if(!PublishSnapshot(snapshots[index]))
            CLogger::Error(StringFormat("CapitalAllocationEngine could not publish %s.",
                                        snapshots[index].symbol));
        }
      if(!PublishGlobalSnapshot(global_snapshot))
         CLogger::Error("CapitalAllocationEngine could not publish global allocation data.");

      BuildShadowPortfolioAllocation();
     }

   virtual void       Shutdown(void)
     {
      ArrayFree(m_symbols);
      m_portfolio_store=NULL;
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_CAPITAL_ALLOCATION_ENGINE_MQH
