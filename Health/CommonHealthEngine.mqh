//+------------------------------------------------------------------+
//|                               Health/CommonHealthEngine.mqh     |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_HEALTH_ENGINE_MQH
#define FENX_COMMON_HEALTH_ENGINE_MQH

#include "../Engine/BaseEngine.mqh"
#include "../Core/DataBusCapacityPlan.mqh"
#include "CommonHealthEngineAdapter.mqh"

//--- Pipeline-tail passive observer for the thirteen adopted Common Engines
//--- and shared infrastructure. It publishes only typed Health diagnostics.
class CCommonHealthEngine : public CBaseEngine
  {
private:
   CCommonSnapshotStore       *m_snapshot_store;
   CCommonSnapshotStore       *m_analysis_store;
   CCommonSnapshotStore       *m_decision_store;
   CCommonSnapshotStore       *m_execution_store;
   CCommonHealthEngineAdapter  m_adapter;
   SRuntimeContextId           m_context_id;
   bool                        m_context_configured;
   ENUM_TIMEFRAMES             m_timeframe;
   string                      m_symbols[];
   bool                        m_collection_error_logged[];
   bool                        m_preflight_passed;

   bool              LoadSymbols(CParameterManager &parameters)
     {
      if(m_context_configured)
        {
         if(ArrayResize(m_symbols,1)!=1 ||
            ArrayResize(m_collection_error_logged,1)!=1 ||
            !m_adapter.RegisterSymbol(m_context_id.symbol))
            return(false);
         m_symbols[0]=m_context_id.symbol;
         m_collection_error_logged[0]=false;
         return(true);
        }
      const int symbol_count=parameters.MarketSelectionSymbolCount();
      if(symbol_count<1 || ArrayResize(m_symbols,symbol_count)!=symbol_count ||
         ArrayResize(m_collection_error_logged,symbol_count)!=symbol_count)
         return(false);
      for(int index=0;index<symbol_count;index++)
        {
         if(!parameters.TryGetMarketSelectionSymbol(index,m_symbols[index]) ||
            !m_adapter.RegisterSymbol(m_symbols[index]))
            return(false);
         m_collection_error_logged[index]=false;
        }
      return(true);
     }

   int               AvailableStatusCount(const SCommonHealthMeasurement &m)
     {
      return((m.environment.available ? 1 : 0)+
             (m.confidence.available ? 1 : 0)+
             (m.decision_score.available ? 1 : 0)+
             (m.volatility.available ? 1 : 0)+
             (m.range.available ? 1 : 0)+
             (m.trend.available ? 1 : 0)+
             (m.market_state.available ? 1 : 0)+
             (m.standby.available ? 1 : 0)+
             (m.risk.available ? 1 : 0)+
             (m.entry.available ? 1 : 0)+
             (m.exit_status.available ? 1 : 0)+
             (m.execution.available ? 1 : 0)+
             (m.recovery.available ? 1 : 0));
     }

   //--- Assembles one context-local measurement from the already separated
   //--- analysis, decision/safety, execution, and recovery stores. Field
   //--- selection mirrors the original single-store measurement and leaves
   //--- CommonHealthEngineAdapter classification completely unchanged.
   bool              CollectContextMeasurement(const string symbol,
                                               SCommonHealthMeasurement &measurement)
     {
      SCommonHealthMeasurement analysis;
      SCommonHealthMeasurement decision;
      SCommonHealthMeasurement execution;
      SCommonHealthMeasurement recovery;
      if(m_analysis_store==NULL || m_decision_store==NULL ||
         m_execution_store==NULL || m_snapshot_store==NULL ||
         !m_analysis_store.CollectHealthMeasurement(symbol,m_timeframe,analysis) ||
         !m_decision_store.CollectHealthMeasurement(symbol,m_timeframe,decision) ||
         !m_execution_store.CollectHealthMeasurement(symbol,m_timeframe,execution) ||
         !m_snapshot_store.CollectHealthMeasurement(symbol,m_timeframe,recovery))
         return(false);

      measurement=execution;
      measurement.environment=analysis.environment;
      measurement.volatility=analysis.volatility;
      measurement.range=analysis.range;
      measurement.trend=analysis.trend;
      measurement.market_state=analysis.market_state;
      measurement.confidence=decision.confidence;
      measurement.decision_score=decision.decision_score;
      measurement.standby=decision.standby;
      measurement.risk=decision.risk;
      measurement.recovery=recovery.recovery;
      measurement.recovery_audit_sequence=recovery.recovery_audit_sequence;
      measurement.recovery_sequence=recovery.recovery_sequence;
      measurement.recovery_active=recovery.recovery_active;
      measurement.recovery_completed=recovery.recovery_completed;
      measurement.recovery_failed=recovery.recovery_failed;
      measurement.recovery_escalated=recovery.recovery_escalated;
      measurement.recovery_entry_resume_allowed=
         recovery.recovery_entry_resume_allowed;
      measurement.recovery_entry_snapshot_available=
         recovery.recovery_entry_snapshot_available;
      measurement.recovery_entry_sequence=recovery.recovery_entry_sequence;
      measurement.recovery_execution_gate_allowed=
         recovery.recovery_execution_gate_allowed;
      measurement.recovery_data_leak_safe=recovery.recovery_data_leak_safe;
      measurement.recovery_history_count=recovery.recovery_history_count;
      measurement.health_history_count=recovery.health_history_count;
      measurement.snapshot_store_available=
         (analysis.snapshot_store_available && decision.snapshot_store_available &&
          execution.snapshot_store_available && recovery.snapshot_store_available);
      measurement.snapshot_identity_consistent=
         (analysis.snapshot_identity_consistent &&
          decision.snapshot_identity_consistent &&
          execution.snapshot_identity_consistent &&
          recovery.snapshot_identity_consistent);
      measurement.snapshot_history_bounded=
         (analysis.snapshot_history_bounded && decision.snapshot_history_bounded &&
          execution.snapshot_history_bounded && recovery.snapshot_history_bounded);
      measurement.snapshot_current_count=AvailableStatusCount(measurement);
      return(true);
     }

public:
                     CCommonHealthEngine(void)
     {
      SetName("CommonHealthEngine");
      m_snapshot_store=NULL;
      m_analysis_store=NULL;
      m_decision_store=NULL;
      m_execution_store=NULL;
      m_context_id.symbol="";
      m_context_id.timeframe=PERIOD_CURRENT;
      m_context_configured=false;
      m_timeframe=PERIOD_CURRENT;
      m_preflight_passed=false;
     }

   //--- Injects the non-owning typed store before EngineManager initialization.
   bool              SetSnapshotStore(CCommonSnapshotStore &snapshot_store)
     {
      if(m_initialized)
         return(false);
      m_snapshot_store=GetPointer(snapshot_store);
      m_analysis_store=m_snapshot_store;
      m_decision_store=m_snapshot_store;
      m_execution_store=m_snapshot_store;
      return(m_snapshot_store!=NULL);
     }

   //--- Selects exactly one Symbol+Timeframe identity for a context-owned
   //--- observer. Legacy Primary callers retain their original symbol list.
   bool              SetRuntimeContext(const SRuntimeContextId &context_id)
     {
      if(m_initialized || !IsValidRuntimeContextId(context_id))
         return(false);
      m_context_id=context_id;
      m_context_configured=true;
      m_timeframe=context_id.timeframe;
      return(true);
     }

   //--- The output store is also the context-local Recovery source. Health
   //--- remains a passive sink and never writes to analysis/decision/execution.
   bool              SetContextStores(CCommonSnapshotStore &analysis_store,
                                      CCommonSnapshotStore &decision_store,
                                      CCommonSnapshotStore &execution_store,
                                      CCommonSnapshotStore &output_store)
     {
      if(m_initialized)
         return(false);
      m_analysis_store=GetPointer(analysis_store);
      m_decision_store=GetPointer(decision_store);
      m_execution_store=GetPointer(execution_store);
      m_snapshot_store=GetPointer(output_store);
      return(m_analysis_store!=NULL && m_decision_store!=NULL &&
             m_execution_store!=NULL && m_snapshot_store!=NULL);
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(m_snapshot_store==NULL || m_analysis_store==NULL ||
         m_decision_store==NULL || m_execution_store==NULL)
        {
         CLogger::Error("CommonHealthEngine requires CommonSnapshotStore before initialization.");
         return(false);
        }
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      CDataBusCapacityPlan capacity_plan;
      m_preflight_passed=(capacity_plan.Build(
         parameters.MarketSelectionSymbolCount(),
         FENX_COMMON_ENVIRONMENT_KEY_COUNT,
         FENX_COMMON_CONFIDENCE_GLOBAL_KEY_COUNT+
            FENX_COMMON_DECISION_GLOBAL_KEY_COUNT,
         FENX_COMMON_CONFIDENCE_PER_SYMBOL_KEY_COUNT+
            FENX_COMMON_DECISION_PER_SYMBOL_KEY_COUNT) &&
         capacity_plan.TotalRequiredEntries()<=data_bus.Capacity());
      if(!m_context_configured)
         m_timeframe=_Period;
      if(!m_adapter.Configure(*m_snapshot_store,m_timeframe) ||
         !LoadSymbols(parameters))
        {
         CLogger::Error("CommonHealthEngine could not load its passive observation contract.");
         CBaseEngine::Shutdown();
         return(false);
        }
      CLogger::Info(StringFormat(
         "CommonHealthEngine configured for %d symbol(s); DataBus keys added=0; PreflightObserved=%s.",
         ArraySize(m_symbols),(m_preflight_passed ? "true" : "false")));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized || m_snapshot_store==NULL || m_data_bus==NULL ||
         m_state_manager==NULL)
         return;
      const datetime evaluation_time=TimeCurrent();
      const string state_name=m_state_manager.StateName(
         m_state_manager.GetState());
      for(int index=0;index<ArraySize(m_symbols);index++)
        {
         SCommonHealthMeasurement measurement;
         const bool collected=(m_context_configured ?
            CollectContextMeasurement(m_symbols[index],measurement) :
            m_snapshot_store.CollectHealthMeasurement(
               m_symbols[index],m_timeframe,measurement));
         if(!collected)
           {
            if(!m_collection_error_logged[index])
              {
               CLogger::Error(StringFormat(
                  "CommonHealthEngine could not collect typed sources for %s.",
                  m_symbols[index]));
               m_collection_error_logged[index]=true;
              }
            continue;
           }
         m_collection_error_logged[index]=false;
         measurement.databus_usage=m_data_bus.CurrentSize();
         measurement.databus_capacity=m_data_bus.Capacity();
         measurement.databus_remaining=m_data_bus.RemainingCapacity();
         measurement.databus_overflow_detected=
            (measurement.databus_usage>measurement.databus_capacity);
         measurement.databus_preflight_passed=m_preflight_passed;
         measurement.state_manager_state=state_name;
         measurement.state_manager_state_known=(state_name!="UNKNOWN");
         // RuntimeErrorCount is limited to errors directly observed by this
         // passive component; full terminal runtime reconciliation is external.
         // StateManager exposes current state but not its rejected-attempt count.
         measurement.runtime_error_count=0;
         measurement.runtime_error_count_available=false;
         measurement.state_transition_error_count=0;
         measurement.state_transition_error_count_available=false;

         SCommonHealthSnapshot snapshot;
         bool emitted=false;
         if(!m_adapter.Observe(measurement,evaluation_time,snapshot,emitted))
           {
            if(!m_collection_error_logged[index])
              {
               CLogger::Error(StringFormat(
                  "CommonHealthEngine could not classify %s without altering its sources.",
                  m_symbols[index]));
               m_collection_error_logged[index]=true;
              }
           }
        }
     }

   virtual void       Shutdown(void)
     {
      if(m_initialized)
         m_adapter.LogSummary(m_context_configured ?
            RuntimeContextToString(m_context_id) : "");
      ArrayFree(m_symbols);
      ArrayFree(m_collection_error_logged);
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_COMMON_HEALTH_ENGINE_MQH
