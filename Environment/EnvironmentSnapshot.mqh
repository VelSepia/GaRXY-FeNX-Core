//+------------------------------------------------------------------+
//|                         Environment/EnvironmentSnapshot.mqh     |
//+------------------------------------------------------------------+
#ifndef FENX_ENVIRONMENT_SNAPSHOT_MQH
#define FENX_ENVIRONMENT_SNAPSHOT_MQH

//--- Consolidated factual snapshot produced by the shadow Environment Engine.
//--- It is not a trading signal and no existing consumer reads it in Task002.
struct SEnvironmentSnapshot
  {
   //--- Identity
   string   symbol;
   string   timeframe;
   string   snapshot_version;
   datetime updated_at;

   //--- Aggregate validity
   bool     is_valid;
   bool     is_fresh;
   string   invalid_reason;

   //--- Volatility facts
   double   atr;
   double   volatility_score;
   string   volatility_level;
   datetime volatility_updated_at;
   bool     volatility_valid;

   //--- Range facts
   double   range_upper;
   double   range_lower;
   double   range_midpoint;
   double   range_width_points;
   double   range_position;
   double   range_score;
   bool     is_range;
   datetime range_updated_at;
   bool     range_valid;

   //--- Trend facts
   string   trend_direction;
   double   trend_strength;
   double   trend_score;
   double   trend_slope;
   double   trend_confidence;
   double   adx;
   bool     is_trend;
   datetime trend_updated_at;
   bool     trend_valid;

   //--- Integrated market-state facts
   string   market_state;
   double   market_confidence;
   string   recommended_style;
   string   recommended_risk;
   datetime market_state_updated_at;
   bool     market_state_valid;
  };

#endif // FENX_ENVIRONMENT_SNAPSHOT_MQH
