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
   bool              m_context_view_active;
   SRuntimeContextId m_context_view_id;
   long              m_context_view_wrong_symbol_count;
   long              m_legacy_write_attempt_count;
   long              m_legacy_read_attempt_count;

   bool RawSetText(const string key,const string value)
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

   bool RawTryGetText(const string key,string &value)
     {
      const int index=FindIndex(key);
      if(index<0)
         return(false);
      value=m_items[index].value;
      return(true);
     }

   //--- Resolves the established field constants used by context-bound engines.
   //--- Storage always uses the canonical namespace.symbol.timeframe.field key.
   bool MapContextField(const string key,string &name_space,string &field)
     {
      string prefix="";
      if(StringFind(key,"Environment.Volatility.")==0)
        {
         name_space=FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY;
         prefix="Environment.Volatility.";
        }
      else if(StringFind(key,"Environment.Range.")==0)
        {
         name_space=FENX_DATABUS_NAMESPACE_CONTEXT_RANGE;
         prefix="Environment.Range.";
        }
      else if(StringFind(key,"Environment.Trend.")==0)
        {
         name_space=FENX_DATABUS_NAMESPACE_CONTEXT_TREND;
         prefix="Environment.Trend.";
        }
      else if(StringFind(key,"Environment.Market.")==0)
        {
         name_space=FENX_DATABUS_NAMESPACE_CONTEXT_MARKET;
         prefix="Environment.Market.";
        }
      else if(StringFind(key,"PairRanking.")==0)
        {
         name_space=FENX_DATABUS_NAMESPACE_CONTEXT_PAIR_RANKING_GLOBAL;
         prefix="PairRanking.";
        }
      else if(StringFind(key,"CapitalAllocation.")==0)
        {
         name_space=FENX_DATABUS_NAMESPACE_CONTEXT_CAPITAL_ALLOCATION_GLOBAL;
         prefix="CapitalAllocation.";
        }
      else if(StringFind(key,"TradingStyle.")==0)
        {
         name_space=FENX_DATABUS_NAMESPACE_CONTEXT_TRADING_STYLE_GLOBAL;
         prefix="TradingStyle.";
        }
      else if(StringFind(key,"StrategySelection.")==0)
        {
         name_space=FENX_DATABUS_NAMESPACE_CONTEXT_STRATEGY_SELECTION_GLOBAL;
         prefix="StrategySelection.";
        }
      else if(StringFind(key,"Standby.")==0)
        {
         name_space=FENX_DATABUS_NAMESPACE_CONTEXT_STANDBY_GLOBAL;
         prefix="Standby.";
        }
      else if(StringFind(key,"Risk.")==0)
        {
         name_space=FENX_DATABUS_NAMESPACE_CONTEXT_RISK_GLOBAL;
         prefix="Risk.";
        }
      else if(StringFind(key,"Execution.")==0)
        {
         name_space=FENX_DATABUS_NAMESPACE_CONTEXT_EXECUTION_GLOBAL;
         prefix="Execution.";
        }
      else
         return(false);

      field=StringSubstr(key,StringLen(prefix));
      return(StringLen(field)>0);
     }

   bool RawSetContextText(const string name_space,
                          const SRuntimeContextId &context_id,
                          const string field,const string value)
     {
      const string key=BuildContextKey(name_space,context_id,field);
      return(StringLen(key)>0 && RawSetText(key,value));
     }

   bool RawTryGetContextText(const string name_space,
                             const SRuntimeContextId &context_id,
                             const string field,string &value)
     {
      const string key=BuildContextKey(name_space,context_id,field);
      return(StringLen(key)>0 && RawTryGetText(key,value));
     }

   int FindIndex(const string key)
     {
      for(int index=0;index<ArraySize(m_items);index++)
        {
         if(m_items[index].key==key)
            return(index);
        }

      return(-1);
     }

   int DelimiterCount(const string key)
     {
      int count=0;
      for(int index=0;index<StringLen(key);index++)
         if(StringGetCharacter(key,index)=='.') count++;
      return(count);
     }

   bool IsGlobalSchemaKey(const string key)
     {
      const int length=StringLen(key);
      return(length>2 && StringSubstr(key,0,1)!="." &&
             StringSubstr(key,length-1,1)!="." && DelimiterCount(key)==1);
     }

   //--- Escapes only the key delimiter and the escape marker.
   string EscapeKeySegment(const string segment)
     {
      string escaped=segment;
      StringReplace(escaped,"%","%25");
      StringReplace(escaped,".","%2E");
      return(escaped);
     }

   int RequiredNewEntries(const string key)
     {
      return(StringLen(key)>0 && FindIndex(key)<0 ? 1 : 0);
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
      m_context_view_active=false;
      m_context_view_id.symbol="";
      m_context_view_id.timeframe=PERIOD_CURRENT;
      m_context_view_wrong_symbol_count=0;
      m_legacy_write_attempt_count=0;
      m_legacy_read_attempt_count=0;
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

   bool SetText(const string key,const string value)
     {
      if(m_context_view_active)
        {
         string name_space="";
         string field="";
         if(MapContextField(key,name_space,field))
            return(RawSetContextText(name_space,m_context_view_id,field,value));
        }
      if(IsGlobalSchemaKey(key))
         return(RawSetText(key,value));
      m_legacy_write_attempt_count++;
      return(false);
     }

   bool TryGetText(const string key,string &value)
     {
      if(m_context_view_active)
        {
         string name_space="";
         string field="";
         if(MapContextField(key,name_space,field))
            return(RawTryGetContextText(name_space,m_context_view_id,field,value));
        }
      if(IsGlobalSchemaKey(key))
         return(RawTryGetText(key,value));
      m_legacy_read_attempt_count++;
      return(false);
     }

   bool SetSymbolText(const string name_space,const string symbol,const string field,
                      const string value)
     {
      if(m_context_view_active)
        {
         if(symbol!=m_context_view_id.symbol)
           {
            m_context_view_wrong_symbol_count++;
            return(false);
           }
         return(RawSetContextText(name_space,m_context_view_id,field,value));
        }
      m_legacy_write_attempt_count++;
      return(false);
     }

   bool TryGetSymbolText(const string name_space,const string symbol,const string field,
                         string &value)
     {
      if(m_context_view_active)
        {
         if(symbol!=m_context_view_id.symbol)
           {
            m_context_view_wrong_symbol_count++;
            return(false);
           }
         return(RawTryGetContextText(name_space,m_context_view_id,field,value));
        }
      m_legacy_read_attempt_count++;
      return(false);
     }

   //--- EngineManager activates this view only for Task029 context instances.
   //--- It is deliberately non-nestable so an early lifecycle error cannot
   //--- silently redirect a following context-bound engine.
   bool BeginContextView(const SRuntimeContextId &context_id)
     {
      if(m_context_view_active || !IsValidRuntimeContextId(context_id))
         return(false);
      m_context_view_id=context_id;
      m_context_view_active=true;
      return(true);
     }

   void EndContextView(void)
     {
      m_context_view_active=false;
      m_context_view_id.symbol="";
      m_context_view_id.timeframe=PERIOD_CURRENT;
     }

   bool ContextViewActive(void) { return(m_context_view_active); }

   bool GetActiveContextId(SRuntimeContextId &context_id)
     {
      if(!m_context_view_active)
         return(false);
      context_id=m_context_view_id;
      return(true);
     }

   long ContextViewWrongSymbolCount(void)
     {
      return(m_context_view_wrong_symbol_count);
     }

   //--- Stores exactly one canonical context value. Task032 permanently
   //--- removes primary alias writes and all legacy fallback behavior.
   bool SetContextText(const string name_space,const SRuntimeContextId &context_id,
                       const string field,const string value)
     {
      const string context_key=BuildContextKey(name_space,context_id,field);
      if(StringLen(context_key)==0)
        {
         CLogger::Warning("DataBus rejected an invalid context key.");
         return(false);
        }

      if(!CanReserve(RequiredNewEntries(context_key)))
        {
         CLogger::Error("DataBus capacity cannot satisfy a context write.");
         return(false);
        }

      return(RawSetText(context_key,value));
     }

   //--- Reads only the canonical key. Missing context data fails closed.
   bool TryGetContextText(const string name_space,const SRuntimeContextId &context_id,
                          const string field,string &value)
     {
      const string context_key=BuildContextKey(name_space,context_id,field);
      if(StringLen(context_key)==0)
         return(false);
      return(RawTryGetText(context_key,value));
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

   //--- Task032 schema audit. Canonical context keys have three delimiters;
   //--- formal global keys have one. Two-delimiter keys are retired aliases.
   int LegacySchemaKeyCount(void)
     {
      int count=0;
      for(int index=0;index<ArraySize(m_items);index++)
         if(DelimiterCount(m_items[index].key)==2) count++;
      return(count);
     }

   int InvalidSchemaKeyCount(void)
     {
      int count=0;
      for(int index=0;index<ArraySize(m_items);index++)
        {
         const int delimiters=DelimiterCount(m_items[index].key);
         if(delimiters!=1 && delimiters!=3) count++;
        }
      return(count);
     }

   long LegacyWriteAttemptCount(void) { return(m_legacy_write_attempt_count); }
   long LegacyReadAttemptCount(void) { return(m_legacy_read_attempt_count); }

   void Clear(void)
     {
      ArrayFree(m_items);
      m_context_view_active=false;
      m_context_view_id.symbol="";
      m_context_view_id.timeframe=PERIOD_CURRENT;
      m_context_view_wrong_symbol_count=0;
      m_legacy_write_attempt_count=0;
      m_legacy_read_attempt_count=0;
     }
  };

#endif // FENX_CORE_DATA_BUS_MQH

