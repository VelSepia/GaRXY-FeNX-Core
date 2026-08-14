//+------------------------------------------------------------------+
//|                                      Entry/EntrySnapshot.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_ENTRY_SNAPSHOT_MQH
#define FENX_ENTRY_SNAPSHOT_MQH

#include "../Common/Constants.mqh"

//--- Read-only audit of one completed-bar entry evaluation. The snapshot
//--- records decisions already made by Strategy, ExecutionGate, position,
//--- duplicate, and order components; it never makes a trading decision.
struct SEntrySnapshot
  {
   //--- Identity
   string   symbol;
   string   timeframe;
   string   snapshot_version;
   datetime updated_at;
   datetime entry_evaluation_time;
   long     entry_evaluation_sequence;

   //--- Validity
   bool     is_valid;
   bool     is_fresh;
   string   invalid_reason;
   bool     data_leak_safe;

   //--- Strategy signal
   bool     signal_present;
   bool     direction_available;
   string   direction;
   string   strategy_name;
   datetime signal_bar_time;

   //--- Final entry decision
   bool     entry_allowed;
   bool     entry_blocked;
   string   final_entry_reason;
   string   block_stage;
   string   block_reason;

   //--- Ordered pipeline permissions. Availability distinguishes an observed
   //--- result from a stage that was not reached.
   bool     market_selection_available;
   bool     market_selection_allowed;
   bool     ranking_available;
   bool     ranking_allowed;
   bool     allocation_available;
   bool     allocation_allowed;
   bool     trading_style_available;
   bool     trading_style_allowed;
   bool     strategy_selection_available;
   bool     strategy_selection_allowed;
   bool     standby_available;
   bool     standby_allowed;
   bool     risk_available;
   bool     risk_allowed;
   bool     execution_gate_available;
   bool     execution_gate_allowed;

   //--- Existing filters. Applicable means the existing pipeline reached the
   //--- directional gate; no predicate is recalculated by this contract.
   bool     c3_applicable;
   bool     c3_blocked;
   bool     task007_applicable;
   bool     task007_blocked;
   bool     task011_applicable;
   bool     task011_blocked;

   //--- Existing quality result
   double   entry_quality_score;
   bool     entry_quality_valid;

   //--- Order readiness and outcome
   bool     position_available;
   bool     duplicate_order_result_available;
   bool     duplicate_order_allowed;
   bool     spread_allowed;
   bool     final_order_ready;
   bool     order_submitted;
   bool     order_succeeded;
   double   requested_lot;
   double   risk_multiplier;

   //--- Source timestamps. Availability is explicit so no missing timestamp
   //--- is synthesized for audit convenience.
   bool     decision_snapshot_available;
   datetime decision_snapshot_updated_at;
   bool     confidence_snapshot_available;
   datetime confidence_snapshot_updated_at;
   bool     standby_snapshot_available;
   datetime standby_snapshot_updated_at;
   bool     risk_snapshot_available;
   datetime risk_snapshot_updated_at;
   bool     market_state_snapshot_available;
   datetime market_state_snapshot_updated_at;
  };

//--- Validates identity and internal consistency of an already-decided Entry
//--- result. It deliberately does not recalculate any strategy or gate rule.
class CEntrySnapshotContract
  {
private:
   bool              TimestampSafe(const bool available,const datetime source_time,
                                   const datetime evaluation_time,
                                   const int freshness_limit_seconds,
                                   bool &fresh)
     {
      if(!available || source_time<=0 || evaluation_time<=0)
         return(false);
      const long age=(long)(evaluation_time-source_time);
      if(age<0)
         return(false);
      if(age>freshness_limit_seconds)
         fresh=false;
      return(true);
     }

public:
   bool              Finalize(SEntrySnapshot &snapshot,
                              const int freshness_limit_seconds)
     {
      snapshot.is_valid=false;
      snapshot.is_fresh=true;
      snapshot.data_leak_safe=false;
      snapshot.invalid_reason="";

      if(StringLen(snapshot.symbol)==0 || StringLen(snapshot.timeframe)==0 ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0 ||
         snapshot.entry_evaluation_time<=0 ||
         snapshot.entry_evaluation_sequence<=0 || snapshot.signal_bar_time<=0 ||
         freshness_limit_seconds<=0)
        {
         snapshot.invalid_reason="Entry snapshot identity is invalid.";
         return(false);
        }
      if(StringLen(snapshot.strategy_name)==0 ||
         StringLen(snapshot.final_entry_reason)==0 ||
         (snapshot.direction_available &&
          snapshot.direction!="BUY" && snapshot.direction!="SELL") ||
         (!snapshot.direction_available && snapshot.direction!="NONE"))
        {
         snapshot.invalid_reason="Entry signal identity is invalid.";
         return(false);
        }
      if(snapshot.entry_allowed && snapshot.entry_blocked)
        {
         snapshot.invalid_reason="Entry cannot be both allowed and blocked.";
         return(false);
        }
      if((snapshot.entry_blocked &&
          (StringLen(snapshot.block_stage)==0 ||
           StringLen(snapshot.block_reason)==0)) ||
         (snapshot.final_order_ready && !snapshot.signal_present) ||
         (snapshot.entry_allowed && !snapshot.final_order_ready) ||
         (snapshot.order_submitted && !snapshot.final_order_ready) ||
         (snapshot.order_succeeded && !snapshot.order_submitted) ||
         (snapshot.duplicate_order_result_available &&
          snapshot.duplicate_order_allowed && snapshot.entry_blocked))
        {
         snapshot.invalid_reason="Entry decision or order-readiness mapping is invalid.";
         return(false);
        }
      if((snapshot.c3_blocked && !snapshot.c3_applicable) ||
         (snapshot.task007_blocked && !snapshot.task007_applicable) ||
         (snapshot.task011_blocked && !snapshot.task011_applicable) ||
         (snapshot.c3_applicable && snapshot.direction!="SELL") ||
         (snapshot.task007_applicable && snapshot.direction!="SELL") ||
         (snapshot.task011_applicable && snapshot.direction!="SELL"))
        {
         snapshot.invalid_reason="Entry filter applicability is invalid.";
         return(false);
        }
      if(!MathIsValidNumber(snapshot.entry_quality_score) ||
         !MathIsValidNumber(snapshot.requested_lot) ||
         !MathIsValidNumber(snapshot.risk_multiplier) ||
         snapshot.entry_quality_score<0.0 ||
         snapshot.entry_quality_score>100.0 || snapshot.requested_lot<0.0 ||
         snapshot.risk_multiplier<0.0 || snapshot.risk_multiplier>1.0)
        {
         snapshot.invalid_reason="Entry numeric integrity is invalid.";
         return(false);
        }

      bool fresh=true;
      const bool timestamps_safe=
         (TimestampSafe(snapshot.decision_snapshot_available,
                        snapshot.decision_snapshot_updated_at,
                        snapshot.entry_evaluation_time,
                        freshness_limit_seconds,fresh) &&
          TimestampSafe(snapshot.confidence_snapshot_available,
                        snapshot.confidence_snapshot_updated_at,
                        snapshot.entry_evaluation_time,
                        freshness_limit_seconds,fresh) &&
          TimestampSafe(snapshot.standby_snapshot_available,
                        snapshot.standby_snapshot_updated_at,
                        snapshot.entry_evaluation_time,
                        freshness_limit_seconds,fresh) &&
          TimestampSafe(snapshot.risk_snapshot_available,
                        snapshot.risk_snapshot_updated_at,
                        snapshot.entry_evaluation_time,
                        freshness_limit_seconds,fresh) &&
          TimestampSafe(snapshot.market_state_snapshot_available,
                        snapshot.market_state_snapshot_updated_at,
                        snapshot.entry_evaluation_time,
                        freshness_limit_seconds,fresh));
      snapshot.data_leak_safe=timestamps_safe;
      snapshot.is_fresh=(timestamps_safe && fresh);
      if(!timestamps_safe)
        {
         snapshot.invalid_reason="Entry source metadata is unavailable or future-dated.";
         return(false);
        }
      if(!snapshot.is_fresh)
        {
         snapshot.invalid_reason="Entry source metadata is stale.";
         return(false);
        }

      snapshot.is_valid=true;
      return(true);
     }
  };

#endif // FENX_ENTRY_SNAPSHOT_MQH
