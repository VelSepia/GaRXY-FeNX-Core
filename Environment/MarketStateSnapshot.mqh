//+------------------------------------------------------------------+
//|                           Environment/MarketStateSnapshot.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_ENVIRONMENT_MARKET_STATE_SNAPSHOT_MQH
#define FENX_ENVIRONMENT_MARKET_STATE_SNAPSHOT_MQH

#include "../Common/Constants.mqh"

//--- Typed representation of the existing MarketStateIntegrator result. The
//--- first fields retain the legacy names so classification code is unchanged.
struct SMarketStateSnapshot
  {
   //--- Existing market-state output
   string   market_state;
   double   confidence;
   string   recommended_trading_style;
   string   recommended_risk_level;
   datetime updated_at;
   bool     is_data_valid;

   //--- Common snapshot identity and validity
   string   symbol;
   string   timeframe;
   string   snapshot_version;
   bool     is_valid;
   bool     is_fresh;
   string   invalid_reason;

   //--- Existing source state mirrored after legacy classification
   bool     volatility_valid;
   bool     range_valid;
   bool     trend_valid;
   double   volatility_score;
   string   volatility_level;
   double   range_score;
   bool     is_range;
   string   trend_direction;
   double   trend_strength;
   double   trend_score;
   double   trend_confidence;
   bool     is_trend;

   //--- Source metadata. Legacy Volatility has no timestamp key, so zero
   //--- explicitly means unavailable rather than an inferred timestamp.
   datetime source_updated_at;
   datetime volatility_updated_at;
   datetime range_updated_at;
   datetime trend_updated_at;
   datetime source_bar_time;
  };

//--- Applies typed validity, freshness, and output-integrity rules only. It
//--- does not classify a market state or reproduce the integrator predicates.
class CMarketStateSnapshotContract
  {
public:
   bool              Finalize(SMarketStateSnapshot &snapshot,
                              const datetime evaluation_time,
                              const int freshness_limit_seconds)
     {
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="";

      if(StringLen(snapshot.symbol)==0 || StringLen(snapshot.timeframe)==0 ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0)
        {
         snapshot.invalid_reason="Snapshot identity is invalid.";
         return(false);
        }
      if(snapshot.source_updated_at<=0 || evaluation_time<=0 ||
         freshness_limit_seconds<=0)
        {
         snapshot.invalid_reason="Market State source timestamp is invalid.";
         return(false);
        }

      const long age_seconds=(long)(evaluation_time-snapshot.source_updated_at);
      snapshot.is_fresh=(age_seconds>=0 && age_seconds<=freshness_limit_seconds);
      if(!snapshot.is_fresh)
        {
         snapshot.invalid_reason=(age_seconds<0 ?
                                  "Market State source is future-dated." :
                                  "Market State source is stale.");
         return(false);
        }
      if(!snapshot.is_data_valid)
        {
         snapshot.invalid_reason="Market State source is unavailable.";
         return(false);
        }
      if(!snapshot.volatility_valid || !snapshot.range_valid ||
         !snapshot.trend_valid)
        {
         snapshot.invalid_reason="One or more Market State inputs are invalid.";
         return(false);
        }
      if(snapshot.range_updated_at<=0 || snapshot.trend_updated_at<=0 ||
         snapshot.source_bar_time<=0)
        {
         snapshot.invalid_reason="Market State source metadata is invalid.";
         return(false);
        }
      if(snapshot.market_state!="RANGING" &&
         snapshot.market_state!="TRENDING" &&
         snapshot.market_state!="VOLATILE" &&
         snapshot.market_state!="TRANSITION")
        {
         snapshot.invalid_reason="Market State enum integrity is invalid.";
         return(false);
        }
      if(snapshot.recommended_trading_style!="Range" &&
         snapshot.recommended_trading_style!="Trend" &&
         snapshot.recommended_trading_style!="Standby")
        {
         snapshot.invalid_reason="Recommended style integrity is invalid.";
         return(false);
        }
      if(snapshot.recommended_risk_level!="Low" &&
         snapshot.recommended_risk_level!="Medium" &&
         snapshot.recommended_risk_level!="High")
        {
         snapshot.invalid_reason="Recommended risk integrity is invalid.";
         return(false);
        }
      if(!MathIsValidNumber(snapshot.confidence) ||
         !MathIsValidNumber(snapshot.volatility_score) ||
         !MathIsValidNumber(snapshot.range_score) ||
         !MathIsValidNumber(snapshot.trend_strength) ||
         !MathIsValidNumber(snapshot.trend_score) ||
         !MathIsValidNumber(snapshot.trend_confidence) ||
         snapshot.confidence<0.0 || snapshot.confidence>100.0 ||
         snapshot.volatility_score<0.0 || snapshot.volatility_score>100.0 ||
         snapshot.range_score<0.0 || snapshot.range_score>100.0 ||
         snapshot.trend_strength<0.0 || snapshot.trend_strength>100.0 ||
         snapshot.trend_score<-100.0 || snapshot.trend_score>100.0 ||
         snapshot.trend_confidence<0.0 || snapshot.trend_confidence>100.0)
        {
         snapshot.invalid_reason="Market State value integrity is invalid.";
         return(false);
        }
      if((snapshot.volatility_level!="LOW" &&
          snapshot.volatility_level!="NORMAL" &&
          snapshot.volatility_level!="HIGH") ||
         (snapshot.trend_direction!="UP" &&
          snapshot.trend_direction!="DOWN" &&
          snapshot.trend_direction!="NEUTRAL"))
        {
         snapshot.invalid_reason="Market State source enum integrity is invalid.";
         return(false);
        }

      //--- Validate the existing output mapping without recomputing State.
      const bool mapping_valid=
         (snapshot.market_state=="RANGING" &&
          snapshot.recommended_trading_style=="Range" &&
          (snapshot.recommended_risk_level=="Medium" ||
           snapshot.recommended_risk_level=="High")) ||
         (snapshot.market_state=="TRENDING" &&
          snapshot.recommended_trading_style=="Trend" &&
          (snapshot.recommended_risk_level=="Medium" ||
           snapshot.recommended_risk_level=="High")) ||
         (snapshot.market_state=="VOLATILE" &&
          snapshot.recommended_trading_style=="Standby" &&
          snapshot.recommended_risk_level=="High") ||
         (snapshot.market_state=="TRANSITION" &&
          snapshot.recommended_trading_style=="Standby" &&
          snapshot.recommended_risk_level=="Low");
      if(!mapping_valid)
        {
         snapshot.invalid_reason="Market State output mapping is invalid.";
         return(false);
        }

      snapshot.is_valid=true;
      return(true);
     }
  };

#endif // FENX_ENVIRONMENT_MARKET_STATE_SNAPSHOT_MQH
