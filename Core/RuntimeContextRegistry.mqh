//+------------------------------------------------------------------+
//|                              Core/RuntimeContextRegistry.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_CORE_RUNTIME_CONTEXT_REGISTRY_MQH
#define FENX_CORE_RUNTIME_CONTEXT_REGISTRY_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Common/Types.mqh"
#include "../Config/ParameterManager.mqh"
#include "../Common/CommonSnapshotStore.mqh"
#include "../Portfolio/GlobalPortfolioSnapshotStore.mqh"
#include "../Environment/VolatilityAnalyzer.mqh"
#include "../Environment/RangeDetector.mqh"
#include "../Environment/TrendDetector.mqh"
#include "../Environment/MarketStateIntegrator.mqh"
#include "../Environment/EnvironmentEngine.mqh"
#include "../MarketSelection/MarketSelectionEngine.mqh"
#include "../TradingStyle/TradingStyleEngine.mqh"
#include "../Strategy/StrategySelectionEngine.mqh"
#include "../Standby/StandbyEngine.mqh"
#include "../Risk/RiskEngine.mqh"
#include "../Risk/GlobalRiskAggregateEngine.mqh"
#include "../Confidence/ConfidenceEngine.mqh"
#include "../Decision/DecisionScoreEngine.mqh"
#include "../Execution/ExecutionEngine.mqh"
#include "../Execution/PositionOwnershipArbiter.mqh"
#include "../Execution/TradeTransactionRouter.mqh"
#include "../Recovery/CommonRecoveryEngine.mqh"
#include "../Health/CommonHealthEngine.mqh"
#include "../Health/GlobalHealthAggregateEngine.mqh"
#include "EngineManager.mqh"
#include "StateManager.mqh"

//--- Captures every fail-closed invariant that must be satisfied before a
//--- future multi-context engine graph can be created.
struct SRuntimeContextPreflight
  {
   int    context_count;
   int    enabled_context_count;
   int    primary_context_index;
   int    estimated_databus_entries;
   int    databus_capacity;
   int    estimated_engine_count;
   int    engine_capacity;
   bool   configuration_valid;
   bool   required_contexts_available;
   bool   databus_capacity_valid;
   bool   engine_capacity_valid;
   bool   accepted;
   string failure_reason;
  };

void ResetRuntimeContextPreflight(SRuntimeContextPreflight &result)
  {
   result.context_count=0;
   result.enabled_context_count=0;
   result.primary_context_index=-1;
   result.estimated_databus_entries=0;
   result.databus_capacity=FENX_DATABUS_CAPACITY;
   result.estimated_engine_count=0;
   result.engine_capacity=FENX_MAX_ENGINES;
   result.configuration_valid=false;
   result.required_contexts_available=false;
   result.databus_capacity_valid=false;
   result.engine_capacity_valid=false;
   result.accepted=false;
   result.failure_reason="";
  }

//--- Registry-owned runtime analysis context. Each context owns its local
//--- state and exactly one instance of every Task027 analysis engine.
class CRuntimeContext
  {
private:
   SRuntimeContextConfig m_config;
   CStateManager         m_local_state;
   bool                  m_initialized;
   bool                  m_available;
   bool                  m_analysis_prepared;
   bool                  m_decision_safety_prepared;
   bool                  m_execution_prepared;
   bool                  m_recovery_health_prepared;
   CExecutionEngine      m_execution;
   CExecutionEngine     *m_execution_external;
   CCommonRecoveryEngine m_recovery;
   CCommonRecoveryEngine *m_recovery_external;
   CCommonHealthEngine   m_health;
   CCommonHealthEngine  *m_health_external;
   CVolatilityAnalyzer   m_volatility;
   CRangeDetector        m_range;
   CTrendDetector        m_trend;
   CMarketStateIntegrator m_market_state;
   CEnvironmentEngine    m_environment;
   CMarketSelectionEngine m_market_selection;
   CTradingStyleEngine      m_trading_style;
   CStrategySelectionEngine m_strategy_selection;
   CStandbyEngine           m_standby;
   CRiskEngine              m_risk;
   CConfidenceEngine        m_confidence;
   CDecisionScoreEngine     m_decision_score;

public:
                     CRuntimeContext(void)
     {
      ResetRuntimeContextConfig(m_config);
      m_local_state.Reset();
      m_initialized=false;
      m_available=false;
      m_analysis_prepared=false;
      m_decision_safety_prepared=false;
      m_execution_prepared=false;
      m_recovery_health_prepared=false;
      m_execution_external=NULL;
      m_recovery_external=NULL;
      m_health_external=NULL;
     }

   bool              Configure(const SRuntimeContextConfig &config,
                               const bool available)
     {
      if(!IsValidRuntimeContextId(config.id) ||
         !IsValidRuntimeContextRole(config.role) || config.magic<=0)
         return(false);

      m_config=config;
      m_available=(config.enabled && available);
      m_initialized=m_available;
      m_analysis_prepared=false;
      m_decision_safety_prepared=false;
      m_execution_prepared=false;
      m_recovery_health_prepared=false;
      m_execution_external=NULL;
      m_recovery_external=NULL;
      m_health_external=NULL;
      m_local_state.Reset();
      if(!m_local_state.ConfigureContext(config.id))
         return(false);
      return(true);
     }

   //--- The runtime context is the sole owner of all six analysis instances.
   //--- EngineManager receives non-owning references only after configuration.
   bool              PrepareAnalysis(CCommonSnapshotStore &snapshot_store,
                                     const bool publish_primary_legacy)
     {
      if(!m_available)
         return(true);
      if(m_analysis_prepared)
         return(true);

      const SRuntimeContextId context_id=m_config.id;
      if(!m_volatility.SetRuntimeContext(context_id,publish_primary_legacy) ||
         !m_range.SetRuntimeContext(context_id,publish_primary_legacy) ||
         !m_trend.SetRuntimeContext(context_id,publish_primary_legacy) ||
         !m_market_state.SetRuntimeContext(context_id,publish_primary_legacy) ||
         !m_environment.SetRuntimeContext(context_id,publish_primary_legacy) ||
         !m_market_selection.SetRuntimeContext(context_id,publish_primary_legacy) ||
         !m_volatility.SetSnapshotStore(snapshot_store) ||
         !m_range.SetSnapshotStore(snapshot_store) ||
         !m_trend.SetSnapshotStore(snapshot_store) ||
         !m_market_state.SetSnapshotStore(snapshot_store) ||
         !m_environment.SetSnapshotStore(snapshot_store))
         return(false);

      m_analysis_prepared=true;
      return(true);
     }

   //--- Registration order is the formal per-context pipeline order. All six
   //--- retain RUNMODE_TICK to preserve Task022/Task026 primary telemetry.
   bool              RegisterAnalysis(CEngineManager &manager)
     {
      if(!m_available)
         return(true);
      if(!m_analysis_prepared)
         return(false);
      return(manager.Register(m_volatility,m_config.id,m_local_state,RUNMODE_TICK) &&
             manager.Register(m_range,m_config.id,m_local_state,RUNMODE_TICK) &&
             manager.Register(m_trend,m_config.id,m_local_state,RUNMODE_TICK) &&
             manager.Register(m_market_state,m_config.id,m_local_state,RUNMODE_TICK) &&
             manager.Register(m_environment,m_config.id,m_local_state,RUNMODE_TICK) &&
             manager.Register(m_market_selection,m_config.id,m_local_state,RUNMODE_TICK));
     }

   //--- Attaches context-local typed storage to the six unchanged Task029
   //--- calculation engines. Their DataBus identity is supplied at lifecycle
   //--- dispatch time by EngineManager, not by handwritten keys in each engine.
   bool              PrepareDecisionSafety(CCommonSnapshotStore &snapshot_store)
     {
      if(!m_available)
         return(true);
      if(m_decision_safety_prepared)
         return(true);
      if(!m_standby.SetSnapshotStore(snapshot_store) ||
         !m_risk.SetSnapshotStore(snapshot_store) ||
         !m_confidence.SetSnapshotStore(snapshot_store) ||
         !m_decision_score.SetSnapshotStore(snapshot_store))
         return(false);
      m_decision_safety_prepared=true;
      return(true);
     }

   //--- Formal local order: Style -> Strategy -> Standby -> Risk ->
   //--- Confidence -> Decision. All writes remain context-only.
   bool              RegisterDecisionSafety(CEngineManager &manager)
     {
      if(!m_available)
         return(true);
      if(!m_decision_safety_prepared)
         return(false);
      return(manager.RegisterContextDataView(m_trading_style,m_config.id,m_local_state) &&
             manager.RegisterContextDataView(m_strategy_selection,m_config.id,m_local_state) &&
             manager.RegisterContextDataView(m_standby,m_config.id,m_local_state) &&
             manager.RegisterContextDataView(m_risk,m_config.id,m_local_state) &&
             manager.RegisterContextDataView(m_confidence,m_config.id,m_local_state) &&
             manager.RegisterContextDataView(m_decision_score,m_config.id,m_local_state));
     }

   //--- Every available context owns one execution infrastructure instance.
   //--- The Primary route binds the unchanged externally registered engine;
   //--- auxiliary routes own dormant instances whose order path is closed by
   //--- both context policy and Strategy SupportsContext.
   bool              PrepareExecution(CExecutionEngine *primary_execution,
                                      CStateManager &global_state,
                                      CCommonSnapshotStore &secondary_store,
                                      CPositionOwnershipArbiter &arbiter,
                                      const bool is_primary)
     {
      if(!m_available)
         return(true);
      if(m_execution_prepared)
         return(true);
      CExecutionEngine *engine=(is_primary ? primary_execution :
                                GetPointer(m_execution));
      if(engine==NULL)
         return(false);
      if(!is_primary && !engine.SetSnapshotStore(secondary_store))
         return(false);
      if(!engine.SetRuntimeContext(m_config,global_state,m_local_state,arbiter,
                                   is_primary))
         return(false);
      m_execution_external=(is_primary ? engine : NULL);
      m_execution_prepared=true;
      return(true);
     }

   bool              RegisterExecution(CEngineManager &manager,
                                       const bool is_primary)
     {
      if(!m_available)
         return(true);
      if(!m_execution_prepared)
         return(false);
      // Primary remains at its established legacy registration point so its
      // tick ordering and Task029 trade series are not shifted.
      if(is_primary)
         return(true);
      return(manager.RegisterContextDataView(m_execution,m_config.id,
                                             m_local_state,RUNMODE_TICK));
     }

   //--- Primary binds the established legacy observer instances so their
   //--- registration position and counters remain unchanged. Auxiliary
   //--- contexts own isolated observers and use only typed local stores.
   bool              PrepareRecoveryHealth(
                        CCommonRecoveryEngine *primary_recovery,
                        CCommonHealthEngine *primary_health,
                        CCommonSnapshotStore &analysis_store,
                        CCommonSnapshotStore &decision_store,
                        CCommonSnapshotStore &execution_store,
                        CCommonSnapshotStore &output_store,
                        const bool is_primary)
     {
      if(!m_available)
         return(true);
      if(!m_execution_prepared || m_recovery_health_prepared)
         return(m_recovery_health_prepared);
      if(is_primary)
        {
         if(primary_recovery==NULL || primary_health==NULL)
            return(false);
         m_recovery_external=primary_recovery;
         m_health_external=primary_health;
        }
      else
        {
         if(!m_recovery.SetRuntimeContext(m_config.id) ||
            !m_recovery.SetContextStores(decision_store,execution_store,
                                         output_store) ||
            !m_health.SetRuntimeContext(m_config.id) ||
            !m_health.SetContextStores(analysis_store,decision_store,
                                       execution_store,output_store))
            return(false);
        }
      m_recovery_health_prepared=true;
      return(true);
     }

   bool              RegisterRecoveryHealth(CEngineManager &manager,
                                             const bool is_primary)
     {
      if(!m_available)
         return(true);
      if(!m_recovery_health_prepared)
         return(false);
      // Primary remains at the exact legacy tail position in the caller.
      if(is_primary)
         return(true);
      return(manager.RegisterContextDataView(m_recovery,m_config.id,
                                             m_local_state,RUNMODE_TICK) &&
             manager.RegisterContextDataView(m_health,m_config.id,
                                             m_local_state,RUNMODE_TICK));
     }

   SRuntimeContextConfig Config(void)
     {
      return(m_config);
     }

   SRuntimeContextId  Id(void)
     {
      return(m_config.id);
     }

   CStateManager     *StateManager(void)
     {
      return(GetPointer(m_local_state));
     }

   bool              IsInitialized(void)
     {
      return(m_initialized);
     }

   bool              IsAvailable(void)
     {
      return(m_available);
     }

   bool              IsAnalysisPrepared(void)
     {
      return(m_analysis_prepared);
     }

   bool              IsDecisionSafetyPrepared(void)
     {
      return(m_decision_safety_prepared);
     }

   bool              IsExecutionPrepared(void) { return(m_execution_prepared); }
   bool              IsRecoveryHealthPrepared(void)
     {
      return(m_recovery_health_prepared);
     }
   CExecutionEngine *Execution(void)
     {
      if(!m_execution_prepared)
         return(NULL);
      return(m_execution_external!=NULL ? m_execution_external :
             GetPointer(m_execution));
     }

   CCommonRecoveryEngine *Recovery(void)
     {
      if(!m_recovery_health_prepared)
         return(NULL);
      return(m_recovery_external!=NULL ? m_recovery_external :
             GetPointer(m_recovery));
     }

   CCommonHealthEngine *Health(void)
     {
      if(!m_recovery_health_prepared)
         return(NULL);
      return(m_health_external!=NULL ? m_health_external : GetPointer(m_health));
     }

   int               DecisionSafetyEngineCount(void)
     {
      return(m_decision_safety_prepared ?
             FENX_DECISION_SAFETY_ENGINES_PER_CONTEXT : 0);
     }

   int               AnalysisEngineCount(void)
     {
      return(m_analysis_prepared ? FENX_ANALYSIS_ENGINES_PER_CONTEXT : 0);
     }

   int               IndicatorHandleCount(void)
     {
      int count=0;
      if(m_volatility.AtrHandle()!=INVALID_HANDLE) count++;
      if(m_trend.MaHandle()!=INVALID_HANDLE) count++;
      if(m_trend.AdxHandle()!=INVALID_HANDLE) count++;
      return(count);
     }

   CVolatilityAnalyzer *Volatility(void) { return(GetPointer(m_volatility)); }
   CRangeDetector *Range(void) { return(GetPointer(m_range)); }
   CTrendDetector *Trend(void) { return(GetPointer(m_trend)); }
   CMarketStateIntegrator *MarketState(void) { return(GetPointer(m_market_state)); }
   CEnvironmentEngine *Environment(void) { return(GetPointer(m_environment)); }
   CMarketSelectionEngine *MarketSelection(void) { return(GetPointer(m_market_selection)); }
  };

//--- Owns runtime context shells. EngineManager only receives non-owning
//--- pointers to their local StateManagers, preventing double deletion.
class CRuntimeContextRegistry
  {
private:
   CRuntimeContext m_contexts[];
   int             m_primary_index;
   bool            m_initialized;
   bool            m_analysis_prepared;
   bool            m_analysis_registered;
   bool            m_decision_safety_prepared;
   bool            m_decision_safety_registered;
   bool            m_execution_prepared;
   bool            m_execution_registered;
   bool            m_recovery_health_prepared;
   bool            m_recovery_health_registered;
   bool            m_global_health_registered;
   CCommonSnapshotStore m_decision_snapshot_store;
   CCommonSnapshotStore m_execution_snapshot_store;
   CCommonSnapshotStore m_recovery_health_snapshot_store;
   CGlobalRiskAggregateStore m_global_risk_aggregate_store;
   CGlobalRiskAggregateEngine m_global_risk_aggregate_engine;
   CPositionOwnershipArbiter m_position_ownership_arbiter;
   CExecutionIntegritySnapshotStore m_execution_integrity_store;
   CGlobalHealthAggregateStore m_global_health_aggregate_store;
   CGlobalHealthAggregateEngine m_global_health_aggregate_engine;

   bool              BrokerContextAvailable(const SRuntimeContextConfig &config)
     {
      if(!config.enabled)
         return(false);

      bool is_custom=false;
      if(!SymbolExist(config.id.symbol,is_custom))
         return(false);
      if(!SymbolSelect(config.id.symbol,true))
         return(false);

      return((bool)SymbolInfoInteger(config.id.symbol,SYMBOL_SELECT));
     }

public:
                     CRuntimeContextRegistry(void)
     {
      m_primary_index=-1;
      m_initialized=false;
      m_analysis_prepared=false;
      m_analysis_registered=false;
      m_decision_safety_prepared=false;
      m_decision_safety_registered=false;
      m_execution_prepared=false;
      m_execution_registered=false;
      m_recovery_health_prepared=false;
      m_recovery_health_registered=false;
      m_global_health_registered=false;
     }

   //--- Pure preflight: identity/policy validation is kept separate from
   //--- broker availability so synthetic contexts remain deterministic.
   bool              EvaluatePreflight(CParameterManager &parameters,
                                       bool &availability[],
                                       const int estimated_databus_entries,
                                       const int estimated_engine_count,
                                       SRuntimeContextPreflight &result)
     {
      ResetRuntimeContextPreflight(result);
      result.context_count=parameters.RuntimeContextCount();
      result.estimated_databus_entries=estimated_databus_entries;
      result.estimated_engine_count=estimated_engine_count;

      string validation_reason="";
      result.configuration_valid=
         parameters.ValidateRuntimeContextConfiguration(validation_reason);
      if(!result.configuration_valid)
        {
         result.failure_reason=validation_reason;
         return(false);
        }

      if(ArraySize(availability)!=result.context_count)
        {
         result.failure_reason="AVAILABILITY_COUNT";
         return(false);
        }

      result.primary_context_index=parameters.PrimaryRuntimeContextIndex();
      result.required_contexts_available=true;
      for(int index=0;index<result.context_count;index++)
        {
         SRuntimeContextConfig config;
         if(!parameters.GetRuntimeContextConfig(index,config))
           {
            result.failure_reason="CONTEXT_LOOKUP";
            return(false);
           }
         if(config.enabled)
            result.enabled_context_count++;
         if(config.enabled && config.required && !availability[index])
           {
            result.required_contexts_available=false;
            result.failure_reason="REQUIRED_CONTEXT_UNAVAILABLE";
            return(false);
           }
        }

      result.databus_capacity_valid=
         (estimated_databus_entries>=0 &&
          estimated_databus_entries<=result.databus_capacity);
      if(!result.databus_capacity_valid)
        {
         result.failure_reason="DATABUS_CAPACITY";
         return(false);
        }

      result.engine_capacity_valid=
         (estimated_engine_count>=0 && estimated_engine_count<=result.engine_capacity);
      if(!result.engine_capacity_valid)
        {
         result.failure_reason="ENGINE_CAPACITY";
         return(false);
        }

      result.accepted=true;
      return(true);
     }

   //--- Deterministic initialization path used by broker-independent harnesses
   //--- and by future availability providers.
   bool              InitializeWithAvailability(CParameterManager &parameters,
                                                bool &availability[])
     {
      Clear();

      SRuntimeContextPreflight preflight;
      if(!EvaluatePreflight(parameters,availability,0,0,preflight))
        {
         CLogger::Error(StringFormat("Runtime context validation failed: %s.",
                                     preflight.failure_reason));
         return(false);
        }

      const int context_count=parameters.RuntimeContextCount();
      if(ArrayResize(m_contexts,context_count)!=context_count)
        {
         CLogger::Error("Runtime context registry allocation failed.");
         return(false);
        }

      for(int index=0;index<context_count;index++)
        {
         SRuntimeContextConfig config;
         if(!parameters.GetRuntimeContextConfig(index,config) ||
            !m_contexts[index].Configure(config,availability[index]))
           {
            Clear();
            CLogger::Error("Runtime context registry initialization failed.");
            return(false);
           }
        }

      m_primary_index=preflight.primary_context_index;
      m_initialized=true;
      return(true);
     }

   //--- Configures owned analysis instances after identity/availability
   //--- validation and before non-owning registration into EngineManager.
   bool              PrepareAnalysis(CCommonSnapshotStore &snapshot_store)
     {
      if(!m_initialized)
         return(false);
      if(m_analysis_prepared)
         return(true);

      for(int index=0;index<ArraySize(m_contexts);index++)
        {
         const bool is_primary=(index==m_primary_index);
         if(!m_contexts[index].PrepareAnalysis(snapshot_store,is_primary))
            return(false);
        }
      m_analysis_prepared=true;
      return(true);
     }

   //--- Registers complete context pipelines in context order. The caller must
   //--- invoke this before global portfolio/downstream engines are registered.
   bool              RegisterAnalysis(CEngineManager &manager)
     {
      if(!m_analysis_prepared || m_analysis_registered)
         return(false);
      for(int index=0;index<ArraySize(m_contexts);index++)
        {
         if(!m_contexts[index].RegisterAnalysis(manager))
            return(false);
        }
      m_analysis_registered=true;
      return(true);
     }

   //--- Prepares a dedicated context decision store. Keeping it separate from
   //--- the legacy Common store prevents the unchanged four-symbol Primary
   //--- compatibility engines from overwriting context-local observations.
   bool              PrepareDecisionSafety(
                        CGlobalPortfolioSnapshotStore &portfolio_store)
     {
      if(!m_initialized || !m_analysis_prepared)
         return(false);
      if(m_decision_safety_prepared)
         return(true);
      m_decision_snapshot_store.Clear();
      m_global_risk_aggregate_store.Clear();
      for(int index=0;index<ArraySize(m_contexts);index++)
         if(!m_contexts[index].PrepareDecisionSafety(m_decision_snapshot_store))
            return(false);

      SPortfolioContextDefinition definitions[];
      if(!ExportPortfolioDefinitions(definitions) ||
         !m_global_risk_aggregate_engine.Configure(
            portfolio_store,m_global_risk_aggregate_store,definitions))
         return(false);
      m_decision_safety_prepared=true;
      return(true);
     }

   bool              RegisterDecisionSafety(CEngineManager &manager)
     {
      if(!m_decision_safety_prepared || m_decision_safety_registered)
         return(false);
      for(int index=0;index<ArraySize(m_contexts);index++)
         if(!m_contexts[index].RegisterDecisionSafety(manager))
            return(false);
      if(!manager.Register(m_global_risk_aggregate_engine,RUNMODE_TICK))
         return(false);
      m_decision_safety_registered=true;
      return(true);
     }

   //--- Binds the existing Primary execution engine and creates one dormant
   //--- owned infrastructure instance for each available auxiliary context.
   bool              PrepareExecution(CExecutionEngine &primary_execution,
                                      CStateManager &global_state)
     {
      if(!m_initialized || !m_decision_safety_prepared)
         return(false);
      if(m_execution_prepared)
         return(true);
      m_execution_snapshot_store.Clear();
      m_position_ownership_arbiter.Clear();
      for(int index=0;index<ArraySize(m_contexts);index++)
        {
         if(!m_contexts[index].PrepareExecution(GetPointer(primary_execution),
               global_state,m_execution_snapshot_store,
               m_position_ownership_arbiter,index==m_primary_index))
            return(false);
        }
      m_execution_prepared=true;
      return(true);
     }

   //--- Auxiliary execution instances run immediately after context
   //--- Decision/Safety. Primary stays at the unchanged legacy pipeline slot.
   bool              RegisterExecution(CEngineManager &manager)
     {
      if(!m_execution_prepared || m_execution_registered)
         return(false);
      for(int index=0;index<ArraySize(m_contexts);index++)
         if(!m_contexts[index].RegisterExecution(manager,
                                                 index==m_primary_index))
            return(false);
      m_execution_registered=true;
      return(true);
     }

   bool              RegisterExecutionRoutes(CTradeTransactionRouter &router)
     {
      if(!m_execution_prepared)
         return(false);
      router.Clear();
      for(int index=0;index<ArraySize(m_contexts);index++)
        {
         if(!m_contexts[index].IsAvailable())
            continue;
         CExecutionEngine *engine=m_contexts[index].Execution();
         if(engine==NULL ||
            !router.RegisterRoute(m_contexts[index].Config(),engine))
            return(false);
        }
      if(router.RouteCount()!=AvailableContextCount())
         return(false);
      return(router.AttachIntegrityStore(m_execution_integrity_store,
                                         m_position_ownership_arbiter,
                                         AvailableContextCount()));
     }

   //--- Promotes only the passive Recovery/Health layer. All Task030 source
   //--- engines and execution routes are already prepared before this call.
   bool              PrepareRecoveryHealth(
                        CCommonRecoveryEngine &primary_recovery,
                        CCommonHealthEngine &primary_health,
                        CCommonSnapshotStore &primary_store)
     {
      if(!m_initialized || !m_execution_prepared)
         return(false);
      if(m_recovery_health_prepared)
         return(true);
      m_recovery_health_snapshot_store.Clear();
      m_global_health_aggregate_store.Clear();
      for(int index=0;index<ArraySize(m_contexts);index++)
        {
         if(!m_contexts[index].PrepareRecoveryHealth(
               GetPointer(primary_recovery),GetPointer(primary_health),
               primary_store,m_decision_snapshot_store,
               m_execution_snapshot_store,m_recovery_health_snapshot_store,
               index==m_primary_index))
            return(false);
        }
      SPortfolioContextDefinition definitions[];
      if(!ExportPortfolioDefinitions(definitions) ||
         !m_global_health_aggregate_engine.Configure(
            primary_store,m_recovery_health_snapshot_store,
            m_execution_integrity_store,m_global_health_aggregate_store,
            definitions))
         return(false);
      m_recovery_health_prepared=true;
      return(true);
     }

   //--- Auxiliary observers run after auxiliary Execution. Primary observers
   //--- are deliberately skipped and retain their legacy registration points.
   bool              RegisterRecoveryHealth(CEngineManager &manager)
     {
      if(!m_recovery_health_prepared || m_recovery_health_registered)
         return(false);
      for(int index=0;index<ArraySize(m_contexts);index++)
         if(!m_contexts[index].RegisterRecoveryHealth(manager,
                                                      index==m_primary_index))
            return(false);
      m_recovery_health_registered=true;
      return(true);
     }

   //--- Registered after the legacy Primary Health observer so every context
   //--- snapshot and execution-integrity fact is complete for the current tick.
   bool              RegisterGlobalHealth(CEngineManager &manager)
     {
      if(!m_recovery_health_registered || m_global_health_registered)
         return(false);
      if(!manager.Register(m_global_health_aggregate_engine,RUNMODE_TICK))
         return(false);
      m_global_health_registered=true;
      return(true);
     }

   //--- Production path. Broker discovery and selection are isolated here;
   //--- required failures stop initialization while optional failures remain
   //--- represented as unavailable contexts.
   bool              Initialize(CParameterManager &parameters,
                                const bool validate_broker_symbols=true)
     {
      const int context_count=parameters.RuntimeContextCount();
      bool availability[];
      if(ArrayResize(availability,context_count)!=context_count)
         return(false);

      for(int index=0;index<context_count;index++)
        {
         SRuntimeContextConfig config;
         if(!parameters.GetRuntimeContextConfig(index,config))
            return(false);
         availability[index]=(validate_broker_symbols ?
                              BrokerContextAvailable(config) : config.enabled);
        }

      return(InitializeWithAvailability(parameters,availability));
     }

   //--- Rechecks capacity estimates after registration but before engines are
   //--- initialized. Registry invariants and required availability are already
   //--- guaranteed by Initialize.
   bool              ValidateCapacityPreflight(const int estimated_databus_entries,
                                               const int estimated_engine_count,
                                               SRuntimeContextPreflight &result)
     {
      ResetRuntimeContextPreflight(result);
      result.context_count=ArraySize(m_contexts);
      result.primary_context_index=m_primary_index;
      result.estimated_databus_entries=estimated_databus_entries;
      result.estimated_engine_count=estimated_engine_count;
      result.configuration_valid=m_initialized;
      result.required_contexts_available=m_initialized;
      for(int index=0;index<ArraySize(m_contexts);index++)
        {
         const SRuntimeContextConfig config=m_contexts[index].Config();
         if(config.enabled)
            result.enabled_context_count++;
         if(config.enabled && config.required && !m_contexts[index].IsAvailable())
            result.required_contexts_available=false;
        }
      result.databus_capacity_valid=
         (estimated_databus_entries>=0 &&
          estimated_databus_entries<=result.databus_capacity);
      result.engine_capacity_valid=
         (estimated_engine_count>=0 && estimated_engine_count<=result.engine_capacity);
      result.accepted=(result.configuration_valid &&
                       result.required_contexts_available &&
                       result.primary_context_index>=0 &&
                       result.databus_capacity_valid &&
                       result.engine_capacity_valid);
      if(!result.accepted)
         result.failure_reason="RUNTIME_PREFLIGHT";
      return(result.accepted);
     }

   void              Clear(void)
     {
      ArrayResize(m_contexts,0);
      m_primary_index=-1;
      m_initialized=false;
      m_analysis_prepared=false;
      m_analysis_registered=false;
      m_decision_safety_prepared=false;
      m_decision_safety_registered=false;
      m_execution_prepared=false;
      m_execution_registered=false;
      m_recovery_health_prepared=false;
      m_recovery_health_registered=false;
      m_global_health_registered=false;
      m_decision_snapshot_store.Clear();
      m_execution_snapshot_store.Clear();
      m_recovery_health_snapshot_store.Clear();
      m_global_risk_aggregate_store.Clear();
      m_position_ownership_arbiter.Clear();
      m_execution_integrity_store.Clear();
      m_global_health_aggregate_store.Clear();
     }

   int               Count(void)
     {
      return(ArraySize(m_contexts));
     }

   int               PrimaryIndex(void)
     {
      return(m_primary_index);
     }

   CRuntimeContext  *ContextAt(const int index)
     {
      if(index<0 || index>=ArraySize(m_contexts))
         return(NULL);
      return(GetPointer(m_contexts[index]));
     }

   int               Find(const SRuntimeContextId &context_id)
     {
      if(!IsValidRuntimeContextId(context_id))
         return(-1);
      for(int index=0;index<ArraySize(m_contexts);index++)
        {
         if(RuntimeContextEquals(m_contexts[index].Id(),context_id))
            return(index);
        }
      return(-1);
     }

   bool              Has(const SRuntimeContextId &context_id)
     {
      return(Find(context_id)>=0);
     }

   CRuntimeContext  *Primary(void)
     {
      return(ContextAt(m_primary_index));
     }

   bool              IsInitialized(void)
     {
      return(m_initialized);
     }

   bool              IsAnalysisPrepared(void) { return(m_analysis_prepared); }
   bool              IsAnalysisRegistered(void) { return(m_analysis_registered); }
   bool              IsDecisionSafetyPrepared(void) { return(m_decision_safety_prepared); }
   bool              IsDecisionSafetyRegistered(void) { return(m_decision_safety_registered); }
   bool              IsExecutionPrepared(void) { return(m_execution_prepared); }
   bool              IsExecutionRegistered(void) { return(m_execution_registered); }
   bool              IsRecoveryHealthPrepared(void) { return(m_recovery_health_prepared); }
   bool              IsRecoveryHealthRegistered(void) { return(m_recovery_health_registered); }
   bool              IsGlobalHealthRegistered(void) { return(m_global_health_registered); }

   int               AvailableContextCount(void)
     {
      int count=0;
      for(int index=0;index<ArraySize(m_contexts);index++)
         if(m_contexts[index].IsAvailable()) count++;
      return(count);
     }

   int               AnalysisEngineCount(void)
     {
      int count=0;
      for(int index=0;index<ArraySize(m_contexts);index++)
         count+=m_contexts[index].AnalysisEngineCount();
      return(count);
     }

   int               DecisionSafetyEngineCount(void)
     {
      int count=0;
      for(int index=0;index<ArraySize(m_contexts);index++)
         count+=m_contexts[index].DecisionSafetyEngineCount();
      return(count);
     }

   int               ExecutionInfrastructureCount(void)
     {
      int count=0;
      for(int index=0;index<ArraySize(m_contexts);index++)
         if(m_contexts[index].IsExecutionPrepared()) count++;
      return(count);
     }

   int               RegisteredContextExecutionEngineCount(void)
     {
      if(!m_execution_registered)
         return(0);
      const int count=ExecutionInfrastructureCount();
      return(count>1 ? count-1 : 0);
     }

   int               RecoveryHealthInfrastructureCount(void)
     {
      int count=0;
      for(int index=0;index<ArraySize(m_contexts);index++)
         if(m_contexts[index].IsRecoveryHealthPrepared()) count++;
      return(count);
     }

   int               RegisteredContextRecoveryHealthEngineCount(void)
     {
      if(!m_recovery_health_registered)
         return(0);
      const int contexts=RecoveryHealthInfrastructureCount();
      return(contexts>1 ? 2*(contexts-1) : 0);
     }

   CCommonSnapshotStore *DecisionSnapshotStore(void)
     {
      return(GetPointer(m_decision_snapshot_store));
     }

   CGlobalRiskAggregateStore *GlobalRiskAggregateStore(void)
     {
      return(GetPointer(m_global_risk_aggregate_store));
     }

   CGlobalRiskAggregateEngine *GlobalRiskAggregateEngine(void)
     {
      return(GetPointer(m_global_risk_aggregate_engine));
     }

   CCommonSnapshotStore *ExecutionSnapshotStore(void)
     {
      return(GetPointer(m_execution_snapshot_store));
     }

   CPositionOwnershipArbiter *PositionOwnershipArbiter(void)
     {
      return(GetPointer(m_position_ownership_arbiter));
     }

   CCommonSnapshotStore *RecoveryHealthSnapshotStore(void)
     {
      return(GetPointer(m_recovery_health_snapshot_store));
     }

   CExecutionIntegritySnapshotStore *ExecutionIntegrityStore(void)
     {
      return(GetPointer(m_execution_integrity_store));
     }

   CGlobalHealthAggregateStore *GlobalHealthAggregateStore(void)
     {
      return(GetPointer(m_global_health_aggregate_store));
     }

   //--- Exports read-only value metadata for the global shadow portfolio.
   //--- The store/portfolio engines never receive ownership of runtime
   //--- contexts, engine instances, indicator handles, or StateManagers.
   bool              ExportPortfolioDefinitions(SPortfolioContextDefinition &definitions[])
     {
      const int count=ArraySize(m_contexts);
      if(!m_initialized || ArrayResize(definitions,count)!=count)
         return(false);
      for(int index=0;index<count;index++)
        {
         definitions[index].config=m_contexts[index].Config();
         definitions[index].available=m_contexts[index].IsAvailable();
         definitions[index].registration_order=index;
        }
      return(true);
     }

   int               IndicatorHandleCount(void)
     {
      int count=0;
      for(int index=0;index<ArraySize(m_contexts);index++)
         count+=m_contexts[index].IndicatorHandleCount();
      return(count);
     }
  };

#endif // FENX_CORE_RUNTIME_CONTEXT_REGISTRY_MQH
