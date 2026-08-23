//+------------------------------------------------------------------+
//|                         Risk/GlobalRiskAggregateEngine.mqh      |
//+------------------------------------------------------------------+
#ifndef FENX_GLOBAL_RISK_AGGREGATE_ENGINE_MQH
#define FENX_GLOBAL_RISK_AGGREGATE_ENGINE_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"
#include "../Portfolio/GlobalPortfolioSnapshotStore.mqh"

#define FENX_GLOBAL_RISK_AGGREGATE_HISTORY_LIMIT 64

//--- Passive system-wide observation of the context-local decision/safety
//--- plane. It owns no trading permission and cannot request a state change.
struct SGlobalRiskAggregateSnapshot
  {
   long     evaluation_sequence;
   datetime evaluation_time;
   int      context_count;
   int      active_count;
   int      standby_count;
   int      risk_stopped_count;
   int      critical_context_count;
   int      invalid_context_count;
   int      portfolio_linkage_error_count;
   int      future_source_count;
   int      wrong_context_count;
   bool     is_valid;
   long     runtime_microseconds;
  };

void ResetGlobalRiskAggregateSnapshot(SGlobalRiskAggregateSnapshot &snapshot)
  {
   snapshot.evaluation_sequence=0;
   snapshot.evaluation_time=0;
   snapshot.context_count=0;
   snapshot.active_count=0;
   snapshot.standby_count=0;
   snapshot.risk_stopped_count=0;
   snapshot.critical_context_count=0;
   snapshot.invalid_context_count=0;
   snapshot.portfolio_linkage_error_count=0;
   snapshot.future_source_count=0;
   snapshot.wrong_context_count=0;
   snapshot.is_valid=false;
   snapshot.runtime_microseconds=0;
  }

//--- Bounded typed store for the non-authoritative aggregate foundation.
class CGlobalRiskAggregateStore
  {
private:
   SGlobalRiskAggregateSnapshot m_latest;
   SGlobalRiskAggregateSnapshot m_history[];
   int                          m_history_count;
   int                          m_history_next;
   long                         m_sequence_gap_count;
   long                         m_sequence_duplicate_count;

public:
                     CGlobalRiskAggregateStore(void)
     {
      Clear();
     }

   bool              Set(const SGlobalRiskAggregateSnapshot &snapshot)
     {
      if(snapshot.evaluation_sequence<=0 || snapshot.evaluation_time<=0)
         return(false);
      if(m_latest.evaluation_sequence>0)
        {
         if(snapshot.evaluation_sequence==m_latest.evaluation_sequence)
            m_sequence_duplicate_count++;
         else if(snapshot.evaluation_sequence!=m_latest.evaluation_sequence+1)
            m_sequence_gap_count++;
        }
      m_latest=snapshot;
      if(ArraySize(m_history)<FENX_GLOBAL_RISK_AGGREGATE_HISTORY_LIMIT)
        {
         const int index=ArraySize(m_history);
         if(ArrayResize(m_history,index+1)!=index+1)
            return(false);
         m_history[index]=snapshot;
         m_history_count=ArraySize(m_history);
         m_history_next=m_history_count%FENX_GLOBAL_RISK_AGGREGATE_HISTORY_LIMIT;
        }
      else
        {
         m_history[m_history_next]=snapshot;
         m_history_next=(m_history_next+1)%FENX_GLOBAL_RISK_AGGREGATE_HISTORY_LIMIT;
         m_history_count=FENX_GLOBAL_RISK_AGGREGATE_HISTORY_LIMIT;
        }
      return(true);
     }

   bool              GetLatest(SGlobalRiskAggregateSnapshot &snapshot)
     {
      if(m_latest.evaluation_sequence<=0)
         return(false);
      snapshot=m_latest;
      return(true);
     }

   int               HistoryCount(void) { return(m_history_count); }
   long              SequenceGapCount(void) { return(m_sequence_gap_count); }
   long              SequenceDuplicateCount(void) { return(m_sequence_duplicate_count); }

   void              Clear(void)
     {
      ResetGlobalRiskAggregateSnapshot(m_latest);
      ArrayFree(m_history);
      m_history_count=0;
      m_history_next=0;
      m_sequence_gap_count=0;
      m_sequence_duplicate_count=0;
     }
  };

//--- Observes all completed context-local decision/safety outputs after their
//--- six-engine pipelines. This engine never publishes a legacy key, never
//--- changes Global State, and never calls Entry/Exit/Execution.
class CGlobalRiskAggregateEngine : public CBaseEngine
  {
private:
   SPortfolioContextDefinition m_contexts[];
   CGlobalPortfolioSnapshotStore *m_portfolio_store;
   CGlobalRiskAggregateStore      *m_aggregate_store;
   long                           m_evaluation_sequence;

   bool ParseBoolean(const string text,bool &value)
     {
      if(text=="true" || text=="TRUE") { value=true; return(true); }
      if(text=="false" || text=="FALSE") { value=false; return(true); }
      return(false);
     }

   bool ReadBoolean(const string name_space,const SRuntimeContextId &id,
                    const string field,bool &value)
     {
      string text="";
      return(m_data_bus!=NULL &&
             m_data_bus.TryGetContextText(name_space,id,field,text) &&
             ParseBoolean(text,value));
     }

   bool ReadText(const string name_space,const SRuntimeContextId &id,
                 const string field,string &value)
     {
      return(m_data_bus!=NULL &&
             m_data_bus.TryGetContextText(name_space,id,field,value));
     }

   bool ReadTimestamp(const string name_space,const SRuntimeContextId &id,
                      const string field,datetime &value)
     {
      string text="";
      if(!ReadText(name_space,id,field,text))
         return(false);
      value=StringToTime(text);
      return(value>0);
     }

   bool FindPortfolioCandidate(SPortfolioCandidateSnapshot &candidates[],
                               const SRuntimeContextId &id,
                               SPortfolioCandidateSnapshot &candidate)
     {
      for(int index=0;index<ArraySize(candidates);index++)
         if(RuntimeContextEquals(candidates[index].context_id,id))
           {
            candidate=candidates[index];
            return(true);
           }
      return(false);
     }

public:
                     CGlobalRiskAggregateEngine(void)
     {
      SetName("GlobalRiskAggregateEngine");
      m_portfolio_store=NULL;
      m_aggregate_store=NULL;
      m_evaluation_sequence=0;
     }

   bool              Configure(CGlobalPortfolioSnapshotStore &portfolio_store,
                               CGlobalRiskAggregateStore &aggregate_store,
                               SPortfolioContextDefinition &contexts[])
     {
      if(m_initialized || ArraySize(contexts)<1)
         return(false);
      const int count=ArraySize(contexts);
      if(ArrayResize(m_contexts,count)!=count)
         return(false);
      for(int index=0;index<count;index++)
         m_contexts[index]=contexts[index];
      m_portfolio_store=GetPointer(portfolio_store);
      m_aggregate_store=GetPointer(aggregate_store);
      return(m_portfolio_store!=NULL && m_aggregate_store!=NULL);
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(m_portfolio_store==NULL || m_aggregate_store==NULL ||
         ArraySize(m_contexts)<1)
         return(false);
      m_aggregate_store.Clear();
      m_evaluation_sequence=0;
      return(CBaseEngine::Initialize(data_bus,parameters));
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;
      const ulong started=GetMicrosecondCount();
      SGlobalRiskAggregateSnapshot snapshot;
      ResetGlobalRiskAggregateSnapshot(snapshot);
      snapshot.evaluation_sequence=++m_evaluation_sequence;
      snapshot.evaluation_time=TimeCurrent();
      snapshot.context_count=ArraySize(m_contexts);

      SGlobalPortfolioSnapshot portfolio;
      SPortfolioCandidateSnapshot candidates[];
      const bool portfolio_available=m_portfolio_store.GetLatest(portfolio,candidates);
      for(int index=0;index<ArraySize(m_contexts);index++)
        {
         const SPortfolioContextDefinition definition=m_contexts[index];
         if(!definition.config.enabled || !definition.available)
            continue;
         snapshot.active_count++;

         bool style_valid=false;
         bool strategy_valid=false;
         bool standby_valid=false;
         bool risk_valid=false;
         bool confidence_valid=false;
         bool decision_valid=false;
         string standby_state="";
         string risk_state="";
         datetime style_time=0;
         datetime strategy_time=0;
         datetime standby_time=0;
         datetime risk_time=0;
         datetime confidence_time=0;
         datetime decision_time=0;
         const SRuntimeContextId id=definition.config.id;
         const bool complete=
            ReadBoolean(FENX_DATABUS_NAMESPACE_TRADING_STYLE,id,
                        FENX_DATABUS_FIELD_TRADING_STYLE_IS_VALID,style_valid) &&
            ReadTimestamp(FENX_DATABUS_NAMESPACE_TRADING_STYLE,id,
                          FENX_DATABUS_FIELD_TRADING_STYLE_UPDATED_AT,style_time) &&
            ReadBoolean(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,id,
                        FENX_DATABUS_FIELD_STRATEGY_SELECTION_IS_VALID,strategy_valid) &&
            ReadTimestamp(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,id,
                          FENX_DATABUS_FIELD_STRATEGY_SELECTION_UPDATED_AT,strategy_time) &&
            ReadBoolean(FENX_DATABUS_NAMESPACE_STANDBY,id,
                        FENX_DATABUS_FIELD_STANDBY_DATA_VALID,standby_valid) &&
            ReadText(FENX_DATABUS_NAMESPACE_STANDBY,id,
                     FENX_DATABUS_FIELD_STANDBY_STATE,standby_state) &&
            ReadTimestamp(FENX_DATABUS_NAMESPACE_STANDBY,id,
                          FENX_DATABUS_FIELD_STANDBY_UPDATED_AT,standby_time) &&
            ReadBoolean(FENX_DATABUS_NAMESPACE_RISK,id,
                        FENX_DATABUS_FIELD_RISK_DATA_VALID,risk_valid) &&
            ReadText(FENX_DATABUS_NAMESPACE_RISK,id,
                     FENX_DATABUS_FIELD_SYMBOL_RISK_STATE,risk_state) &&
            ReadTimestamp(FENX_DATABUS_NAMESPACE_RISK,id,
                          FENX_DATABUS_FIELD_RISK_UPDATED_AT,risk_time) &&
            ReadBoolean(FENX_DATABUS_NAMESPACE_COMMON_CONFIDENCE,id,
                        FENX_DATABUS_FIELD_COMMON_CONFIDENCE_VALID,confidence_valid) &&
            ReadTimestamp(FENX_DATABUS_NAMESPACE_COMMON_CONFIDENCE,id,
                          FENX_DATABUS_FIELD_COMMON_CONFIDENCE_UPDATED_AT,confidence_time) &&
            ReadBoolean(FENX_DATABUS_NAMESPACE_COMMON_DECISION,id,
                        FENX_DATABUS_FIELD_COMMON_DECISION_VALID,decision_valid) &&
            ReadTimestamp(FENX_DATABUS_NAMESPACE_COMMON_DECISION,id,
                          FENX_DATABUS_FIELD_COMMON_DECISION_UPDATED_AT,decision_time);

         if(!complete || !style_valid || !strategy_valid || !standby_valid ||
            !risk_valid || !confidence_valid || !decision_valid)
            snapshot.invalid_context_count++;
         if(standby_state!="NORMAL")
            snapshot.standby_count++;
         if(risk_state=="RISK_STOP_REQUIRED")
            snapshot.risk_stopped_count++;
         if(!complete || !risk_valid || risk_state=="RISK_STOP_REQUIRED")
            snapshot.critical_context_count++;

         datetime times[6]={style_time,strategy_time,standby_time,risk_time,
                            confidence_time,decision_time};
         for(int time_index=0;time_index<6;time_index++)
            if(times[time_index]>snapshot.evaluation_time)
               snapshot.future_source_count++;

         SPortfolioCandidateSnapshot candidate;
         if(!portfolio_available || !FindPortfolioCandidate(candidates,id,candidate))
            snapshot.portfolio_linkage_error_count++;
         else
           {
            string allocation_text="";
            if(!ReadText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,id,
                         FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_PERCENT,
                         allocation_text) ||
               MathAbs(StringToDouble(allocation_text)-
                       candidate.allocation_percent)>0.011)
               snapshot.portfolio_linkage_error_count++;
           }
        }

      snapshot.wrong_context_count=(int)m_data_bus.ContextViewWrongSymbolCount();
      // Aggregate validity describes the integrity of this observation, not
      // whether every child currently permits trading. INVALID/critical child
      // states are legitimate fail-closed outcomes and remain visible through
      // their dedicated counters without invalidating the aggregate record.
      snapshot.is_valid=(snapshot.active_count>0 &&
                         snapshot.portfolio_linkage_error_count==0 &&
                         snapshot.future_source_count==0 &&
                         snapshot.wrong_context_count==0);
      snapshot.runtime_microseconds=(long)(GetMicrosecondCount()-started);
      if(!m_aggregate_store.Set(snapshot))
         CLogger::Error("GlobalRiskAggregateEngine could not store its snapshot.");
     }

   virtual void       Shutdown(void)
     {
      ArrayFree(m_contexts);
      m_portfolio_store=NULL;
      m_aggregate_store=NULL;
      m_evaluation_sequence=0;
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_GLOBAL_RISK_AGGREGATE_ENGINE_MQH
