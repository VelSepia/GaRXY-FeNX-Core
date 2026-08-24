//+------------------------------------------------------------------+
//|                           Core/AnalysisContextBinding.mqh       |
//+------------------------------------------------------------------+
#ifndef FENX_CORE_ANALYSIS_CONTEXT_BINDING_MQH
#define FENX_CORE_ANALYSIS_CONTEXT_BINDING_MQH

#include "../Common/Types.mqh"
#include "DataBus.mqh"

//--- Value-owned canonical identity shared by the six analysis engines.
//--- Task032 removes all alias and fallback behavior from this boundary.
class CAnalysisContextBinding
  {
private:
   SRuntimeContextId m_context_id;
   bool              m_configured;

public:
                     CAnalysisContextBinding(void)
     {
      m_context_id.symbol="";
      m_context_id.timeframe=PERIOD_CURRENT;
      m_configured=false;
     }

   //--- Explicit configuration is accepted only before engine initialization.
   bool              Configure(const SRuntimeContextId &context_id)
     {
      if(!IsValidRuntimeContextId(context_id))
         return(false);
      m_context_id=context_id;
      m_configured=true;
      return(true);
     }

   //--- Runtime identity must be configured before an engine is initialized.
   string            Symbol(void)
     {
      return(m_context_id.symbol);
     }

   ENUM_TIMEFRAMES   Timeframe(void)
     {
      return(m_context_id.timeframe);
     }

   SRuntimeContextId Id(void)
     {
      return(m_context_id);
     }

   bool              IsConfigured(void)
     {
      return(m_configured);
     }

   bool              PublishText(CDataBus *data_bus,
                                 const string context_namespace,
                                 const string context_field,
                                 const string value)
     {
      if(data_bus==NULL || !m_configured)
         return(false);
      return(data_bus.SetContextText(context_namespace,m_context_id,
                                     context_field,value));
     }

   bool              ReadText(CDataBus *data_bus,
                              const string context_namespace,
                              const string context_field,
                              string &value)
     {
      if(data_bus==NULL || !m_configured)
         return(false);
      return(data_bus.TryGetContextText(context_namespace,m_context_id,
                                        context_field,value));
     }

   bool              PublishSymbol(CDataBus *data_bus,
                                   const string name_space,
                                   const string field,
                                   const string value)
     {
      if(data_bus==NULL || !m_configured)
         return(false);
      return(data_bus.SetContextText(name_space,m_context_id,field,value));
     }

   bool              PublishSymbolFor(CDataBus *data_bus,
                                      const string name_space,
                                      const string symbol,
                                      const string field,
                                      const string value)
     {
      if(data_bus==NULL || !m_configured || StringLen(symbol)==0)
         return(false);
      if(symbol!=m_context_id.symbol)
         return(false);
      return(PublishSymbol(data_bus,name_space,field,value));
     }

   bool              ReadSymbol(CDataBus *data_bus,
                                const string name_space,
                                const string field,
                                string &value)
     {
      if(data_bus==NULL || !m_configured)
         return(false);
      return(data_bus.TryGetContextText(name_space,m_context_id,field,value));
     }
  };

#endif // FENX_CORE_ANALYSIS_CONTEXT_BINDING_MQH
