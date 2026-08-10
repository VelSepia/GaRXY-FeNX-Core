//+------------------------------------------------------------------+
//|                                Environment/TrendSnapshot.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_ENVIRONMENT_TREND_SNAPSHOT_MQH
#define FENX_ENVIRONMENT_TREND_SNAPSHOT_MQH

#include "../Common/Constants.mqh"

//--- Typed representation of the existing TrendDetector result. The legacy
//--- fields retain their names so the detector calculation remains unchanged.
struct STrendSnapshot
  {
   //--- Existing trend output
   string   direction;
   double   strength;
   double   score;
   double   slope_points;
   double   confidence;
   double   adx;
   bool     is_trend;
   bool     is_data_valid;
   datetime updated_at;

   //--- Common snapshot identity and validity
   string   symbol;
   string   timeframe;
   string   snapshot_version;
   bool     is_valid;
   bool     is_fresh;
   string   invalid_reason;

   //--- Existing indicator facts. DI values are typed-only because the
   //--- legacy Environment.Trend namespace does not publish DI keys.
   double   plus_di;
   double   minus_di;

   //--- Existing-source metadata
   datetime source_updated_at;
   datetime source_bar_time;
   int      ema_period;
   int      ema_shift;
   int      adx_period;
   int      adx_shift;
  };

//--- Applies typed validity, freshness, and structural-integrity rules only.
//--- It never calculates EMA, ADX, DI, trend scores, or trading decisions.
class CTrendSnapshotContract
  {
public:
   bool              Finalize(STrendSnapshot &snapshot,
                              const datetime evaluation_time,
                              const int freshness_limit_seconds,
                              const double direction_score_threshold,
                              const double strength_threshold,
                              const double confidence_threshold,
                              const double minimum_adx)
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
         snapshot.invalid_reason="Trend source timestamp is invalid.";
         return(false);
        }

      const long age_seconds=(long)(evaluation_time-snapshot.source_updated_at);
      snapshot.is_fresh=(age_seconds>=0 && age_seconds<=freshness_limit_seconds);
      if(!snapshot.is_fresh)
        {
         snapshot.invalid_reason=(age_seconds<0 ?
                                  "Trend source is future-dated." :
                                  "Trend source is stale.");
         return(false);
        }
      if(!snapshot.is_data_valid)
        {
         snapshot.invalid_reason="Trend source is unavailable.";
         return(false);
        }
      if(snapshot.source_bar_time<=0 || snapshot.ema_period<2 ||
         snapshot.ema_shift<0 || snapshot.adx_period<2 ||
         snapshot.adx_shift<0)
        {
         snapshot.invalid_reason="Trend source metadata is invalid.";
         return(false);
        }
      if(snapshot.direction!="UP" && snapshot.direction!="DOWN" &&
         snapshot.direction!="NEUTRAL")
        {
         snapshot.invalid_reason="Trend direction integrity is invalid.";
         return(false);
        }
      if(!MathIsValidNumber(snapshot.strength) ||
         !MathIsValidNumber(snapshot.score) ||
         !MathIsValidNumber(snapshot.slope_points) ||
         !MathIsValidNumber(snapshot.confidence) ||
         !MathIsValidNumber(snapshot.adx) ||
         !MathIsValidNumber(snapshot.plus_di) ||
         !MathIsValidNumber(snapshot.minus_di) ||
         snapshot.strength<0.0 || snapshot.strength>100.0 ||
         snapshot.score<-100.0 || snapshot.score>100.0 ||
         snapshot.confidence<0.0 || snapshot.confidence>100.0 ||
         snapshot.adx<0.0 || snapshot.adx>100.0 ||
         snapshot.plus_di<0.0 || snapshot.plus_di>100.0 ||
         snapshot.minus_di<0.0 || snapshot.minus_di>100.0)
        {
         snapshot.invalid_reason="Trend structure integrity is invalid.";
         return(false);
        }

      string expected_direction="NEUTRAL";
      if(snapshot.score>=direction_score_threshold)
         expected_direction="UP";
      else if(snapshot.score<=-direction_score_threshold)
         expected_direction="DOWN";
      const bool expected_is_trend=(snapshot.direction!="NEUTRAL" &&
                                    snapshot.strength>=strength_threshold &&
                                    snapshot.confidence>=confidence_threshold &&
                                    snapshot.adx>=minimum_adx);
      if(snapshot.direction!=expected_direction ||
         snapshot.is_trend!=expected_is_trend)
        {
         snapshot.invalid_reason="Trend predicate integrity is invalid.";
         return(false);
        }

      snapshot.is_valid=true;
      return(true);
     }
  };

#endif // FENX_ENVIRONMENT_TREND_SNAPSHOT_MQH
