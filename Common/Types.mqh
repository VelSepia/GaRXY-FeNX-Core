//+------------------------------------------------------------------+
//|                                             Common/Types.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_TYPES_MQH
#define FENX_COMMON_TYPES_MQH

//--- High-level lifecycle states for the Expert Advisor.
enum ENUM_FENX_STATE
  {
   FENX_STATE_INIT = 0,
   FENX_STATE_NORMAL,
   FENX_STATE_STANDBY,
   FENX_STATE_DYNAMIC_ZONE,
   FENX_STATE_RISK_STOP,
   FENX_STATE_SHUTDOWN
  };

//--- Log severity used by the shared logger.
enum ENUM_FENX_LOG_LEVEL
  {
   FENX_LOG_INFO = 0,
   FENX_LOG_WARNING,
   FENX_LOG_ERROR
  };

//--- Stable identity for one market-data and trading runtime context.
//--- PERIOD_CURRENT is intentionally not accepted: a stored identity must not
//--- change when an EA is attached to a different chart timeframe.
struct SRuntimeContextId
  {
   string          symbol;
   ENUM_TIMEFRAMES timeframe;
  };

//--- Defines the bounded role a runtime context can have. Task026 permits
//--- trading only through the single primary context; auxiliary contexts are
//--- retained for future analysis-pipeline promotion and do not trade.
enum ENUM_FENX_CONTEXT_ROLE
  {
   FENX_CONTEXT_ROLE_PRIMARY_TRADING = 0,
   FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS
  };

//--- Formal immutable-at-runtime configuration for one Symbol+Timeframe
//--- context. Runtime ownership belongs to CRuntimeContextRegistry; this value
//--- object is safe for ParameterManager and harnesses to copy.
struct SRuntimeContextConfig
  {
   SRuntimeContextId     id;
   bool                  enabled;
   bool                  required;
   bool                  trade_enabled;
   ENUM_FENX_CONTEXT_ROLE role;
   long                  magic;
   string                parameter_profile_id;
  };

//--- Establishes an explicitly invalid, disabled configuration. Callers must
//--- fill every required field before attempting registry initialization.
void ResetRuntimeContextConfig(SRuntimeContextConfig &config)
  {
   config.id.symbol="";
   config.id.timeframe=PERIOD_CURRENT;
   config.enabled=false;
   config.required=false;
   config.trade_enabled=false;
   config.role=FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS;
   config.magic=0;
   config.parameter_profile_id="";
  }

//--- Role validation is intentionally independent from broker availability so
//--- deterministic synthetic-context tests do not require Market Watch state.
bool IsValidRuntimeContextRole(const ENUM_FENX_CONTEXT_ROLE role)
  {
   return(role==FENX_CONTEXT_ROLE_PRIMARY_TRADING ||
          role==FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS);
  }

//--- Returns the explicit, human-readable timeframe token used in context keys.
string RuntimeContextTimeframeName(const ENUM_TIMEFRAMES timeframe)
  {
   if(timeframe==PERIOD_CURRENT || PeriodSeconds(timeframe)<=0)
      return("");

   const string enum_name=EnumToString(timeframe);
   const string prefix="PERIOD_";
   if(StringFind(enum_name,prefix)!=0 || StringLen(enum_name)<=StringLen(prefix))
      return("");

   return(StringSubstr(enum_name,StringLen(prefix)));
  }

//--- Rejects incomplete or chart-relative identities before they reach stores.
bool IsValidRuntimeContextId(const SRuntimeContextId &context_id)
  {
   return(StringLen(context_id.symbol)>0 &&
          StringLen(RuntimeContextTimeframeName(context_id.timeframe))>0);
  }

//--- Context equality always includes both symbol and explicit timeframe.
bool RuntimeContextEquals(const SRuntimeContextId &left,
                          const SRuntimeContextId &right)
  {
   return(left.symbol==right.symbol && left.timeframe==right.timeframe);
  }

//--- Diagnostic representation; DataBus keys are built by CDataBus instead.
string RuntimeContextToString(const SRuntimeContextId &context_id)
  {
   if(!IsValidRuntimeContextId(context_id))
      return("");

   return(context_id.symbol+" "+RuntimeContextTimeframeName(context_id.timeframe));
  }

//--- A lightweight shared-data entry. Typed payloads can be added later.
struct SDataBusItem
  {
   string   key;
   string   value;
   datetime updated_at;
  };

#endif // FENX_COMMON_TYPES_MQH

