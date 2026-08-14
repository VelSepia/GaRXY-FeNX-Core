//+------------------------------------------------------------------+
//|                         Entry/CommonEntryEngineAdapter.mqh      |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_ENTRY_ENGINE_ADAPTER_MQH
#define FENX_COMMON_ENTRY_ENGINE_ADAPTER_MQH

#include "../Common/CommonSnapshotStore.mqh"
#include "../Common/Logger.mqh"

//--- Observes the established Entry pipeline and publishes one final typed
//--- record per unique completed-bar evaluation. It owns no CTrade instance,
//--- order, position, lot, gate, or strategy decision.
class CCommonEntryEngineAdapter
  {
private:
   CCommonSnapshotStore *m_snapshot_store;
   string                m_symbol;
   ENUM_TIMEFRAMES       m_timeframe;
   int                   m_freshness_limit_seconds;
   long                  m_sequence;
   long                  m_evaluation_count;
   long                  m_audit_count;
   long                  m_allowed_count;
   long                  m_blocked_count;
   long                  m_no_signal_count;
   long                  m_order_submitted_count;
   long                  m_order_succeeded_count;
   long                  m_data_leak_count;
   long                  m_invalid_count;

   string            BooleanName(const bool value)
     {
      return(value ? "true" : "false");
     }

   void              PopulateSourceMetadata(SEntrySnapshot &snapshot)
     {
      if(m_snapshot_store==NULL)
         return;

      SDecisionScoreSnapshot decision;
      snapshot.decision_snapshot_available=
         m_snapshot_store.GetDecisionScoreSnapshot(m_symbol,m_timeframe,decision);
      if(snapshot.decision_snapshot_available)
         snapshot.decision_snapshot_updated_at=decision.updated_at;

      SConfidenceSnapshot confidence;
      snapshot.confidence_snapshot_available=
         m_snapshot_store.GetConfidenceSnapshot(m_symbol,m_timeframe,confidence);
      if(snapshot.confidence_snapshot_available)
         snapshot.confidence_snapshot_updated_at=confidence.updated_at;

      SStandbySnapshot standby;
      snapshot.standby_snapshot_available=
         m_snapshot_store.GetStandbySnapshot(m_symbol,m_timeframe,standby);
      if(snapshot.standby_snapshot_available)
         snapshot.standby_snapshot_updated_at=standby.updated_at;

      SRiskSnapshot risk;
      snapshot.risk_snapshot_available=
         m_snapshot_store.GetRiskSnapshot(m_symbol,m_timeframe,risk);
      if(snapshot.risk_snapshot_available)
         snapshot.risk_snapshot_updated_at=risk.updated_at;

      SMarketStateSnapshot market_state;
      snapshot.market_state_snapshot_available=
         m_snapshot_store.GetMarketStateSnapshot(m_symbol,m_timeframe,market_state);
      if(snapshot.market_state_snapshot_available)
         snapshot.market_state_snapshot_updated_at=market_state.updated_at;
     }

   void              LogSnapshot(const SEntrySnapshot &snapshot)
     {
      CLogger::Info(StringFormat(
         "[COMMON_ENTRY] Sequence=%I64d;EntryEvaluationTime=%s;Symbol=%s;Timeframe=%s;Direction=%s;SignalPresent=%s;SignalBarTime=%s;FinalEntryAllowed=%s;FinalEntryBlocked=%s;FinalBlockStage=%s;OrderSubmitted=%s;OrderSucceeded=%s;DataLeakSafe=%s;SnapshotValid=%s",
         snapshot.entry_evaluation_sequence,
         TimeToString(snapshot.entry_evaluation_time,TIME_DATE|TIME_SECONDS),
         snapshot.symbol,snapshot.timeframe,snapshot.direction,
         BooleanName(snapshot.signal_present),
         TimeToString(snapshot.signal_bar_time,TIME_DATE|TIME_SECONDS),
         BooleanName(snapshot.entry_allowed),BooleanName(snapshot.entry_blocked),
         snapshot.block_stage,BooleanName(snapshot.order_submitted),
         BooleanName(snapshot.order_succeeded),
         BooleanName(snapshot.data_leak_safe),BooleanName(snapshot.is_valid)));
      CLogger::Info(StringFormat(
         "[COMMON_ENTRY_FILTERS] Sequence=%I64d;C3Applicable=%s;C3Blocked=%s;Task007Applicable=%s;Task007Blocked=%s;Task011Applicable=%s;Task011Blocked=%s;EntryQuality=%.6f;EntryQualityValid=%s;FinalBlockReason=%s;FinalEntryReason=%s",
         snapshot.entry_evaluation_sequence,
         BooleanName(snapshot.c3_applicable),BooleanName(snapshot.c3_blocked),
         BooleanName(snapshot.task007_applicable),
         BooleanName(snapshot.task007_blocked),
         BooleanName(snapshot.task011_applicable),
         BooleanName(snapshot.task011_blocked),
         snapshot.entry_quality_score,BooleanName(snapshot.entry_quality_valid),
         snapshot.block_reason,snapshot.final_entry_reason));
      CLogger::Info(StringFormat(
         "[COMMON_ENTRY_GATES] Sequence=%I64d;MarketSelection=%s;Ranking=%s;Allocation=%s;TradingStyle=%s;StrategySelection=%s;Standby=%s;Risk=%s;ExecutionGate=%s;PositionAvailable=%s;DuplicateResultAvailable=%s;DuplicateOrderAllowed=%s;SpreadAllowed=%s;FinalOrderReady=%s;RequestedLot=%.8f;RiskMultiplier=%.8f",
         snapshot.entry_evaluation_sequence,
         BooleanName(snapshot.market_selection_allowed),
         BooleanName(snapshot.ranking_allowed),
         BooleanName(snapshot.allocation_allowed),
         BooleanName(snapshot.trading_style_allowed),
         BooleanName(snapshot.strategy_selection_allowed),
         BooleanName(snapshot.standby_allowed),BooleanName(snapshot.risk_allowed),
         BooleanName(snapshot.execution_gate_allowed),
         BooleanName(snapshot.position_available),
         BooleanName(snapshot.duplicate_order_result_available),
         BooleanName(snapshot.duplicate_order_allowed),
         BooleanName(snapshot.spread_allowed),
         BooleanName(snapshot.final_order_ready),snapshot.requested_lot,
         snapshot.risk_multiplier));
      CLogger::Info(StringFormat(
         "[COMMON_ENTRY_SOURCES] Sequence=%I64d;DecisionUpdatedAt=%s;ConfidenceUpdatedAt=%s;StandbyUpdatedAt=%s;RiskUpdatedAt=%s;MarketStateUpdatedAt=%s;SnapshotUpdatedAt=%s;history_count=%d;keys=0",
         snapshot.entry_evaluation_sequence,
         TimeToString(snapshot.decision_snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.confidence_snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.standby_snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.risk_snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.market_state_snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS),
         (m_snapshot_store==NULL ? 0 : m_snapshot_store.EntryHistoryCount())));
     }

public:
                     CCommonEntryEngineAdapter(void)
     {
      m_snapshot_store=NULL;
      m_symbol="";
      m_timeframe=PERIOD_CURRENT;
      m_freshness_limit_seconds=0;
      m_sequence=0;
      m_evaluation_count=0;
      m_audit_count=0;
      m_allowed_count=0;
      m_blocked_count=0;
      m_no_signal_count=0;
      m_order_submitted_count=0;
      m_order_succeeded_count=0;
      m_data_leak_count=0;
      m_invalid_count=0;
     }

   bool              SetSnapshotStore(CCommonSnapshotStore &snapshot_store)
     {
      m_snapshot_store=GetPointer(snapshot_store);
      return(m_snapshot_store!=NULL);
     }

   bool              Configure(const string symbol,const ENUM_TIMEFRAMES timeframe,
                               const int freshness_limit_seconds)
     {
      if(m_snapshot_store==NULL || StringLen(symbol)==0 ||
         PeriodSeconds(timeframe)<=0 || freshness_limit_seconds<=0)
         return(false);
      m_symbol=symbol;
      m_timeframe=timeframe;
      m_freshness_limit_seconds=freshness_limit_seconds;
      m_sequence=0;
      m_evaluation_count=0;
      m_audit_count=0;
      m_allowed_count=0;
      m_blocked_count=0;
      m_no_signal_count=0;
      m_order_submitted_count=0;
      m_order_succeeded_count=0;
      m_data_leak_count=0;
      m_invalid_count=0;
      return(true);
     }

   //--- Begins an audit only after the established Execution lifecycle accepts
   //--- a new completed bar. Calling this method cannot permit or block Entry.
   long              Begin(SEntrySnapshot &snapshot,
                           const datetime evaluation_time,
                           const datetime signal_bar_time)
     {
      m_sequence++;
      m_evaluation_count++;
      snapshot.symbol=m_symbol;
      snapshot.timeframe=EnumToString(m_timeframe);
      snapshot.snapshot_version=FENX_COMMON_ENTRY_SNAPSHOT_VERSION;
      snapshot.updated_at=evaluation_time;
      snapshot.entry_evaluation_time=evaluation_time;
      snapshot.entry_evaluation_sequence=m_sequence;
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="Entry evaluation is not finalized.";
      snapshot.data_leak_safe=false;
      snapshot.signal_present=false;
      snapshot.direction_available=false;
      snapshot.direction="NONE";
      snapshot.strategy_name="RANGE_MEAN_REVERSION";
      snapshot.signal_bar_time=signal_bar_time;
      snapshot.entry_allowed=false;
      snapshot.entry_blocked=false;
      snapshot.final_entry_reason="Entry evaluation is in progress.";
      snapshot.block_stage="";
      snapshot.block_reason="";
      snapshot.market_selection_available=false;
      snapshot.market_selection_allowed=false;
      snapshot.ranking_available=false;
      snapshot.ranking_allowed=false;
      snapshot.allocation_available=false;
      snapshot.allocation_allowed=false;
      snapshot.trading_style_available=false;
      snapshot.trading_style_allowed=false;
      snapshot.strategy_selection_available=false;
      snapshot.strategy_selection_allowed=false;
      snapshot.standby_available=false;
      snapshot.standby_allowed=false;
      snapshot.risk_available=false;
      snapshot.risk_allowed=false;
      snapshot.execution_gate_available=false;
      snapshot.execution_gate_allowed=false;
      snapshot.c3_applicable=false;
      snapshot.c3_blocked=false;
      snapshot.task007_applicable=false;
      snapshot.task007_blocked=false;
      snapshot.task011_applicable=false;
      snapshot.task011_blocked=false;
      snapshot.entry_quality_score=0.0;
      snapshot.entry_quality_valid=false;
      snapshot.position_available=false;
      snapshot.duplicate_order_result_available=false;
      snapshot.duplicate_order_allowed=false;
      snapshot.spread_allowed=false;
      snapshot.final_order_ready=false;
      snapshot.order_submitted=false;
      snapshot.order_succeeded=false;
      snapshot.requested_lot=0.0;
      snapshot.risk_multiplier=0.0;
      snapshot.decision_snapshot_available=false;
      snapshot.decision_snapshot_updated_at=0;
      snapshot.confidence_snapshot_available=false;
      snapshot.confidence_snapshot_updated_at=0;
      snapshot.standby_snapshot_available=false;
      snapshot.standby_snapshot_updated_at=0;
      snapshot.risk_snapshot_available=false;
      snapshot.risk_snapshot_updated_at=0;
      snapshot.market_state_snapshot_available=false;
      snapshot.market_state_snapshot_updated_at=0;
      PopulateSourceMetadata(snapshot);
      return(m_sequence);
     }

   //--- Finalizes and stores audit data after the existing pipeline has already
   //--- made its final decision. The return value is diagnostic only.
   bool              Finalize(SEntrySnapshot &snapshot)
     {
      snapshot.updated_at=TimeCurrent();
      CEntrySnapshotContract contract;
      const bool valid=contract.Finalize(snapshot,m_freshness_limit_seconds);
      bool stored=false;
      if(m_snapshot_store!=NULL)
         stored=m_snapshot_store.SetEntrySnapshot(m_symbol,m_timeframe,snapshot);
      m_audit_count++;
      if(snapshot.entry_allowed)
         m_allowed_count++;
      if(snapshot.entry_blocked)
         m_blocked_count++;
      if(!snapshot.signal_present && !snapshot.entry_blocked)
         m_no_signal_count++;
      if(snapshot.order_submitted)
         m_order_submitted_count++;
      if(snapshot.order_succeeded)
         m_order_succeeded_count++;
      if(!snapshot.data_leak_safe)
         m_data_leak_count++;
      if(!valid || !stored)
         m_invalid_count++;
      LogSnapshot(snapshot);
      return(valid && stored);
     }

   long              EvaluationCount(void) { return(m_evaluation_count); }
   long              AuditCount(void) { return(m_audit_count); }
   long              DataLeakCount(void) { return(m_data_leak_count); }
   long              InvalidCount(void) { return(m_invalid_count); }

   void              LogSummary(void)
     {
      CLogger::Info(StringFormat(
         "[COMMON_ENTRY_SUMMARY] EntryEvaluationCount=%I64d;EntryAuditSequenceCount=%I64d;FinalAllowedCount=%I64d;BlockedCount=%I64d;NoSignalCount=%I64d;OrderSubmittedCount=%I64d;OrderSucceededCount=%I64d;DataLeakCount=%I64d;InvalidCount=%I64d;CurrentSnapshotCount=%d;BoundedHistoryCount=%d;HistoryLimit=%d;GlobalKeys=0;PerSymbolKeys=0",
         m_evaluation_count,m_audit_count,m_allowed_count,m_blocked_count,
         m_no_signal_count,m_order_submitted_count,m_order_succeeded_count,
         m_data_leak_count,m_invalid_count,
         (m_snapshot_store==NULL ? 0 : m_snapshot_store.EntrySnapshotCount()),
         (m_snapshot_store==NULL ? 0 : m_snapshot_store.EntryHistoryCount()),
         FENX_COMMON_ENTRY_HISTORY_LIMIT));
     }
  };

#endif // FENX_COMMON_ENTRY_ENGINE_ADAPTER_MQH
