//+------------------------------------------------------------------+
//|                         Health/CommonHealthEngineAdapter.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_HEALTH_ENGINE_ADAPTER_MQH
#define FENX_COMMON_HEALTH_ENGINE_ADAPTER_MQH

#include "../Common/CommonSnapshotStore.mqh"
#include "../Common/Logger.mqh"

//--- Per-symbol observation memory. It tracks audit continuity only and owns
//--- no trading, order, position, state-transition, or recovery authority.
struct SCommonHealthObserverRuntime
  {
   string                symbol;
   bool                  has_previous;
   datetime              last_periodic_audit_at;
   ulong                 active_exit_lifecycle_id;
   long                  active_recovery_lifecycle_id;
   long                  last_entry_sequence;
   long                  last_exit_sequence;
   long                  last_execution_sequence;
   long                  last_recovery_audit_sequence;
   bool                  last_exit_close_requested;
   bool                  last_exit_close_accepted;
   bool                  last_exit_close_failed;
   SCommonHealthSnapshot previous;
  };

//--- Converts existing typed outcomes into a passive system-health report.
//--- It never calls an Engine, requests a transition, sends an order, repairs
//--- data, or writes to any existing Common snapshot.
class CCommonHealthEngineAdapter
  {
private:
   CCommonSnapshotStore          *m_snapshot_store;
   ENUM_TIMEFRAMES                m_timeframe;
   SCommonHealthObserverRuntime   m_runtimes[];
   long                           m_next_evaluation_sequence;
   long                           m_order_requested_count;
   long                           m_order_accepted_count;
   long                           m_order_rejected_count;
   long                           m_close_requested_count;
   long                           m_close_accepted_count;
   long                           m_close_failed_count;
   long                           m_retry_count;
   long                           m_runtime_error_count;
   bool                           m_runtime_error_count_available;
   long                           m_sequence_error_count;
   long                           m_lifecycle_error_count;
   long                           m_state_transition_error_count;
   bool                           m_state_transition_error_count_available;
   long                           m_data_leak_count;
   long                           m_healthy_count;
   long                           m_degraded_count;
   long                           m_critical_count;
   datetime                       m_last_healthy_at;
   datetime                       m_last_degraded_at;
   datetime                       m_last_critical_at;

   void              ResetSnapshot(SCommonHealthSnapshot &snapshot)
     {
      snapshot.symbol="";
      snapshot.timeframe="";
      snapshot.snapshot_version=FENX_COMMON_HEALTH_SNAPSHOT_VERSION;
      snapshot.updated_at=0;
      snapshot.health_evaluation_time=0;
      snapshot.health_evaluation_sequence=0;
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.data_leak_safe=true;
      snapshot.invalid_reason="";
      snapshot.health_state=FENX_COMMON_HEALTH_UNKNOWN;
      snapshot.health_score=50.0;
      snapshot.health_reason="Health sources are not yet available.";
      snapshot.is_healthy=false;
      snapshot.is_degraded=false;
      snapshot.is_critical=false;
      FenxResetCommonEngineHealthStatus(snapshot.environment,"Environment");
      FenxResetCommonEngineHealthStatus(snapshot.confidence,"Confidence");
      FenxResetCommonEngineHealthStatus(snapshot.decision_score,"DecisionScore");
      FenxResetCommonEngineHealthStatus(snapshot.volatility,"Volatility");
      FenxResetCommonEngineHealthStatus(snapshot.range,"Range");
      FenxResetCommonEngineHealthStatus(snapshot.trend,"Trend");
      FenxResetCommonEngineHealthStatus(snapshot.market_state,"MarketState");
      FenxResetCommonEngineHealthStatus(snapshot.standby,"Standby");
      FenxResetCommonEngineHealthStatus(snapshot.risk,"Risk");
      FenxResetCommonEngineHealthStatus(snapshot.entry,"Entry");
      FenxResetCommonEngineHealthStatus(snapshot.exit_status,"Exit");
      FenxResetCommonEngineHealthStatus(snapshot.execution,"Execution");
      FenxResetCommonEngineHealthStatus(snapshot.recovery,"Recovery");
      snapshot.databus_usage=0;
      snapshot.databus_capacity=0;
      snapshot.databus_remaining=0;
      snapshot.databus_usage_percent=0.0;
      snapshot.databus_overflow_detected=false;
      snapshot.databus_preflight_passed=false;
      snapshot.snapshot_store_healthy=false;
      snapshot.snapshot_current_count=0;
      snapshot.health_history_count=0;
      snapshot.state_manager_healthy=false;
      snapshot.state_manager_state="UNKNOWN";
      snapshot.entry_contract_healthy=true;
      snapshot.exit_contract_healthy=true;
      snapshot.execution_contract_healthy=true;
      snapshot.recovery_contract_healthy=true;
      snapshot.order_requested_count=0;
      snapshot.order_accepted_count=0;
      snapshot.order_rejected_count=0;
      snapshot.close_requested_count=0;
      snapshot.close_accepted_count=0;
      snapshot.close_failed_count=0;
      snapshot.retry_count=0;
      snapshot.runtime_error_count=0;
      snapshot.runtime_error_count_available=false;
      snapshot.sequence_error_count=0;
      snapshot.lifecycle_error_count=0;
      snapshot.state_transition_error_count=0;
      snapshot.state_transition_error_count_available=false;
      snapshot.data_leak_detected=false;
      snapshot.expected_unavailable_count=0;
      snapshot.expected_invalid_count=0;
      snapshot.expected_stale_count=0;
      snapshot.contract_violation_count=0;
      snapshot.infrastructure_failure_count=0;
      snapshot.healthy_count=0;
      snapshot.degraded_count=0;
      snapshot.critical_count=0;
      snapshot.last_healthy_at=0;
      snapshot.last_degraded_at=0;
      snapshot.last_critical_at=0;
     }

   void              ResetRuntime(SCommonHealthObserverRuntime &runtime,
                                  const string symbol)
     {
      runtime.symbol=symbol;
      runtime.has_previous=false;
      runtime.last_periodic_audit_at=0;
      runtime.active_exit_lifecycle_id=0;
      runtime.active_recovery_lifecycle_id=0;
      runtime.last_entry_sequence=0;
      runtime.last_exit_sequence=0;
      runtime.last_execution_sequence=0;
      runtime.last_recovery_audit_sequence=0;
      runtime.last_exit_close_requested=false;
      runtime.last_exit_close_accepted=false;
      runtime.last_exit_close_failed=false;
      ResetSnapshot(runtime.previous);
     }

   int               FindRuntime(const string symbol)
     {
      for(int index=0;index<ArraySize(m_runtimes);index++)
         if(m_runtimes[index].symbol==symbol)
            return(index);
      return(-1);
     }

   bool              ObserveSequence(const long current,long &last_sequence,
                                     const bool require_gap_free)
     {
      if(current<=0)
         return(false);
      if(last_sequence==0)
        {
         if(require_gap_free && current!=1)
            m_sequence_error_count++;
         last_sequence=current;
         return(true);
        }
      if(current==last_sequence)
         return(false);
      if(current<last_sequence ||
         (require_gap_free && current>last_sequence+1))
         m_sequence_error_count++;
      if(current>last_sequence)
        {
         last_sequence=current;
         return(true);
        }
      return(false);
     }

   void              ObserveStatus(const SCommonEngineHealthStatus &status,
                                   int &available_count,
                                   int &expected_unavailable_count,
                                   int &expected_invalid_count,
                                   int &expected_stale_count)
     {
      if(!status.available)
        {
         expected_unavailable_count++;
         return;
        }
      available_count++;
      if(!status.valid)
        {
         string reason=status.invalid_reason;
         StringToLower(reason);
         if(StringFind(reason,"stale")>=0)
            expected_stale_count++;
         else
            expected_invalid_count++;
         return;
        }
      if(!status.fresh)
         expected_stale_count++;
     }

   void              ApplyLastSeen(SCommonEngineHealthStatus &status,
                                   const SCommonEngineHealthStatus &previous,
                                   const datetime evaluation_time)
     {
      status.last_seen_at=(status.available ? evaluation_time :
                           previous.last_seen_at);
     }

   bool              StatusChanged(const SCommonEngineHealthStatus &left,
                                   const SCommonEngineHealthStatus &right)
     {
      return(left.available!=right.available || left.valid!=right.valid ||
             left.fresh!=right.fresh ||
             left.snapshot_version!=right.snapshot_version ||
             left.invalid_reason!=right.invalid_reason);
     }

   bool              SignificantChange(const SCommonHealthSnapshot &left,
                                       const SCommonHealthSnapshot &right)
     {
      return(left.health_state!=right.health_state ||
             left.health_reason!=right.health_reason ||
             left.expected_unavailable_count!=right.expected_unavailable_count ||
             left.expected_invalid_count!=right.expected_invalid_count ||
             left.expected_stale_count!=right.expected_stale_count ||
             left.contract_violation_count!=right.contract_violation_count ||
             left.infrastructure_failure_count!=right.infrastructure_failure_count ||
             left.databus_usage!=right.databus_usage ||
             left.databus_capacity!=right.databus_capacity ||
             left.databus_overflow_detected!=right.databus_overflow_detected ||
             left.snapshot_store_healthy!=right.snapshot_store_healthy ||
             left.state_manager_state!=right.state_manager_state ||
             left.order_requested_count!=right.order_requested_count ||
             left.order_accepted_count!=right.order_accepted_count ||
             left.order_rejected_count!=right.order_rejected_count ||
             left.close_requested_count!=right.close_requested_count ||
             left.close_accepted_count!=right.close_accepted_count ||
             left.close_failed_count!=right.close_failed_count ||
             left.retry_count!=right.retry_count ||
             left.runtime_error_count!=right.runtime_error_count ||
             left.runtime_error_count_available!=
                right.runtime_error_count_available ||
             left.sequence_error_count!=right.sequence_error_count ||
             left.lifecycle_error_count!=right.lifecycle_error_count ||
             left.state_transition_error_count!=right.state_transition_error_count ||
             left.state_transition_error_count_available!=
                right.state_transition_error_count_available ||
             left.data_leak_detected!=right.data_leak_detected ||
             StatusChanged(left.environment,right.environment) ||
             StatusChanged(left.confidence,right.confidence) ||
             StatusChanged(left.decision_score,right.decision_score) ||
             StatusChanged(left.volatility,right.volatility) ||
             StatusChanged(left.range,right.range) ||
             StatusChanged(left.trend,right.trend) ||
             StatusChanged(left.market_state,right.market_state) ||
             StatusChanged(left.standby,right.standby) ||
             StatusChanged(left.risk,right.risk) ||
             StatusChanged(left.entry,right.entry) ||
             StatusChanged(left.exit_status,right.exit_status) ||
             StatusChanged(left.execution,right.execution) ||
             StatusChanged(left.recovery,right.recovery));
     }

   string            StatusMask(const SCommonHealthSnapshot &snapshot,
                                const int mode)
     {
      SCommonEngineHealthStatus statuses[13];
      statuses[0]=snapshot.environment;
      statuses[1]=snapshot.confidence;
      statuses[2]=snapshot.decision_score;
      statuses[3]=snapshot.volatility;
      statuses[4]=snapshot.range;
      statuses[5]=snapshot.trend;
      statuses[6]=snapshot.market_state;
      statuses[7]=snapshot.standby;
      statuses[8]=snapshot.risk;
      statuses[9]=snapshot.entry;
      statuses[10]=snapshot.exit_status;
      statuses[11]=snapshot.execution;
      statuses[12]=snapshot.recovery;
      string result="";
      for(int index=0;index<13;index++)
        {
         bool value=statuses[index].available;
         if(mode==1)
            value=statuses[index].valid;
         else if(mode==2)
            value=statuses[index].fresh;
         result+=(value ? "1" : "0");
        }
      return(result);
     }

   void              LogSnapshot(const SCommonHealthSnapshot &snapshot)
     {
      CLogger::Info(StringFormat(
         "[COMMON_HEALTH] EvaluationSequence=%I64d;Time=%s;Symbol=%s;HealthState=%s;HealthScore=%.1f;HealthReason=%s;AvailabilityMask=%s;ValidityMask=%s;FreshnessMask=%s;DataBusUsage=%d;DataBusCapacity=%d;DataBusOverflow=%s;EntryContractHealthy=%s;ExitContractHealthy=%s;ExecutionContractHealthy=%s;RecoveryContractHealthy=%s;RuntimeErrorCountAvailable=%s;RuntimeErrorCount=%I64d;OrderRejectedCount=%I64d;CloseFailedCount=%I64d;RetryCount=%I64d;SequenceErrorCount=%I64d;LifecycleErrorCount=%I64d;StateTransitionErrorCountAvailable=%s;StateTransitionErrorCount=%I64d;DataLeakDetected=%s",
         snapshot.health_evaluation_sequence,
         TimeToString(snapshot.health_evaluation_time,TIME_DATE|TIME_SECONDS),
         snapshot.symbol,FenxCommonHealthStateName(snapshot.health_state),
         snapshot.health_score,snapshot.health_reason,
         StatusMask(snapshot,0),StatusMask(snapshot,1),StatusMask(snapshot,2),
         snapshot.databus_usage,snapshot.databus_capacity,
         (snapshot.databus_overflow_detected ? "true" : "false"),
         (snapshot.entry_contract_healthy ? "true" : "false"),
         (snapshot.exit_contract_healthy ? "true" : "false"),
         (snapshot.execution_contract_healthy ? "true" : "false"),
         (snapshot.recovery_contract_healthy ? "true" : "false"),
         (snapshot.runtime_error_count_available ? "true" : "false"),
         snapshot.runtime_error_count,snapshot.order_rejected_count,
         snapshot.close_failed_count,snapshot.retry_count,
         snapshot.sequence_error_count,snapshot.lifecycle_error_count,
         (snapshot.state_transition_error_count_available ? "true" : "false"),
         snapshot.state_transition_error_count,
         (snapshot.data_leak_detected ? "true" : "false")));
     }

   //--- One compact row per emitted evaluation makes sequence gaps and
   //--- duplicates externally auditable without producing a per-tick log.
   void              LogAudit(const SCommonHealthSnapshot &snapshot)
     {
      CLogger::Info(StringFormat(
         "[COMMON_HEALTH_AUDIT] EvaluationSequence=%I64d;Time=%s;Symbol=%s;HealthState=%s;CriticalCount=%I64d;DegradedCount=%I64d;DataBusUsage=%d;DataBusOverflow=%s;RuntimeErrorCountAvailable=%s;RuntimeErrorCount=%I64d;OrderRejectedCount=%I64d;CloseFailedCount=%I64d;RetryCount=%I64d;SequenceErrorCount=%I64d;LifecycleErrorCount=%I64d;StateTransitionErrorCountAvailable=%s;StateTransitionErrorCount=%I64d;DataLeakDetected=%s",
         snapshot.health_evaluation_sequence,
         TimeToString(snapshot.health_evaluation_time,TIME_DATE|TIME_SECONDS),
         snapshot.symbol,FenxCommonHealthStateName(snapshot.health_state),
         snapshot.critical_count,snapshot.degraded_count,
         snapshot.databus_usage,
         (snapshot.databus_overflow_detected ? "true" : "false"),
         (snapshot.runtime_error_count_available ? "true" : "false"),
         snapshot.runtime_error_count,snapshot.order_rejected_count,
         snapshot.close_failed_count,snapshot.retry_count,
         snapshot.sequence_error_count,snapshot.lifecycle_error_count,
         (snapshot.state_transition_error_count_available ? "true" : "false"),
         snapshot.state_transition_error_count,
         (snapshot.data_leak_detected ? "true" : "false")));
     }

public:
                     CCommonHealthEngineAdapter(void)
     {
      m_snapshot_store=NULL;
      m_timeframe=PERIOD_CURRENT;
      ResetCounters();
     }

   void              ResetCounters(void)
     {
      m_next_evaluation_sequence=0;
      m_order_requested_count=0;
      m_order_accepted_count=0;
      m_order_rejected_count=0;
      m_close_requested_count=0;
      m_close_accepted_count=0;
      m_close_failed_count=0;
      m_retry_count=0;
      m_runtime_error_count=0;
      m_runtime_error_count_available=false;
      m_sequence_error_count=0;
      m_lifecycle_error_count=0;
      m_state_transition_error_count=0;
      m_state_transition_error_count_available=false;
      m_data_leak_count=0;
      m_healthy_count=0;
      m_degraded_count=0;
      m_critical_count=0;
      m_last_healthy_at=0;
      m_last_degraded_at=0;
      m_last_critical_at=0;
     }

   bool              Configure(CCommonSnapshotStore &snapshot_store,
                               const ENUM_TIMEFRAMES timeframe)
     {
      if(PeriodSeconds(timeframe)<=0)
         return(false);
      m_snapshot_store=GetPointer(snapshot_store);
      m_timeframe=timeframe;
      ArrayFree(m_runtimes);
      ResetCounters();
      return(m_snapshot_store!=NULL);
     }

   bool              RegisterSymbol(const string symbol)
     {
      if(StringLen(symbol)==0 || FindRuntime(symbol)>=0)
         return(false);
      const int count=ArraySize(m_runtimes);
      if(ArrayResize(m_runtimes,count+1)!=(count+1))
         return(false);
      ResetRuntime(m_runtimes[count],symbol);
      return(true);
     }

   //--- Evaluates one read-only measurement. Sequence and lifecycle tracking
   //--- are diagnostic reconciliation only and cannot affect source Engines.
   bool              Observe(const SCommonHealthMeasurement &measurement,
                             const datetime evaluation_time,
                             SCommonHealthSnapshot &snapshot,
                             bool &emitted)
     {
      emitted=false;
      const int index=FindRuntime(measurement.symbol);
      if(index<0 || measurement.timeframe!=EnumToString(m_timeframe) ||
         evaluation_time<=0 || m_snapshot_store==NULL)
         return(false);
      SCommonHealthObserverRuntime runtime=m_runtimes[index];

      const bool new_entry=ObserveSequence(measurement.entry_sequence,
                                           runtime.last_entry_sequence,true);
      const bool new_exit=ObserveSequence(measurement.exit_sequence,
                                          runtime.last_exit_sequence,true);
      const bool new_execution=ObserveSequence(measurement.execution_sequence,
                                               runtime.last_execution_sequence,true);
      const bool new_recovery=ObserveSequence(
         measurement.recovery_audit_sequence,
         runtime.last_recovery_audit_sequence,false);
      m_sequence_error_count+=MathMax(0,measurement.sequence_error_count);
      m_lifecycle_error_count+=MathMax(0,measurement.lifecycle_error_count);
      if(measurement.state_transition_error_count_available)
        {
         m_state_transition_error_count_available=true;
         m_state_transition_error_count+=MathMax(
            0,measurement.state_transition_error_count);
        }
      if(measurement.runtime_error_count_available)
        {
         m_runtime_error_count_available=true;
         m_runtime_error_count=MathMax(m_runtime_error_count,
                                       measurement.runtime_error_count);
        }

      int entry_violation=0;
      int exit_violation=0;
      int execution_violation=0;
      int recovery_violation=0;
      if(new_entry && measurement.entry_allowed &&
         (!measurement.entry_final_order_ready ||
          !measurement.entry_order_submitted ||
          !measurement.entry_order_succeeded))
         entry_violation++;

      if(new_execution)
        {
         m_order_requested_count++;
         if(measurement.execution_order_accepted)
            m_order_accepted_count++;
         if(measurement.execution_order_rejected)
            m_order_rejected_count++;
         m_retry_count+=MathMax(0,measurement.execution_retry_count);
         if(!measurement.execution_order_submitted ||
            measurement.execution_order_accepted==
               measurement.execution_order_rejected)
            execution_violation++;
         if(measurement.execution_request_type=="ENTRY")
           {
            if(measurement.execution_entry_sequence<=0 ||
               measurement.execution_entry_sequence!=measurement.entry_sequence ||
               (measurement.execution_order_accepted &&
                !measurement.execution_position_opened))
               execution_violation++;
           }
         else if(measurement.execution_request_type=="CLOSE")
           {
            if(measurement.execution_exit_sequence<=0 ||
               measurement.execution_exit_sequence!=measurement.exit_sequence ||
               (measurement.execution_order_accepted &&
                !measurement.execution_position_closed))
               execution_violation++;
           }
         else
            execution_violation++;
        }

      if(new_exit)
        {
         runtime.last_exit_close_requested=false;
         runtime.last_exit_close_accepted=false;
         runtime.last_exit_close_failed=false;
         if(measurement.exit_lifecycle_id>0 &&
            runtime.active_exit_lifecycle_id!=0 &&
            runtime.active_exit_lifecycle_id!=measurement.exit_lifecycle_id)
           {
            //--- A broker-side SL/TP finalization is delivered through
            //--- OnTradeTransaction and can occur after Health's same-tick
            //--- observation. The typed history is authoritative evidence
            //--- that the prior lifecycle completed before this replacement.
            if(m_snapshot_store==NULL ||
               !m_snapshot_store.HasFinalizedExitLifecycle(
                  measurement.symbol,m_timeframe,
                  runtime.active_exit_lifecycle_id))
               m_lifecycle_error_count++;
            else
               runtime.active_exit_lifecycle_id=0;
           }
         if(measurement.exit_lifecycle_id>0 &&
            !measurement.exit_position_closed)
            runtime.active_exit_lifecycle_id=measurement.exit_lifecycle_id;
        }
      if(measurement.exit_sequence>0 &&
         measurement.exit_sequence==runtime.last_exit_sequence)
        {
         if(measurement.exit_close_requested &&
            !runtime.last_exit_close_requested)
           {
            m_close_requested_count++;
            runtime.last_exit_close_requested=true;
           }
         if(measurement.exit_close_accepted &&
            !runtime.last_exit_close_accepted)
           {
            m_close_accepted_count++;
            runtime.last_exit_close_accepted=true;
           }
         if(measurement.exit_close_failed &&
            !runtime.last_exit_close_failed)
           {
            m_close_failed_count++;
            runtime.last_exit_close_failed=true;
           }
         if(measurement.exit_close_requested &&
            StringLen(measurement.exit_reason)==0)
            exit_violation++;
         if(measurement.exit_position_closed &&
            StringLen(measurement.exit_final_close_reason)==0)
            exit_violation++;
         if(measurement.exit_position_closed &&
            measurement.exit_lifecycle_id==runtime.active_exit_lifecycle_id)
            runtime.active_exit_lifecycle_id=0;
        }

      if(new_recovery)
        {
         const int terminal_count=(measurement.recovery_completed ? 1 : 0)+
            (measurement.recovery_failed ? 1 : 0)+
            (measurement.recovery_escalated ? 1 : 0);
         if(terminal_count>1 ||
            ((measurement.recovery_active || terminal_count>0) &&
             measurement.recovery_sequence<=0))
            recovery_violation++;
         if(measurement.recovery_active)
           {
            if(runtime.active_recovery_lifecycle_id!=0 &&
               runtime.active_recovery_lifecycle_id!=
                  measurement.recovery_sequence)
               m_lifecycle_error_count++;
            runtime.active_recovery_lifecycle_id=
               measurement.recovery_sequence;
           }
         if(terminal_count==1 && runtime.active_recovery_lifecycle_id==
            measurement.recovery_sequence)
            runtime.active_recovery_lifecycle_id=0;
         if(measurement.recovery_entry_resume_allowed &&
            (!measurement.recovery_entry_snapshot_available ||
             measurement.recovery_entry_sequence<=0 ||
             !measurement.recovery_execution_gate_allowed))
            recovery_violation++;
        }

      bool leak=measurement.data_leak_detected;
      if(measurement.entry.available && !measurement.entry_data_leak_safe)
         leak=true;
      if(measurement.exit_status.available && !measurement.exit_data_leak_safe)
         leak=true;
      if(measurement.execution.available &&
         !measurement.execution_data_leak_safe)
         leak=true;
      if(measurement.recovery.available &&
         !measurement.recovery_data_leak_safe)
         leak=true;
      if(leak && (!runtime.has_previous ||
                  !runtime.previous.data_leak_detected))
         m_data_leak_count++;

      ResetSnapshot(snapshot);
      snapshot.symbol=measurement.symbol;
      snapshot.timeframe=measurement.timeframe;
      snapshot.updated_at=evaluation_time;
      snapshot.health_evaluation_time=evaluation_time;
      snapshot.environment=measurement.environment;
      snapshot.confidence=measurement.confidence;
      snapshot.decision_score=measurement.decision_score;
      snapshot.volatility=measurement.volatility;
      snapshot.range=measurement.range;
      snapshot.trend=measurement.trend;
      snapshot.market_state=measurement.market_state;
      snapshot.standby=measurement.standby;
      snapshot.risk=measurement.risk;
      snapshot.entry=measurement.entry;
      snapshot.exit_status=measurement.exit_status;
      snapshot.execution=measurement.execution;
      snapshot.recovery=measurement.recovery;
      if(runtime.has_previous)
        {
         ApplyLastSeen(snapshot.environment,runtime.previous.environment,evaluation_time);
         ApplyLastSeen(snapshot.confidence,runtime.previous.confidence,evaluation_time);
         ApplyLastSeen(snapshot.decision_score,runtime.previous.decision_score,evaluation_time);
         ApplyLastSeen(snapshot.volatility,runtime.previous.volatility,evaluation_time);
         ApplyLastSeen(snapshot.range,runtime.previous.range,evaluation_time);
         ApplyLastSeen(snapshot.trend,runtime.previous.trend,evaluation_time);
         ApplyLastSeen(snapshot.market_state,runtime.previous.market_state,evaluation_time);
         ApplyLastSeen(snapshot.standby,runtime.previous.standby,evaluation_time);
         ApplyLastSeen(snapshot.risk,runtime.previous.risk,evaluation_time);
         ApplyLastSeen(snapshot.entry,runtime.previous.entry,evaluation_time);
         ApplyLastSeen(snapshot.exit_status,runtime.previous.exit_status,evaluation_time);
         ApplyLastSeen(snapshot.execution,runtime.previous.execution,evaluation_time);
         ApplyLastSeen(snapshot.recovery,runtime.previous.recovery,evaluation_time);
        }
      else
        {
         SCommonEngineHealthStatus empty;
         FenxResetCommonEngineHealthStatus(empty,"");
         ApplyLastSeen(snapshot.environment,empty,evaluation_time);
         ApplyLastSeen(snapshot.confidence,empty,evaluation_time);
         ApplyLastSeen(snapshot.decision_score,empty,evaluation_time);
         ApplyLastSeen(snapshot.volatility,empty,evaluation_time);
         ApplyLastSeen(snapshot.range,empty,evaluation_time);
         ApplyLastSeen(snapshot.trend,empty,evaluation_time);
         ApplyLastSeen(snapshot.market_state,empty,evaluation_time);
         ApplyLastSeen(snapshot.standby,empty,evaluation_time);
         ApplyLastSeen(snapshot.risk,empty,evaluation_time);
         ApplyLastSeen(snapshot.entry,empty,evaluation_time);
         ApplyLastSeen(snapshot.exit_status,empty,evaluation_time);
         ApplyLastSeen(snapshot.execution,empty,evaluation_time);
         ApplyLastSeen(snapshot.recovery,empty,evaluation_time);
        }

      int available_count=0;
      ObserveStatus(snapshot.environment,available_count,
         snapshot.expected_unavailable_count,snapshot.expected_invalid_count,
         snapshot.expected_stale_count);
      ObserveStatus(snapshot.confidence,available_count,
         snapshot.expected_unavailable_count,snapshot.expected_invalid_count,
         snapshot.expected_stale_count);
      ObserveStatus(snapshot.decision_score,available_count,
         snapshot.expected_unavailable_count,snapshot.expected_invalid_count,
         snapshot.expected_stale_count);
      ObserveStatus(snapshot.volatility,available_count,
         snapshot.expected_unavailable_count,snapshot.expected_invalid_count,
         snapshot.expected_stale_count);
      ObserveStatus(snapshot.range,available_count,
         snapshot.expected_unavailable_count,snapshot.expected_invalid_count,
         snapshot.expected_stale_count);
      ObserveStatus(snapshot.trend,available_count,
         snapshot.expected_unavailable_count,snapshot.expected_invalid_count,
         snapshot.expected_stale_count);
      ObserveStatus(snapshot.market_state,available_count,
         snapshot.expected_unavailable_count,snapshot.expected_invalid_count,
         snapshot.expected_stale_count);
      ObserveStatus(snapshot.standby,available_count,
         snapshot.expected_unavailable_count,snapshot.expected_invalid_count,
         snapshot.expected_stale_count);
      ObserveStatus(snapshot.risk,available_count,
         snapshot.expected_unavailable_count,snapshot.expected_invalid_count,
         snapshot.expected_stale_count);
      ObserveStatus(snapshot.entry,available_count,
         snapshot.expected_unavailable_count,snapshot.expected_invalid_count,
         snapshot.expected_stale_count);
      ObserveStatus(snapshot.exit_status,available_count,
         snapshot.expected_unavailable_count,snapshot.expected_invalid_count,
         snapshot.expected_stale_count);
      ObserveStatus(snapshot.execution,available_count,
         snapshot.expected_unavailable_count,snapshot.expected_invalid_count,
         snapshot.expected_stale_count);
      ObserveStatus(snapshot.recovery,available_count,
         snapshot.expected_unavailable_count,snapshot.expected_invalid_count,
         snapshot.expected_stale_count);

      snapshot.databus_usage=measurement.databus_usage;
      snapshot.databus_capacity=measurement.databus_capacity;
      snapshot.databus_remaining=measurement.databus_remaining;
      snapshot.databus_usage_percent=(measurement.databus_capacity>0 ?
         100.0*(double)measurement.databus_usage/
         (double)measurement.databus_capacity : 0.0);
      snapshot.databus_overflow_detected=
         (measurement.databus_overflow_detected ||
          measurement.databus_usage>measurement.databus_capacity);
      snapshot.databus_preflight_passed=measurement.databus_preflight_passed;
      snapshot.snapshot_store_healthy=
         (measurement.snapshot_store_available &&
          measurement.snapshot_identity_consistent &&
          measurement.snapshot_history_bounded);
      snapshot.snapshot_current_count=measurement.snapshot_current_count;
      snapshot.health_history_count=measurement.health_history_count;
      snapshot.state_manager_state=measurement.state_manager_state;
      snapshot.state_manager_healthy=measurement.state_manager_state_known;
      snapshot.order_requested_count=m_order_requested_count;
      snapshot.order_accepted_count=m_order_accepted_count;
      snapshot.order_rejected_count=m_order_rejected_count;
      snapshot.close_requested_count=m_close_requested_count;
      snapshot.close_accepted_count=m_close_accepted_count;
      snapshot.close_failed_count=m_close_failed_count;
      snapshot.retry_count=m_retry_count;
      snapshot.runtime_error_count=m_runtime_error_count;
      snapshot.runtime_error_count_available=m_runtime_error_count_available;
      snapshot.sequence_error_count=m_sequence_error_count;
      snapshot.lifecycle_error_count=m_lifecycle_error_count;
      snapshot.state_transition_error_count=m_state_transition_error_count;
      snapshot.state_transition_error_count_available=
         m_state_transition_error_count_available;
      snapshot.data_leak_detected=(m_data_leak_count>0);
      snapshot.data_leak_safe=!snapshot.data_leak_detected;

      snapshot.infrastructure_failure_count=0;
      if(snapshot.databus_overflow_detected)
         snapshot.infrastructure_failure_count++;
      if(!snapshot.databus_preflight_passed)
         snapshot.infrastructure_failure_count++;
      if(!snapshot.snapshot_store_healthy)
         snapshot.infrastructure_failure_count++;
      if(!snapshot.state_manager_healthy)
         snapshot.infrastructure_failure_count++;
      if(snapshot.runtime_error_count>0)
         snapshot.infrastructure_failure_count++;

      snapshot.contract_violation_count=entry_violation+exit_violation+
         execution_violation+recovery_violation;
      if(snapshot.sequence_error_count>0)
         snapshot.contract_violation_count++;
      if(snapshot.lifecycle_error_count>0)
         snapshot.contract_violation_count++;
      if(snapshot.state_transition_error_count>0)
         snapshot.contract_violation_count++;
      if(snapshot.order_rejected_count>0)
         snapshot.contract_violation_count++;
      if(snapshot.close_failed_count>0)
         snapshot.contract_violation_count++;
      if(snapshot.retry_count>0)
         snapshot.contract_violation_count++;
      if(snapshot.data_leak_detected)
         snapshot.contract_violation_count++;
      snapshot.entry_contract_healthy=(entry_violation==0 &&
                                       snapshot.sequence_error_count==0 &&
                                       !snapshot.data_leak_detected);
      snapshot.exit_contract_healthy=(exit_violation==0 &&
                                      snapshot.lifecycle_error_count==0 &&
                                      snapshot.close_failed_count==0 &&
                                      !snapshot.data_leak_detected);
      snapshot.execution_contract_healthy=(execution_violation==0 &&
         snapshot.order_rejected_count==0 && snapshot.retry_count==0 &&
         snapshot.sequence_error_count==0 && !snapshot.data_leak_detected);
      snapshot.recovery_contract_healthy=(recovery_violation==0 &&
         snapshot.lifecycle_error_count==0 &&
         snapshot.sequence_error_count==0 && !snapshot.data_leak_detected);

      const bool near_capacity=(snapshot.databus_usage_percent>=90.0 &&
                                !snapshot.databus_overflow_detected);
      if(snapshot.infrastructure_failure_count>0 ||
         snapshot.contract_violation_count>0)
        {
         snapshot.health_state=FENX_COMMON_HEALTH_CRITICAL;
         snapshot.health_score=0.0;
         snapshot.health_reason="Infrastructure or formal contract violation detected.";
         snapshot.is_critical=true;
        }
      else if(available_count==0)
        {
         snapshot.health_state=FENX_COMMON_HEALTH_UNKNOWN;
         snapshot.health_score=50.0;
         snapshot.health_reason="Health sources are not yet available.";
        }
      else if(snapshot.expected_unavailable_count>0 ||
              snapshot.expected_invalid_count>0 ||
              snapshot.expected_stale_count>0 || near_capacity)
        {
         snapshot.health_state=FENX_COMMON_HEALTH_DEGRADED;
         snapshot.health_score=75.0;
         snapshot.health_reason=(near_capacity ?
            "DataBus usage is near capacity." :
            "Expected unavailable, invalid, or stale source state observed.");
         snapshot.is_degraded=true;
        }
      else
        {
         snapshot.health_state=FENX_COMMON_HEALTH_HEALTHY;
         snapshot.health_score=100.0;
         snapshot.health_reason="All observed Common Engine and infrastructure contracts are healthy.";
         snapshot.is_healthy=true;
        }

      const bool periodic_due=(runtime.last_periodic_audit_at==0 ||
         evaluation_time-runtime.last_periodic_audit_at>=
            FENX_COMMON_HEALTH_PERIODIC_AUDIT_SECONDS);
      const bool changed=(!runtime.has_previous ||
                          SignificantChange(runtime.previous,snapshot));
      if(!changed && !periodic_due)
        {
         m_runtimes[index]=runtime;
         return(true);
        }

      snapshot.health_evaluation_sequence=++m_next_evaluation_sequence;
      if(snapshot.health_state==FENX_COMMON_HEALTH_HEALTHY)
        {
         m_healthy_count++;
         m_last_healthy_at=evaluation_time;
        }
      else if(snapshot.health_state==FENX_COMMON_HEALTH_DEGRADED)
        {
         m_degraded_count++;
         m_last_degraded_at=evaluation_time;
        }
      else if(snapshot.health_state==FENX_COMMON_HEALTH_CRITICAL)
        {
         m_critical_count++;
         m_last_critical_at=evaluation_time;
        }
      snapshot.healthy_count=m_healthy_count;
      snapshot.degraded_count=m_degraded_count;
      snapshot.critical_count=m_critical_count;
      snapshot.last_healthy_at=m_last_healthy_at;
      snapshot.last_degraded_at=m_last_degraded_at;
      snapshot.last_critical_at=m_last_critical_at;
      snapshot.health_history_count=MathMin(FENX_COMMON_HEALTH_HISTORY_LIMIT,
         measurement.health_history_count+1);
      CCommonHealthSnapshotContract contract;
      contract.Finalize(snapshot);
      if(!snapshot.is_valid ||
         !m_snapshot_store.SetHealthSnapshot(snapshot.symbol,m_timeframe,snapshot))
         return(false);

      LogAudit(snapshot);
      const bool state_changed=(!runtime.has_previous ||
         runtime.previous.health_state!=snapshot.health_state);
      if(periodic_due || state_changed || snapshot.is_critical)
         LogSnapshot(snapshot);
      runtime.previous=snapshot;
      runtime.has_previous=true;
      if(periodic_due)
         runtime.last_periodic_audit_at=evaluation_time;
      m_runtimes[index]=runtime;
      emitted=true;
      return(true);
     }

   int               OpenExitLifecycleCount(void)
     {
      int count=0;
      for(int index=0;index<ArraySize(m_runtimes);index++)
         if(m_runtimes[index].active_exit_lifecycle_id!=0)
            count++;
      return(count);
     }

   int               OpenRecoveryLifecycleCount(void)
     {
      int count=0;
      for(int index=0;index<ArraySize(m_runtimes);index++)
         if(m_runtimes[index].active_recovery_lifecycle_id!=0)
            count++;
      return(count);
     }

   void              LogSummary(void)
     {
      CLogger::Info(StringFormat(
         "[COMMON_HEALTH_SUMMARY] HealthEvaluationCount=%I64d;HealthyCount=%I64d;DegradedCount=%I64d;CriticalCount=%I64d;OrderRequestedCount=%I64d;OrderAcceptedCount=%I64d;OrderRejectedCount=%I64d;CloseRequestedCount=%I64d;CloseAcceptedCount=%I64d;CloseFailedCount=%I64d;RetryCount=%I64d;RuntimeErrorCountAvailable=%s;RuntimeErrorCount=%I64d;SequenceErrorCount=%I64d;LifecycleErrorCount=%I64d;StateTransitionErrorCountAvailable=%s;StateTransitionErrorCount=%I64d;DataLeakCount=%I64d;OpenExitLifecycleCount=%d;OpenRecoveryLifecycleCount=%d;CurrentSnapshotCount=%d;BoundedHistoryCount=%d;HistoryLimit=%d;GlobalKeys=0;PerSymbolKeys=0",
         m_next_evaluation_sequence,m_healthy_count,m_degraded_count,
         m_critical_count,m_order_requested_count,m_order_accepted_count,
         m_order_rejected_count,m_close_requested_count,m_close_accepted_count,
         m_close_failed_count,m_retry_count,
         (m_runtime_error_count_available ? "true" : "false"),
         m_runtime_error_count,
         m_sequence_error_count,m_lifecycle_error_count,
         (m_state_transition_error_count_available ? "true" : "false"),
         m_state_transition_error_count,m_data_leak_count,
         OpenExitLifecycleCount(),OpenRecoveryLifecycleCount(),
         (m_snapshot_store==NULL ? 0 : m_snapshot_store.HealthSnapshotCount()),
         (m_snapshot_store==NULL ? 0 : m_snapshot_store.HealthHistoryCount()),
         FENX_COMMON_HEALTH_HISTORY_LIMIT));
     }
  };

#endif // FENX_COMMON_HEALTH_ENGINE_ADAPTER_MQH
