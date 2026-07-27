//+------------------------------------------------------------------+
//|                                      Risk/RiskEngine.mqh       |
//+------------------------------------------------------------------+
#ifndef FENX_RISK_ENGINE_MQH
#define FENX_RISK_ENGINE_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Environment facts consumed from CDataBus only.
struct SRiskEnvironment
  {
   string   market_state;
   double   market_confidence;
   double   volatility_score;
   double   range_score;
   double   trend_score;
   double   trend_strength;
   bool     range_data_valid;
   bool     trend_data_valid;
   datetime market_updated_at;
   datetime range_updated_at;
   datetime trend_updated_at;
  };

//--- Global upstream validity, timestamps, and aggregate facts.
struct SRiskPipeline
  {
   bool     pair_ranking_valid;
   datetime pair_ranking_updated_at;
   bool     allocation_valid;
   datetime allocation_updated_at;
   double   total_allocated_percent;
   bool     style_valid;
   datetime style_updated_at;
   bool     strategy_valid;
   datetime strategy_updated_at;
   bool     standby_valid;
   datetime standby_updated_at;
   int      standby_active_count;
   int      standby_escalation_count;
   int      standby_risk_stop_count;
  };

//--- Per-symbol records supplied by prior engines through CDataBus.
struct SRiskInput
  {
   string   symbol;
   bool     is_market_eligible;
   datetime market_selection_updated_at;
   bool     is_pair_ranked;
   int      pair_rank;
   double   pair_ranking_score;
   double   pair_ranking_confidence;
   datetime pair_ranking_updated_at;
   bool     is_capital_allocated;
   double   capital_allocation_percent;
   datetime capital_allocation_updated_at;
   string   trading_style;
   double   trading_style_confidence;
   bool     is_trading_style_valid;
   datetime trading_style_updated_at;
   string   selected_strategy;
   double   strategy_selection_confidence;
   bool     is_strategy_selection_valid;
   datetime strategy_selection_updated_at;
   string   standby_state;
   bool     is_standby_active;
   bool     are_new_entries_allowed;
   double   standby_escalation_score;
   string   standby_recommended_next_state;
   bool     standby_data_valid;
   datetime standby_updated_at;
  };

//--- Per-symbol persistent hysteresis state.
struct SRiskRuntime
  {
   string   state;
   datetime state_changed_at;
   int      unsafe_confirmation_count;
   int      recovery_confirmation_count;
  };

//--- Per-symbol final risk recommendation; it never represents an execution command.
struct SRiskSnapshot
  {
   string   symbol;
   string   state;
   string   action;
   bool     is_risk_approved;
   bool     are_new_entries_risk_approved;
   double   allocation_multiplier;
   double   score;
   double   confidence;
   string   reason;
   bool     preserve_existing_positions;
   bool     escalation_required;
   bool     data_valid;
   datetime updated_at;
  };

//--- System-level final risk recommendation.
struct SSystemRiskSnapshot
  {
   string   state;
   double   score;
   double   confidence;
   bool     trading_allowed;
   bool     new_entries_allowed;
   double   allocation_multiplier;
   int      suspended_symbol_count;
   int      risk_stop_required_count;
   int      invalid_symbol_count;
   string   reason;
   bool     data_valid;
   datetime updated_at;
  };

//--- Final safety authority for future execution. It publishes recommendations only.
class CRiskEngine : public CBaseEngine
  {
private:
   string        m_symbols[];
   SRiskRuntime  m_runtime[];
   SRiskRuntime  m_system_runtime;
   ENUM_FENX_STATE m_last_requested_state;
   bool          m_invalid_system_logged;
   double        m_caution_threshold;
   double        m_reduced_threshold;
   double        m_suspended_threshold;
   double        m_risk_stop_threshold;
   double        m_volatility_threshold;
   double        m_minimum_confidence;
   double        m_max_allocation_per_symbol;
   double        m_max_aggregate_allocation;
   double        m_max_concentration_ratio;
   int           m_stale_data_limit_seconds;
   double        m_invalid_symbol_ratio_threshold;
   double        m_standby_escalation_threshold;
   int           m_unsafe_confirmation_count;
   int           m_recovery_confirmation_count;
   int           m_transition_cooldown_seconds;
   double        m_caution_allocation_multiplier;
   double        m_reduced_allocation_multiplier;

   double ClampPercent(const double value)
     {
      return(MathMax(0.0,MathMin(100.0,value)));
     }

   void ResetRuntime(SRiskRuntime &runtime)
     {
      runtime.state="SAFE";
      runtime.state_changed_at=0;
      runtime.unsafe_confirmation_count=0;
      runtime.recovery_confirmation_count=0;
     }

   void ResetEnvironment(SRiskEnvironment &environment)
     {
      environment.market_state="TRANSITION";
      environment.market_confidence=0.0;
      environment.volatility_score=0.0;
      environment.range_score=0.0;
      environment.trend_score=0.0;
      environment.trend_strength=0.0;
      environment.range_data_valid=false;
      environment.trend_data_valid=false;
      environment.market_updated_at=0;
      environment.range_updated_at=0;
      environment.trend_updated_at=0;
     }

   void ResetPipeline(SRiskPipeline &pipeline)
     {
      pipeline.pair_ranking_valid=false;
      pipeline.pair_ranking_updated_at=0;
      pipeline.allocation_valid=false;
      pipeline.allocation_updated_at=0;
      pipeline.total_allocated_percent=0.0;
      pipeline.style_valid=false;
      pipeline.style_updated_at=0;
      pipeline.strategy_valid=false;
      pipeline.strategy_updated_at=0;
      pipeline.standby_valid=false;
      pipeline.standby_updated_at=0;
      pipeline.standby_active_count=0;
      pipeline.standby_escalation_count=0;
      pipeline.standby_risk_stop_count=0;
     }

   void ResetSnapshot(SRiskSnapshot &snapshot,const string symbol)
     {
      snapshot.symbol=symbol;
      snapshot.state="RISK_STOP_REQUIRED";
      snapshot.action="REQUEST_RISK_STOP";
      snapshot.is_risk_approved=false;
      snapshot.are_new_entries_risk_approved=false;
      snapshot.allocation_multiplier=0.0;
      snapshot.score=100.0;
      snapshot.confidence=0.0;
      snapshot.reason="Risk data is unavailable.";
      snapshot.preserve_existing_positions=true;
      snapshot.escalation_required=true;
      snapshot.data_valid=false;
      snapshot.updated_at=TimeCurrent();
     }

   void ResetSystemSnapshot(SSystemRiskSnapshot &snapshot)
     {
      snapshot.state="SYSTEM_SAFE";
      snapshot.score=0.0;
      snapshot.confidence=100.0;
      snapshot.trading_allowed=true;
      snapshot.new_entries_allowed=true;
      snapshot.allocation_multiplier=1.0;
      snapshot.suspended_symbol_count=0;
      snapshot.risk_stop_required_count=0;
      snapshot.invalid_symbol_count=0;
      snapshot.reason="No configured symbols require risk evaluation.";
      snapshot.data_valid=true;
      snapshot.updated_at=TimeCurrent();
     }

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

   bool ReadInteger(const string key,int &value)
     {
      double numeric_value=0.0;
      if(!ReadDouble(key,numeric_value))
         return(false);
      value=(int)numeric_value;
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

   bool ReadEnvironment(SRiskEnvironment &environment)
     {
      if(m_data_bus==NULL)
         return(false);

      string market_state="";
      double market_confidence=0.0;
      double volatility_score=0.0;
      double range_score=0.0;
      double trend_score=0.0;
      double trend_strength=0.0;
      bool range_data_valid=false;
      bool trend_data_valid=false;
      datetime market_updated_at=0;
      datetime range_updated_at=0;
      datetime trend_updated_at=0;
      if(!m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE,market_state) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_CONFIDENCE,market_confidence) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,volatility_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,range_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_SCORE,trend_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_STRENGTH,trend_strength) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,range_data_valid) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DATA_VALID,trend_data_valid) ||
         !ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT,market_updated_at) ||
         !ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPDATED_AT,range_updated_at) ||
         !ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_TREND_UPDATED_AT,trend_updated_at))
         return(false);

      environment.market_state=market_state;
      environment.market_confidence=market_confidence;
      environment.volatility_score=volatility_score;
      environment.range_score=range_score;
      // TrendScore is directional (-100..100); risk thresholds use magnitude.
      environment.trend_score=MathAbs(trend_score);
      environment.trend_strength=trend_strength;
      environment.range_data_valid=range_data_valid;
      environment.trend_data_valid=trend_data_valid;
      environment.market_updated_at=market_updated_at;
      environment.range_updated_at=range_updated_at;
      environment.trend_updated_at=trend_updated_at;

      return((environment.market_state=="RANGING" || environment.market_state=="TRENDING" ||
              environment.market_state=="VOLATILE" || environment.market_state=="TRANSITION") &&
             environment.market_confidence>=0.0 && environment.market_confidence<=100.0 &&
             environment.volatility_score>=0.0 && environment.volatility_score<=100.0 &&
             environment.range_score>=0.0 && environment.range_score<=100.0 &&
             environment.trend_score>=0.0 && environment.trend_score<=100.0 &&
             environment.trend_strength>=0.0 && environment.trend_strength<=100.0);
     }

   bool ReadPipeline(SRiskPipeline &pipeline)
     {
      bool pair_ranking_valid=false;
      datetime pair_ranking_updated_at=0;
      bool allocation_valid=false;
      datetime allocation_updated_at=0;
      double total_allocated_percent=0.0;
      bool style_valid=false;
      datetime style_updated_at=0;
      bool strategy_valid=false;
      datetime strategy_updated_at=0;
      bool standby_valid=false;
      datetime standby_updated_at=0;
      int standby_active_count=0;
      int standby_escalation_count=0;
      int standby_risk_stop_count=0;
      if(!ReadBoolean(FENX_DATABUS_KEY_PAIR_RANKING_DATA_VALID,pair_ranking_valid) ||
         !ReadTimestamp(FENX_DATABUS_KEY_PAIR_RANKING_UPDATED_AT,pair_ranking_updated_at) ||
         !ReadBoolean(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_DATA_VALID,allocation_valid) ||
         !ReadTimestamp(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_UPDATED_AT,
                        allocation_updated_at) ||
         !ReadDouble(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_TOTAL_PERCENT,
                     total_allocated_percent) ||
         !ReadBoolean(FENX_DATABUS_KEY_TRADING_STYLE_DATA_VALID,style_valid) ||
         !ReadTimestamp(FENX_DATABUS_KEY_TRADING_STYLE_UPDATED_AT,style_updated_at) ||
         !ReadBoolean(FENX_DATABUS_KEY_STRATEGY_SELECTION_DATA_VALID,strategy_valid) ||
         !ReadTimestamp(FENX_DATABUS_KEY_STRATEGY_SELECTION_UPDATED_AT,
                        strategy_updated_at) ||
         !ReadBoolean(FENX_DATABUS_KEY_STANDBY_SYSTEM_VALID,standby_valid) ||
         !ReadTimestamp(FENX_DATABUS_KEY_STANDBY_SYSTEM_UPDATED_AT,standby_updated_at) ||
         !ReadInteger(FENX_DATABUS_KEY_STANDBY_ACTIVE_SYMBOL_COUNT,
                      standby_active_count) ||
         !ReadInteger(FENX_DATABUS_KEY_STANDBY_ESCALATION_PENDING_COUNT,
                      standby_escalation_count) ||
         !ReadInteger(FENX_DATABUS_KEY_STANDBY_RISK_STOP_PENDING_COUNT,
                      standby_risk_stop_count))
         return(false);

      pipeline.pair_ranking_valid=pair_ranking_valid;
      pipeline.pair_ranking_updated_at=pair_ranking_updated_at;
      pipeline.allocation_valid=allocation_valid;
      pipeline.allocation_updated_at=allocation_updated_at;
      pipeline.total_allocated_percent=total_allocated_percent;
      pipeline.style_valid=style_valid;
      pipeline.style_updated_at=style_updated_at;
      pipeline.strategy_valid=strategy_valid;
      pipeline.strategy_updated_at=strategy_updated_at;
      pipeline.standby_valid=standby_valid;
      pipeline.standby_updated_at=standby_updated_at;
      pipeline.standby_active_count=standby_active_count;
      pipeline.standby_escalation_count=standby_escalation_count;
      pipeline.standby_risk_stop_count=standby_risk_stop_count;
      return(true);
     }

   bool ReadSymbolBoolean(const string name_space,const string symbol,const string field,
                          bool &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      return(m_data_bus.TryGetSymbolText(name_space,symbol,field,text) &&
             ReadBooleanText(text,value));
     }

   bool ReadSymbolDouble(const string name_space,const string symbol,const string field,
                         double &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      if(!m_data_bus.TryGetSymbolText(name_space,symbol,field,text) || StringLen(text)==0)
         return(false);
      value=StringToDouble(text);
      return(true);
     }

   bool ReadSymbolInteger(const string name_space,const string symbol,const string field,
                          int &value)
     {
      double numeric_value=0.0;
      if(!ReadSymbolDouble(name_space,symbol,field,numeric_value))
         return(false);
      value=(int)numeric_value;
      return(true);
     }

   bool ReadSymbolTimestamp(const string name_space,const string symbol,const string field,
                            datetime &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      return(m_data_bus.TryGetSymbolText(name_space,symbol,field,text) &&
             ReadTimestampText(text,value));
     }

   bool ReadSymbolInput(const string symbol,SRiskInput &source)
     {
      if(m_data_bus==NULL)
         return(false);

      bool is_market_eligible=false;
      datetime market_selection_updated_at=0;
      bool is_pair_ranked=false;
      int pair_rank=0;
      double pair_ranking_score=0.0;
      double pair_ranking_confidence=0.0;
      datetime pair_ranking_updated_at=0;
      bool is_capital_allocated=false;
      double capital_allocation_percent=0.0;
      datetime capital_allocation_updated_at=0;
      string trading_style="";
      double trading_style_confidence=0.0;
      bool is_trading_style_valid=false;
      datetime trading_style_updated_at=0;
      string selected_strategy="";
      double strategy_selection_confidence=0.0;
      bool is_strategy_selection_valid=false;
      datetime strategy_selection_updated_at=0;
      string standby_state="";
      bool is_standby_active=false;
      bool are_new_entries_allowed=false;
      double standby_escalation_score=0.0;
      string standby_recommended_next_state="";
      bool standby_data_valid=false;
      datetime standby_updated_at=0;
      if(!ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                            FENX_DATABUS_FIELD_MARKET_SELECTION_IS_ELIGIBLE,
                            is_market_eligible) ||
         !ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                              FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT,
                              market_selection_updated_at) ||
         !ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                            FENX_DATABUS_FIELD_PAIR_RANKING_IS_RANKED,is_pair_ranked) ||
         !ReadSymbolInteger(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                            FENX_DATABUS_FIELD_PAIR_RANKING_RANK,pair_rank) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                           FENX_DATABUS_FIELD_PAIR_RANKING_SCORE,pair_ranking_score) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                           FENX_DATABUS_FIELD_PAIR_RANKING_CONFIDENCE,
                           pair_ranking_confidence) ||
         !ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                              FENX_DATABUS_FIELD_PAIR_RANKING_UPDATED_AT,
                              pair_ranking_updated_at) ||
         !ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,symbol,
                            FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_IS_ALLOCATED,
                            is_capital_allocated) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,symbol,
                           FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_PERCENT,
                           capital_allocation_percent) ||
         !ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,symbol,
                              FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_UPDATED_AT,
                              capital_allocation_updated_at) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                                      FENX_DATABUS_FIELD_TRADING_STYLE,trading_style) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                           FENX_DATABUS_FIELD_TRADING_STYLE_CONFIDENCE,
                           trading_style_confidence) ||
         !ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                            FENX_DATABUS_FIELD_TRADING_STYLE_IS_VALID,
                            is_trading_style_valid) ||
         !ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                              FENX_DATABUS_FIELD_TRADING_STYLE_UPDATED_AT,
                              trading_style_updated_at) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_SELECTED_STRATEGY,
                                      selected_strategy) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,symbol,
                           FENX_DATABUS_FIELD_STRATEGY_SELECTION_CONFIDENCE,
                           strategy_selection_confidence) ||
         !ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,symbol,
                            FENX_DATABUS_FIELD_STRATEGY_SELECTION_IS_VALID,
                            is_strategy_selection_valid) ||
         !ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,symbol,
                              FENX_DATABUS_FIELD_STRATEGY_SELECTION_UPDATED_AT,
                              strategy_selection_updated_at) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                                      FENX_DATABUS_FIELD_STANDBY_STATE,standby_state) ||
         !ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                            FENX_DATABUS_FIELD_STANDBY_IS_ACTIVE,is_standby_active) ||
         !ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                            FENX_DATABUS_FIELD_STANDBY_NEW_ENTRIES_ALLOWED,
                            are_new_entries_allowed) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                           FENX_DATABUS_FIELD_STANDBY_ESCALATION_SCORE,
                           standby_escalation_score) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                                      FENX_DATABUS_FIELD_STANDBY_RECOMMENDED_NEXT_STATE,
                                      standby_recommended_next_state) ||
         !ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                            FENX_DATABUS_FIELD_STANDBY_DATA_VALID,standby_data_valid) ||
         !ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                              FENX_DATABUS_FIELD_STANDBY_UPDATED_AT,standby_updated_at))
         return(false);

      source.symbol=symbol;
      source.is_market_eligible=is_market_eligible;
      source.market_selection_updated_at=market_selection_updated_at;
      source.is_pair_ranked=is_pair_ranked;
      source.pair_rank=pair_rank;
      source.pair_ranking_score=pair_ranking_score;
      source.pair_ranking_confidence=pair_ranking_confidence;
      source.pair_ranking_updated_at=pair_ranking_updated_at;
      source.is_capital_allocated=is_capital_allocated;
      source.capital_allocation_percent=capital_allocation_percent;
      source.capital_allocation_updated_at=capital_allocation_updated_at;
      source.trading_style=trading_style;
      source.trading_style_confidence=trading_style_confidence;
      source.is_trading_style_valid=is_trading_style_valid;
      source.trading_style_updated_at=trading_style_updated_at;
      source.selected_strategy=selected_strategy;
      source.strategy_selection_confidence=strategy_selection_confidence;
      source.is_strategy_selection_valid=is_strategy_selection_valid;
      source.strategy_selection_updated_at=strategy_selection_updated_at;
      source.standby_state=standby_state;
      source.is_standby_active=is_standby_active;
      source.are_new_entries_allowed=are_new_entries_allowed;
      source.standby_escalation_score=standby_escalation_score;
      source.standby_recommended_next_state=standby_recommended_next_state;
      source.standby_data_valid=standby_data_valid;
      source.standby_updated_at=standby_updated_at;

      return(source.pair_rank>=0 && source.pair_ranking_score>=0.0 &&
             source.pair_ranking_score<=100.0 && source.pair_ranking_confidence>=0.0 &&
             source.pair_ranking_confidence<=100.0 && source.capital_allocation_percent>=0.0 &&
             source.capital_allocation_percent<=100.0 && source.trading_style_confidence>=0.0 &&
             source.trading_style_confidence<=100.0 && source.strategy_selection_confidence>=0.0 &&
             source.strategy_selection_confidence<=100.0 && source.standby_escalation_score>=0.0 &&
             source.standby_escalation_score<=100.0 &&
             (source.trading_style=="RANGE" || source.trading_style=="TREND" ||
              source.trading_style=="HYBRID" || source.trading_style=="STANDBY") &&
             (source.selected_strategy=="RANGE_MEAN_REVERSION" ||
              source.selected_strategy=="TREND_FOLLOWING" || source.selected_strategy=="BREAKOUT" ||
              source.selected_strategy=="HYBRID_ADAPTIVE" || source.selected_strategy=="NO_TRADE") &&
             (source.standby_state=="NORMAL" || source.standby_state=="ENTERING_STANDBY" ||
              source.standby_state=="STANDBY" || source.standby_state=="RECOVERY_PENDING" ||
              source.standby_state=="ESCALATION_PENDING" ||
              source.standby_state=="RISK_STOP_PENDING"));
     }

   bool IsTimestampFresh(const datetime updated_at)
     {
      if(updated_at<=0 || m_stale_data_limit_seconds<=0)
         return(false);
      const long age_seconds=(long)(TimeCurrent()-updated_at);
      return(age_seconds>=0 && age_seconds<=m_stale_data_limit_seconds);
     }

   bool IsEnvironmentFresh(const SRiskEnvironment &environment)
     {
      return(IsTimestampFresh(environment.market_updated_at) &&
             IsTimestampFresh(environment.range_updated_at) &&
             IsTimestampFresh(environment.trend_updated_at));
     }

   bool IsPipelineFresh(const SRiskPipeline &pipeline)
     {
      return(IsTimestampFresh(pipeline.pair_ranking_updated_at) &&
             IsTimestampFresh(pipeline.allocation_updated_at) &&
             IsTimestampFresh(pipeline.style_updated_at) &&
             IsTimestampFresh(pipeline.strategy_updated_at) &&
             IsTimestampFresh(pipeline.standby_updated_at));
     }

   bool IsInputFresh(const SRiskInput &source)
     {
      return(IsTimestampFresh(source.market_selection_updated_at) &&
             IsTimestampFresh(source.pair_ranking_updated_at) &&
             IsTimestampFresh(source.capital_allocation_updated_at) &&
             IsTimestampFresh(source.trading_style_updated_at) &&
             IsTimestampFresh(source.strategy_selection_updated_at) &&
             IsTimestampFresh(source.standby_updated_at));
     }

   //--- Append one diagnostic token without obscuring the first failure.
   void AppendDiagnostic(string &diagnostic,const string value)
     {
      if(StringLen(value)==0)
         return;
      if(StringLen(diagnostic)>0)
         diagnostic+="; ";
      diagnostic+=value;
     }

   //--- Describe missing, future-dated, or stale timestamps with their measured age.
   void AppendTimestampDiagnostic(string &diagnostic,const string label,
                                  const datetime updated_at)
     {
      if(updated_at<=0)
        {
         AppendDiagnostic(diagnostic,label+"=missing");
         return;
        }

      const long age_seconds=(long)(TimeCurrent()-updated_at);
      if(age_seconds<0)
         AppendDiagnostic(diagnostic,
                          StringFormat("%s=future(%d seconds)",label,age_seconds));
      else if(age_seconds>m_stale_data_limit_seconds)
         AppendDiagnostic(diagnostic,
                          StringFormat("%s=stale(%d seconds)",label,age_seconds));
     }

   //--- Build field-level evidence for global input failures before fail-closed handling.
   string UpstreamInvalidDiagnostic(const bool environment_available,
                                    const SRiskEnvironment &environment,
                                    const bool pipeline_available,
                                    const SRiskPipeline &pipeline)
     {
      string diagnostic="";
      if(!environment_available)
         AppendDiagnostic(diagnostic,"environment=missing_or_invalid");
      else
        {
         if(!environment.range_data_valid)
            AppendDiagnostic(diagnostic,"environment.range_data_valid=false");
         if(!environment.trend_data_valid)
            AppendDiagnostic(diagnostic,"environment.trend_data_valid=false");
         AppendTimestampDiagnostic(diagnostic,"environment.market",environment.market_updated_at);
         AppendTimestampDiagnostic(diagnostic,"environment.range",environment.range_updated_at);
         AppendTimestampDiagnostic(diagnostic,"environment.trend",environment.trend_updated_at);
        }

      if(!pipeline_available)
         AppendDiagnostic(diagnostic,"pipeline=missing_or_invalid");
      else
        {
         if(!pipeline.pair_ranking_valid)
            AppendDiagnostic(diagnostic,"pipeline.pair_ranking_valid=false");
         if(!pipeline.allocation_valid)
            AppendDiagnostic(diagnostic,"pipeline.allocation_valid=false");
         if(!pipeline.style_valid)
            AppendDiagnostic(diagnostic,"pipeline.style_valid=false");
         if(!pipeline.strategy_valid)
            AppendDiagnostic(diagnostic,"pipeline.strategy_valid=false");
         if(!pipeline.standby_valid)
            AppendDiagnostic(diagnostic,"pipeline.standby_valid=false");
         AppendTimestampDiagnostic(diagnostic,"pipeline.pair_ranking",
                                   pipeline.pair_ranking_updated_at);
         AppendTimestampDiagnostic(diagnostic,"pipeline.allocation",
                                   pipeline.allocation_updated_at);
         AppendTimestampDiagnostic(diagnostic,"pipeline.style",pipeline.style_updated_at);
         AppendTimestampDiagnostic(diagnostic,"pipeline.strategy",pipeline.strategy_updated_at);
         AppendTimestampDiagnostic(diagnostic,"pipeline.standby",pipeline.standby_updated_at);
        }

      if(StringLen(diagnostic)==0)
         diagnostic="no field-level failure identified";
      return(diagnostic);
     }

   bool LoadSymbols(CParameterManager &parameters)
     {
      const int symbol_count=parameters.MarketSelectionSymbolCount();
      if(symbol_count<0 || symbol_count>FENX_MARKET_SELECTION_MAX_SYMBOLS ||
         ArrayResize(m_symbols,symbol_count)!=symbol_count ||
         ArrayResize(m_runtime,symbol_count)!=symbol_count)
         return(false);

      for(int index=0;index<symbol_count;index++)
        {
         string configured_symbol="";

         if(!parameters.TryGetMarketSelectionSymbol(index,configured_symbol) ||

            StringLen(configured_symbol)==0)

            return(false);

         m_symbols[index]=configured_symbol;
         ResetRuntime(m_runtime[index]);
        }
      return(true);
     }

   double AllocationMultiplier(const string state)
     {
      if(state=="SAFE")
         return(1.0);
      if(state=="CAUTION")
         return(m_caution_allocation_multiplier);
      if(state=="REDUCED")
         return(m_reduced_allocation_multiplier);
      return(0.0);
     }

   int RiskStateSeverity(const string state)
     {
      if(state=="CAUTION") return(1);
      if(state=="REDUCED") return(2);
      if(state=="SUSPENDED") return(3);
      if(state=="RISK_STOP_REQUIRED") return(4);
      return(0);
     }

   string RiskStateFromSeverity(const int severity)
     {
      if(severity>=4) return("RISK_STOP_REQUIRED");
      if(severity==3) return("SUSPENDED");
      if(severity==2) return("REDUCED");
      if(severity==1) return("CAUTION");
      return("SAFE");
     }

   void SetRuntimeState(SRiskRuntime &runtime,const string state,const string subject,
                        const string reason)
     {
      if(runtime.state==state)
         return;

      const string previous_state=runtime.state;
      runtime.state=state;
      runtime.state_changed_at=TimeCurrent();
      runtime.unsafe_confirmation_count=0;
      runtime.recovery_confirmation_count=0;
      if(RiskStateSeverity(state)>RiskStateSeverity(previous_state))
         CLogger::Warning(StringFormat("RiskEngine %s: %s -> %s. %s",
                                      subject,previous_state,state,reason));
      else
         CLogger::Info(StringFormat("RiskEngine %s: %s -> %s. %s",
                                   subject,previous_state,state,reason));
     }

   bool IsRiskCooldownComplete(const SRiskRuntime &runtime)
     {
      if(runtime.state_changed_at<=0 || m_transition_cooldown_seconds<=0)
         return(true);
      const long elapsed_seconds=(long)(TimeCurrent()-runtime.state_changed_at);
      return(elapsed_seconds>=m_transition_cooldown_seconds);
     }

   string ApplyHysteresis(SRiskRuntime &runtime,const string candidate,const string subject,
                          const string reason)
     {
      const int current_severity=RiskStateSeverity(runtime.state);
      const int candidate_severity=RiskStateSeverity(candidate);
      if(candidate=="RISK_STOP_REQUIRED")
        {
         SetRuntimeState(runtime,candidate,subject,reason);
         return(runtime.state);
        }

      if(candidate_severity>current_severity)
        {
         runtime.recovery_confirmation_count=0;
         runtime.unsafe_confirmation_count++;
         if(runtime.unsafe_confirmation_count>=m_unsafe_confirmation_count)
            SetRuntimeState(runtime,candidate,subject,reason);
         return(runtime.state);
        }

      if(candidate_severity<current_severity)
        {
         runtime.unsafe_confirmation_count=0;
         runtime.recovery_confirmation_count++;
         if(runtime.recovery_confirmation_count>=m_recovery_confirmation_count &&
            IsRiskCooldownComplete(runtime))
           {
            const string recovered_state=RiskStateFromSeverity(current_severity-1);
            SetRuntimeState(runtime,recovered_state,subject,
                            "Risk recovery was confirmed and improved by one state.");
           }
         return(runtime.state);
        }

      runtime.unsafe_confirmation_count=0;
      runtime.recovery_confirmation_count=0;
      return(runtime.state);
     }

   double CalculateRiskScore(const SRiskEnvironment &environment,const SRiskInput &source,
                             const bool data_valid)
     {
      if(!data_valid)
         return(100.0);

      double volatility_risk=0.0;
      if(environment.volatility_score>m_volatility_threshold)
         volatility_risk=ClampPercent(100.0*(environment.volatility_score-
                                      m_volatility_threshold)/
                                      MathMax(1.0,100.0-m_volatility_threshold));
      const double environment_confidence_risk=ClampPercent(100.0-
                                                             environment.market_confidence);
      const double ranking_confidence_risk=ClampPercent(100.0-
                                                         source.pair_ranking_confidence);
      double allocation_risk=0.0;
      if(source.capital_allocation_percent>m_max_allocation_per_symbol)
         allocation_risk=ClampPercent(100.0*(source.capital_allocation_percent-
                                      m_max_allocation_per_symbol)/
                                      MathMax(1.0,100.0-m_max_allocation_per_symbol));
      const double strategy_confidence_risk=ClampPercent(100.0-
                                                          source.strategy_selection_confidence);
      const double standby_risk=ClampPercent(source.standby_escalation_score);
      double regime_risk=0.0;
      if(environment.market_state=="TRANSITION")
         regime_risk=100.0;
      else if(environment.market_state=="VOLATILE")
         regime_risk=75.0;
      const bool contradictory=((source.is_standby_active && source.are_new_entries_allowed) ||
                                (source.is_capital_allocated &&
                                 (!source.is_market_eligible || !source.is_pair_ranked)) ||
                                !source.is_trading_style_valid ||
                                !source.is_strategy_selection_valid ||
                                (source.standby_recommended_next_state=="RISK_STOP" &&
                                 source.are_new_entries_allowed));
      const double contradiction_risk=(contradictory ? 100.0 : 0.0);
      const double style_confidence_risk=ClampPercent(100.0-
                                                       source.trading_style_confidence);
      return(ClampPercent((0.15*volatility_risk)+
                          (0.10*environment_confidence_risk)+
                          (0.10*ranking_confidence_risk)+
                          (0.10*allocation_risk)+
                          (0.10*strategy_confidence_risk)+
                          (0.15*standby_risk)+
                          (0.10*regime_risk)+
                          (0.10*contradiction_risk)+
                          (0.10*style_confidence_risk)));
     }

   double CalculateRiskConfidence(const SRiskEnvironment &environment,
                                  const SRiskInput &source,const bool data_valid)
     {
      if(!data_valid)
         return(0.0);
      double confidence=MathMin(environment.market_confidence,
                                source.pair_ranking_confidence);
      confidence=MathMin(confidence,source.strategy_selection_confidence);
      confidence=MathMin(confidence,source.trading_style_confidence);
      return(ClampPercent(confidence));
     }

   string CandidateState(const SRiskEnvironment &environment,const SRiskInput &source,
                         const double score,const double confidence,const bool data_valid)
     {
      // An explicit Standby risk-stop request remains critical even if another
      // upstream validity flag is degraded in the same update.
      if(source.standby_state=="RISK_STOP_PENDING" ||
         source.standby_recommended_next_state=="RISK_STOP")
         return("RISK_STOP_REQUIRED");
      // Missing or temporarily invalid inputs are fail-closed at SUSPENDED.
      // They block every new entry without treating absence of evidence as an
      // independently confirmed critical-risk event.
      if(!data_valid)
         return("SUSPENDED");
      if(score>=m_risk_stop_threshold)
         return("RISK_STOP_REQUIRED");
      if(source.standby_state=="ESCALATION_PENDING" ||
         source.standby_recommended_next_state=="DYNAMIC_ZONE" ||
         (source.is_capital_allocated && !source.are_new_entries_allowed) ||
         score>=m_suspended_threshold)
         return("SUSPENDED");
      if(score>=m_reduced_threshold || confidence<m_minimum_confidence)
         return("REDUCED");
      if(score>=m_caution_threshold || environment.market_state=="TRANSITION")
         return("CAUTION");
      return("SAFE");
     }

   string RiskReason(const string state,const SRiskInput &source,const bool data_valid)
     {
      if(state=="RISK_STOP_REQUIRED" &&
         (source.standby_state=="RISK_STOP_PENDING" ||
          source.standby_recommended_next_state=="RISK_STOP"))
         return("Standby explicitly reported a critical condition requiring Risk Stop.");
      if(!data_valid)
         return("Required risk records are invalid, unavailable, or stale; new entries remain suspended.");
      if(state=="RISK_STOP_REQUIRED")
         return("Critical risk requires a future Risk Engine handoff without forced closure.");
      if(state=="SUSPENDED" && source.standby_recommended_next_state=="DYNAMIC_ZONE")
         return("Standby requested structural escalation and new entries remain blocked.");
      if(state=="SUSPENDED")
         return("Risk conditions require new-entry suspension.");
      if(state=="REDUCED")
         return("Risk conditions permit reduced recommended exposure only.");
      if(state=="CAUTION")
         return("Risk conditions permit cautious reduced exposure.");
      return("Risk inputs support normal future-entry permission.");
     }

   void BuildSnapshot(const string final_state,const SRiskEnvironment &environment,
                      const SRiskInput &source,const double score,const double confidence,
                      const bool data_valid,SRiskSnapshot &snapshot)
     {
      snapshot.state=final_state;
      snapshot.score=score;
      snapshot.confidence=confidence;
      snapshot.data_valid=data_valid;
      snapshot.preserve_existing_positions=true;
      snapshot.allocation_multiplier=AllocationMultiplier(final_state);
      snapshot.is_risk_approved=(final_state=="SAFE" || final_state=="CAUTION" ||
                                 final_state=="REDUCED");
      snapshot.are_new_entries_risk_approved=(snapshot.is_risk_approved && data_valid &&
                                              source.are_new_entries_allowed);
      snapshot.escalation_required=(final_state=="RISK_STOP_REQUIRED" ||
                                    source.standby_recommended_next_state=="DYNAMIC_ZONE");
      if(final_state=="RISK_STOP_REQUIRED")
         snapshot.action="REQUEST_RISK_STOP";
      else if(source.standby_recommended_next_state=="DYNAMIC_ZONE")
         snapshot.action="ESCALATE_DYNAMIC_ZONE";
      else if(final_state=="SUSPENDED")
         snapshot.action="BLOCK_NEW_ENTRIES";
      else if(final_state=="CAUTION" || final_state=="REDUCED")
         snapshot.action="ALLOW_REDUCED";
      else
         snapshot.action="ALLOW";
      snapshot.reason=RiskReason(final_state,source,data_valid);
      snapshot.updated_at=TimeCurrent();
     }

   bool PublishSnapshot(const SRiskSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);
      bool success=true;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_SYMBOL_RISK_STATE,snapshot.state)) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RISK_ACTION,snapshot.action)) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_IS_RISK_APPROVED,
                                   (snapshot.is_risk_approved ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_NEW_ENTRIES_RISK_APPROVED,
                                   (snapshot.are_new_entries_risk_approved ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RECOMMENDED_ALLOCATION_MULTIPLIER,
                                   DoubleToString(snapshot.allocation_multiplier,2))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RISK_SCORE,
                                   DoubleToString(snapshot.score,2))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RISK_CONFIDENCE,
                                   DoubleToString(snapshot.confidence,2))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RISK_REASON,snapshot.reason)) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RISK_PRESERVE_POSITIONS,"true")) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RISK_ESCALATION_REQUIRED,
                                   (snapshot.escalation_required ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RISK_DATA_VALID,
                                   (snapshot.data_valid ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RISK_UPDATED_AT,
                                   TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS))) success=false;
      return(success);
     }

   double SystemScore(const int symbol_count,const int suspended_count,const int risk_stop_count,
                      const int invalid_count,const int standby_or_escalation_count,
                      const double total_allocated,const double largest_allocation,
                      const bool global_data_valid,const bool contradictory)
     {
      if(symbol_count<=0)
         return(0.0);
      const double denominator=(double)symbol_count;
      const double suspended_ratio=suspended_count/denominator;
      const double risk_stop_ratio=risk_stop_count/denominator;
      const double invalid_ratio=invalid_count/denominator;
      const double standby_ratio=standby_or_escalation_count/denominator;
      const double aggregate_risk=(total_allocated>m_max_aggregate_allocation ?
         ClampPercent(100.0*(total_allocated-m_max_aggregate_allocation)/
                      MathMax(1.0,100.0-m_max_aggregate_allocation)) : 0.0);
      const double concentration_ratio=(total_allocated>0.0 ? largest_allocation/total_allocated : 0.0);
      const double concentration_risk=(concentration_ratio>m_max_concentration_ratio ?
         ClampPercent(100.0*(concentration_ratio-m_max_concentration_ratio)/
                      MathMax(0.01,1.0-m_max_concentration_ratio)) : 0.0);
      return(ClampPercent((0.20*100.0*suspended_ratio)+(0.25*100.0*risk_stop_ratio)+
                          (0.10*aggregate_risk)+(0.10*concentration_risk)+
                          (0.15*100.0*invalid_ratio)+(0.10*ClampPercent(100.0*standby_ratio))+
                          (!global_data_valid && invalid_count==0 ? 5.0 : 0.0)+
                          (contradictory ? 5.0 : 0.0)));
     }

   string SystemCandidateState(const int symbol_count,const int risk_stop_count,
                               const int invalid_count,const double system_score)
     {
      if(symbol_count<=0) return("SAFE");
      if(risk_stop_count>0) return("RISK_STOP_REQUIRED");
      if((double)invalid_count/symbol_count>=m_invalid_symbol_ratio_threshold)
         return("SUSPENDED");
      if(system_score>=m_risk_stop_threshold) return("RISK_STOP_REQUIRED");
      if(system_score>=m_suspended_threshold) return("SUSPENDED");
      if(system_score>=m_reduced_threshold) return("REDUCED");
      if(system_score>=m_caution_threshold) return("CAUTION");
      return("SAFE");
     }

   void BuildSystemSnapshot(const string final_state,const double score,const double confidence,
                            const int suspended_count,const int risk_stop_count,
                            const int invalid_count,const bool data_valid,
                            const bool all_symbol_entries_allowed,SSystemRiskSnapshot &snapshot)
     {
      snapshot.state="SYSTEM_"+final_state;
      snapshot.score=score;
      snapshot.confidence=confidence;
      snapshot.suspended_symbol_count=suspended_count;
      snapshot.risk_stop_required_count=risk_stop_count;
      snapshot.invalid_symbol_count=invalid_count;
      snapshot.data_valid=data_valid;
      snapshot.allocation_multiplier=AllocationMultiplier(final_state);
      snapshot.trading_allowed=(final_state=="SAFE" || final_state=="CAUTION" ||
                                final_state=="REDUCED");
      snapshot.new_entries_allowed=(snapshot.trading_allowed && all_symbol_entries_allowed);
      if(final_state=="RISK_STOP_REQUIRED")
         snapshot.reason="Critical system risk requires future Risk Engine handling and no forced closure is performed.";
      else if(final_state=="SUSPENDED")
         snapshot.reason="System risk is suspended pending valid, stable recovery conditions.";
      else if(final_state=="REDUCED")
         snapshot.reason="System risk permits reduced recommended exposure only.";
      else if(final_state=="CAUTION")
         snapshot.reason="System caution reduces recommended exposure.";
      else
         snapshot.reason="System risk inputs support normal future-entry permission.";
      snapshot.updated_at=TimeCurrent();
     }

   bool PublishSystemSnapshot(const SSystemRiskSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);
      bool success=true;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_STATE,snapshot.state)) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_SCORE,
                             DoubleToString(snapshot.score,2))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_CONFIDENCE,
                             DoubleToString(snapshot.confidence,2))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_TRADING_ALLOWED,
                             (snapshot.trading_allowed ? "true" : "false"))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_NEW_ENTRIES_ALLOWED,
                             (snapshot.new_entries_allowed ? "true" : "false"))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_ALLOCATION_MULTIPLIER,
                             DoubleToString(snapshot.allocation_multiplier,2))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SUSPENDED_SYMBOL_COUNT,
                             IntegerToString(snapshot.suspended_symbol_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_STOP_REQUIRED_COUNT,
                             IntegerToString(snapshot.risk_stop_required_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_INVALID_SYMBOL_COUNT,
                             IntegerToString(snapshot.invalid_symbol_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_REASON,snapshot.reason)) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_DATA_VALID,
                             (snapshot.data_valid ? "true" : "false"))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_UPDATED_AT,
                             TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS))) success=false;
      return(success);
     }

   //--- Core recovery requires the already-hysteretic final system state plus
   //--- complete valid inputs and the absence of every escalation or entry block.
   bool IsCoreRecoveryConfirmed(const SSystemRiskSnapshot &system_snapshot,
                                const bool has_dynamic_escalation,
                                const bool has_entry_block)
     {
      return(system_snapshot.state=="SYSTEM_SAFE" &&
             system_snapshot.data_valid &&
             system_snapshot.trading_allowed &&
             system_snapshot.new_entries_allowed &&
             system_snapshot.risk_stop_required_count==0 &&
             system_snapshot.invalid_symbol_count==0 &&
             !has_dynamic_escalation &&
             !has_entry_block);
     }

   void RequestCoreState(const SSystemRiskSnapshot &system_snapshot,
                         const bool has_dynamic_escalation,const bool has_entry_block)
     {
      if(m_state_manager==NULL || m_state_manager.GetState()==FENX_STATE_SHUTDOWN)
         return;

      // StateManager intentionally disallows RISK_STOP -> NORMAL. Once the Risk
      // Engine's final system state has recovered through its confirmation and
      // cooldown rules, request only the first safe leg of the recovery path.
      if(m_state_manager.GetState()==FENX_STATE_RISK_STOP)
        {
         if(!IsCoreRecoveryConfirmed(system_snapshot,has_dynamic_escalation,has_entry_block))
            return;
         if(m_state_manager.RequestTransition(FENX_STATE_STANDBY,"RiskEngine"))
           {
            m_last_requested_state=FENX_STATE_STANDBY;
            CLogger::Info("RiskEngine confirmed safe recovery from RISK_STOP to STANDBY.");
           }
         else
            CLogger::Error("RiskEngine safe RISK_STOP recovery request was rejected.");
         return;
        }

      ENUM_FENX_STATE requested_state=FENX_STATE_NORMAL;
      if(system_snapshot.state=="SYSTEM_RISK_STOP_REQUIRED")
         requested_state=FENX_STATE_RISK_STOP;
      else if(has_dynamic_escalation)
         requested_state=FENX_STATE_DYNAMIC_ZONE;
      else if(system_snapshot.state!="SYSTEM_SAFE" || has_entry_block)
         requested_state=FENX_STATE_STANDBY;

      if(requested_state==m_last_requested_state ||
         requested_state==m_state_manager.GetState())
        {
         m_last_requested_state=requested_state;
         return;
        }
      if(m_state_manager.RequestTransition(requested_state,"RiskEngine"))
         m_last_requested_state=requested_state;
      else
         CLogger::Error("RiskEngine state transition request was rejected.");
     }

public:
                     CRiskEngine(void)
     {
      SetName("RiskEngine");
      ResetRuntime(m_system_runtime);
      m_last_requested_state=FENX_STATE_INIT;
      m_invalid_system_logged=false;
      m_caution_threshold=0.0;
      m_reduced_threshold=0.0;
      m_suspended_threshold=0.0;
      m_risk_stop_threshold=0.0;
      m_volatility_threshold=0.0;
      m_minimum_confidence=0.0;
      m_max_allocation_per_symbol=0.0;
      m_max_aggregate_allocation=0.0;
      m_max_concentration_ratio=0.0;
      m_stale_data_limit_seconds=0;
      m_invalid_symbol_ratio_threshold=0.0;
      m_standby_escalation_threshold=0.0;
      m_unsafe_confirmation_count=0;
      m_recovery_confirmation_count=0;
      m_transition_cooldown_seconds=0;
      m_caution_allocation_multiplier=0.0;
      m_reduced_allocation_multiplier=0.0;
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_caution_threshold=parameters.RiskCautionThreshold();
      m_reduced_threshold=parameters.RiskReducedThreshold();
      m_suspended_threshold=parameters.RiskSuspendedThreshold();
      m_risk_stop_threshold=parameters.RiskStopThreshold();
      m_volatility_threshold=parameters.RiskVolatilityThreshold();
      m_minimum_confidence=parameters.RiskMinimumConfidence();
      m_max_allocation_per_symbol=parameters.RiskMaxAllocationPerSymbol();
      m_max_aggregate_allocation=parameters.RiskMaxAggregateAllocation();
      m_max_concentration_ratio=parameters.RiskMaxConcentrationRatio();
      m_stale_data_limit_seconds=parameters.RiskStaleDataLimitSeconds();
      m_invalid_symbol_ratio_threshold=parameters.RiskInvalidSymbolRatioThreshold();
      m_standby_escalation_threshold=parameters.RiskStandbyEscalationThreshold();
      m_unsafe_confirmation_count=parameters.RiskUnsafeConfirmationCount();
      m_recovery_confirmation_count=parameters.RiskRecoveryConfirmationCount();
      m_transition_cooldown_seconds=parameters.RiskTransitionCooldownSeconds();
      m_caution_allocation_multiplier=parameters.RiskCautionAllocationMultiplier();
      m_reduced_allocation_multiplier=parameters.RiskReducedAllocationMultiplier();

      if(!LoadSymbols(parameters) || m_caution_threshold<0.0 ||
         m_caution_threshold>=m_reduced_threshold ||
         m_reduced_threshold>=m_suspended_threshold ||
         m_suspended_threshold>=m_risk_stop_threshold || m_risk_stop_threshold>100.0 ||
         m_volatility_threshold<=0.0 || m_volatility_threshold>100.0 ||
         m_minimum_confidence<=0.0 || m_minimum_confidence>100.0 ||
         m_max_allocation_per_symbol<=0.0 || m_max_allocation_per_symbol>100.0 ||
         m_max_aggregate_allocation<=0.0 || m_max_aggregate_allocation>100.0 ||
         m_max_concentration_ratio<=0.0 || m_max_concentration_ratio>1.0 ||
         m_stale_data_limit_seconds<=0 || m_invalid_symbol_ratio_threshold<=0.0 ||
         m_invalid_symbol_ratio_threshold>1.0 || m_standby_escalation_threshold<0.0 ||
         m_standby_escalation_threshold>100.0 || m_unsafe_confirmation_count<1 ||
         m_recovery_confirmation_count<1 || m_transition_cooldown_seconds<0 ||
         m_caution_allocation_multiplier<=0.0 || m_caution_allocation_multiplier>=1.0 ||
         m_reduced_allocation_multiplier<=0.0 ||
         m_reduced_allocation_multiplier>=m_caution_allocation_multiplier)
        {
         CLogger::Error("RiskEngine received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      CLogger::Info(StringFormat("RiskEngine configured for %d symbol(s).",ArraySize(m_symbols)));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;

      const int symbol_count=ArraySize(m_symbols);
      SSystemRiskSnapshot system_snapshot;
      ResetSystemSnapshot(system_snapshot);
      if(symbol_count==0)
        {
         PublishSystemSnapshot(system_snapshot);
         RequestCoreState(system_snapshot,false,false);
         return;
        }

      SRiskEnvironment environment;
      SRiskPipeline pipeline;
      ResetEnvironment(environment);
      ResetPipeline(pipeline);
      const bool environment_available=ReadEnvironment(environment);
      const bool pipeline_available=ReadPipeline(pipeline);
      const bool environment_fresh=(environment_available && IsEnvironmentFresh(environment));
      const bool pipeline_fresh=(pipeline_available && IsPipelineFresh(pipeline));
      const bool upstream_valid=(environment_available && pipeline_available && environment_fresh &&
                                 pipeline_fresh && environment.range_data_valid &&
                                 environment.trend_data_valid && pipeline.pair_ranking_valid &&
                                 pipeline.allocation_valid && pipeline.style_valid &&
                                 pipeline.strategy_valid && pipeline.standby_valid);
      if(!upstream_valid && !m_invalid_system_logged)
        {
         CLogger::Error(StringFormat(
            "RiskEngine detected invalid, missing, or stale upstream risk data: %s.",
            UpstreamInvalidDiagnostic(environment_available,environment,
                                      pipeline_available,pipeline)));
         m_invalid_system_logged=true;
        }
      if(upstream_valid)
         m_invalid_system_logged=false;

      SRiskSnapshot snapshots[];
      if(ArrayResize(snapshots,symbol_count)!=symbol_count)
        {
         CLogger::Error("RiskEngine could not allocate per-symbol snapshots.");
         return;
        }

      int suspended_count=0;
      int risk_stop_count=0;
      int invalid_count=0;
      int standby_count=0;
      int escalation_count=0;
      int standby_or_escalation_count=0;
      double largest_allocation=0.0;
      double confidence_total=0.0;
      bool all_entries_allowed=true;
      bool all_data_valid=upstream_valid;
      bool has_dynamic_escalation=false;
      bool has_entry_block=false;
      for(int index=0;index<symbol_count;index++)
        {
         ResetSnapshot(snapshots[index],m_symbols[index]);
         SRiskInput source;
         const bool input_available=ReadSymbolInput(m_symbols[index],source);
         const bool input_fresh=(input_available && IsInputFresh(source));
         const bool data_valid=(upstream_valid && input_available && input_fresh &&
                                source.is_trading_style_valid && source.is_strategy_selection_valid &&
                                source.standby_data_valid);
         if(!input_available)
           {
            const string final_state=ApplyHysteresis(
               m_runtime[index],"SUSPENDED",m_symbols[index],
               "Required symbol-level risk records are unavailable; new entries are suspended.");
            snapshots[index].state=final_state;
            snapshots[index].action="BLOCK_NEW_ENTRIES";
            snapshots[index].is_risk_approved=false;
            snapshots[index].are_new_entries_risk_approved=false;
            snapshots[index].allocation_multiplier=0.0;
            snapshots[index].reason="Required symbol-level risk records are unavailable.";
            snapshots[index].escalation_required=false;
            invalid_count++;
            if(final_state=="SUSPENDED")
               suspended_count++;
            if(final_state=="RISK_STOP_REQUIRED")
               risk_stop_count++;
            all_entries_allowed=false;
            all_data_valid=false;
            has_entry_block=true;
            continue;
           }

         const double score=CalculateRiskScore(environment,source,data_valid);
         const double confidence=CalculateRiskConfidence(environment,source,data_valid);
         const string candidate=CandidateState(environment,source,score,confidence,data_valid);
         const string final_state=ApplyHysteresis(m_runtime[index],candidate,m_symbols[index],
                                                  RiskReason(candidate,source,data_valid));
         BuildSnapshot(final_state,environment,source,score,confidence,data_valid,snapshots[index]);
         if(!data_valid)
            invalid_count++;
         if(!data_valid)
            all_data_valid=false;
         if(source.is_standby_active)
            standby_count++;
         if(source.standby_recommended_next_state=="DYNAMIC_ZONE" ||
            source.standby_escalation_score>=m_standby_escalation_threshold)
            escalation_count++;
         if(source.is_standby_active || source.standby_recommended_next_state=="DYNAMIC_ZONE" ||
            source.standby_escalation_score>=m_standby_escalation_threshold)
            standby_or_escalation_count++;
         if(snapshots[index].state=="SUSPENDED")
            suspended_count++;
         if(snapshots[index].state=="RISK_STOP_REQUIRED")
            risk_stop_count++;
         if(!snapshots[index].are_new_entries_risk_approved)
            {
             all_entries_allowed=false;
             has_entry_block=true;
            }
         if(snapshots[index].action=="ESCALATE_DYNAMIC_ZONE")
            has_dynamic_escalation=true;
         if(snapshots[index].action=="REQUEST_RISK_STOP")
            has_entry_block=true;
         largest_allocation=MathMax(largest_allocation,source.capital_allocation_percent);
         confidence_total+=snapshots[index].confidence;
        }

      const bool contradictory=(pipeline.standby_active_count!=standby_count ||
                                pipeline.standby_escalation_count!=escalation_count ||
                                (pipeline.standby_risk_stop_count>0 && risk_stop_count==0));
      const double system_score=SystemScore(symbol_count,suspended_count,risk_stop_count,
                                            invalid_count,standby_or_escalation_count,
                                            pipeline.total_allocated_percent,largest_allocation,
                                            all_data_valid,contradictory);
      const string system_candidate=SystemCandidateState(symbol_count,risk_stop_count,
                                                          invalid_count,system_score);
      const string final_system_state=ApplyHysteresis(m_system_runtime,system_candidate,"SYSTEM",
                                                       "System risk inputs changed.");
      const double system_confidence=(all_data_valid ?
         ClampPercent(confidence_total/symbol_count) : 0.0);
      BuildSystemSnapshot(final_system_state,system_score,system_confidence,suspended_count,
                          risk_stop_count,invalid_count,all_data_valid,all_entries_allowed,
                          system_snapshot);
      for(int index=0;index<symbol_count;index++)
        {
         if(!PublishSnapshot(snapshots[index]))
            CLogger::Error(StringFormat("RiskEngine could not publish %s.",m_symbols[index]));
        }
      if(!PublishSystemSnapshot(system_snapshot))
         CLogger::Error("RiskEngine could not publish global risk data.");
      RequestCoreState(system_snapshot,has_dynamic_escalation,has_entry_block);
     }

   virtual void       Shutdown(void)
     {
      ArrayFree(m_symbols);
      ArrayFree(m_runtime);
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_RISK_ENGINE_MQH
