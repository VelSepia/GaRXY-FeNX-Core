//+------------------------------------------------------------------+
//|                              Confidence/ConfidenceSnapshot.mqh  |
//+------------------------------------------------------------------+
#ifndef FENX_CONFIDENCE_SNAPSHOT_MQH
#define FENX_CONFIDENCE_SNAPSHOT_MQH

#include "../Common/Constants.mqh"

//--- One factual confidence source and the metadata required to decide
//--- whether it may participate in descriptive statistics.
struct SConfidenceSourceSnapshot
  {
   string   stage;
   double   value;
   bool     is_present;
   bool     is_valid;
   datetime updated_at;
   bool     is_fresh;
   string   invalid_reason;
  };

//--- Bounded, chronological completeness history for one Symbol+Timeframe.
//--- Task007 intentionally retains only the six snapshots used by Task006.
struct SConfidenceCompletenessHistory
  {
   string          symbol;
   ENUM_TIMEFRAMES timeframe;
   int             count;
   datetime        bar_times[FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE];
   datetime        snapshot_updated_at[FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE];
   double          completeness[FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE];
   string          validity_state[FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE];
  };

//--- Initializes a bounded transition history without allocating unbounded
//--- dynamic storage or sharing observations across symbols/timeframes.
void FenxResetConfidenceCompletenessHistory(
   SConfidenceCompletenessHistory &history,const string symbol,
   const ENUM_TIMEFRAMES timeframe)
  {
   history.symbol=symbol;
   history.timeframe=timeframe;
   history.count=0;
   for(int index=0;index<FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE;index++)
     {
      history.bar_times[index]=0;
      history.snapshot_updated_at[index]=0;
      history.completeness[index]=0.0;
      history.validity_state[index]="INVALID";
     }
  }

//--- Adds one new-bar snapshot. Repeated ticks on the same bar never create
//--- duplicate history entries, matching Task005's once-per-bar telemetry.
bool FenxAppendConfidenceCompletenessSnapshot(
   SConfidenceCompletenessHistory &history,const datetime bar_time,
   const datetime snapshot_updated_at,const double completeness,
   const string validity_state)
  {
   if(bar_time<=0 || snapshot_updated_at<=0 ||
      completeness<0.0 || completeness>100.0)
      return(false);
   if(history.count>0 && history.bar_times[history.count-1]==bar_time)
      return(false);

   int target=history.count;
   if(history.count>=FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE)
     {
      for(int index=1;index<FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE;index++)
        {
         history.bar_times[index-1]=history.bar_times[index];
         history.snapshot_updated_at[index-1]=history.snapshot_updated_at[index];
         history.completeness[index-1]=history.completeness[index];
         history.validity_state[index-1]=history.validity_state[index];
        }
      target=FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE-1;
     }
   else
      history.count++;

   history.bar_times[target]=bar_time;
   history.snapshot_updated_at[target]=snapshot_updated_at;
   history.completeness[target]=completeness;
   history.validity_state[target]=validity_state;
   return(true);
  }

//--- Reproduces Task006's six-snapshot completeness transition categories.
//--- A value is full at 99.999 or above; only observations available by the
//--- current snapshot may appear in the supplied chronological history.
string FenxClassifyConfidenceCompletenessTransition(
   const SConfidenceCompletenessHistory &history)
  {
   if(history.count<FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE)
      return("WINDOW_INCOMPLETE");

   const int current=FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE-1;
   if(history.validity_state[current]!="VALID" &&
      history.validity_state[current]!="PARTIAL")
      return("INVALID_OR_STALE_AT_ENTRY");

   const bool current_full=
      (history.completeness[current]>=
       FENX_COMMON_CONFIDENCE_FULL_COMPLETENESS_THRESHOLD);
   const bool previous_full=
      (history.completeness[current-1]>=
       FENX_COMMON_CONFIDENCE_FULL_COMPLETENESS_THRESHOLD);
   bool all_full=true;
   bool older_has_full=false;
   bool older_has_partial=false;
   for(int index=0;index<FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE;index++)
     {
      const bool is_full=
         (history.completeness[index]>=
          FENX_COMMON_CONFIDENCE_FULL_COMPLETENESS_THRESHOLD);
      if(!is_full)
         all_full=false;
      if(index<current && is_full)
         older_has_full=true;
      if(index<current && !is_full)
         older_has_partial=true;
     }

   if(current_full && all_full)
      return("FULL_MAINTAINED");
   if(current_full && !previous_full)
      return("RECOVERED_AT_ENTRY");
   if(current_full && older_has_partial)
      return("RECOVERED_EARLIER");
   if(!current_full && previous_full)
      return("DROPPED_AT_ENTRY");
   if(!current_full && older_has_full)
      return("PARTIAL_AFTER_DROP");
   if(!current_full)
      return("PARTIAL_CONTINUING");
   return("FULL_UNCLASSIFIED");
  }

//--- Shadow-only aggregate of existing confidence outputs. It is descriptive
//--- telemetry and is never an entry, exit, risk, or sizing decision.
struct SConfidenceSnapshot
  {
   //--- Identity
   string   symbol;
   string   timeframe;
   string   snapshot_version;
   datetime updated_at;

   //--- Validity and completeness
   string   validity_state;
   bool     is_valid;
   bool     is_fresh;
   string   invalid_reason;
   int      expected_source_count;
   int      valid_source_count;
   int      missing_source_count;
   int      unavailable_source_count;
   int      invalid_source_count;
   int      stale_source_count;
   double   completeness_ratio;

   //--- Task006-compatible, six-snapshot completeness transition summary.
   string   completeness_transition;
   int      transition_window_size;
   bool     transition_valid;
   datetime transition_updated_at;
   string   transition_invalid_reason;

   //--- Existing source values and source-level metadata
   SConfidenceSourceSnapshot market_state_confidence;
   SConfidenceSourceSnapshot market_selection_confidence;
   SConfidenceSourceSnapshot pair_ranking_confidence;
   SConfidenceSourceSnapshot capital_allocation_confidence;
   SConfidenceSourceSnapshot trading_style_confidence;
   SConfidenceSourceSnapshot strategy_selection_confidence;
   SConfidenceSourceSnapshot standby_confidence;
   SConfidenceSourceSnapshot risk_confidence;

   //--- Descriptive statistics over valid and fresh sources only
   double   average_confidence;
   double   minimum_confidence;
   double   maximum_confidence;
   double   confidence_range;
   double   confidence_variance;
   double   confidence_standard_deviation;
   string   bottleneck_stage;
   string   strongest_stage;

   //--- Existing categorical market state retained for later telemetry joins.
   string   market_state;
  };

#endif // FENX_CONFIDENCE_SNAPSHOT_MQH
