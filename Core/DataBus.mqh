//+------------------------------------------------------------------+
//|                                              Core/DataBus.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_CORE_DATA_BUS_MQH
#define FENX_CORE_DATA_BUS_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Common/Types.mqh"

//--- Shared, in-memory message store for registered framework engines.
class CDataBus
  {
private:
   SDataBusItem m_items[];
   SRuntimeContextId m_primary_context;
   bool              m_primary_context_configured;
   bool              m_legacy_alias_write_enabled;
   bool              m_legacy_fallback_read_enabled;
   long              m_legacy_alias_write_count;
   long              m_legacy_fallback_read_count;

   int FindIndex(const string key)
     {
      for(int index=0;index<ArraySize(m_items);index++)
        {
         if(m_items[index].key==key)
            return(index);
        }

      return(-1);
     }

   string BuildSymbolKey(const string name_space,const string symbol,const string field)
     {
      if(StringLen(name_space)==0 || StringLen(symbol)==0 || StringLen(field)==0)
         return("");

      return(name_space+"."+symbol+"."+field);
     }

   //--- Escapes only the key delimiter and the escape marker. Existing legacy
   //--- keys are intentionally not escaped, preserving their exact schema.
   string EscapeKeySegment(const string segment)
     {
      string escaped=segment;
      StringReplace(escaped,"%","%25");
      StringReplace(escaped,".","%2E");
      return(escaped);
     }

   bool IsPrimaryContext(const SRuntimeContextId &context_id)
     {
      return(m_primary_context_configured &&
             RuntimeContextEquals(m_primary_context,context_id));
     }

   int RequiredNewEntries(const string first_key,const string second_key="")
     {
      int required=0;
      if(StringLen(first_key)>0 && FindIndex(first_key)<0)
         required++;
      if(StringLen(second_key)>0 && second_key!=first_key && FindIndex(second_key)<0)
         required++;
      return(required);
     }

   bool ParseBooleanText(const string text,bool &value)
     {
      if(text=="true" || text=="TRUE")
        {
         value=true;
         return(true);
        }
      if(text=="false" || text=="FALSE")
        {
         value=false;
         return(true);
        }
      return(false);
     }

public:
                     CDataBus(void)
     {
      m_primary_context.symbol="";
      m_primary_context.timeframe=PERIOD_CURRENT;
      m_primary_context_configured=false;
      m_legacy_alias_write_enabled=false;
      m_legacy_fallback_read_enabled=false;
      m_legacy_alias_write_count=0;
      m_legacy_fallback_read_count=0;
     }

   //--- Produces the canonical namespace.symbol.timeframe.field identity.
   //--- Segment escaping prevents broker suffixes such as EURUSD.a from being
   //--- confused with a key delimiter; no key parser is required by DataBus.
   string BuildContextKey(const string name_space,
                          const SRuntimeContextId &context_id,
                          const string field)
     {
      if(StringLen(name_space)==0 || StringLen(field)==0 ||
         !IsValidRuntimeContextId(context_id))
         return("");

      return(EscapeKeySegment(name_space)+"."+
             EscapeKeySegment(context_id.symbol)+"."+
             RuntimeContextTimeframeName(context_id.timeframe)+"."+
             EscapeKeySegment(field));
     }

   //--- Produces a namespace.field key for portfolio/system-wide facts.
   string BuildGlobalKey(const string name_space,const string field)
     {
      if(StringLen(name_space)==0 || StringLen(field)==0)
         return("");

      return(EscapeKeySegment(name_space)+"."+EscapeKeySegment(field));
     }

   //--- Enables temporary primary-context compatibility. Secondary contexts
   //--- never qualify for alias writes or legacy fallback reads.
   bool ConfigureLegacyAlias(const SRuntimeContextId &primary_context,
                             const bool alias_write_enabled,
                             const bool fallback_read_enabled)
     {
      if(!IsValidRuntimeContextId(primary_context) ||
         (fallback_read_enabled && !alias_write_enabled))
         return(false);

      m_primary_context=primary_context;
      m_primary_context_configured=true;
      m_legacy_alias_write_enabled=alias_write_enabled;
      m_legacy_fallback_read_enabled=fallback_read_enabled;
      return(true);
     }

   void DisableLegacyAlias(void)
     {
      m_legacy_alias_write_enabled=false;
      m_legacy_fallback_read_enabled=false;
     }

   bool LegacyAliasWriteEnabled(void)
     {
      return(m_legacy_alias_write_enabled);
     }

   bool LegacyFallbackReadEnabled(void)
     {
      return(m_legacy_fallback_read_enabled);
     }

   long LegacyAliasWriteCount(void)
     {
      return(m_legacy_alias_write_count);
     }

   long LegacyFallbackReadCount(void)
     {
      return(m_legacy_fallback_read_count);
     }

   bool SetText(const string key,const string value)
     {
      if(StringLen(key)==0)
        {
         CLogger::Warning("DataBus rejected an empty key.");
         return(false);
        }

      int index=FindIndex(key);
      if(index<0)
        {
         const int item_count=ArraySize(m_items);
         if(item_count>=Capacity())
           {
            CLogger::Error("DataBus capacity has been reached.");
            return(false);
           }

         if(ArrayResize(m_items,item_count+1)!=(item_count+1))
           {
            CLogger::Error("DataBus could not allocate a new entry.");
            return(false);
           }

         index=item_count;
         m_items[index].key=key;
        }

      m_items[index].value=value;
      m_items[index].updated_at=TimeCurrent();
      return(true);
     }

   bool TryGetText(const string key,string &value)
     {
      const int index=FindIndex(key);
      if(index<0)
         return(false);

      value=m_items[index].value;
      return(true);
     }

   bool SetSymbolText(const string name_space,const string symbol,const string field,
                      const string value)
     {
      const string key=BuildSymbolKey(name_space,symbol,field);
      if(StringLen(key)==0)
        {
         CLogger::Warning("DataBus rejected an incomplete per-symbol key.");
         return(false);
        }

      return(SetText(key,value));
     }

   bool TryGetSymbolText(const string name_space,const string symbol,const string field,
                         string &value)
     {
      const string key=BuildSymbolKey(name_space,symbol,field);
      if(StringLen(key)==0)
         return(false);

      return(TryGetText(key,value));
     }

   //--- Stores a canonical context value and, only for the configured primary
   //--- context, optionally mirrors it to the existing per-symbol legacy key.
   bool SetContextText(const string name_space,const SRuntimeContextId &context_id,
                       const string field,const string value)
     {
      const string context_key=BuildContextKey(name_space,context_id,field);
      if(StringLen(context_key)==0)
        {
         CLogger::Warning("DataBus rejected an invalid context key.");
         return(false);
        }

      const bool write_legacy=(m_legacy_alias_write_enabled &&
                               IsPrimaryContext(context_id));
      const string legacy_key=(write_legacy ?
         BuildSymbolKey(name_space,context_id.symbol,field) : "");
      if(!CanReserve(RequiredNewEntries(context_key,legacy_key)))
        {
         CLogger::Error("DataBus capacity cannot satisfy a context write.");
         return(false);
        }

      if(!SetText(context_key,value))
         return(false);
      if(write_legacy)
        {
         if(!SetText(legacy_key,value))
            return(false);
         m_legacy_alias_write_count++;
        }
      return(true);
     }

   //--- Reads the canonical key first. A legacy read is possible only for the
   //--- configured primary context, so secondary contexts cannot cross-read it.
   bool TryGetContextText(const string name_space,const SRuntimeContextId &context_id,
                          const string field,string &value)
     {
      const string context_key=BuildContextKey(name_space,context_id,field);
      if(StringLen(context_key)==0)
         return(false);
      if(TryGetText(context_key,value))
         return(true);

      if(!m_legacy_fallback_read_enabled || !IsPrimaryContext(context_id))
         return(false);

      if(!TryGetSymbolText(name_space,context_id.symbol,field,value))
         return(false);
      m_legacy_fallback_read_count++;
      return(true);
     }

   bool SetContextInt(const string name_space,const SRuntimeContextId &context_id,
                      const string field,const long value)
     {
      return(SetContextText(name_space,context_id,field,IntegerToString(value)));
     }

   bool TryGetContextInt(const string name_space,const SRuntimeContextId &context_id,
                         const string field,long &value)
     {
      string text="";
      if(!TryGetContextText(name_space,context_id,field,text) || StringLen(text)==0)
         return(false);
      value=StringToInteger(text);
      return(true);
     }

   bool SetContextDouble(const string name_space,const SRuntimeContextId &context_id,
                         const string field,const double value)
     {
      return(SetContextText(name_space,context_id,field,DoubleToString(value,16)));
     }

   bool TryGetContextDouble(const string name_space,const SRuntimeContextId &context_id,
                            const string field,double &value)
     {
      string text="";
      if(!TryGetContextText(name_space,context_id,field,text) || StringLen(text)==0)
         return(false);
      value=StringToDouble(text);
      return(true);
     }

   bool SetContextBool(const string name_space,const SRuntimeContextId &context_id,
                       const string field,const bool value)
     {
      return(SetContextText(name_space,context_id,field,(value ? "true" : "false")));
     }

   bool TryGetContextBool(const string name_space,const SRuntimeContextId &context_id,
                          const string field,bool &value)
     {
      string text="";
      return(TryGetContextText(name_space,context_id,field,text) &&
             ParseBooleanText(text,value));
     }

   bool SetGlobalText(const string name_space,const string field,const string value)
     {
      const string key=BuildGlobalKey(name_space,field);
      return(StringLen(key)>0 && SetText(key,value));
     }

   bool TryGetGlobalText(const string name_space,const string field,string &value)
     {
      const string key=BuildGlobalKey(name_space,field);
      return(StringLen(key)>0 && TryGetText(key,value));
     }

   bool SetGlobalInt(const string name_space,const string field,const long value)
     {
      return(SetGlobalText(name_space,field,IntegerToString(value)));
     }

   bool TryGetGlobalInt(const string name_space,const string field,long &value)
     {
      string text="";
      if(!TryGetGlobalText(name_space,field,text) || StringLen(text)==0)
         return(false);
      value=StringToInteger(text);
      return(true);
     }

   bool SetGlobalDouble(const string name_space,const string field,const double value)
     {
      return(SetGlobalText(name_space,field,DoubleToString(value,16)));
     }

   bool TryGetGlobalDouble(const string name_space,const string field,double &value)
     {
      string text="";
      if(!TryGetGlobalText(name_space,field,text) || StringLen(text)==0)
         return(false);
      value=StringToDouble(text);
      return(true);
     }

   bool SetGlobalBool(const string name_space,const string field,const bool value)
     {
      return(SetGlobalText(name_space,field,(value ? "true" : "false")));
     }

   bool TryGetGlobalBool(const string name_space,const string field,bool &value)
     {
      string text="";
      return(TryGetGlobalText(name_space,field,text) &&
             ParseBooleanText(text,value));
     }

   bool Contains(const string key)
     {
      return(FindIndex(key)>=0);
     }

   //--- Returns the logical safety guard. The dynamic array is not pre-sized.
   int Capacity(void)
     {
      return(FENX_DATABUS_CAPACITY);
     }

   //--- Returns only entries currently stored in the dynamic array.
   int CurrentSize(void)
     {
      return(ArraySize(m_items));
     }

   //--- Returns the number of additional unique keys that can be accepted.
   int RemainingCapacity(void)
     {
      const int remaining=Capacity()-CurrentSize();
      return(remaining>0 ? remaining : 0);
     }

   //--- Tests an additional unique-key reservation without allocating memory.
   bool CanReserve(const int required_entries)
     {
      return(required_entries>=0 && required_entries<=RemainingCapacity());
     }

   //--- Compatibility-friendly alias for capacity planning callers.
   bool HasCapacityFor(const int required_entries)
     {
      return(CanReserve(required_entries));
     }

   int Count(void)
     {
      return(CurrentSize());
     }

   void Clear(void)
     {
      ArrayFree(m_items);
      m_legacy_alias_write_count=0;
      m_legacy_fallback_read_count=0;
     }
  };

#endif // FENX_CORE_DATA_BUS_MQH

