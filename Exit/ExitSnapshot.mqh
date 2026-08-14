//+------------------------------------------------------------------+
//|                                        Exit/ExitSnapshot.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_EXIT_SNAPSHOT_MQH
#define FENX_EXIT_SNAPSHOT_MQH

#include "../Common/Constants.mqh"

//--- Read-only audit of one established Exit evaluation and its optional
//--- close lifecycle. It records facts already produced by Strategy,
//--- Execution, OrderExecutor, PositionManager, and the terminal; it has no
//--- authority to close or modify a position.
struct SExitSnapshot
  {
   //--- Identity
   string   symbol;
   string   timeframe;
   string   snapshot_version;
   datetime updated_at;
   datetime exit_evaluation_time;
   long     exit_evaluation_sequence;
   ulong    position_ticket;
   ulong    position_lifecycle_id;

   //--- Position
   string   direction;
   datetime open_time;
   double   open_price;
   double   current_price;
   double   volume;
   double   stop_loss;
   double   take_profit;
   bool     position_closed;

   //--- Validity
   bool     is_valid;
   bool     is_fresh;
   string   invalid_reason;
   bool     data_leak_safe;

   //--- Existing Exit evaluation result
   bool     exit_signal_present;
   bool     exit_allowed;
   bool     exit_blocked;
   string   exit_type;
   string   exit_reason;
   datetime signal_bar_time;
   double   signal_price;

   //--- Existing Strategy Exit observation
   bool     strategy_exit_applicable;
   bool     strategy_exit_triggered;
   double   range_midpoint;
   bool     range_midpoint_triggered;

   //--- Existing broker-side protective levels and confirmed triggers
   bool     stop_loss_present;
   bool     take_profit_present;
   bool     stop_loss_triggered;
   bool     take_profit_triggered;

   //--- Existing close lifecycle
   bool     close_requested;
   datetime close_request_time;
   bool     close_request_accepted;
   bool     close_succeeded;
   bool     close_failed;
   int      retry_count;
   long     retcode;
   datetime last_attempt_time;
   string   final_close_reason;
   datetime close_time;
   double   close_price;

   //--- Source metadata. Availability is explicit; missing facts are never
   //--- synthesized merely to make an audit record appear complete.
   bool     range_snapshot_available;
   datetime range_snapshot_updated_at;
   bool     market_state_snapshot_available;
   datetime market_state_snapshot_updated_at;
   bool     risk_snapshot_available;
   datetime risk_snapshot_updated_at;
   bool     standby_snapshot_available;
   datetime standby_snapshot_updated_at;
   datetime position_last_seen_at;
  };

//--- Validates a passive Exit record without recalculating the Range midpoint,
//--- changing an Exit result, or applying a new freshness gate to trading.
class CExitSnapshotContract
  {
private:
   bool              TimestampNotFuture(const bool available,
                                        const datetime source_time,
                                        const datetime evaluation_time)
     {
      if(!available)
         return(true);
      return(source_time>0 && evaluation_time>0 &&
             source_time<=evaluation_time);
     }

public:
   bool              Finalize(SExitSnapshot &snapshot,
                              const int freshness_limit_seconds)
     {
      snapshot.is_valid=false;
      snapshot.is_fresh=true;
      snapshot.data_leak_safe=false;
      snapshot.invalid_reason="";

      if(StringLen(snapshot.symbol)==0 || StringLen(snapshot.timeframe)==0 ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0 ||
         snapshot.exit_evaluation_time<=0 ||
         snapshot.exit_evaluation_sequence<=0 || snapshot.position_ticket==0 ||
         snapshot.position_lifecycle_id==0 || freshness_limit_seconds<=0)
        {
         snapshot.invalid_reason="Exit snapshot identity is invalid.";
         return(false);
        }
      if(snapshot.direction!="BUY" && snapshot.direction!="SELL")
        {
         snapshot.invalid_reason="Exit position direction is invalid.";
         return(false);
        }
      if(!MathIsValidNumber(snapshot.open_price) ||
         !MathIsValidNumber(snapshot.current_price) ||
         !MathIsValidNumber(snapshot.volume) ||
         !MathIsValidNumber(snapshot.stop_loss) ||
         !MathIsValidNumber(snapshot.take_profit) ||
         !MathIsValidNumber(snapshot.signal_price) ||
         !MathIsValidNumber(snapshot.range_midpoint) ||
         !MathIsValidNumber(snapshot.close_price) || snapshot.open_price<=0.0 ||
         snapshot.current_price<=0.0 || snapshot.volume<=0.0 ||
         snapshot.stop_loss<0.0 || snapshot.take_profit<0.0 ||
         snapshot.signal_price<0.0 || snapshot.range_midpoint<0.0 ||
         snapshot.close_price<0.0)
        {
         snapshot.invalid_reason="Exit numeric integrity is invalid.";
         return(false);
        }
      if((snapshot.exit_allowed && snapshot.exit_blocked) ||
         (snapshot.exit_allowed && !snapshot.exit_signal_present) ||
         (snapshot.exit_blocked && !snapshot.exit_signal_present) ||
         (snapshot.strategy_exit_triggered &&
          !snapshot.strategy_exit_applicable) ||
         (snapshot.range_midpoint_triggered &&
          !snapshot.strategy_exit_triggered) ||
         (snapshot.close_requested && snapshot.close_request_time<=0) ||
         (snapshot.close_request_accepted && !snapshot.close_requested) ||
         (snapshot.close_succeeded && snapshot.close_failed) ||
         (snapshot.close_failed && !snapshot.close_requested) ||
         (snapshot.retry_count<0) ||
         (snapshot.position_closed &&
          (snapshot.close_time<=0 || snapshot.close_price<=0.0 ||
           StringLen(snapshot.final_close_reason)==0)))
        {
         snapshot.invalid_reason="Exit decision or close lifecycle is inconsistent.";
         return(false);
        }
      if(snapshot.strategy_exit_triggered &&
         (snapshot.signal_bar_time<=0 || snapshot.range_midpoint<=0.0 ||
          !snapshot.range_snapshot_available))
        {
         snapshot.invalid_reason="Strategy Exit source identity is incomplete.";
         return(false);
        }

      // Only Range is an actual Strategy Exit input today. Market State, Risk,
      // and Standby timestamps are recorded metadata and are checked for future
      // dating, but are not promoted into new Exit gates.
      const bool timestamps_safe=
         (TimestampNotFuture(snapshot.range_snapshot_available,
                             snapshot.range_snapshot_updated_at,
                             snapshot.exit_evaluation_time) &&
          TimestampNotFuture(snapshot.market_state_snapshot_available,
                             snapshot.market_state_snapshot_updated_at,
                             snapshot.exit_evaluation_time) &&
          TimestampNotFuture(snapshot.risk_snapshot_available,
                             snapshot.risk_snapshot_updated_at,
                             snapshot.exit_evaluation_time) &&
          TimestampNotFuture(snapshot.standby_snapshot_available,
                             snapshot.standby_snapshot_updated_at,
                             snapshot.exit_evaluation_time));
      snapshot.data_leak_safe=timestamps_safe;
      if(!timestamps_safe)
        {
         snapshot.invalid_reason="Exit source metadata is future-dated.";
         return(false);
        }

      if(snapshot.range_snapshot_available)
        {
         const long age=(long)(snapshot.exit_evaluation_time-
                               snapshot.range_snapshot_updated_at);
         snapshot.is_fresh=(age>=0 && age<=freshness_limit_seconds);
        }
      if(!snapshot.is_fresh)
        {
         snapshot.invalid_reason="Exit Range source metadata is stale.";
         return(false);
        }

      snapshot.is_valid=true;
      return(true);
     }
  };

#endif // FENX_EXIT_SNAPSHOT_MQH
