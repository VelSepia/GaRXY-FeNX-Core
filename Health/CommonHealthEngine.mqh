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
   CCommonHealthEngineAdapter  m_adapter;
   string                      m_symbols[];
   bool                        m_collection_error_logged[];
   bool                        m_preflight_passed;

   bool              LoadSymbols(CParameterManager &parameters)
     {
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

public:
                     CCommonHealthEngine(void)
     {
      SetName("CommonHealthEngine");
      m_snapshot_store=NULL;
      m_preflight_passed=false;
     }

   //--- Injects the non-owning typed store before EngineManager initialization.
   bool              SetSnapshotStore(CCommonSnapshotStore &snapshot_store)
     {
      if(m_initialized)
         return(false);
      m_snapshot_store=GetPointer(snapshot_store);
      return(m_snapshot_store!=NULL);
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(m_snapshot_store==NULL)
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
      if(!m_adapter.Configure(*m_snapshot_store,_Period) ||
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
         if(!m_snapshot_store.CollectHealthMeasurement(
            m_symbols[index],_Period,measurement))
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
         m_adapter.LogSummary();
      ArrayFree(m_symbols);
      ArrayFree(m_collection_error_logged);
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_COMMON_HEALTH_ENGINE_MQH
