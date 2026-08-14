//+------------------------------------------------------------------+
//|                                  Execution/ExecutionGate.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_EXECUTION_GATE_MQH
#define FENX_EXECUTION_GATE_MQH

#include "../Common/Constants.mqh"
#include "../Core/DataBus.mqh"
#include "../Core/StateManager.mqh"

//--- Ordered stages used only to report where a new-entry evaluation stopped.
enum ENUM_FENX_PIPELINE_STAGE
  {
   FENX_PIPELINE_ENVIRONMENT = 0,
   FENX_PIPELINE_MARKET_SELECTION,
   FENX_PIPELINE_PAIR_RANKING,
   FENX_PIPELINE_CAPITAL_ALLOCATION,
   FENX_PIPELINE_TRADING_STYLE,
   FENX_PIPELINE_STRATEGY_SELECTION,
   FENX_PIPELINE_STANDBY,
   FENX_PIPELINE_RISK,
   FENX_PIPELINE_EXECUTION,
   FENX_PIPELINE_STAGE_COUNT
  };

//--- Stable human-readable stage labels for tester logs and summaries.
string FenxPipelineStageName(const ENUM_FENX_PIPELINE_STAGE stage)
  {
   switch(stage)
     {
      case FENX_PIPELINE_ENVIRONMENT:        return("Environment");
      case FENX_PIPELINE_MARKET_SELECTION:   return("MarketSelection");
      case FENX_PIPELINE_PAIR_RANKING:       return("PairRanking");
      case FENX_PIPELINE_CAPITAL_ALLOCATION: return("CapitalAllocation");
      case FENX_PIPELINE_TRADING_STYLE:      return("TradingStyle");
      case FENX_PIPELINE_STRATEGY_SELECTION: return("StrategySelection");
      case FENX_PIPELINE_STANDBY:            return("Standby");
      case FENX_PIPELINE_RISK:               return("Risk");
      case FENX_PIPELINE_EXECUTION:          return("Execution");
      default:                               return("Unknown");
     }
  }

//--- Final non-executable permission returned to the execution lifecycle.
struct SExecutionGateResult
  {
   bool                     allowed;
   bool                     data_valid;
   double                   allocation_multiplier;
   string                   reason;
   ENUM_FENX_PIPELINE_STAGE stop_stage;
   string                   stage_reason;
   string                   pipeline_trace;

   //--- Task018 observations of the existing ordered gates. These flags are
   //--- assigned only beside the established PASS branches and never consumed
   //--- by the permission calculation.
   bool                     market_selection_allowed;
   bool                     ranking_allowed;
   bool                     allocation_allowed;
   bool                     trading_style_allowed;
   bool                     strategy_selection_allowed;
   bool                     standby_allowed;
   bool                     risk_allowed;
   bool                     execution_gate_allowed;
  };

//--- Reads final DataBus permissions and state before a strategy may create an order request.
class CExecutionGate
  {
private:
   CDataBus      *m_data_bus;
   CStateManager *m_state_manager;
   string         m_symbol;
   bool           m_execution_enabled;
   double         m_maximum_spread_points;
   double         m_minimum_range_score;
   double         m_minimum_strategy_confidence;
   double         m_minimum_risk_confidence;
   int            m_stale_data_limit_seconds;

   bool ReadBooleanText(const string text,bool &value)
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

   bool ReadBoolean(const string key,bool &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      return(m_data_bus.TryGetText(key,text) && ReadBooleanText(text,value));
     }

   bool ReadDouble(const string key,double &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      if(!m_data_bus.TryGetText(key,text) || StringLen(text)==0)
         return(false);
      value=StringToDouble(text);
      return(true);
     }

   bool ReadTimestampText(const string text,datetime &value)
     {
      if(StringLen(text)==0)
         return(false);
      value=StringToTime(text);
      return(value>0);
     }

   bool ReadTimestamp(const string key,datetime &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      return(m_data_bus.TryGetText(key,text) && ReadTimestampText(text,value));
     }

   bool ReadSymbolBoolean(const string name_space,const string field,bool &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      return(m_data_bus.TryGetSymbolText(name_space,m_symbol,field,text) &&
             ReadBooleanText(text,value));
     }

   bool ReadSymbolDouble(const string name_space,const string field,double &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      if(!m_data_bus.TryGetSymbolText(name_space,m_symbol,field,text) || StringLen(text)==0)
         return(false);
      value=StringToDouble(text);
      return(true);
     }

   bool ReadSymbolTimestamp(const string name_space,const string field,datetime &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      return(m_data_bus.TryGetSymbolText(name_space,m_symbol,field,text) &&
             ReadTimestampText(text,value));
     }

   bool IsFresh(const datetime timestamp)
     {
      if(timestamp<=0 || m_stale_data_limit_seconds<=0)
         return(false);
      const long age=(long)(TimeCurrent()-timestamp);
      return(age>=0 && age<=m_stale_data_limit_seconds);
     }

   void ResetResult(SExecutionGateResult &result)
     {
      result.allowed=false;
      result.data_valid=false;
      result.allocation_multiplier=0.0;
      result.reason="Execution Gate has not received valid data.";
      result.stop_stage=FENX_PIPELINE_EXECUTION;
      result.stage_reason=result.reason;
      result.pipeline_trace="";
      result.market_selection_allowed=false;
      result.ranking_allowed=false;
      result.allocation_allowed=false;
      result.trading_style_allowed=false;
      result.strategy_selection_allowed=false;
      result.standby_allowed=false;
      result.risk_allowed=false;
      result.execution_gate_allowed=false;
     }

   //--- Adds a successful stage to the compact tester trace.
   void AppendPass(string &trace,const ENUM_FENX_PIPELINE_STAGE stage)
     {
      if(StringLen(trace)>0)
         trace+=";";
      trace+=FenxPipelineStageName(stage)+"=PASS";
     }

   //--- Records an exact stop without changing the gate's existing public reason.
   void SetStop(SExecutionGateResult &result,const ENUM_FENX_PIPELINE_STAGE stage,
                const string stage_reason,const string trace)
     {
      result.stop_stage=stage;
      result.stage_reason=stage_reason;
      result.pipeline_trace=trace;
      if(StringLen(result.pipeline_trace)>0)
         result.pipeline_trace+=";";
      result.pipeline_trace+=FenxPipelineStageName(stage)+"=BLOCK("+stage_reason+")";
     }

public:
                     CExecutionGate(void)
     {
      m_data_bus=NULL;
      m_state_manager=NULL;
      m_symbol="";
      m_execution_enabled=false;
      m_maximum_spread_points=0.0;
      m_minimum_range_score=0.0;
      m_minimum_strategy_confidence=0.0;
      m_minimum_risk_confidence=0.0;
      m_stale_data_limit_seconds=0;
     }

   void              Configure(CDataBus &data_bus,CStateManager *state_manager,
                               const string symbol,const bool execution_enabled,
                               const double maximum_spread_points,
                               const double minimum_range_score,
                               const double minimum_strategy_confidence,
                               const double minimum_risk_confidence,
                               const int stale_data_limit_seconds)
     {
      m_data_bus=GetPointer(data_bus);
      m_state_manager=state_manager;
      m_symbol=symbol;
      m_execution_enabled=execution_enabled;
      m_maximum_spread_points=maximum_spread_points;
      m_minimum_range_score=minimum_range_score;
      m_minimum_strategy_confidence=minimum_strategy_confidence;
      m_minimum_risk_confidence=minimum_risk_confidence;
      m_stale_data_limit_seconds=stale_data_limit_seconds;
     }

   bool              Evaluate(const double spread_points,SExecutionGateResult &result)
     {
      ResetResult(result);
      if(m_data_bus==NULL || m_state_manager==NULL)
        {
         result.reason="Execution Gate is not initialized.";
         SetStop(result,FENX_PIPELINE_EXECUTION,result.reason,"");
         return(false);
        }
      if(!m_execution_enabled)
        {
         result.reason="Execution is disabled by configuration.";
         SetStop(result,FENX_PIPELINE_EXECUTION,result.reason,"");
         return(false);
        }
      if(m_symbol!="USDJPY")
        {
         result.reason="Minimal execution supports USDJPY only.";
         SetStop(result,FENX_PIPELINE_EXECUTION,result.reason,"");
         return(false);
        }
      if(m_state_manager.GetState()!=FENX_STATE_NORMAL)
        {
         result.reason="Framework state is not NORMAL.";
         SetStop(result,FENX_PIPELINE_RISK,result.reason,"");
         return(false);
        }
      if(spread_points<0.0 || spread_points>m_maximum_spread_points)
        {
         result.reason="Current spread exceeds the execution limit.";
         SetStop(result,FENX_PIPELINE_EXECUTION,result.reason,"");
         return(false);
        }

      bool eligible=false,ranked=false,allocated=false,style_valid=false,strategy_valid=false;
      bool range_data_valid=false;
      bool standby_active=false,standby_entries_allowed=false,standby_data_valid=false;
      bool risk_approved=false,risk_entries_approved=false,risk_data_valid=false;
      bool ranking_data_valid=false,allocation_data_valid=false,style_data_valid=false;
      bool strategy_data_valid=false,standby_system_valid=false,risk_system_valid=false;
      bool system_trading_allowed=false,system_entries_allowed=false;
      double range_score=0.0,strategy_confidence=0.0,risk_confidence=0.0;
      double symbol_multiplier=0.0,system_multiplier=0.0;
      string market_state="",trading_style="",selected_strategy="",risk_action="";
      datetime market_updated=0,range_updated=0,selection_updated=0,ranking_updated=0;
      datetime allocation_updated=0,style_updated=0,strategy_updated=0,standby_updated=0;
      datetime risk_updated=0,risk_system_updated=0;

      const bool environment_complete=
         (m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE,market_state) &&
          ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,range_score) &&
          ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,range_data_valid) &&
          ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT,market_updated) &&
          ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPDATED_AT,range_updated));
      const bool market_selection_complete=
         (ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,
                            FENX_DATABUS_FIELD_MARKET_SELECTION_IS_ELIGIBLE,eligible) &&
          ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,
                              FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT,selection_updated));
      const bool pair_ranking_complete=
         (ReadBoolean(FENX_DATABUS_KEY_PAIR_RANKING_DATA_VALID,ranking_data_valid) &&
          ReadTimestamp(FENX_DATABUS_KEY_PAIR_RANKING_UPDATED_AT,ranking_updated) &&
          ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_PAIR_RANKING,
                            FENX_DATABUS_FIELD_PAIR_RANKING_IS_RANKED,ranked));
      const bool capital_allocation_complete=
         (ReadBoolean(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_DATA_VALID,allocation_data_valid) &&
          ReadTimestamp(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_UPDATED_AT,allocation_updated) &&
          ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,
                            FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_IS_ALLOCATED,allocated));
      const bool trading_style_complete=
         (ReadBoolean(FENX_DATABUS_KEY_TRADING_STYLE_DATA_VALID,style_data_valid) &&
          ReadTimestamp(FENX_DATABUS_KEY_TRADING_STYLE_UPDATED_AT,style_updated) &&
          m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_TRADING_STYLE,m_symbol,
                                      FENX_DATABUS_FIELD_TRADING_STYLE,trading_style) &&
          ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_TRADING_STYLE,
                            FENX_DATABUS_FIELD_TRADING_STYLE_IS_VALID,style_valid));
      const bool strategy_selection_complete=
         (ReadBoolean(FENX_DATABUS_KEY_STRATEGY_SELECTION_DATA_VALID,strategy_data_valid) &&
          ReadTimestamp(FENX_DATABUS_KEY_STRATEGY_SELECTION_UPDATED_AT,strategy_updated) &&
          m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,m_symbol,
                                      FENX_DATABUS_FIELD_SELECTED_STRATEGY,selected_strategy) &&
          ReadSymbolDouble(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,
                           FENX_DATABUS_FIELD_STRATEGY_SELECTION_CONFIDENCE,
                           strategy_confidence) &&
          ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,
                            FENX_DATABUS_FIELD_STRATEGY_SELECTION_IS_VALID,strategy_valid));
      const bool standby_complete=
         (ReadBoolean(FENX_DATABUS_KEY_STANDBY_SYSTEM_VALID,standby_system_valid) &&
          ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STANDBY,
                            FENX_DATABUS_FIELD_STANDBY_IS_ACTIVE,standby_active) &&
          ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STANDBY,
                            FENX_DATABUS_FIELD_STANDBY_NEW_ENTRIES_ALLOWED,
                            standby_entries_allowed) &&
          ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STANDBY,
                            FENX_DATABUS_FIELD_STANDBY_DATA_VALID,standby_data_valid) &&
          ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_STANDBY,
                              FENX_DATABUS_FIELD_STANDBY_UPDATED_AT,standby_updated));
      const bool risk_complete=
         (ReadBoolean(FENX_DATABUS_KEY_RISK_SYSTEM_DATA_VALID,risk_system_valid) &&
          ReadBoolean(FENX_DATABUS_KEY_RISK_SYSTEM_TRADING_ALLOWED,system_trading_allowed) &&
          ReadBoolean(FENX_DATABUS_KEY_RISK_SYSTEM_NEW_ENTRIES_ALLOWED,
                      system_entries_allowed) &&
          ReadDouble(FENX_DATABUS_KEY_RISK_SYSTEM_ALLOCATION_MULTIPLIER,system_multiplier) &&
          ReadTimestamp(FENX_DATABUS_KEY_RISK_SYSTEM_UPDATED_AT,risk_system_updated) &&
          ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_RISK,
                            FENX_DATABUS_FIELD_IS_RISK_APPROVED,risk_approved) &&
          ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_RISK,
                            FENX_DATABUS_FIELD_NEW_ENTRIES_RISK_APPROVED,
                            risk_entries_approved) &&
          ReadSymbolDouble(FENX_DATABUS_NAMESPACE_RISK,
                           FENX_DATABUS_FIELD_RECOMMENDED_ALLOCATION_MULTIPLIER,
                           symbol_multiplier) &&
          ReadSymbolDouble(FENX_DATABUS_NAMESPACE_RISK,
                           FENX_DATABUS_FIELD_RISK_CONFIDENCE,risk_confidence) &&
          m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_RISK,m_symbol,
                                      FENX_DATABUS_FIELD_RISK_ACTION,risk_action) &&
          ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_RISK,
                            FENX_DATABUS_FIELD_RISK_DATA_VALID,risk_data_valid) &&
          ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_RISK,
                              FENX_DATABUS_FIELD_RISK_UPDATED_AT,risk_updated));
      const bool complete=(environment_complete && market_selection_complete &&
                           pair_ranking_complete && capital_allocation_complete &&
                           trading_style_complete && strategy_selection_complete &&
                           standby_complete && risk_complete);
      const bool environment_fresh=(IsFresh(market_updated) && IsFresh(range_updated));
      const bool market_selection_fresh=IsFresh(selection_updated);
      const bool pair_ranking_fresh=IsFresh(ranking_updated);
      const bool capital_allocation_fresh=IsFresh(allocation_updated);
      const bool trading_style_fresh=IsFresh(style_updated);
      const bool strategy_selection_fresh=IsFresh(strategy_updated);
      const bool standby_fresh=IsFresh(standby_updated);
      const bool risk_fresh=(IsFresh(risk_updated) && IsFresh(risk_system_updated));
      const bool fresh=(environment_fresh && market_selection_fresh && pair_ranking_fresh &&
                        capital_allocation_fresh && trading_style_fresh &&
                        strategy_selection_fresh && standby_fresh && risk_fresh);
      result.data_valid=(complete && fresh && ranking_data_valid && allocation_data_valid &&
                         style_data_valid && strategy_data_valid && standby_system_valid &&
                         risk_system_valid && standby_data_valid && risk_data_valid && range_data_valid &&
                         range_score>=m_minimum_range_score &&
                         strategy_confidence>=m_minimum_strategy_confidence &&
                         risk_confidence>=m_minimum_risk_confidence);

      string trace="";
      if(!environment_complete || !environment_fresh)
        {
         result.reason="Required final market, strategy, Standby, or Risk data is invalid or stale.";
         SetStop(result,FENX_PIPELINE_ENVIRONMENT,
                 "Environment data is incomplete or stale.",trace);
         return(false);
        }
      if(!range_data_valid || range_score<m_minimum_range_score)
        {
         result.reason="Required final market, strategy, Standby, or Risk data is invalid or stale.";
         SetStop(result,FENX_PIPELINE_ENVIRONMENT,
                 "Range data is invalid or below the execution threshold.",trace);
         return(false);
        }
      if(market_state!="RANGING")
        {
         result.reason="A final selection, Standby, or Risk permission blocks a new entry.";
         SetStop(result,FENX_PIPELINE_ENVIRONMENT,
                 "Market state is not RANGING.",trace);
         return(false);
        }
      AppendPass(trace,FENX_PIPELINE_ENVIRONMENT);

      if(!market_selection_complete || !market_selection_fresh)
        {
         result.reason="Required final market, strategy, Standby, or Risk data is invalid or stale.";
         SetStop(result,FENX_PIPELINE_MARKET_SELECTION,
                 "Market Selection data is incomplete or stale.",trace);
         return(false);
        }
      if(!eligible)
        {
         result.reason="A final selection, Standby, or Risk permission blocks a new entry.";
         SetStop(result,FENX_PIPELINE_MARKET_SELECTION,
                 "Market Selection rejected the symbol.",trace);
         return(false);
        }
      AppendPass(trace,FENX_PIPELINE_MARKET_SELECTION);
      result.market_selection_allowed=true;

      if(!pair_ranking_complete || !pair_ranking_fresh || !ranking_data_valid)
        {
         result.reason="Required final market, strategy, Standby, or Risk data is invalid or stale.";
         SetStop(result,FENX_PIPELINE_PAIR_RANKING,
                 "Pair Ranking data is invalid, incomplete, or stale.",trace);
         return(false);
        }
      if(!ranked)
        {
         result.reason="A final selection, Standby, or Risk permission blocks a new entry.";
         SetStop(result,FENX_PIPELINE_PAIR_RANKING,
                 "Pair Ranking did not rank the symbol.",trace);
         return(false);
        }
      AppendPass(trace,FENX_PIPELINE_PAIR_RANKING);
      result.ranking_allowed=true;

      if(!capital_allocation_complete || !capital_allocation_fresh || !allocation_data_valid)
        {
         result.reason="Required final market, strategy, Standby, or Risk data is invalid or stale.";
         SetStop(result,FENX_PIPELINE_CAPITAL_ALLOCATION,
                 "Capital Allocation data is invalid, incomplete, or stale.",trace);
         return(false);
        }
      if(!allocated)
        {
         result.reason="A final selection, Standby, or Risk permission blocks a new entry.";
         SetStop(result,FENX_PIPELINE_CAPITAL_ALLOCATION,
                 "Capital Allocation did not fund the symbol.",trace);
         return(false);
        }
      AppendPass(trace,FENX_PIPELINE_CAPITAL_ALLOCATION);
      result.allocation_allowed=true;

      if(!trading_style_complete || !trading_style_fresh || !style_data_valid || !style_valid)
        {
         result.reason="Required final market, strategy, Standby, or Risk data is invalid or stale.";
         SetStop(result,FENX_PIPELINE_TRADING_STYLE,
                 "Trading Style data is invalid, incomplete, or stale.",trace);
         return(false);
        }
      if(trading_style!="RANGE")
        {
         result.reason="A final selection, Standby, or Risk permission blocks a new entry.";
         SetStop(result,FENX_PIPELINE_TRADING_STYLE,
                 "Trading Style is not RANGE.",trace);
         return(false);
        }
      AppendPass(trace,FENX_PIPELINE_TRADING_STYLE);
      result.trading_style_allowed=true;

      if(!strategy_selection_complete || !strategy_selection_fresh || !strategy_data_valid ||
         !strategy_valid || strategy_confidence<m_minimum_strategy_confidence)
        {
         result.reason="Required final market, strategy, Standby, or Risk data is invalid or stale.";
         SetStop(result,FENX_PIPELINE_STRATEGY_SELECTION,
                 "Strategy Selection data is invalid, stale, or below confidence.",trace);
         return(false);
        }
      if(selected_strategy!="RANGE_MEAN_REVERSION")
        {
         result.reason="A final selection, Standby, or Risk permission blocks a new entry.";
         SetStop(result,FENX_PIPELINE_STRATEGY_SELECTION,
                 "Selected strategy is not RANGE_MEAN_REVERSION.",trace);
         return(false);
        }
      AppendPass(trace,FENX_PIPELINE_STRATEGY_SELECTION);
      result.strategy_selection_allowed=true;

      if(!standby_complete || !standby_fresh || !standby_system_valid || !standby_data_valid)
        {
         result.reason="Required final market, strategy, Standby, or Risk data is invalid or stale.";
         SetStop(result,FENX_PIPELINE_STANDBY,
                 "Standby data is invalid, incomplete, or stale.",trace);
         return(false);
        }
      if(standby_active || !standby_entries_allowed)
        {
         result.reason="A final selection, Standby, or Risk permission blocks a new entry.";
         SetStop(result,FENX_PIPELINE_STANDBY,
                 "Standby is active or new entries are not allowed.",trace);
         return(false);
        }
      AppendPass(trace,FENX_PIPELINE_STANDBY);
      result.standby_allowed=true;

      if(!risk_complete || !risk_fresh || !risk_system_valid || !risk_data_valid ||
         risk_confidence<m_minimum_risk_confidence)
        {
         result.reason="Required final market, strategy, Standby, or Risk data is invalid or stale.";
         SetStop(result,FENX_PIPELINE_RISK,
                 "Risk data is invalid, incomplete, stale, or below confidence.",trace);
         return(false);
        }
      if(!risk_approved || !risk_entries_approved || !system_trading_allowed ||
         !system_entries_allowed || (risk_action!="ALLOW" && risk_action!="ALLOW_REDUCED"))
        {
         result.reason="A final selection, Standby, or Risk permission blocks a new entry.";
         SetStop(result,FENX_PIPELINE_RISK,
                 "Risk permissions block a new entry.",trace);
         return(false);
        }
      AppendPass(trace,FENX_PIPELINE_RISK);
      result.risk_allowed=true;

      if(!result.data_valid)
        {
         result.reason="Required final market, strategy, Standby, or Risk data is invalid or stale.";
         SetStop(result,FENX_PIPELINE_EXECUTION,
                 "Final gate data failed aggregate validation.",trace);
         return(false);
        }
      result.allocation_multiplier=MathMin(1.0,MathMin(symbol_multiplier,system_multiplier));
      if(result.allocation_multiplier<=0.0 || result.allocation_multiplier>1.0)
        {
         result.reason="Risk allocation multiplier is invalid for a new order.";
         SetStop(result,FENX_PIPELINE_RISK,result.reason,trace);
         return(false);
        }
      result.allowed=true;
      result.execution_gate_allowed=true;
      result.reason="Execution Gate approved a new USDJPY RANGE mean-reversion entry.";
      result.stop_stage=FENX_PIPELINE_EXECUTION;
      result.stage_reason=result.reason;
      AppendPass(trace,FENX_PIPELINE_EXECUTION);
      result.pipeline_trace=trace;
      return(true);
     }
  };

#endif // FENX_EXECUTION_GATE_MQH
