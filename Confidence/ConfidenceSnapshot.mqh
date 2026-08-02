//+------------------------------------------------------------------+
//|                              Confidence/ConfidenceSnapshot.mqh  |
//+------------------------------------------------------------------+
#ifndef FENX_CONFIDENCE_SNAPSHOT_MQH
#define FENX_CONFIDENCE_SNAPSHOT_MQH

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
