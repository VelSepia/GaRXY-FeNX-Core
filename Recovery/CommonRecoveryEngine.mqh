//+------------------------------------------------------------------+
//|                         Recovery/CommonRecoveryEngine.mqh       |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_RECOVERY_ENGINE_MQH
#define FENX_COMMON_RECOVERY_ENGINE_MQH

#include "../Engine/BaseEngine.mqh"
#include "CommonRecoveryEngineAdapter.mqh"

//--- Tick-level passive observer registered after the existing ExecutionEngine.
//--- It reads typed results already produced by Standby/Risk/Entry and observes
//--- StateManager; it writes only the typed Common Recovery store and telemetry.
class CCommonRecoveryEngine : public CBaseEngine
  {
private:
   CCommonSnapshotStore          *m_snapshot_store;
   CCommonSnapshotStore          *m_standby_risk_store;
   CCommonSnapshotStore          *m_entry_store;
   CCommonRecoveryEngineAdapter   m_adapter;
   SRuntimeContextId              m_context_id;
   bool                           m_context_configured;
   ENUM_TIMEFRAMES                m_timeframe;
   string                         m_symbols[];
   bool                           m_source_warning_logged[];

   bool              LoadSymbols(CParameterManager &parameters)
     {
      if(m_context_configured)
        {
         if(ArrayResize(m_symbols,1)!=1 ||
            ArrayResize(m_source_warning_logged,1)!=1 ||
            !m_adapter.RegisterSymbol(m_context_id.symbol))
            return(false);
         m_symbols[0]=m_context_id.symbol;
         m_source_warning_logged[0]=false;
         return(true);
        }
      const int symbol_count=parameters.MarketSelectionSymbolCount();
      if(symbol_count<1 ||
         ArrayResize(m_symbols,symbol_count)!=symbol_count ||
         ArrayResize(m_source_warning_logged,symbol_count)!=symbol_count)
         return(false);
      for(int index=0;index<symbol_count;index++)
        {
         if(!parameters.TryGetMarketSelectionSymbol(index,m_symbols[index]) ||
            !m_adapter.RegisterSymbol(m_symbols[index]))
            return(false);
         m_source_warning_logged[index]=false;
        }
      return(true);
     }

public:
                     CCommonRecoveryEngine(void)
     {
      SetName("CommonRecoveryEngine");
      m_snapshot_store=NULL;
      m_standby_risk_store=NULL;
      m_entry_store=NULL;
      m_context_id.symbol="";
      m_context_id.timeframe=PERIOD_CURRENT;
      m_context_configured=false;
      m_timeframe=PERIOD_CURRENT;
     }

   //--- Injects the existing non-owning typed store before initialization.
   bool              SetSnapshotStore(CCommonSnapshotStore &snapshot_store)
     {
      if(m_initialized)
         return(false);
      m_snapshot_store=GetPointer(snapshot_store);
      m_standby_risk_store=m_snapshot_store;
      m_entry_store=m_snapshot_store;
      return(m_snapshot_store!=NULL);
     }

   //--- Binds one explicit runtime identity. Legacy callers omit this method
   //--- and retain the unchanged configured-symbol observer behavior.
   bool              SetRuntimeContext(const SRuntimeContextId &context_id)
     {
      if(m_initialized || !IsValidRuntimeContextId(context_id))
         return(false);
      m_context_id=context_id;
      m_context_configured=true;
      m_timeframe=context_id.timeframe;
      return(true);
     }

   //--- Context Recovery reads Standby/Risk and Entry from their existing
   //--- context-local typed stores, then writes only its own output store.
   bool              SetContextStores(CCommonSnapshotStore &standby_risk_store,
                                      CCommonSnapshotStore &entry_store,
                                      CCommonSnapshotStore &output_store)
     {
      if(m_initialized)
         return(false);
      m_standby_risk_store=GetPointer(standby_risk_store);
      m_entry_store=GetPointer(entry_store);
      m_snapshot_store=GetPointer(output_store);
      return(m_standby_risk_store!=NULL && m_entry_store!=NULL &&
             m_snapshot_store!=NULL);
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(m_snapshot_store==NULL || m_standby_risk_store==NULL ||
         m_entry_store==NULL)
        {
         CLogger::Error("CommonRecoveryEngine requires CommonSnapshotStore before initialization.");
         return(false);
        }
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);
      if(!m_context_configured)
         m_timeframe=_Period;
      if(!m_adapter.Configure(m_snapshot_store,m_timeframe) ||
         !LoadSymbols(parameters))
        {
         CLogger::Error("CommonRecoveryEngine could not load its passive source contract.");
         CBaseEngine::Shutdown();
         return(false);
        }
      CLogger::Info(StringFormat(
         "CommonRecoveryEngine configured for %d symbol(s); DataBus keys added=0.",
         ArraySize(m_symbols)));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized || m_snapshot_store==NULL || m_state_manager==NULL)
         return;
      const datetime evaluation_time=TimeCurrent();
      const string core_state=m_state_manager.StateName(m_state_manager.GetState());
      for(int index=0;index<ArraySize(m_symbols);index++)
        {
         SStandbySnapshot standby;
         SRiskSnapshot risk;
         if(!m_standby_risk_store.GetStandbySnapshot(
               m_symbols[index],m_timeframe,standby) ||
            !m_standby_risk_store.GetRiskSnapshot(
               m_symbols[index],m_timeframe,risk))
           {
            if(!m_source_warning_logged[index])
              {
               CLogger::Warning(StringFormat(
                  "CommonRecoveryEngine is awaiting typed Standby/Risk sources for %s.",
                  m_symbols[index]));
               m_source_warning_logged[index]=true;
              }
            continue;
           }
         m_source_warning_logged[index]=false;

         SEntrySnapshot entry;
         const bool entry_available=m_entry_store.GetEntrySnapshot(
            m_symbols[index],m_timeframe,entry);
         SCommonRecoverySnapshot snapshot;
         bool emitted=false;
         if(!m_adapter.Observe(standby,risk,entry_available,entry,core_state,
                               evaluation_time,snapshot,emitted))
            CLogger::Error(StringFormat(
               "CommonRecoveryEngine could not observe %s without altering its sources.",
               m_symbols[index]));
        }
     }

   virtual void       Shutdown(void)
     {
      if(m_initialized)
         m_adapter.LogSummary(m_context_configured ?
            RuntimeContextToString(m_context_id) : "");
      ArrayFree(m_symbols);
      ArrayFree(m_source_warning_logged);
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_COMMON_RECOVERY_ENGINE_MQH
