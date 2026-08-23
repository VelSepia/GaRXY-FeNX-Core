//+------------------------------------------------------------------+
//|                Portfolio/GlobalPortfolioSnapshotStore.mqh      |
//+------------------------------------------------------------------+
#ifndef FENX_GLOBAL_PORTFOLIO_SNAPSHOT_STORE_MQH
#define FENX_GLOBAL_PORTFOLIO_SNAPSHOT_STORE_MQH

#include "../Common/Types.mqh"

#define FENX_PORTFOLIO_EVALUATION_HISTORY_LIMIT 64
#define FENX_PORTFOLIO_CANDIDATE_HISTORY_LIMIT  256

//--- Immutable registry metadata used to decide whether one runtime context
//--- may participate in the shadow portfolio. Trading permission is retained
//--- separately in config.trade_enabled and is never inferred from eligibility.
struct SPortfolioContextDefinition
  {
   SRuntimeContextConfig config;
   bool                  available;
   int                   registration_order;
  };

//--- Complete, auditable result for one context in one portfolio evaluation.
//--- Non-candidates are retained with zero rank/allocation and an explicit
//--- reason so unavailable, ineligible, and duplicate-timeframe exclusions can
//--- be verified without publishing candidate details into CDataBus.
struct SPortfolioCandidateSnapshot
  {
   long                  evaluation_sequence;
   SRuntimeContextId     context_id;
   ENUM_FENX_CONTEXT_ROLE context_role;
   int                   registration_order;
   bool                  context_enabled;
   bool                  context_available;
   bool                  trade_enabled;
   bool                  portfolio_eligible;
   bool                  market_eligible;
   bool                  is_candidate;
   bool                  is_ranked;
   bool                  is_allocated;
   double                selection_score;
   double                selection_confidence;
   double                spread_points;
   double                spread_to_atr_ratio;
   double                environment_atr;
   double                environment_volatility_score;
   double                environment_range_score;
   double                environment_trend_score;
   double                environment_confidence;
   bool                  environment_is_range;
   bool                  environment_is_trend;
   string                environment_market_state;
   double                ranking_score;
   double                ranking_confidence;
   int                   rank;
   double                allocation_score;
   double                allocation_confidence;
   double                allocation_percent;
   string                reason;
   datetime              selection_updated_at;
   datetime              environment_updated_at;
   datetime              volatility_updated_at;
   datetime              range_updated_at;
   datetime              trend_updated_at;
   datetime              market_state_updated_at;
   datetime              ranking_updated_at;
   datetime              allocation_updated_at;
   datetime              updated_at;
  };

//--- One final global portfolio evaluation. The ranking and allocation phases
//--- share evaluation_sequence, allowing every candidate's source, rank, and
//--- recommendation to be traced as one transaction-like shadow observation.
struct SGlobalPortfolioSnapshot
  {
   long     evaluation_sequence;
   datetime evaluation_time;
   datetime updated_at;
   int      context_count;
   int      available_count;
   int      eligible_count;
   int      candidate_count;
   int      excluded_count;
   int      duplicate_symbol_context_count;
   int      duplicate_symbol_candidate_count;
   int      allocated_count;
   double   total_allocation;
   bool     ranking_valid;
   bool     allocation_valid;
   bool     is_valid;
   bool     is_fresh;
   long     ranking_runtime_microseconds;
   long     allocation_runtime_microseconds;
  };

void ResetPortfolioCandidateSnapshot(SPortfolioCandidateSnapshot &snapshot)
  {
   snapshot.evaluation_sequence=0;
   snapshot.context_id.symbol="";
   snapshot.context_id.timeframe=PERIOD_CURRENT;
   snapshot.context_role=FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS;
   snapshot.registration_order=-1;
   snapshot.context_enabled=false;
   snapshot.context_available=false;
   snapshot.trade_enabled=false;
   snapshot.portfolio_eligible=false;
   snapshot.market_eligible=false;
   snapshot.is_candidate=false;
   snapshot.is_ranked=false;
   snapshot.is_allocated=false;
   snapshot.selection_score=0.0;
   snapshot.selection_confidence=0.0;
   snapshot.spread_points=0.0;
   snapshot.spread_to_atr_ratio=0.0;
   snapshot.environment_atr=0.0;
   snapshot.environment_volatility_score=0.0;
   snapshot.environment_range_score=0.0;
   snapshot.environment_trend_score=0.0;
   snapshot.environment_confidence=0.0;
   snapshot.environment_is_range=false;
   snapshot.environment_is_trend=false;
   snapshot.environment_market_state="";
   snapshot.ranking_score=0.0;
   snapshot.ranking_confidence=0.0;
   snapshot.rank=0;
   snapshot.allocation_score=0.0;
   snapshot.allocation_confidence=0.0;
   snapshot.allocation_percent=0.0;
   snapshot.reason="";
   snapshot.selection_updated_at=0;
   snapshot.environment_updated_at=0;
   snapshot.volatility_updated_at=0;
   snapshot.range_updated_at=0;
   snapshot.trend_updated_at=0;
   snapshot.market_state_updated_at=0;
   snapshot.ranking_updated_at=0;
   snapshot.allocation_updated_at=0;
   snapshot.updated_at=0;
  }

void ResetGlobalPortfolioSnapshot(SGlobalPortfolioSnapshot &snapshot)
  {
   snapshot.evaluation_sequence=0;
   snapshot.evaluation_time=0;
   snapshot.updated_at=0;
   snapshot.context_count=0;
   snapshot.available_count=0;
   snapshot.eligible_count=0;
   snapshot.candidate_count=0;
   snapshot.excluded_count=0;
   snapshot.duplicate_symbol_context_count=0;
   snapshot.duplicate_symbol_candidate_count=0;
   snapshot.allocated_count=0;
   snapshot.total_allocation=0.0;
   snapshot.ranking_valid=false;
   snapshot.allocation_valid=false;
   snapshot.is_valid=false;
   snapshot.is_fresh=false;
   snapshot.ranking_runtime_microseconds=0;
   snapshot.allocation_runtime_microseconds=0;
  }

//--- Bounded typed store for the shadow-only global portfolio. No candidate
//--- values are written to legacy DataBus keys, and history uses ring buffers
//--- so storage cannot grow during a long Strategy Tester run.
class CGlobalPortfolioSnapshotStore
  {
private:
   SGlobalPortfolioSnapshot    m_latest;
   SPortfolioCandidateSnapshot m_latest_candidates[];
   SGlobalPortfolioSnapshot    m_pending;
   SPortfolioCandidateSnapshot m_pending_candidates[];
   bool                        m_has_latest;
   bool                        m_has_pending;
   long                        m_last_sequence;
   long                        m_evaluation_count;
   long                        m_candidate_evaluation_count;
   long                        m_allocation_evaluation_count;
   int                         m_max_candidate_count;
   int                         m_max_allocated_count;
   double                      m_max_total_allocation;
   long                        m_total_ranking_runtime_microseconds;
   long                        m_total_allocation_runtime_microseconds;
   SGlobalPortfolioSnapshot    m_evaluation_history[];
   int                         m_evaluation_history_head;
   int                         m_evaluation_history_count;
   SPortfolioCandidateSnapshot m_candidate_history[];
   int                         m_candidate_history_head;
   int                         m_candidate_history_count;
   long                        m_sequence_gap_count;
   long                        m_sequence_duplicate_count;
   long                        m_future_source_count;
   long                        m_wrong_context_linkage_count;
   long                        m_duplicate_symbol_candidate_count;
   long                        m_allocation_invariant_count;

   bool              CopyCandidates(SPortfolioCandidateSnapshot &source[],
                                    SPortfolioCandidateSnapshot &target[])
     {
      const int count=ArraySize(source);
      if(ArrayResize(target,count)!=count)
         return(false);
      for(int index=0;index<count;index++)
         target[index]=source[index];
      return(true);
     }

   bool              SameIdentity(const SPortfolioCandidateSnapshot &left,
                                  const SPortfolioCandidateSnapshot &right)
     {
      return(left.evaluation_sequence==right.evaluation_sequence &&
             RuntimeContextEquals(left.context_id,right.context_id) &&
             left.registration_order==right.registration_order);
     }

   bool              HasFutureSource(const SPortfolioCandidateSnapshot &candidate,
                                     const datetime evaluation_time)
     {
      return(candidate.selection_updated_at>evaluation_time ||
             candidate.environment_updated_at>evaluation_time ||
             candidate.volatility_updated_at>evaluation_time ||
             candidate.range_updated_at>evaluation_time ||
             candidate.trend_updated_at>evaluation_time ||
             candidate.market_state_updated_at>evaluation_time ||
             candidate.ranking_updated_at>evaluation_time ||
             candidate.allocation_updated_at>evaluation_time ||
             candidate.updated_at>evaluation_time);
     }

   void              AppendEvaluationHistory(const SGlobalPortfolioSnapshot &snapshot)
     {
      if(ArraySize(m_evaluation_history)!=FENX_PORTFOLIO_EVALUATION_HISTORY_LIMIT)
         return;
      m_evaluation_history[m_evaluation_history_head]=snapshot;
      m_evaluation_history_head=(m_evaluation_history_head+1)%
                                 FENX_PORTFOLIO_EVALUATION_HISTORY_LIMIT;
      if(m_evaluation_history_count<FENX_PORTFOLIO_EVALUATION_HISTORY_LIMIT)
         m_evaluation_history_count++;
     }

   void              AppendCandidateHistory(SPortfolioCandidateSnapshot &candidates[])
     {
      if(ArraySize(m_candidate_history)!=FENX_PORTFOLIO_CANDIDATE_HISTORY_LIMIT)
         return;
      for(int index=0;index<ArraySize(candidates);index++)
        {
         m_candidate_history[m_candidate_history_head]=candidates[index];
         m_candidate_history_head=(m_candidate_history_head+1)%
                                   FENX_PORTFOLIO_CANDIDATE_HISTORY_LIMIT;
         if(m_candidate_history_count<FENX_PORTFOLIO_CANDIDATE_HISTORY_LIMIT)
            m_candidate_history_count++;
        }
     }

public:
                     CGlobalPortfolioSnapshotStore(void)
     {
      Clear();
     }

   //--- Clears current observations and audit counters while retaining fixed,
   //--- bounded ring capacity. This is called only during initialization and
   //--- shutdown, never from a portfolio update cycle.
   void              Clear(void)
     {
      ResetGlobalPortfolioSnapshot(m_latest);
      ResetGlobalPortfolioSnapshot(m_pending);
      ArrayResize(m_latest_candidates,0);
      ArrayResize(m_pending_candidates,0);
      ArrayResize(m_evaluation_history,FENX_PORTFOLIO_EVALUATION_HISTORY_LIMIT);
      ArrayResize(m_candidate_history,FENX_PORTFOLIO_CANDIDATE_HISTORY_LIMIT);
      m_has_latest=false;
      m_has_pending=false;
      m_last_sequence=0;
      m_evaluation_count=0;
      m_candidate_evaluation_count=0;
      m_allocation_evaluation_count=0;
      m_max_candidate_count=0;
      m_max_allocated_count=0;
      m_max_total_allocation=0.0;
      m_total_ranking_runtime_microseconds=0;
      m_total_allocation_runtime_microseconds=0;
      m_evaluation_history_head=0;
      m_evaluation_history_count=0;
      m_candidate_history_head=0;
      m_candidate_history_count=0;
      m_sequence_gap_count=0;
      m_sequence_duplicate_count=0;
      m_future_source_count=0;
      m_wrong_context_linkage_count=0;
      m_duplicate_symbol_candidate_count=0;
      m_allocation_invariant_count=0;
     }

   long              ExpectedSequence(void)
     {
      return(m_last_sequence+1);
     }

   //--- Starts one ranked evaluation. Validation is fail-closed: future data,
   //--- duplicate active symbols, malformed identities, or sequence errors are
   //--- rejected before Capital Allocation can consume the pending result.
   bool              BeginRankedEvaluation(SGlobalPortfolioSnapshot &snapshot,
                                           SPortfolioCandidateSnapshot &candidates[])
     {
      const long expected=m_last_sequence+1;
      if(m_has_pending || snapshot.evaluation_sequence<=m_last_sequence)
        {
         m_sequence_duplicate_count++;
         return(false);
        }
      if(snapshot.evaluation_sequence!=expected)
        {
         m_sequence_gap_count++;
         return(false);
        }
      if(snapshot.evaluation_time<=0 || snapshot.context_count!=ArraySize(candidates))
        {
         m_wrong_context_linkage_count++;
         return(false);
        }

      int candidate_count=0;
      int duplicate_count=0;
      for(int left=0;left<ArraySize(candidates);left++)
        {
         if(!IsValidRuntimeContextId(candidates[left].context_id) ||
            candidates[left].evaluation_sequence!=snapshot.evaluation_sequence ||
            candidates[left].registration_order<0)
           {
            m_wrong_context_linkage_count++;
            return(false);
           }
         if(HasFutureSource(candidates[left],snapshot.evaluation_time))
           {
            m_future_source_count++;
            return(false);
           }
         if(!candidates[left].is_candidate)
            continue;
         candidate_count++;
         for(int right=left+1;right<ArraySize(candidates);right++)
            if(candidates[right].is_candidate &&
               candidates[left].context_id.symbol==candidates[right].context_id.symbol)
               duplicate_count++;
        }
      if(duplicate_count>0)
        {
         m_duplicate_symbol_candidate_count+=duplicate_count;
         return(false);
        }
      if(snapshot.candidate_count!=candidate_count ||
         snapshot.duplicate_symbol_candidate_count!=0)
        {
         m_wrong_context_linkage_count++;
         return(false);
        }
      if(!CopyCandidates(candidates,m_pending_candidates))
         return(false);
      m_pending=snapshot;
      m_has_pending=true;
      return(true);
     }

   bool              GetPendingEvaluation(SGlobalPortfolioSnapshot &snapshot,
                                          SPortfolioCandidateSnapshot &candidates[])
     {
      if(!m_has_pending)
         return(false);
      snapshot=m_pending;
      return(CopyCandidates(m_pending_candidates,candidates));
     }

   //--- Finalizes allocation for the same identities and sequence produced by
   //--- Pair Ranking. Allocation invariants are recomputed by the store rather
   //--- than trusted from the publisher.
   bool              CompleteAllocation(SGlobalPortfolioSnapshot &snapshot,
                                        SPortfolioCandidateSnapshot &candidates[])
     {
      if(!m_has_pending || snapshot.evaluation_sequence!=m_pending.evaluation_sequence ||
         ArraySize(candidates)!=ArraySize(m_pending_candidates))
        {
         m_wrong_context_linkage_count++;
         return(false);
        }

      int allocated_count=0;
      double total_allocation=0.0;
      for(int left=0;left<ArraySize(candidates);left++)
        {
         if(!SameIdentity(candidates[left],m_pending_candidates[left]))
           {
            m_wrong_context_linkage_count++;
            return(false);
           }
         if(HasFutureSource(candidates[left],snapshot.evaluation_time))
           {
            m_future_source_count++;
            return(false);
           }
         if(candidates[left].allocation_percent<0.0 ||
            candidates[left].allocation_percent>100.0)
           {
            m_allocation_invariant_count++;
            return(false);
           }
         if((!candidates[left].context_available ||
             !candidates[left].portfolio_eligible ||
             !candidates[left].market_eligible ||
             !candidates[left].is_candidate) &&
            candidates[left].allocation_percent>0.0001)
           {
            m_allocation_invariant_count++;
            return(false);
           }
         if(candidates[left].is_allocated)
           {
            allocated_count++;
            for(int right=left+1;right<ArraySize(candidates);right++)
               if(candidates[right].is_allocated &&
                  candidates[left].context_id.symbol==candidates[right].context_id.symbol)
                 {
                  m_duplicate_symbol_candidate_count++;
                  return(false);
                 }
           }
         total_allocation+=candidates[left].allocation_percent;
        }
      if(total_allocation>100.0+0.0001 ||
         snapshot.allocated_count!=allocated_count ||
         MathAbs(snapshot.total_allocation-total_allocation)>0.001)
        {
         m_allocation_invariant_count++;
         return(false);
        }

      snapshot.is_valid=(snapshot.ranking_valid && snapshot.allocation_valid);
      snapshot.updated_at=snapshot.evaluation_time;
      if(!CopyCandidates(candidates,m_latest_candidates))
         return(false);
      m_latest=snapshot;
      m_has_latest=true;
      m_last_sequence=snapshot.evaluation_sequence;
      m_evaluation_count++;
      if(snapshot.candidate_count>0)
         m_candidate_evaluation_count++;
      if(snapshot.allocated_count>0)
         m_allocation_evaluation_count++;
      if(snapshot.candidate_count>m_max_candidate_count)
         m_max_candidate_count=snapshot.candidate_count;
      if(snapshot.allocated_count>m_max_allocated_count)
         m_max_allocated_count=snapshot.allocated_count;
      if(snapshot.total_allocation>m_max_total_allocation)
         m_max_total_allocation=snapshot.total_allocation;
      m_total_ranking_runtime_microseconds+=snapshot.ranking_runtime_microseconds;
      m_total_allocation_runtime_microseconds+=snapshot.allocation_runtime_microseconds;
      AppendEvaluationHistory(snapshot);
      AppendCandidateHistory(candidates);
      m_has_pending=false;
      ArrayResize(m_pending_candidates,0);
      ResetGlobalPortfolioSnapshot(m_pending);
      return(true);
     }

   bool              GetLatest(SGlobalPortfolioSnapshot &snapshot,
                               SPortfolioCandidateSnapshot &candidates[])
     {
      if(!m_has_latest)
         return(false);
      snapshot=m_latest;
      return(CopyCandidates(m_latest_candidates,candidates));
     }

   long              EvaluationCount(void) { return(m_evaluation_count); }
   long              CandidateEvaluationCount(void) { return(m_candidate_evaluation_count); }
   long              AllocationEvaluationCount(void) { return(m_allocation_evaluation_count); }
   int               MaximumCandidateCount(void) { return(m_max_candidate_count); }
   int               MaximumAllocatedCount(void) { return(m_max_allocated_count); }
   double            MaximumTotalAllocation(void) { return(m_max_total_allocation); }
   long              TotalRankingRuntimeMicroseconds(void) { return(m_total_ranking_runtime_microseconds); }
   long              TotalAllocationRuntimeMicroseconds(void) { return(m_total_allocation_runtime_microseconds); }
   int               EvaluationHistoryCount(void) { return(m_evaluation_history_count); }
   int               CandidateHistoryCount(void) { return(m_candidate_history_count); }
   long              SequenceGapCount(void) { return(m_sequence_gap_count); }
   long              SequenceDuplicateCount(void) { return(m_sequence_duplicate_count); }
   long              FutureSourceCount(void) { return(m_future_source_count); }
   long              WrongContextLinkageCount(void) { return(m_wrong_context_linkage_count); }
   long              DuplicateSymbolCandidateCount(void) { return(m_duplicate_symbol_candidate_count); }
   long              AllocationInvariantCount(void) { return(m_allocation_invariant_count); }
  };

#endif // FENX_GLOBAL_PORTFOLIO_SNAPSHOT_STORE_MQH
