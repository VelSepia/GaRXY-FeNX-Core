//+------------------------------------------------------------------+
//|                          Exit/CommonExitEngineAdapter.mqh       |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_EXIT_ENGINE_ADAPTER_MQH
#define FENX_COMMON_EXIT_ENGINE_ADAPTER_MQH

#include "../Common/CommonSnapshotStore.mqh"
#include "../Common/Logger.mqh"

//--- Observes the established Exit pipeline and publishes typed audit facts.
//--- It owns no CTrade instance, sends no close request, performs no retry,
//--- removes no position, and never recalculates the Strategy Exit predicate.
class CCommonExitEngineAdapter
  {
private:
   CCommonSnapshotStore *m_snapshot_store;
   string                m_symbol;
   ENUM_TIMEFRAMES       m_timeframe;
   long                  m_magic_number;
   int                   m_freshness_limit_seconds;
   long                  m_sequence;
   long                  m_evaluate_exit_invocation_count;
   long                  m_evaluation_audit_count;
   long                  m_strategy_signal_count;
   long                  m_close_request_count;
   long                  m_close_accepted_count;
   long                  m_close_failed_count;
   long                  m_retry_count;
   long                  m_lifecycle_count;
   long                  m_finalized_count;
   long                  m_expert_close_count;
   long                  m_stop_loss_close_count;
   long                  m_take_profit_close_count;
   long                  m_external_close_count;
   long                  m_data_leak_count;
   long                  m_invalid_count;
   bool                  m_has_active_position;
   ulong                 m_active_lifecycle_id;
   datetime              m_last_signal_bar_time;
   SExitSnapshot         m_active_snapshot;

   string            BooleanName(const bool value)
     {
      return(value ? "true" : "false");
     }

   string            PositionDirectionName(const ENUM_POSITION_TYPE direction)
     {
      return(direction==POSITION_TYPE_BUY ? "BUY" : "SELL");
     }

   void              ResetSnapshot(SExitSnapshot &snapshot)
     {
      snapshot.symbol=m_symbol;
      snapshot.timeframe=EnumToString(m_timeframe);
      snapshot.snapshot_version=FENX_COMMON_EXIT_SNAPSHOT_VERSION;
      snapshot.updated_at=0;
      snapshot.exit_evaluation_time=0;
      snapshot.exit_evaluation_sequence=0;
      snapshot.position_ticket=0;
      snapshot.position_lifecycle_id=0;
      snapshot.direction="";
      snapshot.open_time=0;
      snapshot.open_price=0.0;
      snapshot.current_price=0.0;
      snapshot.volume=0.0;
      snapshot.stop_loss=0.0;
      snapshot.take_profit=0.0;
      snapshot.position_closed=false;
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="Exit evaluation is not finalized.";
      snapshot.data_leak_safe=false;
      snapshot.exit_signal_present=false;
      snapshot.exit_allowed=false;
      snapshot.exit_blocked=false;
      snapshot.exit_type="NONE";
      snapshot.exit_reason="Exit evaluation is in progress.";
      snapshot.signal_bar_time=0;
      snapshot.signal_price=0.0;
      snapshot.strategy_exit_applicable=false;
      snapshot.strategy_exit_triggered=false;
      snapshot.range_midpoint=0.0;
      snapshot.range_midpoint_triggered=false;
      snapshot.stop_loss_present=false;
      snapshot.take_profit_present=false;
      snapshot.stop_loss_triggered=false;
      snapshot.take_profit_triggered=false;
      snapshot.close_requested=false;
      snapshot.close_request_time=0;
      snapshot.close_request_accepted=false;
      snapshot.close_succeeded=false;
      snapshot.close_failed=false;
      snapshot.retry_count=0;
      snapshot.retcode=0;
      snapshot.last_attempt_time=0;
      snapshot.final_close_reason="";
      snapshot.close_time=0;
      snapshot.close_price=0.0;
      snapshot.range_snapshot_available=false;
      snapshot.range_snapshot_updated_at=0;
      snapshot.market_state_snapshot_available=false;
      snapshot.market_state_snapshot_updated_at=0;
      snapshot.risk_snapshot_available=false;
      snapshot.risk_snapshot_updated_at=0;
      snapshot.standby_snapshot_available=false;
      snapshot.standby_snapshot_updated_at=0;
      snapshot.position_last_seen_at=0;
     }

   void              PopulateSourceMetadata(SExitSnapshot &snapshot)
     {
      if(m_snapshot_store==NULL)
         return;

      SRangeSnapshot range_snapshot;
      snapshot.range_snapshot_available=
         m_snapshot_store.GetRangeSnapshot(m_symbol,m_timeframe,range_snapshot);
      if(snapshot.range_snapshot_available)
         snapshot.range_snapshot_updated_at=range_snapshot.updated_at;

      SMarketStateSnapshot market_state;
      snapshot.market_state_snapshot_available=
         m_snapshot_store.GetMarketStateSnapshot(m_symbol,m_timeframe,market_state);
      if(snapshot.market_state_snapshot_available)
         snapshot.market_state_snapshot_updated_at=market_state.updated_at;

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

   bool              PopulateSelectedPosition(const ulong position_ticket,
                                               SExitSnapshot &snapshot)
     {
      if(position_ticket==0 || !PositionSelectByTicket(position_ticket))
         return(false);
      if(PositionGetString(POSITION_SYMBOL)!=m_symbol ||
         PositionGetInteger(POSITION_MAGIC)!=m_magic_number)
         return(false);

      const ulong lifecycle_id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(lifecycle_id==0)
         return(false);
      snapshot.position_ticket=position_ticket;
      snapshot.position_lifecycle_id=lifecycle_id;
      snapshot.direction=PositionDirectionName(
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE));
      snapshot.open_time=(datetime)PositionGetInteger(POSITION_TIME);
      snapshot.open_price=PositionGetDouble(POSITION_PRICE_OPEN);
      snapshot.current_price=PositionGetDouble(POSITION_PRICE_CURRENT);
      snapshot.volume=PositionGetDouble(POSITION_VOLUME);
      snapshot.stop_loss=PositionGetDouble(POSITION_SL);
      snapshot.take_profit=PositionGetDouble(POSITION_TP);
      snapshot.stop_loss_present=(snapshot.stop_loss>0.0);
      snapshot.take_profit_present=(snapshot.take_profit>0.0);
      snapshot.position_last_seen_at=TimeCurrent();
      return(true);
     }

   bool              EnsureActivePosition(const ulong position_ticket)
     {
      SExitSnapshot observed;
      ResetSnapshot(observed);
      if(!PopulateSelectedPosition(position_ticket,observed))
         return(false);

      if(!m_has_active_position ||
         observed.position_lifecycle_id!=m_active_lifecycle_id)
        {
         m_active_snapshot=observed;
         m_active_lifecycle_id=observed.position_lifecycle_id;
         m_has_active_position=true;
         m_last_signal_bar_time=0;
         m_lifecycle_count++;
         return(true);
        }

      // Preserve the current evaluation and close lifecycle while refreshing
      // only factual position properties already selected by PositionManager.
      m_active_snapshot.position_ticket=observed.position_ticket;
      m_active_snapshot.direction=observed.direction;
      m_active_snapshot.open_time=observed.open_time;
      m_active_snapshot.open_price=observed.open_price;
      m_active_snapshot.current_price=observed.current_price;
      m_active_snapshot.volume=observed.volume;
      m_active_snapshot.stop_loss=observed.stop_loss;
      m_active_snapshot.take_profit=observed.take_profit;
      m_active_snapshot.stop_loss_present=observed.stop_loss_present;
      m_active_snapshot.take_profit_present=observed.take_profit_present;
      m_active_snapshot.position_last_seen_at=observed.position_last_seen_at;
      return(true);
     }

   bool              WriteSnapshot(SExitSnapshot &snapshot,
                                   const bool count_validation)
     {
      snapshot.updated_at=TimeCurrent();
      CExitSnapshotContract contract;
      const bool valid=contract.Finalize(snapshot,m_freshness_limit_seconds);
      bool stored=false;
      if(m_snapshot_store!=NULL)
         stored=m_snapshot_store.SetExitSnapshot(m_symbol,m_timeframe,snapshot);
      if(count_validation && !snapshot.data_leak_safe)
         m_data_leak_count++;
      if(count_validation && (!valid || !stored))
         m_invalid_count++;
      m_active_snapshot=snapshot;
      return(valid && stored);
     }

   void              LogEvaluation(const SExitSnapshot &snapshot)
     {
      CLogger::Info(StringFormat(
         "[COMMON_EXIT] Sequence=%I64d;ExitEvaluationTime=%s;PositionTicket=%I64u;LifecycleID=%I64u;Symbol=%s;Timeframe=%s;Direction=%s;SignalBarTime=%s;StrategyExitTriggered=%s;RangeMidpoint=%.6f;SignalPrice=%.6f;SL=%.6f;TP=%.6f;ExitType=%s;ExitReason=%s;ExitAllowed=%s;ExitBlocked=%s;DataLeakSafe=%s;SnapshotValid=%s",
         snapshot.exit_evaluation_sequence,
         TimeToString(snapshot.exit_evaluation_time,TIME_DATE|TIME_SECONDS),
         snapshot.position_ticket,snapshot.position_lifecycle_id,
         snapshot.symbol,snapshot.timeframe,snapshot.direction,
         TimeToString(snapshot.signal_bar_time,TIME_DATE|TIME_SECONDS),
         BooleanName(snapshot.strategy_exit_triggered),snapshot.range_midpoint,
         snapshot.signal_price,snapshot.stop_loss,snapshot.take_profit,
         snapshot.exit_type,snapshot.exit_reason,
         BooleanName(snapshot.exit_allowed),BooleanName(snapshot.exit_blocked),
         BooleanName(snapshot.data_leak_safe),BooleanName(snapshot.is_valid)));
      CLogger::Info(StringFormat(
         "[COMMON_EXIT_SOURCES] Sequence=%I64d;RangeUpdatedAt=%s;MarketStateUpdatedAt=%s;RiskUpdatedAt=%s;StandbyUpdatedAt=%s;PositionLastSeenAt=%s;SnapshotUpdatedAt=%s;history_count=%d;keys=0",
         snapshot.exit_evaluation_sequence,
         TimeToString(snapshot.range_snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.market_state_snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.risk_snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.standby_snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.position_last_seen_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS),
         (m_snapshot_store==NULL ? 0 : m_snapshot_store.ExitHistoryCount())));
     }

   string            DealReasonName(const ENUM_DEAL_REASON reason)
     {
      if(reason==DEAL_REASON_EXPERT)
         return("EXPERT");
      if(reason==DEAL_REASON_SL)
         return("SL");
      if(reason==DEAL_REASON_TP)
         return("TP");
      return("EXTERNAL:"+EnumToString(reason));
     }

public:
                     CCommonExitEngineAdapter(void)
     {
      m_snapshot_store=NULL;
      m_symbol="";
      m_timeframe=PERIOD_CURRENT;
      m_magic_number=0;
      m_freshness_limit_seconds=0;
      m_sequence=0;
      m_evaluate_exit_invocation_count=0;
      m_evaluation_audit_count=0;
      m_strategy_signal_count=0;
      m_close_request_count=0;
      m_close_accepted_count=0;
      m_close_failed_count=0;
      m_retry_count=0;
      m_lifecycle_count=0;
      m_finalized_count=0;
      m_expert_close_count=0;
      m_stop_loss_close_count=0;
      m_take_profit_close_count=0;
      m_external_close_count=0;
      m_data_leak_count=0;
      m_invalid_count=0;
      m_has_active_position=false;
      m_active_lifecycle_id=0;
      m_last_signal_bar_time=0;
      ResetSnapshot(m_active_snapshot);
     }

   bool              SetSnapshotStore(CCommonSnapshotStore &snapshot_store)
     {
      m_snapshot_store=GetPointer(snapshot_store);
      return(m_snapshot_store!=NULL);
     }

   bool              Configure(const string symbol,const ENUM_TIMEFRAMES timeframe,
                               const long magic_number,
                               const int freshness_limit_seconds)
     {
      if(m_snapshot_store==NULL || StringLen(symbol)==0 ||
         PeriodSeconds(timeframe)<=0 || magic_number<=0 ||
         freshness_limit_seconds<=0)
         return(false);
      m_symbol=symbol;
      m_timeframe=timeframe;
      m_magic_number=magic_number;
      m_freshness_limit_seconds=freshness_limit_seconds;
      m_sequence=0;
      m_evaluate_exit_invocation_count=0;
      m_evaluation_audit_count=0;
      m_strategy_signal_count=0;
      m_close_request_count=0;
      m_close_accepted_count=0;
      m_close_failed_count=0;
      m_retry_count=0;
      m_lifecycle_count=0;
      m_finalized_count=0;
      m_expert_close_count=0;
      m_stop_loss_close_count=0;
      m_take_profit_close_count=0;
      m_external_close_count=0;
      m_data_leak_count=0;
      m_invalid_count=0;
      m_has_active_position=false;
      m_active_lifecycle_id=0;
      m_last_signal_bar_time=0;
      ResetSnapshot(m_active_snapshot);
      return(true);
     }

   //--- Converts the single result already returned by EvaluateExit into the
   //--- Common contract. Repeated ticks for the same completed bar retain one
   //--- Sequence, avoiding unbounded tick telemetry while separately counting
   //--- every unchanged EvaluateExit invocation.
   bool              ObserveEvaluation(const ulong position_ticket,
                                       const ENUM_POSITION_TYPE position_type,
                                       const datetime opened_at,
                                       const bool should_close,
                                       const double signal_price,
                                       const double range_midpoint,
                                       const datetime signal_bar_time,
                                       const string reason,
                                       SExitSnapshot &snapshot,
                                       bool &new_evaluation)
     {
      m_evaluate_exit_invocation_count++;
      new_evaluation=false;
      ResetSnapshot(snapshot);
      if(!EnsureActivePosition(position_ticket))
         return(false);

      new_evaluation=(m_active_snapshot.exit_evaluation_sequence<=0 ||
                      signal_bar_time!=m_last_signal_bar_time);
      snapshot=m_active_snapshot;
      if(new_evaluation)
        {
         m_sequence++;
         m_evaluation_audit_count++;
         snapshot.exit_evaluation_sequence=m_sequence;
         snapshot.exit_evaluation_time=TimeCurrent();
         m_last_signal_bar_time=signal_bar_time;
        }

      snapshot.position_ticket=position_ticket;
      snapshot.direction=PositionDirectionName(position_type);
      snapshot.open_time=opened_at;
      snapshot.signal_price=signal_price;
      snapshot.exit_signal_present=should_close;
      snapshot.exit_allowed=false;
      snapshot.exit_blocked=false;
      snapshot.exit_type=(should_close ? "STRATEGY_RANGE_MIDPOINT" : "NONE");
      snapshot.exit_reason=reason;
      snapshot.signal_bar_time=signal_bar_time;
      snapshot.strategy_exit_applicable=true;
      snapshot.strategy_exit_triggered=should_close;
      snapshot.range_midpoint=range_midpoint;
      snapshot.range_midpoint_triggered=should_close;
      // A logical evaluation Sequence represents one Position+completed-bar
      // result. Freeze its source timestamps at that first observation; later
      // ticks must not rewrite metadata as if it existed at the earlier time.
      if(new_evaluation)
         PopulateSourceMetadata(snapshot);
      return(true);
     }

   //--- Records only the existing ExecutionEngine guard outcome. Its return
   //--- value is diagnostic and must never feed back into the close decision.
   bool              RecordEvaluationOutcome(SExitSnapshot &snapshot,
                                             const bool allowed,
                                             const bool blocked,
                                             const string reason,
                                             const bool log_evaluation)
     {
      snapshot.exit_allowed=allowed;
      snapshot.exit_blocked=blocked;
      snapshot.exit_reason=reason;
      if(log_evaluation && snapshot.strategy_exit_triggered)
         m_strategy_signal_count++;
      bool stored=true;
      if(log_evaluation || snapshot.exit_signal_present)
         stored=WriteSnapshot(snapshot,log_evaluation);
      else
         m_active_snapshot=snapshot;
      if(log_evaluation)
         LogEvaluation(snapshot);
      return(stored);
     }

   void              RecordCloseRequest(SExitSnapshot &snapshot,
                                        const datetime request_time)
     {
      snapshot.close_requested=true;
      snapshot.close_request_time=request_time;
      snapshot.last_attempt_time=request_time;
      snapshot.exit_allowed=true;
      snapshot.exit_blocked=false;
      m_close_request_count++;
      WriteSnapshot(snapshot,false);
      CLogger::Info(StringFormat(
         "[COMMON_EXIT_CLOSE_REQUEST] Sequence=%I64d;PositionTicket=%I64u;CloseRequestTime=%s;ExitType=%s;ExitReason=%s",
         snapshot.exit_evaluation_sequence,snapshot.position_ticket,
         TimeToString(request_time,TIME_DATE|TIME_SECONDS),snapshot.exit_type,
         snapshot.exit_reason));
     }

   void              RecordCloseResult(SExitSnapshot &snapshot,
                                       const bool accepted,const long retcode,
                                       const int retry_count,
                                       const datetime result_time,
                                       const string description)
     {
      snapshot.close_request_accepted=accepted;
      snapshot.close_succeeded=accepted;
      snapshot.close_failed=!accepted;
      snapshot.retcode=retcode;
      snapshot.retry_count=retry_count;
      snapshot.last_attempt_time=result_time;
      if(accepted)
         m_close_accepted_count++;
      else
         m_close_failed_count++;
      m_retry_count+=retry_count;
      WriteSnapshot(snapshot,false);
      CLogger::Info(StringFormat(
         "[COMMON_EXIT_CLOSE_RESULT] Sequence=%I64d;PositionTicket=%I64u;Accepted=%s;Succeeded=%s;Failed=%s;Retcode=%I64d;RetryCount=%d;LastAttemptTime=%s;Description=%s",
         snapshot.exit_evaluation_sequence,snapshot.position_ticket,
         BooleanName(accepted),BooleanName(snapshot.close_succeeded),
         BooleanName(snapshot.close_failed),retcode,retry_count,
         TimeToString(result_time,TIME_DATE|TIME_SECONDS),description));
     }

   //--- Observes terminal deals to distinguish Strategy/Expert closures from
   //--- broker-side SL/TP and other external lifecycle finalization. It never
   //--- sends, changes, or retries a trade request.
   void              ObserveTradeTransaction(const MqlTradeTransaction &transaction)
     {
      if(transaction.type!=TRADE_TRANSACTION_DEAL_ADD || transaction.deal==0 ||
         !HistoryDealSelect(transaction.deal))
         return;
      if(HistoryDealGetString(transaction.deal,DEAL_SYMBOL)!=m_symbol ||
         HistoryDealGetInteger(transaction.deal,DEAL_MAGIC)!=m_magic_number)
         return;

      const ENUM_DEAL_ENTRY deal_entry=(ENUM_DEAL_ENTRY)
         HistoryDealGetInteger(transaction.deal,DEAL_ENTRY);
      const ENUM_DEAL_TYPE deal_type=(ENUM_DEAL_TYPE)
         HistoryDealGetInteger(transaction.deal,DEAL_TYPE);
      const ulong lifecycle_id=(ulong)
         HistoryDealGetInteger(transaction.deal,DEAL_POSITION_ID);
      const datetime deal_time=(datetime)
         HistoryDealGetInteger(transaction.deal,DEAL_TIME);
      const double deal_price=HistoryDealGetDouble(transaction.deal,DEAL_PRICE);
      const double deal_volume=HistoryDealGetDouble(transaction.deal,DEAL_VOLUME);

      if(deal_entry==DEAL_ENTRY_IN)
        {
         if(!m_has_active_position || lifecycle_id!=m_active_lifecycle_id)
           {
            ResetSnapshot(m_active_snapshot);
            m_active_snapshot.position_ticket=(transaction.position>0 ?
               transaction.position : lifecycle_id);
            m_active_snapshot.position_lifecycle_id=lifecycle_id;
            m_active_snapshot.direction=(deal_type==DEAL_TYPE_BUY ? "BUY" : "SELL");
            m_active_snapshot.open_time=deal_time;
            m_active_snapshot.open_price=deal_price;
            m_active_snapshot.current_price=deal_price;
            m_active_snapshot.volume=deal_volume;
            m_active_snapshot.stop_loss=transaction.price_sl;
            m_active_snapshot.take_profit=transaction.price_tp;
            m_active_snapshot.stop_loss_present=(transaction.price_sl>0.0);
            m_active_snapshot.take_profit_present=(transaction.price_tp>0.0);
            m_active_snapshot.position_last_seen_at=deal_time;
            m_active_lifecycle_id=lifecycle_id;
            m_has_active_position=true;
            m_last_signal_bar_time=0;
            m_lifecycle_count++;
           }
         return;
        }

      if(deal_entry!=DEAL_ENTRY_OUT && deal_entry!=DEAL_ENTRY_OUT_BY)
         return;

      SExitSnapshot snapshot;
      if(m_has_active_position && lifecycle_id==m_active_lifecycle_id)
         snapshot=m_active_snapshot;
      else
        {
         ResetSnapshot(snapshot);
         snapshot.position_ticket=(transaction.position>0 ?
            transaction.position : lifecycle_id);
         snapshot.position_lifecycle_id=lifecycle_id;
         snapshot.direction=(deal_type==DEAL_TYPE_SELL ? "BUY" : "SELL");
         snapshot.open_time=deal_time;
         snapshot.open_price=deal_price;
         snapshot.current_price=deal_price;
         snapshot.volume=deal_volume;
         snapshot.position_last_seen_at=deal_time;
         m_lifecycle_count++;
        }

      if(snapshot.exit_evaluation_sequence<=0)
        {
         m_sequence++;
         m_evaluation_audit_count++;
         snapshot.exit_evaluation_sequence=m_sequence;
         snapshot.exit_evaluation_time=deal_time;
         snapshot.exit_reason="Position closed before a Strategy Exit evaluation.";
         snapshot.strategy_exit_applicable=false;
        }
      const ENUM_DEAL_REASON deal_reason=(ENUM_DEAL_REASON)
         HistoryDealGetInteger(transaction.deal,DEAL_REASON);
      const string final_reason=DealReasonName(deal_reason);
      snapshot.updated_at=deal_time;
      snapshot.current_price=deal_price;
      snapshot.position_closed=true;
      snapshot.close_succeeded=true;
      snapshot.close_failed=false;
      snapshot.close_time=deal_time;
      snapshot.close_price=deal_price;
      snapshot.final_close_reason=final_reason;
      snapshot.stop_loss_triggered=(deal_reason==DEAL_REASON_SL);
      snapshot.take_profit_triggered=(deal_reason==DEAL_REASON_TP);
      if(deal_reason==DEAL_REASON_EXPERT)
        {
         snapshot.exit_type="STRATEGY_RANGE_MIDPOINT";
         m_expert_close_count++;
        }
      else if(deal_reason==DEAL_REASON_SL)
        {
         snapshot.exit_type="STOP_LOSS";
         m_stop_loss_close_count++;
        }
      else if(deal_reason==DEAL_REASON_TP)
        {
         snapshot.exit_type="TAKE_PROFIT";
         m_take_profit_close_count++;
        }
      else
        {
         snapshot.exit_type="BROKER_EXTERNAL";
         m_external_close_count++;
        }
      m_finalized_count++;
      WriteSnapshot(snapshot,true);
      CLogger::Info(StringFormat(
         "[COMMON_EXIT_FINAL] Sequence=%I64d;PositionTicket=%I64u;LifecycleID=%I64u;Direction=%s;ExitType=%s;FinalCloseReason=%s;CloseRequested=%s;CloseRequestAccepted=%s;CloseSucceeded=%s;CloseFailed=%s;Retcode=%I64d;RetryCount=%d;PositionClosed=%s;CloseTime=%s;ClosePrice=%.6f;SLTriggered=%s;TPTriggered=%s;DataLeakSafe=%s;SnapshotValid=%s;InvalidReason=%s",
         snapshot.exit_evaluation_sequence,snapshot.position_ticket,
         snapshot.position_lifecycle_id,snapshot.direction,snapshot.exit_type,
         snapshot.final_close_reason,BooleanName(snapshot.close_requested),
         BooleanName(snapshot.close_request_accepted),
         BooleanName(snapshot.close_succeeded),BooleanName(snapshot.close_failed),
         snapshot.retcode,snapshot.retry_count,
         BooleanName(snapshot.position_closed),
         TimeToString(snapshot.close_time,TIME_DATE|TIME_SECONDS),
         snapshot.close_price,BooleanName(snapshot.stop_loss_triggered),
         BooleanName(snapshot.take_profit_triggered),
         BooleanName(snapshot.data_leak_safe),BooleanName(snapshot.is_valid),
         snapshot.invalid_reason));
      m_active_snapshot=snapshot;
      m_has_active_position=false;
      m_active_lifecycle_id=0;
      m_last_signal_bar_time=0;
     }

   long              FinalizedCount(void) { return(m_finalized_count); }
   long              CurrentSequence(void) { return(m_sequence); }
   long              DataLeakCount(void) { return(m_data_leak_count); }
   long              InvalidCount(void) { return(m_invalid_count); }

   void              LogSummary(void)
     {
      CLogger::Info(StringFormat(
         "[COMMON_EXIT_SUMMARY] EvaluateExitInvocationCount=%I64d;ExitEvaluationSequenceCount=%I64d;ExitAuditCount=%I64d;StrategySignalCount=%I64d;CloseRequestCount=%I64d;CloseAcceptedCount=%I64d;CloseFailedCount=%I64d;RetryCount=%I64d;PositionLifecycleCount=%I64d;LifecycleFinalizedCount=%I64d;ExpertCloseCount=%I64d;StopLossCloseCount=%I64d;TakeProfitCloseCount=%I64d;ExternalCloseCount=%I64d;DataLeakCount=%I64d;InvalidCount=%I64d;CurrentSnapshotCount=%d;BoundedHistoryCount=%d;HistoryLimit=%d;GlobalKeys=0;PerSymbolKeys=0",
         m_evaluate_exit_invocation_count,m_sequence,m_evaluation_audit_count,
         m_strategy_signal_count,m_close_request_count,m_close_accepted_count,
         m_close_failed_count,m_retry_count,m_lifecycle_count,m_finalized_count,
         m_expert_close_count,m_stop_loss_close_count,m_take_profit_close_count,
         m_external_close_count,m_data_leak_count,m_invalid_count,
         (m_snapshot_store==NULL ? 0 : m_snapshot_store.ExitSnapshotCount()),
         (m_snapshot_store==NULL ? 0 : m_snapshot_store.ExitHistoryCount()),
         FENX_COMMON_EXIT_HISTORY_LIMIT));
     }
  };

#endif // FENX_COMMON_EXIT_ENGINE_ADAPTER_MQH
