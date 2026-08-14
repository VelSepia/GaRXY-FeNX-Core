//+------------------------------------------------------------------+
//|                 Execution/CommonExecutionEngineAdapter.mqh     |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_EXECUTION_ENGINE_ADAPTER_MQH
#define FENX_COMMON_EXECUTION_ENGINE_ADAPTER_MQH

#include "../Common/CommonSnapshotStore.mqh"
#include "../Common/Logger.mqh"
#include "OrderRequest.mqh"

//--- Promotes the existing Execution request/result stream into a typed Common
//--- contract. It deliberately owns no CTrade, permission, normalization,
//--- duplicate, retry, or position-management behavior.
class CCommonExecutionEngineAdapter
  {
private:
   CCommonSnapshotStore *m_snapshot_store;
   string                m_symbol;
   ENUM_TIMEFRAMES       m_timeframe;
   int                   m_freshness_limit_seconds;
   long                  m_sequence;
   long                  m_request_count;
   long                  m_audit_count;
   long                  m_entry_request_count;
   long                  m_close_request_count;
   long                  m_submitted_count;
   long                  m_accepted_count;
   long                  m_rejected_count;
   long                  m_retry_count;
   long                  m_position_opened_count;
   long                  m_position_closed_count;
   long                  m_duplicate_allowed_count;
   long                  m_volume_normalization_count;
   long                  m_price_normalization_count;
   long                  m_stop_loss_normalization_count;
   long                  m_take_profit_normalization_count;
   long                  m_data_leak_count;
   long                  m_invalid_count;

   string            BooleanName(const bool value)
     {
      return(value ? "true" : "false");
     }

   string            OrderDirectionName(const ENUM_ORDER_TYPE direction)
     {
      return(direction==ORDER_TYPE_BUY ? "BUY" : "SELL");
     }

   string            PositionDirectionName(const ENUM_POSITION_TYPE direction)
     {
      return(direction==POSITION_TYPE_BUY ? "BUY" : "SELL");
     }

   string            DealReasonName(const ENUM_DEAL_REASON reason)
     {
      if(reason==DEAL_REASON_EXPERT)
         return("EXPERT");
      if(reason==DEAL_REASON_SL)
         return("SL");
      if(reason==DEAL_REASON_TP)
         return("TP");
      return(EnumToString(reason));
     }

   void              ResetSnapshot(SCommonExecutionSnapshot &snapshot)
     {
      snapshot.symbol=m_symbol;
      snapshot.timeframe=EnumToString(m_timeframe);
      snapshot.snapshot_version=FENX_COMMON_EXECUTION_SNAPSHOT_VERSION;
      snapshot.updated_at=0;
      snapshot.execution_sequence=0;
      snapshot.execution_time=0;
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="Execution request is not finalized.";
      snapshot.data_leak_safe=false;
      snapshot.request_type="NONE";
      snapshot.direction="NONE";
      snapshot.position_ticket=0;
      snapshot.requested_volume=0.0;
      snapshot.requested_price=0.0;
      snapshot.requested_stop_loss=0.0;
      snapshot.requested_take_profit=0.0;
      snapshot.execution_allowed=false;
      snapshot.execution_blocked=false;
      snapshot.block_reason="";
      snapshot.preparation_succeeded=false;
      snapshot.normalized_volume=0.0;
      snapshot.normalized_price=0.0;
      snapshot.normalized_stop_loss=0.0;
      snapshot.normalized_take_profit=0.0;
      snapshot.duplicate_allowed=false;
      snapshot.position_available=false;
      snapshot.order_submitted=false;
      snapshot.order_accepted=false;
      snapshot.order_rejected=false;
      snapshot.retcode=0;
      snapshot.deal_ticket=0;
      snapshot.retry_count=0;
      snapshot.result_description="";
      snapshot.result_time=0;
      snapshot.position_opened=false;
      snapshot.opened_ticket=0;
      snapshot.open_price=0.0;
      snapshot.open_volume=0.0;
      snapshot.position_closed=false;
      snapshot.close_price=0.0;
      snapshot.close_reason="";
      snapshot.entry_evaluation_sequence=0;
      snapshot.exit_evaluation_sequence=0;
      snapshot.entry_snapshot_available=false;
      snapshot.entry_snapshot_updated_at=0;
      snapshot.exit_snapshot_available=false;
      snapshot.exit_snapshot_updated_at=0;
      snapshot.risk_snapshot_available=false;
      snapshot.risk_snapshot_updated_at=0;
      snapshot.standby_snapshot_available=false;
      snapshot.standby_snapshot_updated_at=0;
     }

   void              BeginCommon(const string request_type,
                                 const datetime execution_time,
                                 SCommonExecutionSnapshot &snapshot)
     {
      ResetSnapshot(snapshot);
      m_sequence++;
      m_request_count++;
      snapshot.execution_sequence=m_sequence;
      snapshot.execution_time=execution_time;
      snapshot.updated_at=execution_time;
      snapshot.request_type=request_type;
      snapshot.execution_allowed=true;
      snapshot.execution_blocked=false;
      snapshot.block_reason="";
      snapshot.preparation_succeeded=true;
      snapshot.duplicate_allowed=true;
      snapshot.position_available=true;
      if(request_type=="ENTRY")
         m_entry_request_count++;
      else
         m_close_request_count++;
      m_duplicate_allowed_count++;
     }

   void              PopulateSafetySources(SCommonExecutionSnapshot &snapshot)
     {
      if(m_snapshot_store==NULL)
         return;
      SRiskSnapshot risk;
      snapshot.risk_snapshot_available=
         m_snapshot_store.GetRiskSnapshot(m_symbol,m_timeframe,risk);
      if(snapshot.risk_snapshot_available)
         snapshot.risk_snapshot_updated_at=risk.updated_at;

      SStandbySnapshot standby;
      snapshot.standby_snapshot_available=
         m_snapshot_store.GetStandbySnapshot(m_symbol,m_timeframe,standby);
      if(snapshot.standby_snapshot_available)
         snapshot.standby_snapshot_updated_at=standby.updated_at;
     }

   void              CountNormalization(const SOrderRequest &requested,
                                        const SOrderRequest &normalized)
     {
      if(MathAbs(requested.volume-normalized.volume)>0.00000001)
         m_volume_normalization_count++;
      if(MathAbs(requested.entry_price-normalized.entry_price)>0.00000001)
         m_price_normalization_count++;
      if(MathAbs(requested.stop_loss-normalized.stop_loss)>0.00000001)
         m_stop_loss_normalization_count++;
      if(MathAbs(requested.take_profit-normalized.take_profit)>0.00000001)
         m_take_profit_normalization_count++;
     }

   bool              PopulateDealResult(const SOrderExecutionResult &result,
                                        SCommonExecutionSnapshot &snapshot)
     {
      if(!result.accepted || result.deal_ticket<=0 ||
         !HistoryDealSelect((ulong)result.deal_ticket))
         return(false);
      const double deal_price=
         HistoryDealGetDouble((ulong)result.deal_ticket,DEAL_PRICE);
      const double deal_volume=
         HistoryDealGetDouble((ulong)result.deal_ticket,DEAL_VOLUME);
      const ulong lifecycle_id=(ulong)
         HistoryDealGetInteger((ulong)result.deal_ticket,DEAL_POSITION_ID);
      const ENUM_DEAL_REASON reason=(ENUM_DEAL_REASON)
         HistoryDealGetInteger((ulong)result.deal_ticket,DEAL_REASON);
      if(snapshot.request_type=="ENTRY")
        {
         snapshot.position_opened=true;
         snapshot.opened_ticket=lifecycle_id;
         snapshot.open_price=deal_price;
         snapshot.open_volume=deal_volume;
        }
      else
        {
         snapshot.position_closed=true;
         snapshot.close_price=deal_price;
         snapshot.close_reason=DealReasonName(reason);
        }
      return(true);
     }

   void              LogSnapshot(const SCommonExecutionSnapshot &snapshot)
     {
      CLogger::Info(StringFormat(
         "[COMMON_EXECUTION] Sequence=%I64d;ExecutionTime=%s;Symbol=%s;Timeframe=%s;RequestType=%s;Direction=%s;PositionTicket=%I64u;EntryEvaluationSequence=%I64d;ExitEvaluationSequence=%I64d;ExecutionAllowed=%s;ExecutionBlocked=%s;BlockReason=%s;OrderSubmitted=%s;DataLeakSafe=%s;SnapshotValid=%s",
         snapshot.execution_sequence,
         TimeToString(snapshot.execution_time,TIME_DATE|TIME_SECONDS),
         snapshot.symbol,snapshot.timeframe,snapshot.request_type,
         snapshot.direction,snapshot.position_ticket,
         snapshot.entry_evaluation_sequence,snapshot.exit_evaluation_sequence,
         BooleanName(snapshot.execution_allowed),
         BooleanName(snapshot.execution_blocked),snapshot.block_reason,
         BooleanName(snapshot.order_submitted),
         BooleanName(snapshot.data_leak_safe),BooleanName(snapshot.is_valid)));
      CLogger::Info(StringFormat(
         "[COMMON_EXECUTION_PREPARATION] Sequence=%I64d;RequestedVolume=%.8f;NormalizedVolume=%.8f;RequestedPrice=%.6f;NormalizedPrice=%.6f;RequestedSL=%.6f;NormalizedSL=%.6f;RequestedTP=%.6f;NormalizedTP=%.6f;PreparationSucceeded=%s;DuplicateAllowed=%s;PositionAvailable=%s",
         snapshot.execution_sequence,snapshot.requested_volume,
         snapshot.normalized_volume,snapshot.requested_price,
         snapshot.normalized_price,snapshot.requested_stop_loss,
         snapshot.normalized_stop_loss,snapshot.requested_take_profit,
         snapshot.normalized_take_profit,
         BooleanName(snapshot.preparation_succeeded),
         BooleanName(snapshot.duplicate_allowed),
         BooleanName(snapshot.position_available)));
      CLogger::Info(StringFormat(
         "[COMMON_EXECUTION_RESULT] Sequence=%I64d;OrderAccepted=%s;OrderRejected=%s;Retcode=%I64d;DealTicket=%I64d;RetryCount=%d;ResultTime=%s;PositionOpened=%s;OpenedTicket=%I64u;OpenPrice=%.6f;OpenVolume=%.8f;PositionClosed=%s;ClosePrice=%.6f;CloseReason=%s;Description=%s",
         snapshot.execution_sequence,BooleanName(snapshot.order_accepted),
         BooleanName(snapshot.order_rejected),snapshot.retcode,
         snapshot.deal_ticket,snapshot.retry_count,
         TimeToString(snapshot.result_time,TIME_DATE|TIME_SECONDS),
         BooleanName(snapshot.position_opened),snapshot.opened_ticket,
         snapshot.open_price,snapshot.open_volume,
         BooleanName(snapshot.position_closed),snapshot.close_price,
         snapshot.close_reason,snapshot.result_description));
      CLogger::Info(StringFormat(
         "[COMMON_EXECUTION_SOURCES] Sequence=%I64d;EntryUpdatedAt=%s;ExitUpdatedAt=%s;RiskUpdatedAt=%s;StandbyUpdatedAt=%s;SnapshotUpdatedAt=%s;DataLeakSafe=%s;SnapshotValid=%s;history_count=%d;keys=0",
         snapshot.execution_sequence,
         TimeToString(snapshot.entry_snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.exit_snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.risk_snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.standby_snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS),
         BooleanName(snapshot.data_leak_safe),BooleanName(snapshot.is_valid),
         (m_snapshot_store==NULL ? 0 :
          m_snapshot_store.ExecutionHistoryCount())));
     }

public:
                     CCommonExecutionEngineAdapter(void)
     {
      m_snapshot_store=NULL;
      m_symbol="";
      m_timeframe=PERIOD_CURRENT;
      m_freshness_limit_seconds=0;
      m_sequence=0;
      m_request_count=0;
      m_audit_count=0;
      m_entry_request_count=0;
      m_close_request_count=0;
      m_submitted_count=0;
      m_accepted_count=0;
      m_rejected_count=0;
      m_retry_count=0;
      m_position_opened_count=0;
      m_position_closed_count=0;
      m_duplicate_allowed_count=0;
      m_volume_normalization_count=0;
      m_price_normalization_count=0;
      m_stop_loss_normalization_count=0;
      m_take_profit_normalization_count=0;
      m_data_leak_count=0;
      m_invalid_count=0;
     }

   bool              SetSnapshotStore(CCommonSnapshotStore &snapshot_store)
     {
      m_snapshot_store=GetPointer(snapshot_store);
      return(m_snapshot_store!=NULL);
     }

   bool              Configure(const string symbol,
                               const ENUM_TIMEFRAMES timeframe,
                               const int freshness_limit_seconds)
     {
      if(m_snapshot_store==NULL || StringLen(symbol)==0 ||
         PeriodSeconds(timeframe)<=0 || freshness_limit_seconds<=0)
         return(false);
      m_symbol=symbol;
      m_timeframe=timeframe;
      m_freshness_limit_seconds=freshness_limit_seconds;
      m_sequence=0;
      m_request_count=0;
      m_audit_count=0;
      m_entry_request_count=0;
      m_close_request_count=0;
      m_submitted_count=0;
      m_accepted_count=0;
      m_rejected_count=0;
      m_retry_count=0;
      m_position_opened_count=0;
      m_position_closed_count=0;
      m_duplicate_allowed_count=0;
      m_volume_normalization_count=0;
      m_price_normalization_count=0;
      m_stop_loss_normalization_count=0;
      m_take_profit_normalization_count=0;
      m_data_leak_count=0;
      m_invalid_count=0;
      return(true);
     }

   //--- Copies the raw and already-normalized request after all established
   //--- gates have passed. The caller must never branch on this observer.
   void              BeginEntry(const SEntrySnapshot &entry_source,
                                const SOrderRequest &requested,
                                const SOrderRequest &normalized,
                                const datetime execution_time,
                                SCommonExecutionSnapshot &snapshot)
     {
      BeginCommon("ENTRY",execution_time,snapshot);
      snapshot.direction=OrderDirectionName(normalized.direction);
      snapshot.requested_volume=requested.volume;
      snapshot.requested_price=requested.entry_price;
      snapshot.requested_stop_loss=requested.stop_loss;
      snapshot.requested_take_profit=requested.take_profit;
      snapshot.normalized_volume=normalized.volume;
      snapshot.normalized_price=normalized.entry_price;
      snapshot.normalized_stop_loss=normalized.stop_loss;
      snapshot.normalized_take_profit=normalized.take_profit;
      snapshot.entry_evaluation_sequence=
         entry_source.entry_evaluation_sequence;
      snapshot.entry_snapshot_available=
         (entry_source.entry_evaluation_sequence>0 && entry_source.updated_at>0);
      snapshot.entry_snapshot_updated_at=entry_source.updated_at;
      PopulateSafetySources(snapshot);
      CountNormalization(requested,normalized);
     }

   //--- Captures the selected position immediately before the established
   //--- OrderExecutor close call. No close parameter or position fact is
   //--- synthesized when the terminal does not expose it.
   void              BeginClose(const SExitSnapshot &exit_source,
                                const ulong position_ticket,
                                const ENUM_POSITION_TYPE position_type,
                                const datetime execution_time,
                                SCommonExecutionSnapshot &snapshot)
     {
      BeginCommon("CLOSE",execution_time,snapshot);
      snapshot.direction=PositionDirectionName(position_type);
      snapshot.position_ticket=position_ticket;
      if(position_ticket>0 && PositionSelectByTicket(position_ticket))
        {
         snapshot.requested_volume=PositionGetDouble(POSITION_VOLUME);
         snapshot.requested_price=PositionGetDouble(POSITION_PRICE_CURRENT);
         snapshot.requested_stop_loss=PositionGetDouble(POSITION_SL);
         snapshot.requested_take_profit=PositionGetDouble(POSITION_TP);
         // PositionClose submits the selected position as-is; unlike Entry,
         // there is no separate EA-side price or volume normalization stage.
         snapshot.normalized_volume=snapshot.requested_volume;
         snapshot.normalized_price=snapshot.requested_price;
         snapshot.normalized_stop_loss=snapshot.requested_stop_loss;
         snapshot.normalized_take_profit=snapshot.requested_take_profit;
        }
      snapshot.exit_evaluation_sequence=exit_source.exit_evaluation_sequence;
      snapshot.exit_snapshot_available=
         (exit_source.exit_evaluation_sequence>0 && exit_source.updated_at>0);
      snapshot.exit_snapshot_updated_at=exit_source.updated_at;
      PopulateSafetySources(snapshot);
     }

   //--- Finalizes the typed audit from the result already returned by the sole
   //--- OrderExecutor. Its return value is diagnostic only.
   bool              RecordResult(SCommonExecutionSnapshot &snapshot,
                                  const SOrderExecutionResult &result)
     {
      snapshot.order_submitted=true;
      snapshot.order_accepted=result.accepted;
      snapshot.order_rejected=!result.accepted;
      snapshot.retcode=result.retcode;
      snapshot.deal_ticket=result.deal_ticket;
      snapshot.retry_count=result.retry_count;
      snapshot.result_description=result.description;
      snapshot.result_time=result.executed_at;
      snapshot.updated_at=result.executed_at;
      PopulateDealResult(result,snapshot);

      CCommonExecutionSnapshotContract contract;
      const bool valid=contract.Finalize(snapshot,m_freshness_limit_seconds);
      bool stored=false;
      if(m_snapshot_store!=NULL)
         stored=m_snapshot_store.SetExecutionSnapshot(m_symbol,m_timeframe,snapshot);
      m_audit_count++;
      m_submitted_count++;
      if(snapshot.order_accepted)
         m_accepted_count++;
      else
         m_rejected_count++;
      m_retry_count+=snapshot.retry_count;
      if(snapshot.position_opened)
         m_position_opened_count++;
      if(snapshot.position_closed)
         m_position_closed_count++;
      if(!snapshot.data_leak_safe)
         m_data_leak_count++;
      if(!valid || !stored)
         m_invalid_count++;
      LogSnapshot(snapshot);
      return(valid && stored);
     }

   void              LogSummary(void)
     {
      CLogger::Info(StringFormat(
         "[COMMON_EXECUTION_SUMMARY] ExecutionRequestCount=%I64d;ExecutionAuditCount=%I64d;EntryRequestCount=%I64d;CloseRequestCount=%I64d;SubmittedCount=%I64d;AcceptedCount=%I64d;RejectedCount=%I64d;RetryCount=%I64d;PositionOpenedCount=%I64d;PositionClosedCount=%I64d;DuplicateAllowedCount=%I64d;VolumeNormalizationCount=%I64d;PriceNormalizationCount=%I64d;StopLossNormalizationCount=%I64d;TakeProfitNormalizationCount=%I64d;DataLeakCount=%I64d;InvalidCount=%I64d;CurrentSnapshotCount=%d;BoundedHistoryCount=%d;HistoryLimit=%d;GlobalKeys=0;PerSymbolKeys=0",
         m_request_count,m_audit_count,m_entry_request_count,
         m_close_request_count,m_submitted_count,m_accepted_count,
         m_rejected_count,m_retry_count,m_position_opened_count,
         m_position_closed_count,m_duplicate_allowed_count,
         m_volume_normalization_count,m_price_normalization_count,
         m_stop_loss_normalization_count,m_take_profit_normalization_count,
         m_data_leak_count,m_invalid_count,
         (m_snapshot_store==NULL ? 0 :
          m_snapshot_store.ExecutionSnapshotCount()),
         (m_snapshot_store==NULL ? 0 :
          m_snapshot_store.ExecutionHistoryCount()),
         FENX_COMMON_EXECUTION_HISTORY_LIMIT));
     }
  };

#endif // FENX_COMMON_EXECUTION_ENGINE_ADAPTER_MQH
