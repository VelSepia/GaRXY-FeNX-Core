//+------------------------------------------------------------------+
//|                    Health/GlobalHealthAggregateEngine.mqh       |
//+------------------------------------------------------------------+
#ifndef FENX_GLOBAL_HEALTH_AGGREGATE_ENGINE_MQH
#define FENX_GLOBAL_HEALTH_AGGREGATE_ENGINE_MQH

#include "../Engine/BaseEngine.mqh"
#include "../Portfolio/GlobalPortfolioSnapshotStore.mqh"
#include "../Execution/ExecutionIntegritySnapshotStore.mqh"
#include "../Common/CommonSnapshotStore.mqh"

#define FENX_GLOBAL_HEALTH_AGGREGATE_HISTORY_LIMIT 64

//--- System-wide diagnostic view of context-local Recovery/Health and the
//--- adopted Task030 execution infrastructure. It deliberately contains no
//--- field that can permit/block trading or request a state transition.
struct SGlobalHealthAggregateSnapshot
  {
   long     evaluation_sequence;
   datetime evaluation_time;
   int      context_count;
   int      available_context_count;
   int      required_context_count;
   int      optional_context_count;
   int      healthy_context_count;
   int      degraded_context_count;
   int      critical_context_count;
   int      required_unavailable_count;
   int      optional_unavailable_count;
   int      expected_invalid_count;
   int      expected_stale_count;
   int      recovery_cross_context_count;
   int      entry_resume_wrong_context_count;
   int      health_wrong_context_count;
   int      execution_position_router_linkage_error_count;
   long     data_leak_count;
   long     trade_leak_count;
   long     runtime_error_count;
   bool     is_valid;
   long     runtime_microseconds;
  };

void ResetGlobalHealthAggregateSnapshot(SGlobalHealthAggregateSnapshot &snapshot)
  {
   snapshot.evaluation_sequence=0;
   snapshot.evaluation_time=0;
   snapshot.context_count=0;
   snapshot.available_context_count=0;
   snapshot.required_context_count=0;
   snapshot.optional_context_count=0;
   snapshot.healthy_context_count=0;
   snapshot.degraded_context_count=0;
   snapshot.critical_context_count=0;
   snapshot.required_unavailable_count=0;
   snapshot.optional_unavailable_count=0;
   snapshot.expected_invalid_count=0;
   snapshot.expected_stale_count=0;
   snapshot.recovery_cross_context_count=0;
   snapshot.entry_resume_wrong_context_count=0;
   snapshot.health_wrong_context_count=0;
   snapshot.execution_position_router_linkage_error_count=0;
   snapshot.data_leak_count=0;
   snapshot.trade_leak_count=0;
   snapshot.runtime_error_count=0;
   snapshot.is_valid=false;
   snapshot.runtime_microseconds=0;
  }

//--- Bounded audit store for the passive global diagnostic.
class CGlobalHealthAggregateStore
  {
private:
   SGlobalHealthAggregateSnapshot m_latest;
   SGlobalHealthAggregateSnapshot m_history[];
   int                            m_history_next;
   long                           m_sequence_gap_count;
   long                           m_sequence_duplicate_count;

public:
                     CGlobalHealthAggregateStore(void)
     {
      Clear();
     }

   bool              Set(const SGlobalHealthAggregateSnapshot &snapshot)
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
      if(ArraySize(m_history)<FENX_GLOBAL_HEALTH_AGGREGATE_HISTORY_LIMIT)
        {
         const int index=ArraySize(m_history);
         if(ArrayResize(m_history,index+1)!=(index+1))
            return(false);
         m_history[index]=snapshot;
         m_history_next=ArraySize(m_history)%FENX_GLOBAL_HEALTH_AGGREGATE_HISTORY_LIMIT;
        }
      else
        {
         m_history[m_history_next]=snapshot;
         m_history_next=(m_history_next+1)%FENX_GLOBAL_HEALTH_AGGREGATE_HISTORY_LIMIT;
        }
      return(true);
     }

   bool              GetLatest(SGlobalHealthAggregateSnapshot &snapshot)
     {
      if(m_latest.evaluation_sequence<=0)
         return(false);
      snapshot=m_latest;
      return(true);
     }

   int               HistoryCount(void) { return(ArraySize(m_history)); }
   long              SequenceGapCount(void) { return(m_sequence_gap_count); }
   long              SequenceDuplicateCount(void) { return(m_sequence_duplicate_count); }

   void              Clear(void)
     {
      ResetGlobalHealthAggregateSnapshot(m_latest);
      ArrayFree(m_history);
      m_history_next=0;
      m_sequence_gap_count=0;
      m_sequence_duplicate_count=0;
     }
  };

//--- Runs after every context Health observer. Required/optional availability
//--- and integrity failures remain diagnostic; this engine has no authority
//--- over Entry, Exit, Risk, Recovery, Execution, or either StateManager.
class CGlobalHealthAggregateEngine : public CBaseEngine
  {
private:
   SPortfolioContextDefinition    m_contexts[];
   CCommonSnapshotStore          *m_primary_store;
   CCommonSnapshotStore          *m_context_store;
   CExecutionIntegritySnapshotStore *m_integrity_store;
   CGlobalHealthAggregateStore   *m_aggregate_store;
   long                           m_evaluation_sequence;

public:
                     CGlobalHealthAggregateEngine(void)
     {
      SetName("GlobalHealthAggregateEngine");
      m_primary_store=NULL;
      m_context_store=NULL;
      m_integrity_store=NULL;
      m_aggregate_store=NULL;
      m_evaluation_sequence=0;
     }

   bool              Configure(CCommonSnapshotStore &primary_store,
                               CCommonSnapshotStore &context_store,
                               CExecutionIntegritySnapshotStore &integrity_store,
                               CGlobalHealthAggregateStore &aggregate_store,
                               SPortfolioContextDefinition &contexts[])
     {
      if(m_initialized || ArraySize(contexts)<1)
         return(false);
      const int count=ArraySize(contexts);
      if(ArrayResize(m_contexts,count)!=count)
         return(false);
      for(int index=0;index<count;index++)
         m_contexts[index]=contexts[index];
      m_primary_store=GetPointer(primary_store);
      m_context_store=GetPointer(context_store);
      m_integrity_store=GetPointer(integrity_store);
      m_aggregate_store=GetPointer(aggregate_store);
      return(m_primary_store!=NULL && m_context_store!=NULL &&
             m_integrity_store!=NULL && m_aggregate_store!=NULL);
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(m_primary_store==NULL || m_context_store==NULL ||
         m_integrity_store==NULL || m_aggregate_store==NULL ||
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
      SGlobalHealthAggregateSnapshot aggregate;
      ResetGlobalHealthAggregateSnapshot(aggregate);
      aggregate.evaluation_sequence=++m_evaluation_sequence;
      aggregate.evaluation_time=TimeCurrent();

      for(int index=0;index<ArraySize(m_contexts);index++)
        {
         const SPortfolioContextDefinition definition=m_contexts[index];
         if(!definition.config.enabled)
            continue;
         aggregate.context_count++;
         if(definition.config.required)
            aggregate.required_context_count++;
         else
            aggregate.optional_context_count++;
         if(!definition.available)
           {
            if(definition.config.required)
               aggregate.required_unavailable_count++;
            else
               aggregate.optional_unavailable_count++;
            continue;
           }
         aggregate.available_context_count++;

         CCommonSnapshotStore *store=(definition.config.role==
            FENX_CONTEXT_ROLE_PRIMARY_TRADING ? m_primary_store : m_context_store);
         SCommonHealthSnapshot health;
         SCommonRecoverySnapshot recovery;
         const SRuntimeContextId id=definition.config.id;
         const bool health_available=(store!=NULL &&
            store.GetHealthSnapshot(id.symbol,id.timeframe,health));
         const bool recovery_available=(store!=NULL &&
            store.GetRecoverySnapshot(id.symbol,id.timeframe,recovery));
         if(!health_available)
           {
            if(definition.config.required)
               aggregate.required_unavailable_count++;
            else
               aggregate.optional_unavailable_count++;
           }
         else
           {
            if(!RuntimeContextEquals(health.runtime_context_id,id) ||
               health.symbol!=id.symbol ||
               health.timeframe!=EnumToString(id.timeframe))
               aggregate.health_wrong_context_count++;
            if(health.is_healthy) aggregate.healthy_context_count++;
            if(health.is_degraded) aggregate.degraded_context_count++;
            if(health.is_critical) aggregate.critical_context_count++;
            aggregate.expected_invalid_count+=health.expected_invalid_count;
            aggregate.expected_stale_count+=health.expected_stale_count;
            if(health.data_leak_detected || !health.data_leak_safe)
               aggregate.data_leak_count++;
           }
         if(!recovery_available)
            aggregate.recovery_cross_context_count++;
         else
           {
            if(!RuntimeContextEquals(recovery.runtime_context_id,id) ||
               recovery.symbol!=id.symbol ||
               recovery.timeframe!=EnumToString(id.timeframe))
               aggregate.recovery_cross_context_count++;
            if(recovery.entry_resume_allowed &&
               (!recovery.entry_snapshot_available ||
                !RuntimeContextEquals(recovery.entry_context_id,id)))
               aggregate.entry_resume_wrong_context_count++;
            if(!recovery.data_leak_safe)
               aggregate.data_leak_count++;
           }
        }

      SExecutionIntegritySnapshot integrity;
      ResetExecutionIntegritySnapshot(integrity);
      if(!m_integrity_store.GetLatest(integrity) || !integrity.is_valid ||
         integrity.route_count!=integrity.expected_route_count)
         aggregate.execution_position_router_linkage_error_count++;
      else
        {
         aggregate.execution_position_router_linkage_error_count=(int)(
            integrity.wrong_dispatch_count+integrity.wrong_owner_count+
            integrity.duplicate_lifecycle_count+integrity.ownership_conflict_count+
            integrity.cross_symbol_order_count+integrity.wrong_context_close_count+
            integrity.wrong_transaction_route_count);
         aggregate.trade_leak_count=integrity.trade_leak_count;
         aggregate.runtime_error_count=integrity.runtime_error_count;
        }

      aggregate.is_valid=(aggregate.context_count>0 &&
         aggregate.required_unavailable_count==0 &&
         aggregate.recovery_cross_context_count==0 &&
         aggregate.entry_resume_wrong_context_count==0 &&
         aggregate.health_wrong_context_count==0 &&
         aggregate.execution_position_router_linkage_error_count==0 &&
         aggregate.data_leak_count==0 && aggregate.trade_leak_count==0 &&
         aggregate.runtime_error_count==0);
      aggregate.runtime_microseconds=(long)(GetMicrosecondCount()-started);
      if(!m_aggregate_store.Set(aggregate))
         CLogger::Error("GlobalHealthAggregateEngine could not store its snapshot.");
     }

   virtual void       Shutdown(void)
     {
      ArrayFree(m_contexts);
      m_primary_store=NULL;
      m_context_store=NULL;
      m_integrity_store=NULL;
      m_aggregate_store=NULL;
      m_evaluation_sequence=0;
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_GLOBAL_HEALTH_AGGREGATE_ENGINE_MQH
