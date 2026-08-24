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
   bool           m_runtime_contexts_prepared;
   bool           m_runtime_decision_safety_prepared;
   bool           m_runtime_execution_prepared;
   bool           m_runtime_recovery_health_prepared;

public:
                     CCoreController(void)
     {
      m_initialized=false;
      m_runtime_contexts_prepared=false;
      m_runtime_decision_safety_prepared=false;
      m_runtime_execution_prepared=false;
      m_runtime_recovery_health_prepared=false;
     }

   //--- Creates context-owned analysis instances before registration and
   //--- reserves at least 30% of DataBus capacity for subsequent engines.
   bool              PrepareRuntimeContexts(CParameterManager &parameters,
                                            CCommonSnapshotStore &snapshot_store,
                                            const bool validate_broker_symbols=true)
     {
      if(m_initialized)
         return(false);
      if(m_runtime_contexts_prepared)
         return(true);
      if(!m_runtime_context_registry.Initialize(parameters,
                                                validate_broker_symbols) ||
         !m_runtime_context_registry.PrepareAnalysis(snapshot_store))
        {
         m_runtime_context_registry.Clear();
         return(false);
        }

      const int configured_symbols=parameters.MarketSelectionSymbolCount();
      const int available_contexts=
         m_runtime_context_registry.AvailableContextCount();
      const int estimated_databus_entries=
         FENX_DATABUS_BASELINE_FIXED_ENTRIES+
         FENX_DATABUS_BASELINE_PER_SYMBOL_ENTRIES*configured_symbols+
         FENX_COMMON_ENVIRONMENT_KEY_COUNT+
         FENX_COMMON_CONFIDENCE_GLOBAL_KEY_COUNT+
         FENX_COMMON_DECISION_GLOBAL_KEY_COUNT+
         (FENX_COMMON_CONFIDENCE_PER_SYMBOL_KEY_COUNT+
          FENX_COMMON_DECISION_PER_SYMBOL_KEY_COUNT)*configured_symbols+
         FENX_ANALYSIS_CONTEXT_KEY_COUNT*available_contexts;
      const int estimated_engine_count=
         m_engine_manager.Count()+
         FENX_ANALYSIS_ENGINES_PER_CONTEXT*available_contexts;
      const int maximum_safe_entries=(int)MathFloor(
         FENX_DATABUS_CAPACITY*(1.0-FENX_DATABUS_MINIMUM_SPARE_RATIO));
      SRuntimeContextPreflight runtime_preflight;
      if(estimated_databus_entries>maximum_safe_entries ||
         !m_runtime_context_registry.ValidateCapacityPreflight(
            estimated_databus_entries,estimated_engine_count,runtime_preflight))
        {
         m_runtime_context_registry.Clear();
         CLogger::Error("Runtime context analysis capacity preflight failed.");
         return(false);
        }

      CLogger::Info(StringFormat(
         "[CONTEXT CAPACITY] Contexts=%d;EstimatedKeys=%d;Capacity=%d;Remaining=%d;RemainingRatio=%.2f%%;AnalysisEngines=%d",
         available_contexts,estimated_databus_entries,FENX_DATABUS_CAPACITY,
         FENX_DATABUS_CAPACITY-estimated_databus_entries,
         100.0*(FENX_DATABUS_CAPACITY-estimated_databus_entries)/
               FENX_DATABUS_CAPACITY,
         FENX_ANALYSIS_ENGINES_PER_CONTEXT*available_contexts));
      m_runtime_contexts_prepared=true;
      return(true);
     }

   bool              PrepareRuntimeContextDecisionSafety(
                        CGlobalPortfolioSnapshotStore &portfolio_store)
     {
      if(m_initialized || !m_runtime_contexts_prepared)
         return(false);
      if(m_runtime_decision_safety_prepared)
         return(true);
      if(!m_runtime_context_registry.PrepareDecisionSafety(portfolio_store))
         return(false);

      m_runtime_decision_safety_prepared=true;
      return(true);
     }

   //--- Must be called before global portfolio/downstream registration so all
   //--- context analysis pipelines complete first on every scheduler tick.
   bool              RegisterRuntimeContextAnalysisEngines(void)
     {
      if(!m_runtime_contexts_prepared || m_initialized)
         return(false);
      return(m_runtime_context_registry.RegisterAnalysis(m_engine_manager));
     }

   bool              RegisterRuntimeContextDecisionSafetyEngines(void)
     {
      if(!m_runtime_decision_safety_prepared || m_initialized)
         return(false);
      return(m_runtime_context_registry.RegisterDecisionSafety(m_engine_manager));
     }

   bool              PrepareRuntimeContextExecution(
                        CExecutionEngine &primary_execution)
     {
      if(m_initialized || !m_runtime_decision_safety_prepared)
         return(false);
      if(m_runtime_execution_prepared)
         return(true);
      if(!m_runtime_context_registry.PrepareExecution(primary_execution,
                                                      m_state_manager))
         return(false);

      m_runtime_execution_prepared=true;
      return(true);
     }

   bool              RegisterRuntimeContextExecutionEngines(void)
     {
      if(!m_runtime_execution_prepared || m_initialized)
         return(false);
      return(m_runtime_context_registry.RegisterExecution(m_engine_manager));
     }

   bool              PrepareRuntimeContextRecoveryHealth(
                        CCommonRecoveryEngine &primary_recovery,
                        CCommonHealthEngine &primary_health,
                        CCommonSnapshotStore &primary_store)
     {
      if(m_initialized || !m_runtime_execution_prepared)
         return(false);
      if(m_runtime_recovery_health_prepared)
         return(true);
      if(!m_runtime_context_registry.PrepareRecoveryHealth(
            primary_recovery,primary_health,primary_store))
         return(false);
      m_runtime_recovery_health_prepared=true;
      return(true);
     }

   bool              RegisterRuntimeContextRecoveryHealthEngines(void)
     {
      if(!m_runtime_recovery_health_prepared || m_initialized)
         return(false);
      return(m_runtime_context_registry.RegisterRecoveryHealth(m_engine_manager));
     }

   bool              RegisterGlobalHealthAggregateEngine(void)
     {
      if(!m_runtime_recovery_health_prepared || m_initialized)
         return(false);
      return(m_runtime_context_registry.RegisterGlobalHealth(m_engine_manager));
     }

   bool              Initialize(CParameterManager &parameters)
     {
      if(m_initialized)
        {
         CLogger::Warning("CoreController was already initialized.");
         return(true);
        }

      // Registry-only harnesses that do not promote analysis engines retain
      // the Task026 initialization path.
      if(!m_runtime_context_registry.IsInitialized() &&
         !m_runtime_context_registry.Initialize(parameters,true))
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
          FENX_COMMON_DECISION_PER_SYMBOL_KEY_COUNT)*configured_symbols+
         (m_runtime_contexts_prepared ?
          FENX_ANALYSIS_CONTEXT_KEY_COUNT*
             m_runtime_context_registry.AvailableContextCount() : 0)+
          (m_runtime_decision_safety_prepared ?
           FENX_DECISION_SAFETY_CONTEXT_KEY_COUNT*
              m_runtime_context_registry.AvailableContextCount() : 0)+
          (m_runtime_execution_prepared ?
           FENX_EXECUTION_CONTEXT_KEY_COUNT*
              (m_runtime_context_registry.AvailableContextCount()>1 ?
               m_runtime_context_registry.AvailableContextCount()-1 : 0) : 0);
      const int maximum_safe_entries=(int)MathFloor(
         FENX_DATABUS_CAPACITY*(1.0-FENX_DATABUS_MINIMUM_SPARE_RATIO));
      SRuntimeContextPreflight runtime_preflight;
      if(estimated_databus_entries>maximum_safe_entries ||
         !m_runtime_context_registry.ValidateCapacityPreflight(
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

   //--- Retains the established Primary registration positions while binding
   //--- every DataBus access to the formal Symbol+Timeframe identity.
   bool              RegisterPrimaryContextEngine(IEngine &engine)
     {
      if(m_initialized || !m_runtime_contexts_prepared)
         return(false);
      CRuntimeContext *primary=m_runtime_context_registry.Primary();
      if(primary==NULL || !primary.IsAvailable())
         return(false);
      return(m_engine_manager.RegisterContextDataView(
                engine,primary.Id(),m_state_manager,RUNMODE_TICK));
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
      m_runtime_contexts_prepared=false;
      m_runtime_decision_safety_prepared=false;
      m_runtime_execution_prepared=false;
      m_runtime_recovery_health_prepared=false;
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
