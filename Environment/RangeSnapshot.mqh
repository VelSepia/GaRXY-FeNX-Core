//+------------------------------------------------------------------+
//|                                Environment/RangeSnapshot.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_ENVIRONMENT_RANGE_SNAPSHOT_MQH
#define FENX_ENVIRONMENT_RANGE_SNAPSHOT_MQH

#include "../Common/Constants.mqh"

//--- Typed representation of the existing RangeDetector result. The legacy
//--- fields retain their names so the detector calculation remains unchanged.
struct SRangeSnapshot
  {
   //--- Existing range output
   double   upper;
   double   lower;
   double   width_points;
   double   midpoint;
   double   position;
   double   score;
   bool     is_range;
   bool     is_data_valid;
   datetime updated_at;
   datetime closed_bar_time;

   //--- Common snapshot identity and validity
   string   symbol;
   string   timeframe;
   string   snapshot_version;
   bool     is_valid;
   bool     is_fresh;
   string   invalid_reason;

   //--- Existing-source metadata
   datetime source_updated_at;
   datetime source_bar_time;
   int      lookback;
   int      price_digits;
   double   point_size;
   double   source_atr;
   //--- The legacy ATR DataBus key has no timestamp API. Zero explicitly
   //--- means unavailable; no inferred timestamp is fabricated.
   datetime atr_updated_at;
  };

//--- Applies typed validity, freshness, and structural-integrity rules only.
//--- It never calculates range boundaries, scores, or trading decisions.
class CRangeSnapshotContract
  {
public:
   bool              Finalize(SRangeSnapshot &snapshot,
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
         snapshot.invalid_reason="Range source timestamp is invalid.";
         return(false);
        }

      const long age_seconds=(long)(evaluation_time-snapshot.source_updated_at);
      snapshot.is_fresh=(age_seconds>=0 && age_seconds<=freshness_limit_seconds);
      if(!snapshot.is_fresh)
        {
         snapshot.invalid_reason=(age_seconds<0 ?
                                  "Range source is future-dated." :
                                  "Range source is stale.");
         return(false);
        }
      if(!snapshot.is_data_valid)
        {
         snapshot.invalid_reason="Range source is unavailable.";
         return(false);
        }
      if(snapshot.source_bar_time<=0 || snapshot.lookback<=0 ||
         snapshot.price_digits<0 ||
         !MathIsValidNumber(snapshot.point_size) || snapshot.point_size<=0.0 ||
         !MathIsValidNumber(snapshot.source_atr) || snapshot.source_atr<=0.0)
        {
         snapshot.invalid_reason="Range source metadata is invalid.";
         return(false);
        }
      if(!MathIsValidNumber(snapshot.upper) ||
         !MathIsValidNumber(snapshot.lower) ||
         !MathIsValidNumber(snapshot.midpoint) ||
         !MathIsValidNumber(snapshot.width_points) ||
         !MathIsValidNumber(snapshot.position) ||
         !MathIsValidNumber(snapshot.score) ||
         snapshot.upper<snapshot.lower ||
         snapshot.midpoint<snapshot.lower || snapshot.midpoint>snapshot.upper ||
         snapshot.width_points<0.0 ||
         snapshot.position<0.0 || snapshot.position>1.0 ||
         snapshot.score<0.0 || snapshot.score>100.0)
        {
         snapshot.invalid_reason="Range structure integrity is invalid.";
         return(false);
        }

      snapshot.is_valid=true;
      return(true);
     }
  };

#endif // FENX_ENVIRONMENT_RANGE_SNAPSHOT_MQH
