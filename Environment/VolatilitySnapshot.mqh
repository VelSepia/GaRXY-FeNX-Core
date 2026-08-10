//+------------------------------------------------------------------+
//|                          Environment/VolatilitySnapshot.mqh     |
//+------------------------------------------------------------------+
#ifndef FENX_ENVIRONMENT_VOLATILITY_SNAPSHOT_MQH
#define FENX_ENVIRONMENT_VOLATILITY_SNAPSHOT_MQH

#include "../Common/Constants.mqh"

//--- Typed representation of the legacy VolatilityAnalyzer output. Source
//--- values are the exact values serialized to Environment.Volatility.*;
//--- metadata describes the existing indicator read without recalculation.
struct SVolatilitySnapshot
  {
   //--- Identity
   string   symbol;
   string   timeframe;
   string   snapshot_version;
   datetime updated_at;

   //--- Validity
   bool     is_valid;
   bool     is_fresh;
   string   invalid_reason;

   //--- Existing source output
   double   atr;
   double   volatility_score;
   string   volatility_level;

   //--- Existing source metadata
   datetime source_updated_at;
   datetime source_bar_time;
   int      atr_period;
   int      atr_shift;
   int      baseline_samples;
  };

//--- Centralizes validity/freshness rules so production and the independent
//--- harness exercise the same typed contract. It never calculates ATR, score,
//--- or level and therefore cannot change the legacy volatility algorithm.
class CVolatilitySnapshotContract
  {
public:
   void              Reset(SVolatilitySnapshot &snapshot,
                           const string symbol,
                           const ENUM_TIMEFRAMES timeframe,
                           const datetime updated_at,
                           const int atr_period,
                           const int atr_shift,
                           const int baseline_samples)
     {
      snapshot.symbol=symbol;
      snapshot.timeframe=EnumToString(timeframe);
      snapshot.snapshot_version=FENX_COMMON_VOLATILITY_SNAPSHOT_VERSION;
      snapshot.updated_at=updated_at;
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="Volatility source is unavailable.";
      snapshot.atr=0.0;
      snapshot.volatility_score=0.0;
      snapshot.volatility_level="";
      snapshot.source_updated_at=0;
      snapshot.source_bar_time=0;
      snapshot.atr_period=atr_period;
      snapshot.atr_shift=atr_shift;
      snapshot.baseline_samples=baseline_samples;
     }

   bool              Finalize(SVolatilitySnapshot &snapshot,
                              const datetime evaluation_time,
                              const int freshness_limit_seconds)
     {
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="";

      if(StringLen(snapshot.symbol)==0 ||
         StringLen(snapshot.timeframe)==0 ||
         StringLen(snapshot.snapshot_version)==0 ||
         snapshot.updated_at<=0)
        {
         snapshot.invalid_reason="Snapshot identity is invalid.";
         return(false);
        }
      if(snapshot.atr_period<=0 || snapshot.atr_shift<0 ||
         snapshot.baseline_samples<=0)
        {
         snapshot.invalid_reason="ATR metadata is invalid.";
         return(false);
        }
      if(!MathIsValidNumber(snapshot.atr) || snapshot.atr<=0.0 ||
         !MathIsValidNumber(snapshot.volatility_score) ||
         snapshot.volatility_score<0.0 || snapshot.volatility_score>100.0 ||
         (snapshot.volatility_level!="LOW" &&
          snapshot.volatility_level!="NORMAL" &&
          snapshot.volatility_level!="HIGH"))
        {
         snapshot.invalid_reason="Volatility source values are invalid.";
         return(false);
        }
      if(snapshot.source_updated_at<=0 || snapshot.source_bar_time<=0 ||
         evaluation_time<=0 || freshness_limit_seconds<=0)
        {
         snapshot.invalid_reason="Volatility source timestamp is invalid.";
         return(false);
        }

      const long age_seconds=(long)(evaluation_time-snapshot.source_updated_at);
      snapshot.is_fresh=(age_seconds>=0 && age_seconds<=freshness_limit_seconds);
      if(!snapshot.is_fresh)
        {
         snapshot.invalid_reason=(age_seconds<0 ?
                                  "Volatility source is future-dated." :
                                  "Volatility source is stale.");
         return(false);
        }

      snapshot.is_valid=true;
      return(true);
     }
  };

#endif // FENX_ENVIRONMENT_VOLATILITY_SNAPSHOT_MQH
