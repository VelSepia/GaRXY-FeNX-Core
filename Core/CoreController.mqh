//+------------------------------------------------------------------+
//|                                        Core/CoreController.mqh  |
//+------------------------------------------------------------------+
#ifndef FENX_CORE_CONTROLLER_MQH
#define FENX_CORE_CONTROLLER_MQH

#include "../Common/Logger.mqh"
#include "../Config/ParameterManager.mqh"
#include "DataBus.mqh"
#include "EngineManager.mqh"
#include "RuntimeContextRegistry.mqh"
#include "StateManager.mqh"

//--- Top-level coordinator for framework initialization, updates, and shutdown.
class CCoreController
  {
private:
   CDataBus       m_data_bus;
   CEngineManager m_engine_manager;
   CStateManager  m_state_manager;
   CRuntimeContextRegistry m_runtime_context_registry;
   bool           m_initialized;

public:
                     CCoreController(void)
     {
      m_initialized=false;
     }

   bool              Initialize(CParameterManager &parameters)
     {
      if(m_initialized)
        {
         CLogger::Warning("CoreController was already initialized.");
         return(true);
        }

      // Runtime contexts are validated before any engine can initialize or
      // trade. Existing engines remain on their legacy global-state path.
      if(!m_runtime_context_registry.Initialize(parameters,true))
        {
         CLogger::Error("CoreController runtime context initialization failed.");
         return(false);
        }

      const int configured_symbols=parameters.MarketSelectionSymbolCount();
      const int estimated_databus_entries=
         FENX_DATABUS_BASELINE_FIXED_ENTRIES+
         FENX_DATABUS_BASELINE_PER_SYMBOL_ENTRIES*configured_symbols+
         FENX_COMMON_ENVIRONMENT_KEY_COUNT+
         FENX_COMMON_CONFIDENCE_GLOBAL_KEY_COUNT+
         FENX_COMMON_DECISION_GLOBAL_KEY_COUNT+
         (FENX_COMMON_CONFIDENCE_PER_SYMBOL_KEY_COUNT+
          FENX_COMMON_DECISION_PER_SYMBOL_KEY_COUNT)*configured_symbols;
      SRuntimeContextPreflight runtime_preflight;
      if(!m_runtime_context_registry.ValidateCapacityPreflight(
            estimated_databus_entries,m_engine_manager.Count(),runtime_preflight))
        {
         m_runtime_context_registry.Clear();
         CLogger::Error("CoreController runtime context preflight failed.");
         return(false);
        }

      m_state_manager.Reset();

      // TODO(Phase3-3+): Register additional engines as their dedicated phases begin.
      if(!m_engine_manager.Initialize(m_data_bus,parameters,m_state_manager))
        {
         m_state_manager.TransitionTo(FENX_STATE_SHUTDOWN);
         m_runtime_context_registry.Clear();
         CLogger::Error("CoreController failed to initialize EngineManager.");
         return(false);
        }

      if(!m_state_manager.TransitionTo(FENX_STATE_NORMAL))
        {
         m_engine_manager.Shutdown();
         m_runtime_context_registry.Clear();
         return(false);
        }

      m_initialized=true;
      CLogger::Info("CoreController initialized.");
      return(true);
     }

   bool              RegisterEngine(IEngine &engine)
     {
      if(m_initialized)
        {
         CLogger::Warning("CoreController cannot register an engine after initialization.");
         return(false);
        }

      return(m_engine_manager.Register(engine));
     }

   void              Update(void)
     {
      if(!m_initialized || m_state_manager.GetState()==FENX_STATE_SHUTDOWN)
         return;

      m_engine_manager.Update();
     }

   void              Shutdown(void)
     {
      if(m_state_manager.GetState()!=FENX_STATE_SHUTDOWN)
         m_state_manager.TransitionTo(FENX_STATE_SHUTDOWN);

      m_engine_manager.Shutdown();
      m_runtime_context_registry.Clear();
      m_data_bus.Clear();
      m_initialized=false;
      CLogger::Info("CoreController shut down.");
     }

   CEngineManager   *Engines(void)
     {
      return(GetPointer(m_engine_manager));
     }

   CDataBus         *DataBus(void)
     {
      return(GetPointer(m_data_bus));
     }

   CStateManager    *State(void)
     {
      return(GetPointer(m_state_manager));
     }

   CRuntimeContextRegistry *RuntimeContexts(void)
     {
      return(GetPointer(m_runtime_context_registry));
     }
  };

#endif // FENX_CORE_CONTROLLER_MQH
