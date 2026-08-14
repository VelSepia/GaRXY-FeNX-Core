//+------------------------------------------------------------------+
//|                                  Config/ParameterManager.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_CONFIG_PARAMETER_MANAGER_MQH
#define FENX_CONFIG_PARAMETER_MANAGER_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Common/Types.mqh"

//--- Owns framework configuration independently from trading logic.
class CParameterManager
  {
private:
   int    m_update_interval_seconds;
   bool   m_framework_logging_enabled;
   int    m_volatility_atr_period;
   int    m_volatility_baseline_samples;
   double m_volatility_low_score;
   double m_volatility_high_score;
   int    m_range_lookback_bars;
   double m_range_boundary_trim_fraction;
   int    m_range_min_boundary_touches;
   double m_range_min_width_points;
   double m_range_min_width_atr_multiple;
   double m_range_max_width_atr_multiple;
   double m_range_touch_tolerance_atr_fraction;
   double m_range_break_buffer_atr_fraction;
   int    m_range_max_break_events;
   double m_range_score_threshold;
   int    m_trend_lookback_bars;
   int    m_trend_ma_period;
   int    m_trend_slope_bars;
   int    m_trend_adx_period;
   double m_trend_min_adx;
   double m_trend_min_slope_atr_fraction;
   double m_trend_min_atr_movement;
   double m_trend_noise_atr_fraction;
   double m_trend_direction_score_threshold;
   double m_trend_strength_threshold;
   double m_trend_confidence_threshold;
   double m_market_range_score_threshold;
   double m_market_range_max_trend_score;
   double m_market_trend_score_threshold;
   double m_market_volatility_score_threshold;
   double m_market_trend_min_adx;
   string m_market_selection_symbols[];
   int    m_market_selection_min_history_bars;
   double m_market_selection_max_spread_points;
   double m_market_selection_max_spread_to_atr_ratio;
   double m_market_selection_min_volatility_score;
   double m_market_selection_max_volatility_score;
   double m_market_selection_min_score;
   double m_market_selection_transition_penalty;
   int    m_pair_ranking_max_data_age_seconds;
   double m_pair_ranking_weight_selection_score;
   double m_pair_ranking_weight_selection_confidence;
   double m_pair_ranking_weight_spread_efficiency;
   double m_pair_ranking_weight_environment_confidence;
   double m_pair_ranking_weight_volatility_suitability;
   double m_pair_ranking_weight_regime_suitability;
   double m_pair_ranking_weight_freshness;
   double m_capital_allocation_total_budget;
   double m_capital_allocation_max_per_symbol;
   double m_capital_allocation_min_threshold;
   int    m_capital_allocation_max_funded_symbols;
   double m_capital_allocation_concentration_limit;
   double m_capital_allocation_confidence_threshold;
   int    m_capital_allocation_stale_data_limit_seconds;
   double m_capital_allocation_volatility_penalty;
   double m_capital_allocation_transition_penalty;
   double m_trading_style_trend_confidence_threshold;
   double m_trading_style_range_confidence_threshold;
   double m_trading_style_max_volatility_score;
   double m_trading_style_transition_penalty;
   int    m_trading_style_stale_data_limit_seconds;
   double m_trading_style_stale_data_penalty;
   double m_trading_style_min_allocation_percent;
   double m_strategy_selection_min_confidence;
   double m_strategy_selection_min_allocation_percent;
   double m_strategy_selection_min_ranking_score;
   double m_strategy_selection_range_threshold;
   double m_strategy_selection_trend_threshold;
   double m_strategy_selection_breakout_volatility_threshold;
   double m_strategy_selection_transition_penalty;
   int    m_strategy_selection_stale_data_limit_seconds;
   double m_strategy_selection_no_trade_safety_threshold;
   int    m_standby_entry_confirmation_bars;
   int    m_standby_recovery_confirmation_bars;
   int    m_standby_max_duration_seconds;
   double m_standby_breakout_distance_points;
   double m_standby_breakout_distance_atr_multiple;
   double m_standby_min_range_recovery_score;
   double m_standby_trend_escalation_threshold;
   double m_standby_volatility_escalation_threshold;
   double m_standby_confidence_recovery_threshold;
   double m_standby_confidence_failure_threshold;
   int    m_standby_transition_cooldown_seconds;
   int    m_standby_stale_data_grace_seconds;
   double m_risk_caution_threshold;
   double m_risk_reduced_threshold;
   double m_risk_suspended_threshold;
   double m_risk_stop_threshold;
   double m_risk_volatility_threshold;
   double m_risk_minimum_confidence;
   double m_risk_max_allocation_per_symbol;
   double m_risk_max_aggregate_allocation;
   double m_risk_max_concentration_ratio;
   int    m_risk_stale_data_limit_seconds;
   double m_risk_invalid_symbol_ratio_threshold;
   double m_risk_standby_escalation_threshold;
   int    m_risk_unsafe_confirmation_count;
   int    m_risk_recovery_confirmation_count;
   int    m_risk_transition_cooldown_seconds;
   double m_risk_caution_allocation_multiplier;
   double m_risk_reduced_allocation_multiplier;

   bool   m_execution_enabled;
   string m_execution_symbol;
   long   m_execution_magic_number;
   double m_execution_fixed_lot;
   double m_execution_maximum_spread_points;
   double m_execution_entry_boundary_distance_points;
   double m_execution_entry_boundary_distance_atr_ratio;
   string m_execution_exit_mode;
   double m_execution_fixed_take_profit_points;
   double m_execution_fixed_stop_loss_points;
   double m_execution_range_stop_buffer_points;
   double m_execution_minimum_range_score;
   double m_execution_minimum_strategy_confidence;
   double m_execution_minimum_risk_confidence;
   int    m_execution_order_cooldown_seconds;
   bool   m_execution_one_order_per_bar;
   int    m_execution_maximum_open_positions_per_symbol;
   bool   m_execution_allow_buy;
   bool   m_execution_allow_sell;
   int    m_execution_maximum_slippage_points;
   int    m_execution_transient_retry_limit;
   string m_execution_trade_comment;

   SRuntimeContextConfig m_runtime_contexts[];
   bool                  m_has_explicit_runtime_contexts;

   //--- Creates the compatibility context without marking it as an explicit
   //--- user configuration. The chart period is captured as an explicit enum.
   bool              BuildSingleRuntimeContextFallbackInternal(const string symbol,
                                                                const ENUM_TIMEFRAMES timeframe,
                                                                const long magic)
     {
      SRuntimeContextId context_id;
      context_id.symbol=symbol;
      context_id.timeframe=timeframe;
      if(!IsValidRuntimeContextId(context_id) || magic<=0)
         return(false);

      if(ArrayResize(m_runtime_contexts,1)!=1)
         return(false);

      m_runtime_contexts[0].id=context_id;
      m_runtime_contexts[0].enabled=true;
      m_runtime_contexts[0].required=true;
      m_runtime_contexts[0].trade_enabled=true;
      m_runtime_contexts[0].role=FENX_CONTEXT_ROLE_PRIMARY_TRADING;
      m_runtime_contexts[0].magic=magic;
      m_runtime_contexts[0].parameter_profile_id="default";
      m_has_explicit_runtime_contexts=false;
      return(true);
     }

public:
                     CParameterManager(void)
     {
      Reset();
     }

   bool              Load(void)
     {
      // TODO: Read EA input parameters and external configuration in a later phase.
      Reset();
      CLogger::Info("ParameterManager loaded framework defaults.");
      return(true);
     }

   //--- Applies the Expert Advisor inputs for the isolated Phase3-9.5 execution layer.
   //--- Keeping this mapping here preserves ParameterManager as the single configuration owner.
   bool              ConfigureExecution(const bool enabled,const string symbol,
                                        const long magic_number,const double fixed_lot,
                                        const double maximum_spread_points,
                                        const double entry_boundary_distance_points,
                                        const double entry_boundary_distance_atr_ratio,
                                        const string exit_mode,
                                        const double fixed_take_profit_points,
                                        const double fixed_stop_loss_points,
                                        const double range_stop_buffer_points,
                                        const double minimum_range_score,
                                        const double minimum_strategy_confidence,
                                        const double minimum_risk_confidence,
                                        const int order_cooldown_seconds,
                                        const bool one_order_per_bar,
                                        const int maximum_open_positions_per_symbol,
                                        const bool allow_buy,const bool allow_sell,
                                        const int maximum_slippage_points,
                                        const int transient_retry_limit,
                                        const string trade_comment)
     {
      if(StringLen(symbol)==0 || magic_number<=0 || fixed_lot<=0.0 ||
         maximum_spread_points<=0.0 || entry_boundary_distance_points<0.0 ||
         entry_boundary_distance_atr_ratio<0.0 ||
         (exit_mode!="RANGE_BASED" && exit_mode!="FIXED_POINTS") ||
         fixed_take_profit_points<=0.0 || fixed_stop_loss_points<=0.0 ||
         range_stop_buffer_points<0.0 || minimum_range_score<0.0 ||
         minimum_strategy_confidence<0.0 || minimum_risk_confidence<0.0 ||
         order_cooldown_seconds<0 || maximum_open_positions_per_symbol<=0 ||
         maximum_slippage_points<0 || transient_retry_limit<0 ||
         StringLen(trade_comment)==0)
        {
         CLogger::Error("Execution parameter input is invalid.");
         return(false);
        }
      m_execution_enabled=enabled;
      m_execution_symbol=symbol;
      m_execution_magic_number=magic_number;
      m_execution_fixed_lot=fixed_lot;
      m_execution_maximum_spread_points=maximum_spread_points;
      m_execution_entry_boundary_distance_points=entry_boundary_distance_points;
      m_execution_entry_boundary_distance_atr_ratio=entry_boundary_distance_atr_ratio;
      m_execution_exit_mode=exit_mode;
      m_execution_fixed_take_profit_points=fixed_take_profit_points;
      m_execution_fixed_stop_loss_points=fixed_stop_loss_points;
      m_execution_range_stop_buffer_points=range_stop_buffer_points;
      m_execution_minimum_range_score=minimum_range_score;
      m_execution_minimum_strategy_confidence=minimum_strategy_confidence;
      m_execution_minimum_risk_confidence=minimum_risk_confidence;
      m_execution_order_cooldown_seconds=order_cooldown_seconds;
      m_execution_one_order_per_bar=one_order_per_bar;
      m_execution_maximum_open_positions_per_symbol=maximum_open_positions_per_symbol;
      m_execution_allow_buy=allow_buy;
      m_execution_allow_sell=allow_sell;
      m_execution_maximum_slippage_points=maximum_slippage_points;
      m_execution_transient_retry_limit=transient_retry_limit;
      m_execution_trade_comment=trade_comment;

      // Keep the generated single-context fallback aligned with the existing
      // execution magic while leaving an explicit context list untouched.
      if(!m_has_explicit_runtime_contexts &&
         !BuildSingleRuntimeContextFallbackInternal(_Symbol,
                                                    (ENUM_TIMEFRAMES)_Period,
                                                    magic_number))
        {
         CLogger::Error("Unable to refresh the single runtime context fallback.");
         return(false);
        }
      return(true);
     }

   //--- Replaces the formal context list. Cross-context invariants are checked
   //--- by ValidateRuntimeContextConfiguration during startup preflight so the
   //--- same validation path can be exercised with failing harness fixtures.
   bool              SetRuntimeContextConfigs(SRuntimeContextConfig &configs[])
     {
      const int context_count=ArraySize(configs);
      if(context_count<1 || context_count>FENX_MAX_RUNTIME_CONTEXTS)
         return(false);

      for(int index=0;index<context_count;index++)
        {
         if(!IsValidRuntimeContextId(configs[index].id) ||
            !IsValidRuntimeContextRole(configs[index].role) ||
            configs[index].magic<=0)
            return(false);
        }

      if(ArrayResize(m_runtime_contexts,context_count)!=context_count)
         return(false);

      for(int index=0;index<context_count;index++)
         m_runtime_contexts[index]=configs[index];

      m_has_explicit_runtime_contexts=true;
      return(true);
     }

   //--- Restores the exact legacy chart context when no explicit list exists.
   bool              UseSingleRuntimeContextFallback(void)
     {
      return(BuildSingleRuntimeContextFallbackInternal(_Symbol,
                                                       (ENUM_TIMEFRAMES)_Period,
                                                       m_execution_magic_number));
     }

   int               RuntimeContextCount(void)
     {
      return(ArraySize(m_runtime_contexts));
     }

   bool              HasExplicitRuntimeContexts(void)
     {
      return(m_has_explicit_runtime_contexts);
     }

   bool              GetRuntimeContextConfig(const int index,
                                             SRuntimeContextConfig &config)
     {
      if(index<0 || index>=ArraySize(m_runtime_contexts))
         return(false);

      config=m_runtime_contexts[index];
      return(true);
     }

   int               FindRuntimeContext(const SRuntimeContextId &context_id)
     {
      if(!IsValidRuntimeContextId(context_id))
         return(-1);

      for(int index=0;index<ArraySize(m_runtime_contexts);index++)
        {
         if(RuntimeContextEquals(m_runtime_contexts[index].id,context_id))
            return(index);
        }
      return(-1);
     }

   bool              HasRuntimeContext(const SRuntimeContextId &context_id)
     {
      return(FindRuntimeContext(context_id)>=0);
     }

   //--- Returns a primary only when exactly one enabled trading primary exists.
   int               PrimaryRuntimeContextIndex(void)
     {
      int primary_index=-1;
      for(int index=0;index<ArraySize(m_runtime_contexts);index++)
        {
         if(!m_runtime_contexts[index].enabled ||
            !m_runtime_contexts[index].trade_enabled ||
            m_runtime_contexts[index].role!=FENX_CONTEXT_ROLE_PRIMARY_TRADING)
            continue;

         if(primary_index>=0)
            return(-1);
         primary_index=index;
        }
      return(primary_index);
     }

   bool              GetPrimaryRuntimeContext(SRuntimeContextConfig &config)
     {
      const int primary_index=PrimaryRuntimeContextIndex();
      return(primary_index>=0 && GetRuntimeContextConfig(primary_index,config));
     }

   //--- Validates identity and policy invariants without touching broker state.
   //--- Symbol existence/selection is deliberately a separate registry step.
   bool              ValidateRuntimeContextConfiguration(string &reason)
     {
      reason="";
      const int context_count=ArraySize(m_runtime_contexts);
      if(context_count<1 || context_count>FENX_MAX_RUNTIME_CONTEXTS)
        {
         reason="CONTEXT_COUNT";
         return(false);
        }

      int primary_count=0;
      int enabled_count=0;
      for(int left=0;left<context_count;left++)
        {
         const SRuntimeContextConfig config=m_runtime_contexts[left];
         if(!IsValidRuntimeContextId(config.id))
           {
            reason="INVALID_IDENTITY";
            return(false);
           }
         if(!IsValidRuntimeContextRole(config.role) || config.magic<=0)
           {
            reason="INVALID_CONTEXT_CONFIG";
            return(false);
           }
         if((config.required || config.trade_enabled) && !config.enabled)
           {
            reason="DISABLED_CONTEXT_FLAGS";
            return(false);
           }
         if(config.role==FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS && config.trade_enabled)
           {
            reason="AUXILIARY_TRADING";
            return(false);
           }

         if(config.enabled)
           {
            enabled_count++;
            if(config.role==FENX_CONTEXT_ROLE_PRIMARY_TRADING)
              {
               if(!config.trade_enabled)
                 {
                  reason="PRIMARY_TRADING_DISABLED";
                  return(false);
                 }
               primary_count++;
              }
           }

         for(int right=left+1;right<context_count;right++)
           {
            if(RuntimeContextEquals(config.id,m_runtime_contexts[right].id))
              {
               reason="DUPLICATE_IDENTITY";
               return(false);
              }
            if(config.enabled && m_runtime_contexts[right].enabled &&
               config.id.symbol==m_runtime_contexts[right].id.symbol &&
               config.magic==m_runtime_contexts[right].magic)
              {
               reason="MAGIC_OWNERSHIP_COLLISION";
               return(false);
              }
           }
        }

      if(enabled_count<1)
        {
         reason="NO_ENABLED_CONTEXT";
         return(false);
        }
      if(primary_count!=1)
        {
         reason="PRIMARY_COUNT";
         return(false);
        }
      return(true);
     }

   void              Reset(void)
     {
      m_update_interval_seconds=1;
      m_framework_logging_enabled=true;
      m_volatility_atr_period=14;
      m_volatility_baseline_samples=20;
      m_volatility_low_score=35.0;
      m_volatility_high_score=65.0;
      m_range_lookback_bars=40;
      m_range_boundary_trim_fraction=0.10;
      m_range_min_boundary_touches=2;
      m_range_min_width_points=20.0;
      m_range_min_width_atr_multiple=0.75;
      m_range_max_width_atr_multiple=6.00;
      m_range_touch_tolerance_atr_fraction=0.20;
      m_range_break_buffer_atr_fraction=0.15;
      m_range_max_break_events=4;
      m_range_score_threshold=65.0;
      m_trend_lookback_bars=30;
      m_trend_ma_period=20;
      m_trend_slope_bars=10;
      m_trend_adx_period=14;
      m_trend_min_adx=20.0;
      m_trend_min_slope_atr_fraction=0.05;
      m_trend_min_atr_movement=0.75;
      m_trend_noise_atr_fraction=0.10;
      m_trend_direction_score_threshold=20.0;
      m_trend_strength_threshold=60.0;
      m_trend_confidence_threshold=60.0;
      m_market_range_score_threshold=70.0;
      m_market_range_max_trend_score=40.0;
      m_market_trend_score_threshold=70.0;
      m_market_volatility_score_threshold=80.0;
      m_market_trend_min_adx=20.0;
      ArrayResize(m_market_selection_symbols,1);
      m_market_selection_symbols[0]=_Symbol;
      m_market_selection_min_history_bars=100;
      m_market_selection_max_spread_points=30.0;
      m_market_selection_max_spread_to_atr_ratio=0.30;
      m_market_selection_min_volatility_score=20.0;
      m_market_selection_max_volatility_score=80.0;
      m_market_selection_min_score=60.0;
      m_market_selection_transition_penalty=30.0;
      m_pair_ranking_max_data_age_seconds=5;
      m_pair_ranking_weight_selection_score=0.25;
      m_pair_ranking_weight_selection_confidence=0.15;
      m_pair_ranking_weight_spread_efficiency=0.15;
      m_pair_ranking_weight_environment_confidence=0.15;
      m_pair_ranking_weight_volatility_suitability=0.10;
      m_pair_ranking_weight_regime_suitability=0.10;
      m_pair_ranking_weight_freshness=0.10;
      m_capital_allocation_total_budget=100.0;
      m_capital_allocation_max_per_symbol=40.0;
      m_capital_allocation_min_threshold=5.0;
      m_capital_allocation_max_funded_symbols=3;
      m_capital_allocation_concentration_limit=50.0;
      m_capital_allocation_confidence_threshold=60.0;
      m_capital_allocation_stale_data_limit_seconds=5;
      m_capital_allocation_volatility_penalty=40.0;
      m_capital_allocation_transition_penalty=30.0;
      m_trading_style_trend_confidence_threshold=65.0;
      m_trading_style_range_confidence_threshold=70.0;
      m_trading_style_max_volatility_score=80.0;
      m_trading_style_transition_penalty=30.0;
      m_trading_style_stale_data_limit_seconds=5;
      m_trading_style_stale_data_penalty=20.0;
      m_trading_style_min_allocation_percent=5.0;
      m_strategy_selection_min_confidence=60.0;
      m_strategy_selection_min_allocation_percent=5.0;
      m_strategy_selection_min_ranking_score=60.0;
      m_strategy_selection_range_threshold=70.0;
      m_strategy_selection_trend_threshold=70.0;
      m_strategy_selection_breakout_volatility_threshold=75.0;
      m_strategy_selection_transition_penalty=10.0;
      m_strategy_selection_stale_data_limit_seconds=5;
      m_strategy_selection_no_trade_safety_threshold=40.0;
      m_standby_entry_confirmation_bars=2;
      m_standby_recovery_confirmation_bars=2;
      m_standby_max_duration_seconds=900;
      m_standby_breakout_distance_points=10.0;
      m_standby_breakout_distance_atr_multiple=0.15;
      m_standby_min_range_recovery_score=65.0;
      m_standby_trend_escalation_threshold=70.0;
      m_standby_volatility_escalation_threshold=85.0;
      m_standby_confidence_recovery_threshold=65.0;
      m_standby_confidence_failure_threshold=40.0;
      m_standby_transition_cooldown_seconds=30;
      m_standby_stale_data_grace_seconds=15;
      m_risk_caution_threshold=30.0;
      m_risk_reduced_threshold=50.0;
      m_risk_suspended_threshold=70.0;
      m_risk_stop_threshold=85.0;
      m_risk_volatility_threshold=80.0;
      m_risk_minimum_confidence=60.0;
      m_risk_max_allocation_per_symbol=40.0;
      m_risk_max_aggregate_allocation=100.0;
      m_risk_max_concentration_ratio=0.50;
      m_risk_stale_data_limit_seconds=5;
      m_risk_invalid_symbol_ratio_threshold=0.50;
      m_risk_standby_escalation_threshold=50.0;
      m_risk_unsafe_confirmation_count=2;
      m_risk_recovery_confirmation_count=2;
      m_risk_transition_cooldown_seconds=30;
      m_risk_caution_allocation_multiplier=0.75;
      m_risk_reduced_allocation_multiplier=0.50;
      m_execution_enabled=false;
      m_execution_symbol="USDJPY";
      m_execution_magic_number=93095;
      m_execution_fixed_lot=0.01;
      m_execution_maximum_spread_points=20.0;
      m_execution_entry_boundary_distance_points=20.0;
      m_execution_entry_boundary_distance_atr_ratio=0.15;
      m_execution_exit_mode="RANGE_BASED";
      m_execution_fixed_take_profit_points=30.0;
      m_execution_fixed_stop_loss_points=30.0;
      m_execution_range_stop_buffer_points=10.0;
      m_execution_minimum_range_score=70.0;
      m_execution_minimum_strategy_confidence=65.0;
      m_execution_minimum_risk_confidence=60.0;
      m_execution_order_cooldown_seconds=60;
      m_execution_one_order_per_bar=true;
      m_execution_maximum_open_positions_per_symbol=1;
      m_execution_allow_buy=true;
      m_execution_allow_sell=true;
      m_execution_maximum_slippage_points=10;
      m_execution_transient_retry_limit=1;
      m_execution_trade_comment="GaRXY_FeNX_Core_v1";
      m_has_explicit_runtime_contexts=false;
      if(!BuildSingleRuntimeContextFallbackInternal(_Symbol,
                                                    (ENUM_TIMEFRAMES)_Period,
                                                    m_execution_magic_number))
         ArrayResize(m_runtime_contexts,0);
     }

   int               UpdateIntervalSeconds(void)
     {
      return(m_update_interval_seconds);
     }

   bool              IsFrameworkLoggingEnabled(void)
     {
      return(m_framework_logging_enabled);
     }

   int               VolatilityAtrPeriod(void)
     {
      return(m_volatility_atr_period);
     }

   int               VolatilityBaselineSamples(void)
     {
      return(m_volatility_baseline_samples);
     }

   double            VolatilityLowScore(void)
     {
      return(m_volatility_low_score);
     }

   double            VolatilityHighScore(void)
     {
      return(m_volatility_high_score);
     }

   int               RangeLookbackBars(void)
     {
      return(m_range_lookback_bars);
     }

   double            RangeBoundaryTrimFraction(void)
     {
      return(m_range_boundary_trim_fraction);
     }

   int               RangeMinBoundaryTouches(void)
     {
      return(m_range_min_boundary_touches);
     }

   double            RangeMinWidthPoints(void)
     {
      return(m_range_min_width_points);
     }

   double            RangeMinWidthAtrMultiple(void)
     {
      return(m_range_min_width_atr_multiple);
     }

   double            RangeMaxWidthAtrMultiple(void)
     {
      return(m_range_max_width_atr_multiple);
     }

   double            RangeTouchToleranceAtrFraction(void)
     {
      return(m_range_touch_tolerance_atr_fraction);
     }

   double            RangeBreakBufferAtrFraction(void)
     {
      return(m_range_break_buffer_atr_fraction);
     }

   int               RangeMaxBreakEvents(void)
     {
      return(m_range_max_break_events);
     }

   double            RangeScoreThreshold(void)
     {
      return(m_range_score_threshold);
     }

   int               TrendLookbackBars(void)
     {
      return(m_trend_lookback_bars);
     }

   int               TrendMaPeriod(void)
     {
      return(m_trend_ma_period);
     }

   int               TrendSlopeBars(void)
     {
      return(m_trend_slope_bars);
     }

   int               TrendAdxPeriod(void)
     {
      return(m_trend_adx_period);
     }

   double            TrendMinAdx(void)
     {
      return(m_trend_min_adx);
     }

   double            TrendMinSlopeAtrFraction(void)
     {
      return(m_trend_min_slope_atr_fraction);
     }

   double            TrendMinAtrMovement(void)
     {
      return(m_trend_min_atr_movement);
     }

   double            TrendNoiseAtrFraction(void)
     {
      return(m_trend_noise_atr_fraction);
     }

   double            TrendDirectionScoreThreshold(void)
     {
      return(m_trend_direction_score_threshold);
     }

   double            TrendStrengthThreshold(void)
     {
      return(m_trend_strength_threshold);
     }

   double            TrendConfidenceThreshold(void)
     {
      return(m_trend_confidence_threshold);
     }

   double            MarketRangeScoreThreshold(void)
     {
      return(m_market_range_score_threshold);
     }

   double            MarketRangeMaxTrendScore(void)
     {
      return(m_market_range_max_trend_score);
     }

   double            MarketTrendScoreThreshold(void)
     {
      return(m_market_trend_score_threshold);
     }

   double            MarketVolatilityScoreThreshold(void)
     {
      return(m_market_volatility_score_threshold);
     }

   double            MarketTrendMinAdx(void)
     {
      return(m_market_trend_min_adx);
     }

   bool              SetMarketSelectionSymbols(string &symbols[])
     {
      const int symbol_count=ArraySize(symbols);
      if(symbol_count<1 || symbol_count>FENX_MARKET_SELECTION_MAX_SYMBOLS)
         return(false);

      for(int index=0;index<symbol_count;index++)
        {
         if(StringLen(symbols[index])==0)
            return(false);
        }

      if(ArrayResize(m_market_selection_symbols,symbol_count)!=symbol_count)
         return(false);

      for(int index=0;index<symbol_count;index++)
         m_market_selection_symbols[index]=symbols[index];

      return(true);
     }

   int               MarketSelectionSymbolCount(void)
     {
      return(ArraySize(m_market_selection_symbols));
     }

   bool              TryGetMarketSelectionSymbol(const int index,string &symbol)
     {
      if(index<0 || index>=ArraySize(m_market_selection_symbols))
         return(false);

      symbol=m_market_selection_symbols[index];
      return(StringLen(symbol)>0);
     }

   int               MarketSelectionMinHistoryBars(void)
     {
      return(m_market_selection_min_history_bars);
     }

   double            MarketSelectionMaxSpreadPoints(void)
     {
      return(m_market_selection_max_spread_points);
     }

   double            MarketSelectionMaxSpreadToAtrRatio(void)
     {
      return(m_market_selection_max_spread_to_atr_ratio);
     }

   double            MarketSelectionMinVolatilityScore(void)
     {
      return(m_market_selection_min_volatility_score);
     }

   double            MarketSelectionMaxVolatilityScore(void)
     {
      return(m_market_selection_max_volatility_score);
     }

   double            MarketSelectionMinScore(void)
     {
      return(m_market_selection_min_score);
     }

   double            MarketSelectionTransitionPenalty(void)
     {
      return(m_market_selection_transition_penalty);
     }

   int               PairRankingMaxDataAgeSeconds(void)
     {
      return(m_pair_ranking_max_data_age_seconds);
     }

   double            PairRankingWeightSelectionScore(void)
     {
      return(m_pair_ranking_weight_selection_score);
     }

   double            PairRankingWeightSelectionConfidence(void)
     {
      return(m_pair_ranking_weight_selection_confidence);
     }

   double            PairRankingWeightSpreadEfficiency(void)
     {
      return(m_pair_ranking_weight_spread_efficiency);
     }

   double            PairRankingWeightEnvironmentConfidence(void)
     {
      return(m_pair_ranking_weight_environment_confidence);
     }

   double            PairRankingWeightVolatilitySuitability(void)
     {
      return(m_pair_ranking_weight_volatility_suitability);
     }

   double            PairRankingWeightRegimeSuitability(void)
     {
      return(m_pair_ranking_weight_regime_suitability);
     }

   double            PairRankingWeightFreshness(void)
     {
      return(m_pair_ranking_weight_freshness);
     }

   double            CapitalAllocationTotalBudget(void)
     {
      return(m_capital_allocation_total_budget);
     }

   double            CapitalAllocationMaxPerSymbol(void)
     {
      return(m_capital_allocation_max_per_symbol);
     }

   double            CapitalAllocationMinThreshold(void)
     {
      return(m_capital_allocation_min_threshold);
     }

   int               CapitalAllocationMaxFundedSymbols(void)
     {
      return(m_capital_allocation_max_funded_symbols);
     }

   double            CapitalAllocationConcentrationLimit(void)
     {
      return(m_capital_allocation_concentration_limit);
     }

   double            CapitalAllocationConfidenceThreshold(void)
     {
      return(m_capital_allocation_confidence_threshold);
     }

   int               CapitalAllocationStaleDataLimitSeconds(void)
     {
      return(m_capital_allocation_stale_data_limit_seconds);
     }

   double            CapitalAllocationVolatilityPenalty(void)
     {
      return(m_capital_allocation_volatility_penalty);
     }

   double            CapitalAllocationTransitionPenalty(void)
     {
      return(m_capital_allocation_transition_penalty);
     }

   double            TradingStyleTrendConfidenceThreshold(void)
     {
      return(m_trading_style_trend_confidence_threshold);
     }

   double            TradingStyleRangeConfidenceThreshold(void)
     {
      return(m_trading_style_range_confidence_threshold);
     }

   double            TradingStyleMaxVolatilityScore(void)
     {
      return(m_trading_style_max_volatility_score);
     }

   double            TradingStyleTransitionPenalty(void)
     {
      return(m_trading_style_transition_penalty);
     }

   int               TradingStyleStaleDataLimitSeconds(void)
     {
      return(m_trading_style_stale_data_limit_seconds);
     }

   double            TradingStyleStaleDataPenalty(void)
     {
      return(m_trading_style_stale_data_penalty);
     }

   double            TradingStyleMinAllocationPercent(void)
     {
      return(m_trading_style_min_allocation_percent);
     }

   double            StrategySelectionMinConfidence(void)
     {
      return(m_strategy_selection_min_confidence);
     }

   double            StrategySelectionMinAllocationPercent(void)
     {
      return(m_strategy_selection_min_allocation_percent);
     }

   double            StrategySelectionMinRankingScore(void)
     {
      return(m_strategy_selection_min_ranking_score);
     }

   double            StrategySelectionRangeThreshold(void)
     {
      return(m_strategy_selection_range_threshold);
     }

   double            StrategySelectionTrendThreshold(void)
     {
      return(m_strategy_selection_trend_threshold);
     }

   double            StrategySelectionBreakoutVolatilityThreshold(void)
     {
      return(m_strategy_selection_breakout_volatility_threshold);
     }

   double            StrategySelectionTransitionPenalty(void)
     {
      return(m_strategy_selection_transition_penalty);
     }

   int               StrategySelectionStaleDataLimitSeconds(void)
     {
      return(m_strategy_selection_stale_data_limit_seconds);
     }

   double            StrategySelectionNoTradeSafetyThreshold(void)
     {
      return(m_strategy_selection_no_trade_safety_threshold);
     }

   int               StandbyEntryConfirmationBars(void)
     {
      return(m_standby_entry_confirmation_bars);
     }

   int               StandbyRecoveryConfirmationBars(void)
     {
      return(m_standby_recovery_confirmation_bars);
     }

   int               StandbyMaxDurationSeconds(void)
     {
      return(m_standby_max_duration_seconds);
     }

   double            StandbyBreakoutDistancePoints(void)
     {
      return(m_standby_breakout_distance_points);
     }

   double            StandbyBreakoutDistanceAtrMultiple(void)
     {
      return(m_standby_breakout_distance_atr_multiple);
     }

   double            StandbyMinRangeRecoveryScore(void)
     {
      return(m_standby_min_range_recovery_score);
     }

   double            StandbyTrendEscalationThreshold(void)
     {
      return(m_standby_trend_escalation_threshold);
     }

   double            StandbyVolatilityEscalationThreshold(void)
     {
      return(m_standby_volatility_escalation_threshold);
     }

   double            StandbyConfidenceRecoveryThreshold(void)
     {
      return(m_standby_confidence_recovery_threshold);
     }

   double            StandbyConfidenceFailureThreshold(void)
     {
      return(m_standby_confidence_failure_threshold);
     }

   int               StandbyTransitionCooldownSeconds(void)
     {
      return(m_standby_transition_cooldown_seconds);
     }

   int               StandbyStaleDataGraceSeconds(void)
     {
      return(m_standby_stale_data_grace_seconds);
     }

   double            RiskCautionThreshold(void)
     {
      return(m_risk_caution_threshold);
     }

   double            RiskReducedThreshold(void)
     {
      return(m_risk_reduced_threshold);
     }

   double            RiskSuspendedThreshold(void)
     {
      return(m_risk_suspended_threshold);
     }

   double            RiskStopThreshold(void)
     {
      return(m_risk_stop_threshold);
     }

   double            RiskVolatilityThreshold(void)
     {
      return(m_risk_volatility_threshold);
     }

   double            RiskMinimumConfidence(void)
     {
      return(m_risk_minimum_confidence);
     }

   double            RiskMaxAllocationPerSymbol(void)
     {
      return(m_risk_max_allocation_per_symbol);
     }

   double            RiskMaxAggregateAllocation(void)
     {
      return(m_risk_max_aggregate_allocation);
     }

   double            RiskMaxConcentrationRatio(void)
     {
      return(m_risk_max_concentration_ratio);
     }

   int               RiskStaleDataLimitSeconds(void)
     {
      return(m_risk_stale_data_limit_seconds);
     }

   double            RiskInvalidSymbolRatioThreshold(void)
     {
      return(m_risk_invalid_symbol_ratio_threshold);
     }

   double            RiskStandbyEscalationThreshold(void)
     {
      return(m_risk_standby_escalation_threshold);
     }

   int               RiskUnsafeConfirmationCount(void)
     {
      return(m_risk_unsafe_confirmation_count);
     }

   int               RiskRecoveryConfirmationCount(void)
     {
      return(m_risk_recovery_confirmation_count);
     }

   int               RiskTransitionCooldownSeconds(void)
     {
      return(m_risk_transition_cooldown_seconds);
     }

   double            RiskCautionAllocationMultiplier(void)
     {
      return(m_risk_caution_allocation_multiplier);
     }

   double            RiskReducedAllocationMultiplier(void)
     {
      return(m_risk_reduced_allocation_multiplier);
     }
   bool              ExecutionEnabled(void)
     {
      return(m_execution_enabled);
     }

   string            ExecutionSymbol(void)
     {
      return(m_execution_symbol);
     }

   long              ExecutionMagicNumber(void)
     {
      return(m_execution_magic_number);
     }

   double            ExecutionFixedLot(void)
     {
      return(m_execution_fixed_lot);
     }

   double            ExecutionMaximumSpreadPoints(void)
     {
      return(m_execution_maximum_spread_points);
     }

   double            ExecutionEntryBoundaryDistancePoints(void)
     {
      return(m_execution_entry_boundary_distance_points);
     }

   double            ExecutionEntryBoundaryDistanceAtrRatio(void)
     {
      return(m_execution_entry_boundary_distance_atr_ratio);
     }

   string            ExecutionExitMode(void)
     {
      return(m_execution_exit_mode);
     }

   double            ExecutionFixedTakeProfitPoints(void)
     {
      return(m_execution_fixed_take_profit_points);
     }

   double            ExecutionFixedStopLossPoints(void)
     {
      return(m_execution_fixed_stop_loss_points);
     }

   double            ExecutionRangeStopBufferPoints(void)
     {
      return(m_execution_range_stop_buffer_points);
     }

   double            ExecutionMinimumRangeScore(void)
     {
      return(m_execution_minimum_range_score);
     }

   double            ExecutionMinimumStrategyConfidence(void)
     {
      return(m_execution_minimum_strategy_confidence);
     }

   double            ExecutionMinimumRiskConfidence(void)
     {
      return(m_execution_minimum_risk_confidence);
     }

   int               ExecutionOrderCooldownSeconds(void)
     {
      return(m_execution_order_cooldown_seconds);
     }

   bool              ExecutionOneOrderPerBar(void)
     {
      return(m_execution_one_order_per_bar);
     }

   int               ExecutionMaximumOpenPositionsPerSymbol(void)
     {
      return(m_execution_maximum_open_positions_per_symbol);
     }

   bool              ExecutionAllowBuy(void)
     {
      return(m_execution_allow_buy);
     }

   bool              ExecutionAllowSell(void)
     {
      return(m_execution_allow_sell);
     }

   int               ExecutionMaximumSlippagePoints(void)
     {
      return(m_execution_maximum_slippage_points);
     }

   int               ExecutionTransientRetryLimit(void)
     {
      return(m_execution_transient_retry_limit);
     }

   string            ExecutionTradeComment(void)
     {
      return(m_execution_trade_comment);
     }
  };

#endif // FENX_CONFIG_PARAMETER_MANAGER_MQH
