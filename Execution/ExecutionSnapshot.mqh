//+------------------------------------------------------------------+
//|                           Execution/ExecutionSnapshot.mqh      |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_EXECUTION_SNAPSHOT_MQH
#define FENX_COMMON_EXECUTION_SNAPSHOT_MQH

#include "../Common/Constants.mqh"

//--- Typed, passive record of one request already authorized by the existing
//--- Execution pipeline. The record never grants permission, normalizes an
//--- order, sends a trade, retries a request, or changes a position.
struct SCommonExecutionSnapshot
  {
   //--- Identity
   string   symbol;
   string   timeframe;
   string   snapshot_version;
   datetime updated_at;
   long     execution_sequence;
   datetime execution_time;

   //--- Validity
   bool     is_valid;
   bool     is_fresh;
   string   invalid_reason;
   bool     data_leak_safe;

   //--- Existing request
   string   request_type;
   string   direction;
   ulong    position_ticket;
   double   requested_volume;
   double   requested_price;
   double   requested_stop_loss;
   double   requested_take_profit;

   //--- Existing permission outcome
   bool     execution_allowed;
   bool     execution_blocked;
   string   block_reason;

   //--- Existing preparation and guard outcomes
   bool     preparation_succeeded;
   double   normalized_volume;
   double   normalized_price;
   double   normalized_stop_loss;
   double   normalized_take_profit;
   bool     duplicate_allowed;
   bool     position_available;

   //--- Existing OrderExecutor result
   bool     order_submitted;
   bool     order_accepted;
   bool     order_rejected;
   long     retcode;
   long     deal_ticket;
   int      retry_count;
   string   result_description;
   datetime result_time;

   //--- Confirmed position result
   bool     position_opened;
   ulong    opened_ticket;
   double   open_price;
   double   open_volume;
   bool     position_closed;
   double   close_price;
   string   close_reason;

   //--- Source linkage. Source timestamps are frozen when the existing
   //--- Execution request is authorized; post-result facts cannot flow back
   //--- into permission.
   long     entry_evaluation_sequence;
   long     exit_evaluation_sequence;
   bool     entry_snapshot_available;
   datetime entry_snapshot_updated_at;
   bool     exit_snapshot_available;
   datetime exit_snapshot_updated_at;
   bool     risk_snapshot_available;
   datetime risk_snapshot_updated_at;
   bool     standby_snapshot_available;
   datetime standby_snapshot_updated_at;
  };

//--- Validates the audit contract after the established OrderExecutor result
//--- is known. A validation failure is telemetry only and never changes the
//--- already completed execution result.
class CCommonExecutionSnapshotContract
  {
private:
   bool              TimestampSafe(const bool available,
                                   const datetime source_time,
                                   const datetime execution_time)
     {
      return(available && source_time>0 && execution_time>0 &&
             source_time<=execution_time);
     }

   bool              TimestampFresh(const datetime source_time,
                                    const datetime execution_time,
                                    const int freshness_limit_seconds)
     {
      const long age=(long)(execution_time-source_time);
      return(age>=0 && age<=freshness_limit_seconds);
     }

public:
   bool              Finalize(SCommonExecutionSnapshot &snapshot,
                              const int freshness_limit_seconds)
     {
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.data_leak_safe=false;
      snapshot.invalid_reason="";

      if(StringLen(snapshot.symbol)==0 || StringLen(snapshot.timeframe)==0 ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0 ||
         snapshot.execution_sequence<=0 || snapshot.execution_time<=0 ||
         snapshot.updated_at<snapshot.execution_time ||
         freshness_limit_seconds<=0)
        {
         snapshot.invalid_reason="Execution snapshot identity is invalid.";
         return(false);
        }
      if(snapshot.request_type!="ENTRY" && snapshot.request_type!="CLOSE")
        {
         snapshot.invalid_reason="Execution request type is invalid.";
         return(false);
        }
      if(snapshot.direction!="BUY" && snapshot.direction!="SELL")
        {
         snapshot.invalid_reason="Execution direction is invalid.";
         return(false);
        }
      if(!MathIsValidNumber(snapshot.requested_volume) ||
         !MathIsValidNumber(snapshot.requested_price) ||
         !MathIsValidNumber(snapshot.requested_stop_loss) ||
         !MathIsValidNumber(snapshot.requested_take_profit) ||
         !MathIsValidNumber(snapshot.normalized_volume) ||
         !MathIsValidNumber(snapshot.normalized_price) ||
         !MathIsValidNumber(snapshot.normalized_stop_loss) ||
         !MathIsValidNumber(snapshot.normalized_take_profit) ||
         !MathIsValidNumber(snapshot.open_price) ||
         !MathIsValidNumber(snapshot.open_volume) ||
         !MathIsValidNumber(snapshot.close_price) ||
         snapshot.requested_volume<=0.0 || snapshot.requested_price<=0.0 ||
         snapshot.requested_stop_loss<0.0 ||
         snapshot.requested_take_profit<0.0 ||
         snapshot.normalized_volume<=0.0 || snapshot.normalized_price<=0.0 ||
         snapshot.normalized_stop_loss<0.0 ||
         snapshot.normalized_take_profit<0.0 || snapshot.open_price<0.0 ||
         snapshot.open_volume<0.0 || snapshot.close_price<0.0)
        {
         snapshot.invalid_reason="Execution numeric integrity is invalid.";
         return(false);
        }
      if(!snapshot.execution_allowed || snapshot.execution_blocked ||
         StringLen(snapshot.block_reason)>0 || !snapshot.preparation_succeeded ||
         !snapshot.duplicate_allowed || !snapshot.position_available ||
         !snapshot.order_submitted ||
         snapshot.order_accepted==snapshot.order_rejected ||
         snapshot.retry_count<0 || snapshot.result_time<=0 ||
         snapshot.result_time<snapshot.execution_time ||
         (snapshot.order_accepted &&
          (snapshot.retcode<=0 || snapshot.deal_ticket<=0)) ||
         (snapshot.order_rejected &&
          (snapshot.position_opened || snapshot.position_closed)))
        {
         snapshot.invalid_reason="Execution permission or result is inconsistent.";
         return(false);
        }

      if(snapshot.request_type=="ENTRY")
        {
         if(snapshot.entry_evaluation_sequence<=0 ||
            snapshot.exit_evaluation_sequence!=0 ||
            !snapshot.entry_snapshot_available ||
            snapshot.requested_stop_loss<=0.0 ||
            snapshot.requested_take_profit<=0.0 ||
            snapshot.normalized_stop_loss<=0.0 ||
            snapshot.normalized_take_profit<=0.0 ||
            (snapshot.order_accepted &&
             (!snapshot.position_opened || snapshot.position_closed ||
              snapshot.opened_ticket==0 || snapshot.open_price<=0.0 ||
              snapshot.open_volume<=0.0)))
           {
            snapshot.invalid_reason="Entry execution linkage is inconsistent.";
            return(false);
           }
        }
      else
        {
         if(snapshot.position_ticket==0 || snapshot.entry_evaluation_sequence!=0 ||
            snapshot.exit_evaluation_sequence<=0 ||
            !snapshot.exit_snapshot_available ||
            (snapshot.order_accepted &&
             (!snapshot.position_closed || snapshot.position_opened ||
              snapshot.close_price<=0.0 ||
              StringLen(snapshot.close_reason)==0)))
           {
            snapshot.invalid_reason="Close execution linkage is inconsistent.";
            return(false);
           }
        }

      const bool entry_safe=(snapshot.request_type!="ENTRY" ||
         TimestampSafe(snapshot.entry_snapshot_available,
                       snapshot.entry_snapshot_updated_at,
                       snapshot.execution_time));
      const bool exit_safe=(snapshot.request_type!="CLOSE" ||
         TimestampSafe(snapshot.exit_snapshot_available,
                       snapshot.exit_snapshot_updated_at,
                       snapshot.execution_time));
      const bool risk_safe=TimestampSafe(snapshot.risk_snapshot_available,
                                         snapshot.risk_snapshot_updated_at,
                                         snapshot.execution_time);
      const bool standby_safe=TimestampSafe(snapshot.standby_snapshot_available,
                                            snapshot.standby_snapshot_updated_at,
                                            snapshot.execution_time);
      snapshot.data_leak_safe=(entry_safe && exit_safe && risk_safe && standby_safe);
      if(!snapshot.data_leak_safe)
        {
         snapshot.invalid_reason="Execution source metadata is missing or future-dated.";
         return(false);
        }

      const datetime contract_source=(snapshot.request_type=="ENTRY" ?
         snapshot.entry_snapshot_updated_at : snapshot.exit_snapshot_updated_at);
      snapshot.is_fresh=
         (TimestampFresh(contract_source,snapshot.execution_time,
                         freshness_limit_seconds) &&
          TimestampFresh(snapshot.risk_snapshot_updated_at,snapshot.execution_time,
                         freshness_limit_seconds) &&
          TimestampFresh(snapshot.standby_snapshot_updated_at,snapshot.execution_time,
                         freshness_limit_seconds));
      if(!snapshot.is_fresh)
        {
         snapshot.invalid_reason="Execution source metadata is stale.";
         return(false);
        }

      snapshot.is_valid=true;
      return(true);
     }
  };

#endif // FENX_COMMON_EXECUTION_SNAPSHOT_MQH
