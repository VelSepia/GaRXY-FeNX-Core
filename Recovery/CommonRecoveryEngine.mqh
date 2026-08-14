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
   CCommonRecoveryEngineAdapter   m_adapter;
   string                         m_symbols[];
   bool                           m_source_warning_logged[];

   bool              LoadSymbols(CParameterManager &parameters)
     {
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
     }

   //--- Injects the existing non-owning typed store before initialization.
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
         CLogger::Error("CommonRecoveryEngine requires CommonSnapshotStore before initialization.");
         return(false);
        }
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);
      if(!m_adapter.Configure(m_snapshot_store,_Period) ||
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
         if(!m_snapshot_store.GetStandbySnapshot(m_symbols[index],_Period,standby) ||
            !m_snapshot_store.GetRiskSnapshot(m_symbols[index],_Period,risk))
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
         const bool entry_available=m_snapshot_store.GetEntrySnapshot(
            m_symbols[index],_Period,entry);
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
         m_adapter.LogSummary();
      ArrayFree(m_symbols);
      ArrayFree(m_source_warning_logged);
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_COMMON_RECOVERY_ENGINE_MQH
