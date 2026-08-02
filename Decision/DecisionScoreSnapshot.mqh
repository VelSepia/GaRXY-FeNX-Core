//+------------------------------------------------------------------+
//|                         Decision/DecisionScoreSnapshot.mqh      |
//+------------------------------------------------------------------+
#ifndef FENX_DECISION_SCORE_SNAPSHOT_MQH
#define FENX_DECISION_SCORE_SNAPSHOT_MQH

#include "../Common/Constants.mqh"

//--- One audited upstream score and the metadata required to decide whether
//--- it may participate in the shadow aggregate. Missing or stale values are
//--- represented explicitly and are never substituted with zero.
struct SDecisionScoreSourceSnapshot
  {
   string   source_name;
   double   score;
   bool     is_present;
   bool     is_valid;
   bool     is_fresh;
   datetime updated_at;
   string   invalid_reason;
  };

//--- Shadow-only aggregate of the five compatible, always-available pipeline
//--- suitability scores audited in Task008. This snapshot is descriptive and
//--- is not an entry, exit, risk, sizing, or execution instruction.
struct SDecisionScoreSnapshot
  {
   //--- Stable typed-store identity.
   string   symbol;
   string   timeframe;
   string   snapshot_version;
   datetime updated_at;

   //--- Aggregate validity and completeness.
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

   //--- Source contracts accepted by the pre-implementation audit.
   SDecisionScoreSourceSnapshot market_selection_score;
   SDecisionScoreSourceSnapshot pair_ranking_score;
   SDecisionScoreSourceSnapshot capital_allocation_score;
   SDecisionScoreSourceSnapshot trading_style_score;
   SDecisionScoreSourceSnapshot strategy_selection_score;

   //--- Unweighted descriptive statistics over valid and fresh sources only.
   double   average_score;
   double   minimum_score;
   double   maximum_score;
   double   score_range;
   double   score_variance;
   double   score_standard_deviation;
   string   bottleneck_stage;
   string   strongest_stage;

   //--- Exact disagreement facts; no trading threshold is introduced.
   bool     all_sources_aligned;
   bool     source_disagreement;
   double   disagreement_magnitude;
  };

#endif // FENX_DECISION_SCORE_SNAPSHOT_MQH
