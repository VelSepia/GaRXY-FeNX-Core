//+------------------------------------------------------------------+
//|                              Core/RuntimeContextRegistry.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_CORE_RUNTIME_CONTEXT_REGISTRY_MQH
#define FENX_CORE_RUNTIME_CONTEXT_REGISTRY_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Common/Types.mqh"
#include "../Config/ParameterManager.mqh"
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

//--- Registry-owned runtime shell. Task026 intentionally owns no indicators or
//--- engines here; it establishes only identity, availability, and local state.
class CRuntimeContext
  {
private:
   SRuntimeContextConfig m_config;
   CStateManager         m_local_state;
   bool                  m_initialized;
   bool                  m_available;

public:
                     CRuntimeContext(void)
     {
      ResetRuntimeContextConfig(m_config);
      m_local_state.Reset();
      m_initialized=false;
      m_available=false;
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
      m_local_state.Reset();
      return(true);
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
  };

//--- Owns runtime context shells. EngineManager only receives non-owning
//--- pointers to their local StateManagers, preventing double deletion.
class CRuntimeContextRegistry
  {
private:
   CRuntimeContext m_contexts[];
   int             m_primary_index;
   bool            m_initialized;

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
  };

#endif // FENX_CORE_RUNTIME_CONTEXT_REGISTRY_MQH
