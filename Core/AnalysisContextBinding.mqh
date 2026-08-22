//+------------------------------------------------------------------+
//|                           Core/AnalysisContextBinding.mqh       |
//+------------------------------------------------------------------+
#ifndef FENX_CORE_ANALYSIS_CONTEXT_BINDING_MQH
#define FENX_CORE_ANALYSIS_CONTEXT_BINDING_MQH

#include "../Common/Types.mqh"
#include "DataBus.mqh"

//--- Small value-owned binding shared by the six Task027 analysis engines.
//--- It changes only data identity and compatibility routing; indicator
//--- calculations, classification rules, and trading decisions stay outside.
class CAnalysisContextBinding
  {
private:
   SRuntimeContextId m_context_id;
   bool              m_configured;
   bool              m_publish_primary_legacy;

public:
                     CAnalysisContextBinding(void)
     {
      m_context_id.symbol="";
      m_context_id.timeframe=PERIOD_CURRENT;
      m_configured=false;
      m_publish_primary_legacy=true;
     }

   //--- Explicit configuration is accepted only before engine initialization.
   bool              Configure(const SRuntimeContextId &context_id,
                               const bool publish_primary_legacy)
     {
      if(!IsValidRuntimeContextId(context_id))
         return(false);
      m_context_id=context_id;
      m_configured=true;
      m_publish_primary_legacy=publish_primary_legacy;
      return(true);
     }

   //--- Standalone legacy harnesses remain compatible without configuration.
   string            Symbol(void)
     {
      return(m_configured ? m_context_id.symbol : _Symbol);
     }

   ENUM_TIMEFRAMES   Timeframe(void)
     {
      return(m_configured ? m_context_id.timeframe : (ENUM_TIMEFRAMES)_Period);
     }

   SRuntimeContextId Id(void)
     {
      if(m_configured)
         return(m_context_id);
      SRuntimeContextId legacy_id;
      legacy_id.symbol=_Symbol;
      legacy_id.timeframe=(ENUM_TIMEFRAMES)_Period;
      return(legacy_id);
     }

   bool              IsConfigured(void)
     {
      return(m_configured);
     }

   bool              PublishesPrimaryLegacy(void)
     {
      return(!m_configured || m_publish_primary_legacy);
     }

   //--- Global legacy Environment.* fields are written only by the primary.
   //--- Canonical context publication is mandatory for configured contexts.
   bool              PublishGlobalLegacy(CDataBus *data_bus,
                                         const string context_namespace,
                                         const string context_field,
                                         const string legacy_key,
                                         const string value)
     {
      if(data_bus==NULL)
         return(false);
      if(!m_configured)
         return(data_bus.SetText(legacy_key,value));
      if(m_publish_primary_legacy && !data_bus.SetText(legacy_key,value))
         return(false);
      return(data_bus.SetContextText(context_namespace,m_context_id,
                                     context_field,value));
     }

   //--- Reads are strictly context-local after promotion. No secondary or
   //--- primary legacy fallback is needed because producers precede consumers.
   bool              ReadGlobalLegacy(CDataBus *data_bus,
                                      const string context_namespace,
                                      const string context_field,
                                      const string legacy_key,
                                      string &value)
     {
      if(data_bus==NULL)
         return(false);
      if(!m_configured)
         return(data_bus.TryGetText(legacy_key,value));
      return(data_bus.TryGetContextText(context_namespace,m_context_id,
                                        context_field,value));
     }

   //--- Central translation for the four promoted legacy Environment groups.
   //--- Consumers pass the established key constant; this method alone maps it
   //--- to the canonical context namespace and final field segment.
   bool              ReadEnvironmentLegacy(CDataBus *data_bus,
                                           const string legacy_key,
                                           string &value)
     {
      if(!m_configured)
         return(data_bus!=NULL && data_bus.TryGetText(legacy_key,value));

      string name_space="";
      string prefix="";
      if(StringFind(legacy_key,"Environment.Volatility.")==0)
        {
         name_space=FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY;
         prefix="Environment.Volatility.";
        }
      else if(StringFind(legacy_key,"Environment.Range.")==0)
        {
         name_space=FENX_DATABUS_NAMESPACE_CONTEXT_RANGE;
         prefix="Environment.Range.";
        }
      else if(StringFind(legacy_key,"Environment.Trend.")==0)
        {
         name_space=FENX_DATABUS_NAMESPACE_CONTEXT_TREND;
         prefix="Environment.Trend.";
        }
      else if(StringFind(legacy_key,"Environment.Market.")==0)
        {
         name_space=FENX_DATABUS_NAMESPACE_CONTEXT_MARKET;
         prefix="Environment.Market.";
        }
      if(StringLen(name_space)==0 || StringLen(legacy_key)<=StringLen(prefix))
         return(false);

      return(data_bus!=NULL && data_bus.TryGetContextText(
             name_space,m_context_id,
             StringSubstr(legacy_key,StringLen(prefix)),value));
     }

   //--- Existing per-symbol namespaces receive an exact primary alias. A
   //--- secondary context can never reach SetSymbolText through this method.
   bool              PublishSymbolLegacy(CDataBus *data_bus,
                                         const string name_space,
                                         const string field,
                                         const string value)
     {
      if(data_bus==NULL)
         return(false);
      if(!m_configured)
         return(data_bus.SetSymbolText(name_space,_Symbol,field,value));
      if(m_publish_primary_legacy &&
         !data_bus.SetSymbolText(name_space,m_context_id.symbol,field,value))
         return(false);
      return(data_bus.SetContextText(name_space,m_context_id,field,value));
     }

   //--- Compatibility overload for the historical multi-symbol loop. Once an
   //--- engine is context-bound, the supplied symbol must equal its owner.
   bool              PublishSymbolLegacyFor(CDataBus *data_bus,
                                            const string name_space,
                                            const string legacy_symbol,
                                            const string field,
                                            const string value)
     {
      if(data_bus==NULL || StringLen(legacy_symbol)==0)
         return(false);
      if(!m_configured)
         return(data_bus.SetSymbolText(name_space,legacy_symbol,field,value));
      if(legacy_symbol!=m_context_id.symbol)
         return(false);
      return(PublishSymbolLegacy(data_bus,name_space,field,value));
     }

   bool              ReadSymbolLegacy(CDataBus *data_bus,
                                      const string name_space,
                                      const string field,
                                      string &value)
     {
      if(data_bus==NULL)
         return(false);
      if(!m_configured)
         return(data_bus.TryGetSymbolText(name_space,_Symbol,field,value));
      return(data_bus.TryGetContextText(name_space,m_context_id,field,value));
     }
  };

#endif // FENX_CORE_ANALYSIS_CONTEXT_BINDING_MQH
