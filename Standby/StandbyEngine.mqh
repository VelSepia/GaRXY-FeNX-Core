//+------------------------------------------------------------------+
//|                                  Standby/StandbyEngine.mqh     |
//+------------------------------------------------------------------+
#ifndef FENX_STANDBY_ENGINE_MQH
#define FENX_STANDBY_ENGINE_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Common/CommonSnapshotStore.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Factual Environment data supplied by the earlier Environment Engine.
struct SStandbyEnvironment
  {
   string   market_state;
   double   market_confidence;
   double   atr;
   double   range_upper;
   double   range_lower;
   double   range_width_points;
   double   range_position;
   double   range_score;
   bool     is_range;
   bool     range_data_valid;
   double   trend_score;
   double   trend_strength;
   string   trend_direction;
   bool     trend_data_valid;
   double   volatility_score;
   datetime market_updated_at;
   datetime range_updated_at;
   datetime range_closed_bar_time;
   datetime trend_updated_at;
  };

//--- Global validity and freshness facts supplied by upstream engines.
struct SStandbyPipeline
  {
   bool     pair_ranking_valid;
   datetime pair_ranking_updated_at;
   bool     allocation_valid;
   datetime allocation_updated_at;
   bool     style_valid;
   datetime style_updated_at;
   bool     strategy_valid;
   datetime strategy_updated_at;
  };

//--- Per-symbol facts consumed only through CDataBus.
struct SStandbyInput
  {
   string   symbol;
   bool     is_market_eligible;
   datetime market_selection_updated_at;
   bool     is_pair_ranked;
   int      pair_rank;
   double   pair_ranking_score;
   datetime pair_ranking_updated_at;
   bool     is_capital_allocated;
   double   capital_allocation_percent;
   datetime capital_allocation_updated_at;
   string   trading_style;
   bool     is_trading_style_valid;
   datetime trading_style_updated_at;
   string   selected_strategy;
   double   strategy_selection_confidence;
   bool     is_strategy_selection_valid;
   datetime strategy_selection_updated_at;
  };

//--- Persistent state retained per configured symbol to prevent state flapping.
struct SStandbyRuntime
  {
   string   state;
   datetime entered_at;
   datetime state_changed_at;
   datetime last_confirmation_bar_time;
   int      entry_confirmation_count;
   int      recovery_confirmation_count;
   bool     duration_warning_logged;
   bool     critical_warning_logged;
   bool     last_recovery_condition_met;
   datetime last_recovery_check_at;
   string   last_transition_reason;
  };

//--- Global Standby Engine snapshot.
struct SGlobalStandbySnapshot
  {
   int      active_symbol_count;
   int      recovery_pending_count;
   int      escalation_pending_count;
   int      risk_stop_pending_count;
   bool     system_valid;
   datetime updated_at;
  };

//--- Coordinates temporary protective standby recommendations without executing trades.
class CStandbyEngine : public CBaseEngine
  {
private:
   string          m_symbols[];
   SStandbyRuntime m_runtime[];
   int             m_entry_confirmation_bars;
   int             m_recovery_confirmation_bars;
   int             m_max_duration_seconds;
   double          m_breakout_distance_points;
   double          m_breakout_distance_atr_multiple;
   double          m_min_range_recovery_score;
   double          m_trend_escalation_threshold;
   double          m_volatility_escalation_threshold;
   double          m_confidence_recovery_threshold;
   double          m_confidence_failure_threshold;
   int             m_transition_cooldown_seconds;
   int             m_stale_data_grace_seconds;
   int             m_base_stale_data_limit_seconds;
   bool            m_consistency_verified;
   CCommonSnapshotStore *m_snapshot_store;

   double ClampPercent(const double value)
     {
      return(MathMax(0.0,MathMin(100.0,value)));
     }

   void ResetRuntime(SStandbyRuntime &runtime)
     {
      runtime.state="NORMAL";
      runtime.entered_at=0;
      runtime.state_changed_at=0;
      runtime.last_confirmation_bar_time=0;
      runtime.entry_confirmation_count=0;
      runtime.recovery_confirmation_count=0;
      runtime.duration_warning_logged=false;
      runtime.critical_warning_logged=false;
      runtime.last_recovery_condition_met=false;
      runtime.last_recovery_check_at=0;
      runtime.last_transition_reason="";
     }

   void ResetSnapshot(SStandbySnapshot &snapshot,const string symbol)
     {
      snapshot.symbol=symbol;
      snapshot.state="NORMAL";
      snapshot.is_active=false;
      snapshot.are_new_entries_allowed=false;
      snapshot.preserve_existing_positions=true;
      snapshot.reason="";
      snapshot.confidence=0.0;
      snapshot.entered_at=0;
      snapshot.duration_seconds=0;
      snapshot.recovery_progress=0.0;
      snapshot.escalation_score=0.0;
      snapshot.recommended_next_state="NORMAL";
      snapshot.is_data_valid=false;
      snapshot.updated_at=TimeCurrent();
      snapshot.timeframe=EnumToString(_Period);
      snapshot.snapshot_version=FENX_COMMON_STANDBY_SNAPSHOT_VERSION;
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="";
      snapshot.is_standby=false;
      snapshot.is_recovering=false;
      snapshot.escalation_requested=false;
      snapshot.risk_stop_requested=false;
      snapshot.recovery_condition_met=false;
      snapshot.recovery_confirmation_count=0;
      snapshot.required_confirmation_count=m_recovery_confirmation_bars;
      snapshot.recovery_started_at=0;
      snapshot.last_recovery_check_at=0;
      snapshot.standby_started_at=0;
      snapshot.standby_duration_seconds=0;
      snapshot.cooldown_until=0;
      snapshot.last_state_changed_at=0;
      snapshot.standby_reason="";
      snapshot.recovery_reason="";
      snapshot.escalation_reason="";
      snapshot.market_state="TRANSITION";
      snapshot.market_state_updated_at=0;
      snapshot.market_selection_valid_available=false;
      snapshot.market_selection_valid=false;
      snapshot.is_market_eligible=false;
      snapshot.strategy_selection_valid=false;
      snapshot.source_updated_at=0;
      snapshot.state_manager_state="INIT";
     }

   void ResetGlobalSnapshot(SGlobalStandbySnapshot &snapshot)
     {
      snapshot.active_symbol_count=0;
      snapshot.recovery_pending_count=0;
      snapshot.escalation_pending_count=0;
      snapshot.risk_stop_pending_count=0;
      snapshot.system_valid=false;
      snapshot.updated_at=TimeCurrent();
     }

   void ResetEnvironment(SStandbyEnvironment &environment)
     {
      environment.market_state="TRANSITION";
      environment.market_confidence=0.0;
      environment.atr=0.0;
      environment.range_upper=0.0;
      environment.range_lower=0.0;
      environment.range_width_points=0.0;
      environment.range_position=0.0;
      environment.range_score=0.0;
      environment.is_range=false;
      environment.range_data_valid=false;
      environment.trend_score=0.0;
      environment.trend_strength=0.0;
      environment.trend_direction="NEUTRAL";
      environment.trend_data_valid=false;
      environment.volatility_score=0.0;
      environment.market_updated_at=0;
      environment.range_updated_at=0;
      environment.range_closed_bar_time=0;
      environment.trend_updated_at=0;
     }

   void ResetPipeline(SStandbyPipeline &pipeline)
     {
      pipeline.pair_ranking_valid=false;
      pipeline.pair_ranking_updated_at=0;
      pipeline.allocation_valid=false;
      pipeline.allocation_updated_at=0;
      pipeline.style_valid=false;
      pipeline.style_updated_at=0;
      pipeline.strategy_valid=false;
      pipeline.strategy_updated_at=0;
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

   bool ReadEnvironment(SStandbyEnvironment &environment)
     {
      if(m_data_bus==NULL)
         return(false);

      string market_state="";
      double market_confidence=0.0;
      double atr=0.0;
      double range_upper=0.0;
      double range_lower=0.0;
      double range_width_points=0.0;
      double range_position=0.0;
      double range_score=0.0;
      bool is_range=false;
      bool range_data_valid=false;
      double trend_score=0.0;
      double trend_strength=0.0;
      string trend_direction="";
      bool trend_data_valid=false;
      double volatility_score=0.0;
      datetime market_updated_at=0;
      datetime range_updated_at=0;
      datetime range_closed_bar_time=0;
      datetime trend_updated_at=0;
      if(!m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE,market_state) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_CONFIDENCE,market_confidence) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_ATR,atr) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPPER,range_upper) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_LOWER,range_lower) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_WIDTH_POINTS,range_width_points) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_POSITION,range_position) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,range_score) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_IS_RANGE,is_range) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,range_data_valid) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_SCORE,trend_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_STRENGTH,trend_strength) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DIRECTION,
                                trend_direction) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DATA_VALID,trend_data_valid) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,volatility_score) ||
         !ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT,market_updated_at) ||
         !ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPDATED_AT,range_updated_at) ||
         !ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_CLOSED_BAR_TIME,
                        range_closed_bar_time) ||
         !ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_TREND_UPDATED_AT,trend_updated_at))
         return(false);

      environment.market_state=market_state;
      environment.market_confidence=market_confidence;
      environment.atr=atr;
      environment.range_upper=range_upper;
      environment.range_lower=range_lower;
      environment.range_width_points=range_width_points;
      environment.range_position=range_position;
      environment.range_score=range_score;
      environment.is_range=is_range;
      environment.range_data_valid=range_data_valid;
      // TrendScore is directional (-100..100); standby thresholds use magnitude.
      environment.trend_score=MathAbs(trend_score);
      environment.trend_strength=trend_strength;
      environment.trend_direction=trend_direction;
      environment.trend_data_valid=trend_data_valid;
      environment.volatility_score=volatility_score;
      environment.market_updated_at=market_updated_at;
      environment.range_updated_at=range_updated_at;
      environment.range_closed_bar_time=range_closed_bar_time;
      environment.trend_updated_at=trend_updated_at;

      return((environment.market_state=="RANGING" || environment.market_state=="TRENDING" ||
              environment.market_state=="VOLATILE" || environment.market_state=="TRANSITION") &&
             environment.market_confidence>=0.0 && environment.market_confidence<=100.0 &&
             environment.atr>0.0 && environment.range_upper>environment.range_lower &&
             environment.range_width_points>0.0 && environment.range_position>=0.0 &&
             environment.range_position<=1.0 && environment.range_score>=0.0 &&
             environment.range_score<=100.0 && environment.trend_score>=0.0 &&
             environment.trend_score<=100.0 && environment.trend_strength>=0.0 &&
             environment.trend_strength<=100.0 && environment.volatility_score>=0.0 &&
             environment.volatility_score<=100.0);
     }

   bool ReadPipeline(SStandbyPipeline &pipeline)
     {
      bool pair_ranking_valid=false;
      datetime pair_ranking_updated_at=0;
      bool allocation_valid=false;
      datetime allocation_updated_at=0;
      bool style_valid=false;
      datetime style_updated_at=0;
      bool strategy_valid=false;
      datetime strategy_updated_at=0;
      if(!ReadBoolean(FENX_DATABUS_KEY_PAIR_RANKING_DATA_VALID,pair_ranking_valid) ||
         !ReadTimestamp(FENX_DATABUS_KEY_PAIR_RANKING_UPDATED_AT,pair_ranking_updated_at) ||
         !ReadBoolean(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_DATA_VALID,allocation_valid) ||
         !ReadTimestamp(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_UPDATED_AT,
                        allocation_updated_at) ||
         !ReadBoolean(FENX_DATABUS_KEY_TRADING_STYLE_DATA_VALID,style_valid) ||
         !ReadTimestamp(FENX_DATABUS_KEY_TRADING_STYLE_UPDATED_AT,style_updated_at) ||
         !ReadBoolean(FENX_DATABUS_KEY_STRATEGY_SELECTION_DATA_VALID,strategy_valid) ||
         !ReadTimestamp(FENX_DATABUS_KEY_STRATEGY_SELECTION_UPDATED_AT,
                        strategy_updated_at))
         return(false);

      pipeline.pair_ranking_valid=pair_ranking_valid;
      pipeline.pair_ranking_updated_at=pair_ranking_updated_at;
      pipeline.allocation_valid=allocation_valid;
      pipeline.allocation_updated_at=allocation_updated_at;
      pipeline.style_valid=style_valid;
      pipeline.style_updated_at=style_updated_at;
      pipeline.strategy_valid=strategy_valid;
      pipeline.strategy_updated_at=strategy_updated_at;
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

   bool ReadSymbolInput(const string symbol,SStandbyInput &source)
     {
      if(m_data_bus==NULL)
         return(false);

      bool is_market_eligible=false;
      datetime market_selection_updated_at=0;
      bool is_pair_ranked=false;
      int pair_rank=0;
      double pair_ranking_score=0.0;
      datetime pair_ranking_updated_at=0;
      bool is_capital_allocated=false;
      double capital_allocation_percent=0.0;
      datetime capital_allocation_updated_at=0;
      string trading_style="";
      bool is_trading_style_valid=false;
      datetime trading_style_updated_at=0;
      string selected_strategy="";
      double strategy_selection_confidence=0.0;
      bool is_strategy_selection_valid=false;
      datetime strategy_selection_updated_at=0;
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
                              strategy_selection_updated_at))
         return(false);

      source.symbol=symbol;
      source.is_market_eligible=is_market_eligible;
      source.market_selection_updated_at=market_selection_updated_at;
      source.is_pair_ranked=is_pair_ranked;
      source.pair_rank=pair_rank;
      source.pair_ranking_score=pair_ranking_score;
      source.pair_ranking_updated_at=pair_ranking_updated_at;
      source.is_capital_allocated=is_capital_allocated;
      source.capital_allocation_percent=capital_allocation_percent;
      source.capital_allocation_updated_at=capital_allocation_updated_at;
      source.trading_style=trading_style;
      source.is_trading_style_valid=is_trading_style_valid;
      source.trading_style_updated_at=trading_style_updated_at;
      source.selected_strategy=selected_strategy;
      source.strategy_selection_confidence=strategy_selection_confidence;
      source.is_strategy_selection_valid=is_strategy_selection_valid;
      source.strategy_selection_updated_at=strategy_selection_updated_at;

      return(source.pair_rank>=0 && source.pair_ranking_score>=0.0 &&
             source.pair_ranking_score<=100.0 && source.capital_allocation_percent>=0.0 &&
             source.capital_allocation_percent<=100.0 &&
             source.strategy_selection_confidence>=0.0 &&
             source.strategy_selection_confidence<=100.0 &&
             (source.trading_style=="RANGE" || source.trading_style=="TREND" ||
              source.trading_style=="HYBRID" || source.trading_style=="STANDBY") &&
             (source.selected_strategy=="RANGE_MEAN_REVERSION" ||
              source.selected_strategy=="TREND_FOLLOWING" || source.selected_strategy=="BREAKOUT" ||
              source.selected_strategy=="HYBRID_ADAPTIVE" || source.selected_strategy=="NO_TRADE"));
     }

   bool IsTimestampFresh(const datetime updated_at,const int limit_seconds)
     {
      if(updated_at<=0 || limit_seconds<=0)
         return(false);
      const long age_seconds=(long)(TimeCurrent()-updated_at);
      return(age_seconds>=0 && age_seconds<=limit_seconds);
     }

   bool IsEnvironmentFresh(const SStandbyEnvironment &environment,const int limit_seconds)
     {
      return(IsTimestampFresh(environment.market_updated_at,limit_seconds) &&
             IsTimestampFresh(environment.range_updated_at,limit_seconds) &&
             IsTimestampFresh(environment.trend_updated_at,limit_seconds));
     }

   bool IsPipelineFresh(const SStandbyPipeline &pipeline,const int limit_seconds)
     {
      return(IsTimestampFresh(pipeline.pair_ranking_updated_at,limit_seconds) &&
             IsTimestampFresh(pipeline.allocation_updated_at,limit_seconds) &&
             IsTimestampFresh(pipeline.style_updated_at,limit_seconds) &&
             IsTimestampFresh(pipeline.strategy_updated_at,limit_seconds));
     }

   bool IsInputFresh(const SStandbyInput &source,const int limit_seconds)
     {
      return(IsTimestampFresh(source.market_selection_updated_at,limit_seconds) &&
             IsTimestampFresh(source.pair_ranking_updated_at,limit_seconds) &&
             IsTimestampFresh(source.capital_allocation_updated_at,limit_seconds) &&
             IsTimestampFresh(source.trading_style_updated_at,limit_seconds) &&
             IsTimestampFresh(source.strategy_selection_updated_at,limit_seconds));
     }

   //--- Returns the oldest required publisher timestamp. This mirrors the
   //--- existing all-source freshness rule without adding a new data source.
   datetime OldestTimestamp(const datetime &values[])
     {
      const int count=ArraySize(values);
      if(count<=0)
         return(0);
      datetime oldest=values[0];
      if(oldest<=0)
         return(0);
      for(int index=1;index<count;index++)
        {
         if(values[index]<=0)
            return(0);
         if(values[index]<oldest)
            oldest=values[index];
        }
      return(oldest);
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

   bool IsNewConfirmationBar(SStandbyRuntime &runtime,const datetime closed_bar_time)
     {
      if(closed_bar_time<=0 || closed_bar_time<=runtime.last_confirmation_bar_time)
         return(false);

      runtime.last_confirmation_bar_time=closed_bar_time;
      return(true);
     }

   bool IsCooldownComplete(const SStandbyRuntime &runtime)
     {
      if(runtime.state_changed_at<=0 || m_transition_cooldown_seconds<=0)
         return(true);
      const long elapsed_seconds=(long)(TimeCurrent()-runtime.state_changed_at);
      return(elapsed_seconds>=m_transition_cooldown_seconds);
     }

   double BoundaryBufferRatio(const SStandbyEnvironment &environment)
     {
      if(environment.range_width_points<=0.0 ||
         environment.range_upper<=environment.range_lower)
         return(0.5);

      const double point_size=(environment.range_upper-environment.range_lower)/
                              environment.range_width_points;
      if(point_size<=0.0)
         return(0.5);

      const double atr_points=environment.atr/point_size;
      const double buffer_points=MathMax(m_breakout_distance_points,
                                         m_breakout_distance_atr_multiple*atr_points);
      return(MathMax(0.0,MathMin(0.5,buffer_points/environment.range_width_points)));
     }

   bool IsBoundaryBreach(const SStandbyEnvironment &environment)
     {
      const double buffer_ratio=BoundaryBufferRatio(environment);
      return(environment.range_position<=buffer_ratio ||
             environment.range_position>=1.0-buffer_ratio);
     }

   double CalculateStandbyConfidence(const SStandbyEnvironment &environment,
                                     const SStandbyInput &source,const bool data_fresh)
     {
      double confidence=MathMin(environment.market_confidence,
                                source.strategy_selection_confidence);
      confidence=MathMin(confidence,source.pair_ranking_score);
      if(environment.is_range)
         confidence=MathMin(confidence,environment.range_score);
      if(!data_fresh)
         confidence*=0.75;
      return(ClampPercent(confidence));
     }

   double CalculateEscalationScore(const SStandbyRuntime &runtime,
                                   const SStandbyEnvironment &environment,
                                   const bool boundary_breach)
     {
      double duration_score=0.0;
      if(runtime.entered_at>0 && m_max_duration_seconds>0)
        {
         const long duration_seconds=(long)(TimeCurrent()-runtime.entered_at);
         duration_score=ClampPercent(100.0*(double)MathMax(0,duration_seconds)/
                                     m_max_duration_seconds);
        }

      const double confidence_score=ClampPercent(100.0-environment.market_confidence);
      const double boundary_score=(boundary_breach ? 50.0 : 0.0);
      return(ClampPercent(MathMax(duration_score,
                          MathMax(environment.trend_strength,
                          MathMax(environment.volatility_score,
                          MathMax(confidence_score,boundary_score))))));
     }

   void SetRuntimeState(SStandbyRuntime &runtime,const string state,const string symbol,
                        const string reason)
     {
      if(runtime.state==state)
         return;

      const string previous_state=runtime.state;
      const datetime now=TimeCurrent();
      runtime.state=state;
      runtime.state_changed_at=now;
      runtime.entry_confirmation_count=0;
      runtime.recovery_confirmation_count=0;
      runtime.last_transition_reason=reason;

      if(state=="NORMAL")
        {
         runtime.entered_at=0;
         runtime.duration_warning_logged=false;
         runtime.critical_warning_logged=false;
        }
      else if(runtime.entered_at<=0)
         runtime.entered_at=now;

      if(state=="ESCALATION_PENDING" || state=="RISK_STOP_PENDING")
         CLogger::Warning(StringFormat("StandbyEngine %s: %s -> %s. %s",
                                      symbol,previous_state,state,reason));
      else
         CLogger::Info(StringFormat("StandbyEngine %s: %s -> %s. %s",
                                   symbol,previous_state,state,reason));
     }

   void UpdateRuntime(SStandbyRuntime &runtime,const string symbol,
                      const SStandbyEnvironment &environment,
                      const SStandbyPipeline &pipeline,const SStandbyInput &source,
                      const bool raw_data_available,const bool data_fresh,
                      const bool within_grace,const bool data_valid)
     {
      const bool is_new_bar=IsNewConfirmationBar(runtime,environment.range_closed_bar_time);
      const bool boundary_breach=IsBoundaryBreach(environment);
      const double confidence=CalculateStandbyConfidence(environment,source,data_fresh);
      const double escalation_score=CalculateEscalationScore(runtime,environment,
                                                              boundary_breach);
      const long duration_seconds=(runtime.entered_at>0 ?
                                   (long)(TimeCurrent()-runtime.entered_at) : 0);
      const bool pipeline_degraded=(!pipeline.pair_ranking_valid || !pipeline.allocation_valid ||
                                    !pipeline.style_valid || !pipeline.strategy_valid);
      const bool recommendation_blocked=(!source.is_market_eligible || !source.is_pair_ranked ||
                                         !source.is_trading_style_valid ||
                                         !source.is_strategy_selection_valid ||
                                         source.trading_style=="STANDBY" ||
                                         source.selected_strategy=="NO_TRADE");
      const bool severe_volatility=(environment.volatility_score>=
                                     MathMin(100.0,m_volatility_escalation_threshold+10.0));
      const bool severe_condition=(!raw_data_available || !within_grace ||
                                   severe_volatility ||
                                   (data_fresh &&
                                    confidence<=m_confidence_failure_threshold));
      const bool entry_condition=(boundary_breach ||
                                  environment.market_state=="TRANSITION" ||
                                  pipeline_degraded || recommendation_blocked ||
                                  !data_fresh ||
                                  confidence<m_confidence_recovery_threshold);
      const bool escalation_condition=(duration_seconds>=m_max_duration_seconds ||
                                       environment.trend_strength>=
                                          m_trend_escalation_threshold ||
                                       environment.volatility_score>=
                                          m_volatility_escalation_threshold ||
                                       escalation_score>=m_trend_escalation_threshold);
      const bool recovery_condition=(data_valid && data_fresh && environment.is_range &&
                                     environment.range_data_valid &&
                                     environment.trend_data_valid &&
                                     environment.range_score>=m_min_range_recovery_score &&
                                     confidence>=m_confidence_recovery_threshold &&
                                     !boundary_breach &&
                                     environment.trend_strength<
                                        m_trend_escalation_threshold &&
                                     environment.volatility_score<
                                        m_volatility_escalation_threshold &&
                                     !recommendation_blocked);
      //--- Retain the already-calculated observation for the typed adapter.
      //--- These fields never participate in a later state transition.
      runtime.last_recovery_condition_met=recovery_condition;
      runtime.last_recovery_check_at=TimeCurrent();

      if(runtime.state=="NORMAL")
        {
         if(severe_condition)
            SetRuntimeState(runtime,"RISK_STOP_PENDING",symbol,
                            "Critical data loss, volatility, or confidence requires risk review.");
         else if(entry_condition)
           {
            SetRuntimeState(runtime,"ENTERING_STANDBY",symbol,
                            "A temporary protective condition requires confirmation.");
            if(is_new_bar)
               runtime.entry_confirmation_count++;
            if(runtime.entry_confirmation_count>=m_entry_confirmation_bars)
               SetRuntimeState(runtime,"STANDBY",symbol,
                               "Standby entry persisted across completed-bar confirmations.");
           }
         return;
        }

      if(runtime.state=="ENTERING_STANDBY")
        {
         if(severe_condition)
            SetRuntimeState(runtime,"RISK_STOP_PENDING",symbol,
                            "Entry-confirmation data became critically unsafe.");
         else if(!entry_condition)
            SetRuntimeState(runtime,"NORMAL",symbol,
                            "Temporary standby condition cleared before confirmation.");
         else if(is_new_bar)
           {
            runtime.entry_confirmation_count++;
            if(runtime.entry_confirmation_count>=m_entry_confirmation_bars)
               SetRuntimeState(runtime,"STANDBY",symbol,
                               "Standby entry persisted across completed-bar confirmations.");
           }
         return;
        }

      if(runtime.state=="STANDBY")
        {
         if(severe_condition)
            SetRuntimeState(runtime,"RISK_STOP_PENDING",symbol,
                            "Standby conditions became critically unsafe.");
         else if(escalation_condition)
            SetRuntimeState(runtime,"ESCALATION_PENDING",symbol,
                            "Duration, trend, volatility, or confidence indicates structural change.");
         else if(recovery_condition && IsCooldownComplete(runtime))
           {
            SetRuntimeState(runtime,"RECOVERY_PENDING",symbol,
                            "Recovery conditions were observed; awaiting completed-bar confirmation.");
            if(is_new_bar)
               runtime.recovery_confirmation_count++;
            if(runtime.recovery_confirmation_count>=m_recovery_confirmation_bars)
               SetRuntimeState(runtime,"NORMAL",symbol,
                               "Recovery conditions persisted across completed-bar confirmations.");
           }
         return;
        }

      if(runtime.state=="RECOVERY_PENDING")
        {
         if(severe_condition)
            SetRuntimeState(runtime,"RISK_STOP_PENDING",symbol,
                            "Recovery data became unsafe and requires risk review.");
         else if(entry_condition)
            SetRuntimeState(runtime,"STANDBY",symbol,
                            "A temporary entry condition returned during recovery confirmation.");
         else if(escalation_condition)
            SetRuntimeState(runtime,"ESCALATION_PENDING",symbol,
                            "Recovery did not prevent a structural condition.");
         else
           {
            if(is_new_bar)
               runtime.recovery_confirmation_count++;
            if(runtime.recovery_confirmation_count>=m_recovery_confirmation_bars)
               SetRuntimeState(runtime,"NORMAL",symbol,
                               "Recovery conditions persisted across completed-bar confirmations.");
           }
         return;
        }

      if(runtime.state=="ESCALATION_PENDING")
        {
         if(severe_condition)
            SetRuntimeState(runtime,"RISK_STOP_PENDING",symbol,
                            "Escalated condition requires immediate risk review.");
         else if(recovery_condition && IsCooldownComplete(runtime))
           {
            SetRuntimeState(runtime,"RECOVERY_PENDING",symbol,
                            "Escalated condition improved; awaiting recovery confirmation.");
            if(is_new_bar)
               runtime.recovery_confirmation_count++;
           }
         return;
        }
      // RISK_STOP_PENDING remains stable until the future Risk Engine owns the outcome.
     }

   string RecommendedNextState(const string standby_state)
     {
      if(standby_state=="ESCALATION_PENDING")
         return("DYNAMIC_ZONE");
      if(standby_state=="RISK_STOP_PENDING")
         return("RISK_STOP");
      if(standby_state=="ENTERING_STANDBY" || standby_state=="STANDBY" ||
         standby_state=="RECOVERY_PENDING")
         return("STANDBY");
      return("NORMAL");
     }

   void BuildSnapshot(const SStandbyRuntime &runtime,const SStandbyEnvironment &environment,
                      const SStandbyPipeline &pipeline,const SStandbyInput &source,
                      const bool is_participant,const bool data_valid,
                      const bool data_fresh,SStandbySnapshot &snapshot)
     {
      snapshot.state=runtime.state;
      snapshot.is_active=(runtime.state!="NORMAL" && is_participant);
      snapshot.preserve_existing_positions=true;
      snapshot.entered_at=(snapshot.is_active ? runtime.entered_at : 0);
      if(snapshot.entered_at>0)
         snapshot.duration_seconds=MathMax(0,(long)(TimeCurrent()-snapshot.entered_at));
      snapshot.confidence=CalculateStandbyConfidence(environment,source,data_fresh);
      snapshot.escalation_score=CalculateEscalationScore(runtime,environment,
                                                          IsBoundaryBreach(environment));
      snapshot.recommended_next_state=RecommendedNextState(runtime.state);
      snapshot.is_data_valid=data_valid;
      snapshot.are_new_entries_allowed=(runtime.state=="NORMAL" && is_participant && data_valid &&
                                        source.is_market_eligible && source.is_pair_ranked &&
                                        source.is_trading_style_valid &&
                                        source.is_strategy_selection_valid &&
                                        source.trading_style!="STANDBY" &&
                                        source.selected_strategy!="NO_TRADE");
      if(runtime.state=="RECOVERY_PENDING")
         snapshot.recovery_progress=ClampPercent(100.0*runtime.recovery_confirmation_count/
                                                  MathMax(1,m_recovery_confirmation_bars));
      else if(runtime.state=="NORMAL")
         snapshot.recovery_progress=100.0;

      if(!is_participant)
         snapshot.reason="Symbol is not currently capital allocated; standby monitoring is inactive.";
      else if(runtime.state=="ENTERING_STANDBY")
         snapshot.reason="Temporary condition is awaiting completed-bar entry confirmation.";
      else if(runtime.state=="STANDBY")
         snapshot.reason="New-entry permission is paused while existing positions are preserved.";
      else if(runtime.state=="RECOVERY_PENDING")
         snapshot.reason="Recovery is awaiting completed-bar confirmation before NORMAL is requested.";
      else if(runtime.state=="ESCALATION_PENDING")
         snapshot.reason="Structural change is pending DYNAMIC_ZONE review.";
      else if(runtime.state=="RISK_STOP_PENDING")
         snapshot.reason="Critical condition is pending future Risk Engine review.";
      else if(!data_valid)
         snapshot.reason="Required DataBus facts are invalid, unavailable, or stale.";
      else
         snapshot.reason="Normal participation conditions are currently available.";

      //--- Typed-only adapter fields observe the existing output and runtime.
      snapshot.is_standby=snapshot.is_active;
      snapshot.is_recovering=(runtime.state=="RECOVERY_PENDING");
      snapshot.escalation_requested=(runtime.state=="ESCALATION_PENDING");
      snapshot.risk_stop_requested=(runtime.state=="RISK_STOP_PENDING");
      snapshot.recovery_condition_met=runtime.last_recovery_condition_met;
      snapshot.recovery_confirmation_count=runtime.recovery_confirmation_count;
      snapshot.required_confirmation_count=m_recovery_confirmation_bars;
      snapshot.recovery_started_at=(snapshot.is_recovering ?
                                    runtime.state_changed_at : 0);
      snapshot.last_recovery_check_at=runtime.last_recovery_check_at;
      snapshot.standby_started_at=snapshot.entered_at;
      snapshot.standby_duration_seconds=snapshot.duration_seconds;
      snapshot.cooldown_until=(runtime.state_changed_at>0 ?
                               runtime.state_changed_at+
                               m_transition_cooldown_seconds : 0);
      snapshot.last_state_changed_at=runtime.state_changed_at;
      snapshot.standby_reason=snapshot.reason;
      snapshot.recovery_reason=(snapshot.is_recovering ?
                                runtime.last_transition_reason : "");
      snapshot.escalation_reason=(snapshot.escalation_requested ||
                                  snapshot.risk_stop_requested ?
                                  runtime.last_transition_reason : "");
      snapshot.market_state=environment.market_state;
      snapshot.market_state_updated_at=environment.market_updated_at;
      // MarketSelection has eligibility and timestamp fields, but no explicit
      // validity publisher; never infer a validity value from eligibility.
      snapshot.market_selection_valid_available=false;
      snapshot.market_selection_valid=false;
      snapshot.is_market_eligible=source.is_market_eligible;
      snapshot.strategy_selection_valid=source.is_strategy_selection_valid;
      const datetime source_times[12]=
        {
         environment.market_updated_at,environment.range_updated_at,
         environment.trend_updated_at,pipeline.pair_ranking_updated_at,
         pipeline.allocation_updated_at,pipeline.style_updated_at,
         pipeline.strategy_updated_at,source.market_selection_updated_at,
         source.pair_ranking_updated_at,source.capital_allocation_updated_at,
         source.trading_style_updated_at,source.strategy_selection_updated_at
        };
      snapshot.source_updated_at=OldestTimestamp(source_times);
     }

   bool SameTypedSnapshot(const SStandbySnapshot &left,
                          const SStandbySnapshot &right)
     {
      return(left.symbol==right.symbol && left.state==right.state &&
             left.is_active==right.is_active &&
             left.are_new_entries_allowed==right.are_new_entries_allowed &&
             left.preserve_existing_positions==right.preserve_existing_positions &&
             left.reason==right.reason && left.confidence==right.confidence &&
             left.entered_at==right.entered_at &&
             left.duration_seconds==right.duration_seconds &&
             left.recovery_progress==right.recovery_progress &&
             left.escalation_score==right.escalation_score &&
             left.recommended_next_state==right.recommended_next_state &&
             left.is_data_valid==right.is_data_valid &&
             left.updated_at==right.updated_at && left.timeframe==right.timeframe &&
             left.snapshot_version==right.snapshot_version &&
             left.is_valid==right.is_valid && left.is_fresh==right.is_fresh &&
             left.invalid_reason==right.invalid_reason &&
             left.is_standby==right.is_standby &&
             left.is_recovering==right.is_recovering &&
             left.escalation_requested==right.escalation_requested &&
             left.risk_stop_requested==right.risk_stop_requested &&
             left.recovery_condition_met==right.recovery_condition_met &&
             left.recovery_confirmation_count==right.recovery_confirmation_count &&
             left.required_confirmation_count==right.required_confirmation_count &&
             left.recovery_started_at==right.recovery_started_at &&
             left.last_recovery_check_at==right.last_recovery_check_at &&
             left.standby_started_at==right.standby_started_at &&
             left.standby_duration_seconds==right.standby_duration_seconds &&
             left.cooldown_until==right.cooldown_until &&
             left.last_state_changed_at==right.last_state_changed_at &&
             left.standby_reason==right.standby_reason &&
             left.recovery_reason==right.recovery_reason &&
             left.escalation_reason==right.escalation_reason &&
             left.market_state==right.market_state &&
             left.market_state_updated_at==right.market_state_updated_at &&
             left.market_selection_valid_available==
                right.market_selection_valid_available &&
             left.market_selection_valid==right.market_selection_valid &&
             left.is_market_eligible==right.is_market_eligible &&
             left.strategy_selection_valid==right.strategy_selection_valid &&
             left.source_updated_at==right.source_updated_at &&
             left.state_manager_state==right.state_manager_state);
     }

   bool VerifyDataBusSnapshot(const SStandbySnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);
      string state="",active="",entry_allowed="",preserve="",reason="";
      string confidence="",entered="",duration="",recovery="",escalation="";
      string next_state="",data_valid="",updated="";
      return(m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,
                                         snapshot.symbol,
                                         FENX_DATABUS_FIELD_STANDBY_STATE,state) &&
             m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,
                                         snapshot.symbol,
                                         FENX_DATABUS_FIELD_STANDBY_IS_ACTIVE,active) &&
             m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,
                                         snapshot.symbol,
                                         FENX_DATABUS_FIELD_STANDBY_NEW_ENTRIES_ALLOWED,
                                         entry_allowed) &&
             m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,
                                         snapshot.symbol,
                                         FENX_DATABUS_FIELD_STANDBY_PRESERVE_POSITIONS,
                                         preserve) &&
             m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,
                                         snapshot.symbol,
                                         FENX_DATABUS_FIELD_STANDBY_REASON,reason) &&
             m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,
                                         snapshot.symbol,
                                         FENX_DATABUS_FIELD_STANDBY_CONFIDENCE,
                                         confidence) &&
             m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,
                                         snapshot.symbol,
                                         FENX_DATABUS_FIELD_STANDBY_ENTERED_AT,entered) &&
             m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,
                                         snapshot.symbol,
                                         FENX_DATABUS_FIELD_STANDBY_DURATION_SECONDS,
                                         duration) &&
             m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,
                                         snapshot.symbol,
                                         FENX_DATABUS_FIELD_STANDBY_RECOVERY_PROGRESS,
                                         recovery) &&
             m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,
                                         snapshot.symbol,
                                         FENX_DATABUS_FIELD_STANDBY_ESCALATION_SCORE,
                                         escalation) &&
             m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,
                                         snapshot.symbol,
                                         FENX_DATABUS_FIELD_STANDBY_RECOMMENDED_NEXT_STATE,
                                         next_state) &&
             m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,
                                         snapshot.symbol,
                                         FENX_DATABUS_FIELD_STANDBY_DATA_VALID,
                                         data_valid) &&
             m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,
                                         snapshot.symbol,
                                         FENX_DATABUS_FIELD_STANDBY_UPDATED_AT,updated) &&
             state==snapshot.state &&
             active==(snapshot.is_active ? "true" : "false") &&
             entry_allowed==(snapshot.are_new_entries_allowed ? "true" : "false") &&
             preserve=="true" && reason==snapshot.reason &&
             confidence==DoubleToString(snapshot.confidence,2) &&
             entered==TimeToString(snapshot.entered_at,TIME_DATE|TIME_SECONDS) &&
             duration==IntegerToString((int)snapshot.duration_seconds) &&
             recovery==DoubleToString(snapshot.recovery_progress,2) &&
             escalation==DoubleToString(snapshot.escalation_score,2) &&
             next_state==snapshot.recommended_next_state &&
             data_valid==(snapshot.is_data_valid ? "true" : "false") &&
             updated==TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS));
     }

   void LogTypedTelemetry(const string event_name,const string state_before,
                          const SStandbySnapshot &snapshot)
     {
      CLogger::Info(StringFormat(
         "[COMMON_STANDBY] event=%s;Time=%s;Symbol=%s;StateBefore=%s;StateAfter=%s;EntryAllowed=%s;StandbyReason=%s;RecoveryCondition=%s;RecoveryConfirmationCount=%d;EscalationRequested=%s;RiskStopRequested=%s;StateManagerState=%s;SnapshotUpdatedAt=%s;store_count=%d;keys=0;market_selection_valid_available=false",
         event_name,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
         snapshot.symbol,state_before,snapshot.state,
         (snapshot.are_new_entries_allowed ? "true" : "false"),snapshot.reason,
         (snapshot.recovery_condition_met ? "true" : "false"),
         snapshot.recovery_confirmation_count,
         (snapshot.escalation_requested ? "true" : "false"),
         (snapshot.risk_stop_requested ? "true" : "false"),
         snapshot.state_manager_state,
         TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS),
         m_snapshot_store.StandbySnapshotCount()));
     }

   bool StoreTypedSnapshot(SStandbySnapshot &snapshot)
     {
      if(m_snapshot_store==NULL)
         return(false);

      snapshot.state_manager_state=(m_state_manager==NULL ? "INIT" :
         m_state_manager.StateName(m_state_manager.GetState()));
      CStandbySnapshotContract contract;
      contract.Finalize(snapshot,TimeCurrent(),m_base_stale_data_limit_seconds);

      SStandbySnapshot previous;
      const bool had_previous=m_snapshot_store.GetStandbySnapshot(
         snapshot.symbol,_Period,previous);
      if(!m_snapshot_store.SetStandbySnapshot(snapshot.symbol,_Period,snapshot))
         return(false);

      SStandbySnapshot stored;
      if(!m_snapshot_store.GetStandbySnapshot(snapshot.symbol,_Period,stored) ||
         !SameTypedSnapshot(snapshot,stored))
         return(false);

      if(!m_consistency_verified)
        {
         if(!VerifyDataBusSnapshot(snapshot))
            return(false);
         LogTypedTelemetry("CONSISTENCY_PASS","UNAVAILABLE",snapshot);
         m_consistency_verified=true;
        }
      else if(had_previous && previous.state!=snapshot.state)
         LogTypedTelemetry("STATE_CHANGE",previous.state,snapshot);
      return(true);
     }

   bool PublishSnapshot(const SStandbySnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);
      bool success=true;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_STATE,snapshot.state)) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_IS_ACTIVE,
                                   (snapshot.is_active ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_NEW_ENTRIES_ALLOWED,
                                   (snapshot.are_new_entries_allowed ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_PRESERVE_POSITIONS,"true")) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_REASON,snapshot.reason)) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_CONFIDENCE,
                                   DoubleToString(snapshot.confidence,2))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_ENTERED_AT,
                                   TimeToString(snapshot.entered_at,TIME_DATE|TIME_SECONDS))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_DURATION_SECONDS,
                                   IntegerToString((int)snapshot.duration_seconds))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_RECOVERY_PROGRESS,
                                   DoubleToString(snapshot.recovery_progress,2))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_ESCALATION_SCORE,
                                   DoubleToString(snapshot.escalation_score,2))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_RECOMMENDED_NEXT_STATE,
                                   snapshot.recommended_next_state)) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_DATA_VALID,
                                   (snapshot.is_data_valid ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_UPDATED_AT,
                                   TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS))) success=false;
      return(success);
     }

   bool PublishGlobalSnapshot(const SGlobalStandbySnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);
      bool success=true;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STANDBY_ACTIVE_SYMBOL_COUNT,
                             IntegerToString(snapshot.active_symbol_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STANDBY_RECOVERY_PENDING_COUNT,
                             IntegerToString(snapshot.recovery_pending_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STANDBY_ESCALATION_PENDING_COUNT,
                             IntegerToString(snapshot.escalation_pending_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STANDBY_RISK_STOP_PENDING_COUNT,
                             IntegerToString(snapshot.risk_stop_pending_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STANDBY_SYSTEM_VALID,
                             (snapshot.system_valid ? "true" : "false"))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STANDBY_SYSTEM_UPDATED_AT,
                             TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS))) success=false;
      return(success);
     }

   void RequestCoreState(const SGlobalStandbySnapshot &snapshot)
     {
      if(m_state_manager==NULL || m_state_manager.GetState()==FENX_STATE_SHUTDOWN ||
         m_state_manager.GetState()==FENX_STATE_RISK_STOP)
         return;

      if(snapshot.risk_stop_pending_count>0)
        {
         m_state_manager.RequestTransition(FENX_STATE_RISK_STOP,"StandbyEngine");
         return;
        }
      if(snapshot.escalation_pending_count>0)
        {
         if(m_state_manager.GetState()==FENX_STATE_STANDBY)
            m_state_manager.RequestTransition(FENX_STATE_DYNAMIC_ZONE,"StandbyEngine");
         else if(m_state_manager.GetState()==FENX_STATE_NORMAL)
            m_state_manager.RequestTransition(FENX_STATE_STANDBY,"StandbyEngine");
         return;
        }
      if(snapshot.active_symbol_count>0)
        {
         if(m_state_manager.GetState()==FENX_STATE_NORMAL ||
            m_state_manager.GetState()==FENX_STATE_DYNAMIC_ZONE)
            m_state_manager.RequestTransition(FENX_STATE_STANDBY,"StandbyEngine");
         return;
        }
      if(m_state_manager.GetState()==FENX_STATE_STANDBY ||
         m_state_manager.GetState()==FENX_STATE_DYNAMIC_ZONE)
         m_state_manager.RequestTransition(FENX_STATE_NORMAL,"StandbyEngine");
     }

public:
                     CStandbyEngine(void)
     {
      SetName("StandbyEngine");
      m_entry_confirmation_bars=0;
      m_recovery_confirmation_bars=0;
      m_max_duration_seconds=0;
      m_breakout_distance_points=0.0;
      m_breakout_distance_atr_multiple=0.0;
      m_min_range_recovery_score=0.0;
      m_trend_escalation_threshold=0.0;
      m_volatility_escalation_threshold=0.0;
      m_confidence_recovery_threshold=0.0;
      m_confidence_failure_threshold=0.0;
      m_transition_cooldown_seconds=0;
      m_stale_data_grace_seconds=0;
      m_base_stale_data_limit_seconds=0;
      m_consistency_verified=false;
      m_snapshot_store=NULL;
     }

   //--- Injects the non-owning typed store before framework initialization.
   //--- Existing Standby DataBus outputs remain the trading interface.
   bool              SetSnapshotStore(CCommonSnapshotStore &snapshot_store)
     {
      if(m_initialized)
         return(false);
      m_snapshot_store=GetPointer(snapshot_store);
      return(m_snapshot_store!=NULL);
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(m_snapshot_store==NULL)
        {
         CLogger::Error("StandbyEngine requires CommonSnapshotStore before initialization.");
         return(false);
        }
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_entry_confirmation_bars=parameters.StandbyEntryConfirmationBars();
      m_recovery_confirmation_bars=parameters.StandbyRecoveryConfirmationBars();
      m_max_duration_seconds=parameters.StandbyMaxDurationSeconds();
      m_breakout_distance_points=parameters.StandbyBreakoutDistancePoints();
      m_breakout_distance_atr_multiple=parameters.StandbyBreakoutDistanceAtrMultiple();
      m_min_range_recovery_score=parameters.StandbyMinRangeRecoveryScore();
      m_trend_escalation_threshold=parameters.StandbyTrendEscalationThreshold();
      m_volatility_escalation_threshold=parameters.StandbyVolatilityEscalationThreshold();
      m_confidence_recovery_threshold=parameters.StandbyConfidenceRecoveryThreshold();
      m_confidence_failure_threshold=parameters.StandbyConfidenceFailureThreshold();
      m_transition_cooldown_seconds=parameters.StandbyTransitionCooldownSeconds();
      m_stale_data_grace_seconds=parameters.StandbyStaleDataGraceSeconds();
      m_base_stale_data_limit_seconds=parameters.StrategySelectionStaleDataLimitSeconds();

      if(!LoadSymbols(parameters) || m_entry_confirmation_bars<1 ||
         m_recovery_confirmation_bars<1 || m_max_duration_seconds<1 ||
         m_breakout_distance_points<0.0 || m_breakout_distance_atr_multiple<0.0 ||
         m_min_range_recovery_score<0.0 || m_min_range_recovery_score>100.0 ||
         m_trend_escalation_threshold<=0.0 || m_trend_escalation_threshold>100.0 ||
         m_volatility_escalation_threshold<=0.0 || m_volatility_escalation_threshold>100.0 ||
         m_confidence_recovery_threshold<=0.0 || m_confidence_recovery_threshold>100.0 ||
         m_confidence_failure_threshold<0.0 ||
         m_confidence_failure_threshold>=m_confidence_recovery_threshold ||
         m_transition_cooldown_seconds<0 || m_stale_data_grace_seconds<0 ||
         m_base_stale_data_limit_seconds<1)
        {
         CLogger::Error("StandbyEngine received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      CLogger::Info(StringFormat("StandbyEngine configured for %d symbol(s) with %d/%d bar confirmation.",
                                 ArraySize(m_symbols),m_entry_confirmation_bars,
                                 m_recovery_confirmation_bars));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;

      SStandbyEnvironment environment;
      SStandbyPipeline pipeline;
      ResetEnvironment(environment);
      ResetPipeline(pipeline);
      const bool environment_available=ReadEnvironment(environment);
      const bool pipeline_available=ReadPipeline(pipeline);
      const bool environment_fresh=(environment_available &&
                                    IsEnvironmentFresh(environment,m_base_stale_data_limit_seconds));
      const bool pipeline_fresh=(pipeline_available &&
                                 IsPipelineFresh(pipeline,m_base_stale_data_limit_seconds));
      const bool environment_within_grace=(environment_available &&
                                           IsEnvironmentFresh(environment,
                                           m_base_stale_data_limit_seconds+m_stale_data_grace_seconds));
      const bool pipeline_within_grace=(pipeline_available &&
                                        IsPipelineFresh(pipeline,
                                        m_base_stale_data_limit_seconds+m_stale_data_grace_seconds));
      if(!environment_available || !pipeline_available)
         CLogger::Warning("StandbyEngine is waiting for complete Environment and upstream DataBus facts.");

      const int symbol_count=ArraySize(m_symbols);
      SStandbySnapshot snapshots[];
      if(ArrayResize(snapshots,symbol_count)!=symbol_count)
        {
         CLogger::Error("StandbyEngine could not allocate per-symbol snapshots.");
         return;
        }

      SGlobalStandbySnapshot global_snapshot;
      ResetGlobalSnapshot(global_snapshot);
      bool all_data_valid=(environment_available && pipeline_available && environment_fresh &&
                           pipeline_fresh && environment.range_data_valid &&
                           environment.trend_data_valid && pipeline.pair_ranking_valid &&
                           pipeline.allocation_valid && pipeline.style_valid &&
                           pipeline.strategy_valid);
      for(int index=0;index<symbol_count;index++)
        {
         ResetSnapshot(snapshots[index],m_symbols[index]);
         SStandbyInput source;
         const bool input_available=ReadSymbolInput(m_symbols[index],source);
         const bool input_fresh=(input_available &&
                                 IsInputFresh(source,m_base_stale_data_limit_seconds));
         const bool input_within_grace=(input_available &&
                                        IsInputFresh(source,m_base_stale_data_limit_seconds+
                                        m_stale_data_grace_seconds));
         const bool raw_data_available=(environment_available && pipeline_available && input_available);
         const bool data_fresh=(environment_fresh && pipeline_fresh && input_fresh);
         const bool within_grace=(environment_within_grace && pipeline_within_grace &&
                                  input_within_grace);
         const bool data_valid=(data_fresh && environment.range_data_valid &&
                                environment.trend_data_valid && pipeline.pair_ranking_valid &&
                                pipeline.allocation_valid && pipeline.style_valid &&
                                pipeline.strategy_valid && source.is_market_eligible &&
                                source.is_pair_ranked && source.is_trading_style_valid &&
                                source.is_strategy_selection_valid);
         const bool is_participant=(input_available && source.is_capital_allocated &&
                                    source.capital_allocation_percent>0.0);

         if(!input_available)
           {
            snapshots[index].reason="Per-symbol eligibility, ranking, allocation, style, or strategy data is unavailable.";
            snapshots[index].is_data_valid=false;
            all_data_valid=false;
            continue;
           }

         if(is_participant)
            UpdateRuntime(m_runtime[index],m_symbols[index],environment,pipeline,source,
                          raw_data_available,data_fresh,within_grace,data_valid);
         else
            ResetRuntime(m_runtime[index]);

         BuildSnapshot(m_runtime[index],environment,pipeline,source,is_participant,data_valid,
                       data_fresh,snapshots[index]);
         if(!snapshots[index].is_data_valid)
            all_data_valid=false;
         if(snapshots[index].is_active)
            global_snapshot.active_symbol_count++;
         if(snapshots[index].state=="RECOVERY_PENDING")
            global_snapshot.recovery_pending_count++;
         if(snapshots[index].state=="ESCALATION_PENDING")
            global_snapshot.escalation_pending_count++;
         if(snapshots[index].state=="RISK_STOP_PENDING")
            global_snapshot.risk_stop_pending_count++;
        }

      global_snapshot.system_valid=all_data_valid;
      for(int index=0;index<symbol_count;index++)
        {
         if(!PublishSnapshot(snapshots[index]))
            CLogger::Error(StringFormat("StandbyEngine could not publish %s.",m_symbols[index]));
        }
      if(!PublishGlobalSnapshot(global_snapshot))
         CLogger::Error("StandbyEngine could not publish global standby data.");
      RequestCoreState(global_snapshot);
      for(int index=0;index<symbol_count;index++)
        {
         if(!StoreTypedSnapshot(snapshots[index]))
            CLogger::Error(StringFormat(
               "StandbyEngine could not store or verify the typed %s snapshot.",
               m_symbols[index]));
        }
     }

   virtual void       Shutdown(void)
     {
      ArrayFree(m_symbols);
      ArrayFree(m_runtime);
      m_consistency_verified=false;
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_STANDBY_ENGINE_MQH
