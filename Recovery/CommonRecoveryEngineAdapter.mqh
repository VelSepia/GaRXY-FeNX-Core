//+------------------------------------------------------------------+
//|                   Recovery/CommonRecoveryEngineAdapter.mqh      |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_RECOVERY_ENGINE_ADAPTER_MQH
#define FENX_COMMON_RECOVERY_ENGINE_ADAPTER_MQH

#include "../Common/CommonSnapshotStore.mqh"

//--- Private observer state. It identifies one audit lifecycle but never
//--- participates in the Standby, Risk, StateManager, Entry, or Execution path.
struct SCommonRecoveryObserverRuntime
  {
   string                   symbol;
   bool                     has_previous;
   bool                     lifecycle_open;
   long                     lifecycle_sequence;
   datetime                 lifecycle_started_at;
   string                   lifecycle_source;
   string                   lifecycle_reason;
   SCommonRecoverySnapshot  previous;
  };

//--- Consolidates already-decided recovery facts into a typed audit contract.
//--- The adapter owns no recovery predicate, state transition, permission,
//--- order, position, lot, cooldown, confirmation, or hysteresis decision.
class CCommonRecoveryEngineAdapter
  {
private:
   CCommonSnapshotStore            *m_snapshot_store;
   ENUM_TIMEFRAMES                  m_timeframe;
   SCommonRecoveryObserverRuntime  m_runtimes[];
   long                             m_next_recovery_sequence;
   long                             m_next_audit_sequence;
   long                             m_recovery_started_count;
   long                             m_recovery_completed_count;
   long                             m_recovery_failed_count;
   long                             m_recovery_escalated_count;
   long                             m_entry_resume_count;
   long                             m_standby_source_count;
   long                             m_risk_source_count;
   long                             m_other_source_count;
   long                             m_data_leak_count;
   long                             m_invalid_count;

   void              ResetSnapshot(SCommonRecoverySnapshot &snapshot)
     {
      snapshot.runtime_context_id.symbol="";
      snapshot.runtime_context_id.timeframe=PERIOD_CURRENT;
      snapshot.entry_context_id.symbol="";
      snapshot.entry_context_id.timeframe=PERIOD_CURRENT;
      snapshot.symbol="";
      snapshot.timeframe="";
      snapshot.snapshot_version=FENX_COMMON_RECOVERY_SNAPSHOT_VERSION;
      snapshot.updated_at=0;
      snapshot.recovery_evaluation_time=0;
      snapshot.recovery_sequence=0;
      snapshot.recovery_audit_sequence=0;
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.data_leak_safe=false;
      snapshot.invalid_reason="";
      snapshot.recovery_required=false;
      snapshot.recovery_active=false;
      snapshot.recovery_state="NONE";
      snapshot.recovery_source="NONE";
      snapshot.recovery_reason="";
      snapshot.recovery_condition_met=false;
      snapshot.recovery_allowed=false;
      snapshot.entry_resume_allowed=false;
      snapshot.confirmation_count=0;
      snapshot.required_confirmation_count=1;
      snapshot.confirmation_complete=false;
      snapshot.recovery_started_at=0;
      snapshot.last_recovery_check_at=0;
      snapshot.cooldown_started_at=0;
      snapshot.cooldown_started_at_available=false;
      snapshot.cooldown_until=0;
      snapshot.recovery_completed_at=0;
      snapshot.recovery_duration_seconds=0;
      snapshot.hysteresis_active=false;
      snapshot.hysteresis_state="";
      snapshot.standby_snapshot_valid=false;
      snapshot.standby_snapshot_fresh=false;
      snapshot.standby_state="";
      snapshot.standby_recovery_condition=false;
      snapshot.standby_entry_allowed=false;
      snapshot.standby_updated_at=0;
      snapshot.risk_snapshot_valid=false;
      snapshot.risk_snapshot_fresh=false;
      snapshot.risk_state="";
      snapshot.risk_stop_active=false;
      snapshot.risk_recovery_condition=false;
      snapshot.risk_entry_allowed=false;
      snapshot.risk_updated_at=0;
      snapshot.market_state="";
      snapshot.market_state_available=false;
      snapshot.market_state_updated_at=0;
      snapshot.state_manager_state="INIT";
      snapshot.state_manager_observed_at=0;
      snapshot.entry_snapshot_available=false;
      snapshot.entry_evaluation_sequence=0;
      snapshot.entry_snapshot_updated_at=0;
      snapshot.execution_gate_allowed=false;
      snapshot.recovery_completed=false;
      snapshot.recovery_escalated=false;
      snapshot.recovery_failed=false;
      snapshot.final_recovery_reason="";
     }

   void              ResetRuntime(SCommonRecoveryObserverRuntime &runtime,
                                  const string symbol)
     {
      runtime.symbol=symbol;
      runtime.has_previous=false;
      runtime.lifecycle_open=false;
      runtime.lifecycle_sequence=0;
      runtime.lifecycle_started_at=0;
      runtime.lifecycle_source="NONE";
      runtime.lifecycle_reason="";
      ResetSnapshot(runtime.previous);
     }

   int               FindRuntime(const string symbol)
     {
      for(int index=0;index<ArraySize(m_runtimes);index++)
         if(m_runtimes[index].symbol==symbol)
            return(index);
      return(-1);
     }

   string            DetermineSource(const SStandbySnapshot &standby,
                                     const SRiskSnapshot &risk,
                                     const string core_state)
     {
      if(core_state=="RISK_STOP" || risk.risk_stop_active ||
         risk.risk_stop_requested || standby.risk_stop_requested)
         return("RISK_STOP");
      if(standby.escalation_requested ||
         risk.action=="ESCALATE_DYNAMIC_ZONE")
         return("ESCALATION");
      if(core_state=="DYNAMIC_ZONE")
         return("DYNAMIC_ZONE");
      if(standby.is_active || standby.is_recovering)
         return("STANDBY");
      if(risk.recovery_condition_met || risk.state!="SAFE" ||
         core_state!="NORMAL")
         return("SYSTEM_STATE");
      return("NONE");
     }

   string            DetermineReason(const SStandbySnapshot &standby,
                                     const SRiskSnapshot &risk,
                                     const string source)
     {
      if(source=="STANDBY" || source=="ESCALATION" ||
         source=="DYNAMIC_ZONE")
        {
         if(StringLen(standby.recovery_reason)>0)
            return(standby.recovery_reason);
         if(StringLen(standby.escalation_reason)>0)
            return(standby.escalation_reason);
         return(standby.reason);
        }
      if(source=="RISK_STOP" && StringLen(risk.risk_stop_reason)>0)
         return(risk.risk_stop_reason);
      return(risk.reason);
     }

   bool              IsStandbySource(const string source)
     {
      return(source=="STANDBY" || source=="ESCALATION" ||
             source=="DYNAMIC_ZONE");
     }

   bool              RecoveryTargetReached(const SStandbySnapshot &standby,
                                           const SRiskSnapshot &risk,
                                           const string core_state)
     {
      return(standby.state=="NORMAL" && risk.state=="SAFE" &&
             !risk.risk_stop_active && !risk.risk_stop_requested &&
             core_state=="NORMAL");
     }

   bool              RecoveryEscalated(const SCommonRecoveryObserverRuntime &runtime,
                                       const SStandbySnapshot &standby,
                                       const SRiskSnapshot &risk,
                                       const string core_state)
     {
      if(!runtime.lifecycle_open)
         return(false);
      if(runtime.lifecycle_source=="RISK_STOP")
         return(false);
      return(core_state=="RISK_STOP" || risk.risk_stop_active ||
             risk.risk_stop_requested || standby.risk_stop_requested ||
             (runtime.lifecycle_source=="STANDBY" &&
              standby.escalation_requested));
     }

   bool              SignificantChange(const SCommonRecoverySnapshot &left,
                                       const SCommonRecoverySnapshot &right)
     {
      return(left.recovery_sequence!=right.recovery_sequence ||
             left.recovery_required!=right.recovery_required ||
             left.recovery_active!=right.recovery_active ||
             left.recovery_state!=right.recovery_state ||
             left.recovery_source!=right.recovery_source ||
             left.recovery_condition_met!=right.recovery_condition_met ||
             left.recovery_allowed!=right.recovery_allowed ||
             left.entry_resume_allowed!=right.entry_resume_allowed ||
             left.confirmation_count!=right.confirmation_count ||
             left.required_confirmation_count!=right.required_confirmation_count ||
             left.cooldown_until!=right.cooldown_until ||
             left.hysteresis_active!=right.hysteresis_active ||
             left.hysteresis_state!=right.hysteresis_state ||
             left.standby_state!=right.standby_state ||
             left.standby_recovery_condition!=right.standby_recovery_condition ||
             left.standby_entry_allowed!=right.standby_entry_allowed ||
             left.risk_state!=right.risk_state ||
             left.risk_stop_active!=right.risk_stop_active ||
             left.risk_recovery_condition!=right.risk_recovery_condition ||
             left.risk_entry_allowed!=right.risk_entry_allowed ||
             left.state_manager_state!=right.state_manager_state ||
             left.execution_gate_allowed!=right.execution_gate_allowed ||
             left.recovery_completed!=right.recovery_completed ||
             left.recovery_escalated!=right.recovery_escalated ||
             left.recovery_failed!=right.recovery_failed ||
             left.is_valid!=right.is_valid || left.is_fresh!=right.is_fresh ||
             left.data_leak_safe!=right.data_leak_safe);
     }

   string            SafeText(const string value)
     {
      string result=value;
      StringReplace(result,";",",");
      return(result);
     }

   void              LogSnapshot(const string state_before,
                                 const SCommonRecoverySnapshot &snapshot)
     {
      CLogger::Info(StringFormat(
         "[COMMON_RECOVERY] AuditSequence=%I64d;RecoverySequence=%I64d;Time=%s;Symbol=%s;StateBefore=%s;StateAfter=%s;Source=%s;Required=%s;Active=%s;Reason=%s;ConditionMet=%s;RecoveryAllowed=%s;EntryResumeAllowed=%s;Completed=%s;Escalated=%s;Failed=%s;DataLeakSafe=%s;SnapshotValid=%s",
         snapshot.recovery_audit_sequence,snapshot.recovery_sequence,
         TimeToString(snapshot.recovery_evaluation_time,TIME_DATE|TIME_SECONDS),
         snapshot.symbol,state_before,snapshot.recovery_state,
         snapshot.recovery_source,(snapshot.recovery_required ? "true" : "false"),
         (snapshot.recovery_active ? "true" : "false"),
         SafeText(snapshot.recovery_reason),
         (snapshot.recovery_condition_met ? "true" : "false"),
         (snapshot.recovery_allowed ? "true" : "false"),
         (snapshot.entry_resume_allowed ? "true" : "false"),
         (snapshot.recovery_completed ? "true" : "false"),
         (snapshot.recovery_escalated ? "true" : "false"),
         (snapshot.recovery_failed ? "true" : "false"),
         (snapshot.data_leak_safe ? "true" : "false"),
         (snapshot.is_valid ? "true" : "false")));
      CLogger::Info(StringFormat(
         "[COMMON_RECOVERY_CONFIRMATION] AuditSequence=%I64d;RecoverySequence=%I64d;ConfirmationCount=%d;RequiredConfirmationCount=%d;ConfirmationComplete=%s;HysteresisActive=%s;HysteresisState=%s",
         snapshot.recovery_audit_sequence,snapshot.recovery_sequence,
         snapshot.confirmation_count,snapshot.required_confirmation_count,
         (snapshot.confirmation_complete ? "true" : "false"),
         (snapshot.hysteresis_active ? "true" : "false"),
         snapshot.hysteresis_state));
      CLogger::Info(StringFormat(
         "[COMMON_RECOVERY_TIMING] AuditSequence=%I64d;RecoverySequence=%I64d;RecoveryStartedAt=%s;LastRecoveryCheckAt=%s;CooldownStartedAtAvailable=%s;CooldownStartedAt=%s;CooldownUntil=%s;RecoveryCompletedAt=%s;RecoveryDuration=%I64d",
         snapshot.recovery_audit_sequence,snapshot.recovery_sequence,
         TimeToString(snapshot.recovery_started_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.last_recovery_check_at,TIME_DATE|TIME_SECONDS),
         (snapshot.cooldown_started_at_available ? "true" : "false"),
         TimeToString(snapshot.cooldown_started_at,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.cooldown_until,TIME_DATE|TIME_SECONDS),
         TimeToString(snapshot.recovery_completed_at,TIME_DATE|TIME_SECONDS),
         snapshot.recovery_duration_seconds));
      CLogger::Info(StringFormat(
         "[COMMON_RECOVERY_SOURCES] AuditSequence=%I64d;RecoverySequence=%I64d;StandbyState=%s;StandbyRecoveryCondition=%s;StandbyEntryAllowed=%s;StandbyUpdatedAt=%s;RiskState=%s;RiskStopActive=%s;RiskRecoveryCondition=%s;RiskEntryAllowed=%s;RiskUpdatedAt=%s;MarketState=%s;MarketStateAvailable=%s;MarketStateUpdatedAt=%s;StateManagerState=%s;StateManagerObservedAt=%s",
         snapshot.recovery_audit_sequence,snapshot.recovery_sequence,
         snapshot.standby_state,
         (snapshot.standby_recovery_condition ? "true" : "false"),
         (snapshot.standby_entry_allowed ? "true" : "false"),
         TimeToString(snapshot.standby_updated_at,TIME_DATE|TIME_SECONDS),
         snapshot.risk_state,(snapshot.risk_stop_active ? "true" : "false"),
         (snapshot.risk_recovery_condition ? "true" : "false"),
         (snapshot.risk_entry_allowed ? "true" : "false"),
         TimeToString(snapshot.risk_updated_at,TIME_DATE|TIME_SECONDS),
         snapshot.market_state,
         (snapshot.market_state_available ? "true" : "false"),
         TimeToString(snapshot.market_state_updated_at,TIME_DATE|TIME_SECONDS),
         snapshot.state_manager_state,
         TimeToString(snapshot.state_manager_observed_at,TIME_DATE|TIME_SECONDS)));
      CLogger::Info(StringFormat(
         "[COMMON_RECOVERY_ENTRY_RESUME] AuditSequence=%I64d;RecoverySequence=%I64d;StandbyEntryAllowed=%s;RiskEntryAllowed=%s;ExecutionGateAllowed=%s;RecoveryState=%s;StateManagerState=%s;EntrySnapshotAvailable=%s;EntryEvaluationSequence=%I64d;EntrySnapshotUpdatedAt=%s;EntryResumeAllowed=%s",
         snapshot.recovery_audit_sequence,snapshot.recovery_sequence,
         (snapshot.standby_entry_allowed ? "true" : "false"),
         (snapshot.risk_entry_allowed ? "true" : "false"),
         (snapshot.execution_gate_allowed ? "true" : "false"),
         snapshot.recovery_state,snapshot.state_manager_state,
         (snapshot.entry_snapshot_available ? "true" : "false"),
         snapshot.entry_evaluation_sequence,
         TimeToString(snapshot.entry_snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         (snapshot.entry_resume_allowed ? "true" : "false")));
     }

public:
                     CCommonRecoveryEngineAdapter(void)
     {
      m_snapshot_store=NULL;
      m_timeframe=PERIOD_CURRENT;
      ResetCounters();
     }

   void              ResetCounters(void)
     {
      m_next_recovery_sequence=0;
      m_next_audit_sequence=0;
      m_recovery_started_count=0;
      m_recovery_completed_count=0;
      m_recovery_failed_count=0;
      m_recovery_escalated_count=0;
      m_entry_resume_count=0;
      m_standby_source_count=0;
      m_risk_source_count=0;
      m_other_source_count=0;
      m_data_leak_count=0;
      m_invalid_count=0;
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

   bool              Observe(const SStandbySnapshot &standby,
                             const SRiskSnapshot &risk,
                             const bool entry_available,
                             const SEntrySnapshot &entry,
                             const string core_state,
                             const datetime evaluation_time,
                             SCommonRecoverySnapshot &snapshot,
                             bool &emitted)
     {
      emitted=false;
      const int index=FindRuntime(standby.symbol);
      if(index<0 || standby.symbol!=risk.symbol || evaluation_time<=0 ||
         m_snapshot_store==NULL)
         return(false);
      SCommonRecoveryObserverRuntime runtime=m_runtimes[index];
      ResetSnapshot(snapshot);
      snapshot.runtime_context_id.symbol=standby.symbol;
      snapshot.runtime_context_id.timeframe=m_timeframe;
      snapshot.symbol=standby.symbol;
      snapshot.timeframe=EnumToString(m_timeframe);
      snapshot.recovery_evaluation_time=evaluation_time;
      snapshot.updated_at=evaluation_time;
      snapshot.standby_snapshot_valid=standby.is_valid;
      snapshot.standby_snapshot_fresh=standby.is_fresh;
      snapshot.standby_state=standby.state;
      snapshot.standby_recovery_condition=standby.recovery_condition_met;
      snapshot.standby_entry_allowed=standby.are_new_entries_allowed;
      snapshot.standby_updated_at=standby.updated_at;
      snapshot.risk_snapshot_valid=risk.is_valid;
      snapshot.risk_snapshot_fresh=risk.is_fresh;
      snapshot.risk_state=risk.state;
      snapshot.risk_stop_active=risk.risk_stop_active;
      snapshot.risk_recovery_condition=risk.recovery_condition_met;
      snapshot.risk_entry_allowed=risk.are_new_entries_risk_approved;
      snapshot.risk_updated_at=risk.updated_at;
      snapshot.market_state=standby.market_state;
      snapshot.market_state_available=(standby.market_state_updated_at>0);
      snapshot.market_state_updated_at=standby.market_state_updated_at;
      snapshot.state_manager_state=core_state;
      snapshot.state_manager_observed_at=evaluation_time;
      snapshot.entry_snapshot_available=entry_available;
      if(entry_available)
        {
         snapshot.entry_context_id=snapshot.runtime_context_id;
         snapshot.entry_evaluation_sequence=entry.entry_evaluation_sequence;
         snapshot.entry_snapshot_updated_at=entry.updated_at;
         snapshot.execution_gate_allowed=entry.execution_gate_allowed;
        }

      snapshot.recovery_required=(standby.is_active || risk.state!="SAFE" ||
                                  risk.risk_stop_active || risk.risk_stop_requested ||
                                  (core_state!="NORMAL" && core_state!="INIT" &&
                                   core_state!="SHUTDOWN"));
      snapshot.recovery_condition_met=(standby.is_recovering &&
                                       standby.recovery_condition_met) ||
                                      risk.recovery_condition_met;

      const bool had_previous=runtime.has_previous;
      const string previous_core=(had_previous ?
         runtime.previous.state_manager_state : core_state);
      const bool core_recovery_edge=(had_previous &&
         previous_core!="NORMAL" && core_state=="NORMAL");
      const bool risk_stop_exit=(had_previous && previous_core=="RISK_STOP" &&
                                 core_state=="STANDBY");
      const bool start_signal=(!runtime.lifecycle_open &&
         ((snapshot.recovery_condition_met && snapshot.recovery_required) ||
          core_recovery_edge || risk_stop_exit));
      if(start_signal)
        {
         runtime.lifecycle_open=true;
         runtime.lifecycle_sequence=++m_next_recovery_sequence;
         runtime.lifecycle_started_at=(standby.is_recovering &&
            standby.recovery_started_at>0 ? standby.recovery_started_at :
            evaluation_time);
         runtime.lifecycle_source=(risk_stop_exit ? "RISK_STOP" :
            DetermineSource(standby,risk,(core_recovery_edge ? previous_core :
                                         core_state)));
         if(runtime.lifecycle_source=="NONE")
            runtime.lifecycle_source="SYSTEM_STATE";
         runtime.lifecycle_reason=DetermineReason(standby,risk,
                                                   runtime.lifecycle_source);
         m_recovery_started_count++;
         if(IsStandbySource(runtime.lifecycle_source))
            m_standby_source_count++;
         else if(runtime.lifecycle_source=="RISK_STOP" ||
                 runtime.lifecycle_source=="SYSTEM_STATE")
            m_risk_source_count++;
         else
            m_other_source_count++;
        }

      snapshot.recovery_active=runtime.lifecycle_open;
      snapshot.recovery_sequence=(runtime.lifecycle_open ?
                                  runtime.lifecycle_sequence : 0);
      snapshot.recovery_source=(runtime.lifecycle_open ?
                                runtime.lifecycle_source :
                                DetermineSource(standby,risk,core_state));
      snapshot.recovery_reason=(runtime.lifecycle_open ?
                                runtime.lifecycle_reason :
                                DetermineReason(standby,risk,
                                                snapshot.recovery_source));
      const bool standby_source=(runtime.lifecycle_open &&
                                 IsStandbySource(runtime.lifecycle_source));
      snapshot.confirmation_count=(standby_source ?
         standby.recovery_confirmation_count :
         risk.recovery_confirmation_count);
      snapshot.required_confirmation_count=(standby_source ?
         standby.required_confirmation_count :
         risk.required_confirmation_count);
      snapshot.confirmation_complete=
         (snapshot.confirmation_count>=snapshot.required_confirmation_count);
      snapshot.recovery_started_at=(runtime.lifecycle_open ?
                                    runtime.lifecycle_started_at : 0);
      snapshot.last_recovery_check_at=(standby_source ?
         standby.last_recovery_check_at : risk.updated_at);
      snapshot.cooldown_started_at_available=(standby_source &&
                                              standby.last_state_changed_at>0);
      snapshot.cooldown_started_at=(snapshot.cooldown_started_at_available ?
                                    standby.last_state_changed_at : 0);
      snapshot.cooldown_until=(standby_source ? standby.cooldown_until :
                               risk.cooldown_until);
      snapshot.hysteresis_active=(risk.recovery_condition_met &&
                                  (risk.recovery_confirmation_count>0 ||
                                   !risk.recovery_allowed));
      snapshot.hysteresis_state=risk.hysteresis_state;
      snapshot.recovery_allowed=(standby_source ?
         snapshot.confirmation_complete : risk.recovery_allowed);
      snapshot.entry_resume_allowed=(standby.are_new_entries_allowed &&
                                     risk.are_new_entries_risk_approved &&
                                     core_state=="NORMAL" && entry_available &&
                                     entry.execution_gate_allowed);

      if(runtime.lifecycle_open)
        {
         const bool completed=RecoveryTargetReached(standby,risk,core_state);
         const bool escalated=(!completed &&
            RecoveryEscalated(runtime,standby,risk,core_state));
         const bool failed=(!completed && !escalated &&
                            !snapshot.recovery_condition_met &&
                            !core_recovery_edge && !risk_stop_exit);
         if(completed || escalated || failed)
           {
            snapshot.recovery_active=false;
            snapshot.recovery_sequence=runtime.lifecycle_sequence;
            snapshot.recovery_completed=completed;
            snapshot.recovery_escalated=escalated;
            snapshot.recovery_failed=failed;
            snapshot.recovery_state=(completed ? "COMPLETED" :
                                     (escalated ? "ESCALATED" : "FAILED"));
            snapshot.recovery_allowed=completed;
            snapshot.recovery_completed_at=(completed ? evaluation_time : 0);
            snapshot.recovery_duration_seconds=MathMax(0,
               (long)(evaluation_time-runtime.lifecycle_started_at));
            snapshot.final_recovery_reason=(completed ?
               "Existing Standby, Risk, and StateManager recovery outcomes restored the observed target state." :
               (escalated ?
                "Existing Standby, Risk, or StateManager outcome escalated the observed recovery lifecycle." :
                "Existing recovery condition ended before the observed target state was restored."));
            snapshot.recovery_reason=snapshot.final_recovery_reason;
            if(completed)
               m_recovery_completed_count++;
            else if(escalated)
               m_recovery_escalated_count++;
            else
               m_recovery_failed_count++;
            runtime.lifecycle_open=false;
            runtime.lifecycle_sequence=0;
            runtime.lifecycle_started_at=0;
            runtime.lifecycle_source="NONE";
            runtime.lifecycle_reason="";
           }
        }

      if(snapshot.recovery_state!="COMPLETED" &&
         snapshot.recovery_state!="ESCALATED" &&
         snapshot.recovery_state!="FAILED")
        {
         if(snapshot.recovery_active)
           {
            if(snapshot.cooldown_until>evaluation_time &&
               !snapshot.recovery_allowed)
               snapshot.recovery_state="COOLDOWN";
            else if(snapshot.confirmation_count>0 &&
                    !snapshot.confirmation_complete)
               snapshot.recovery_state="CONFIRMING";
            else if(snapshot.recovery_allowed ||
                    snapshot.confirmation_complete)
               snapshot.recovery_state="READY";
            else
               snapshot.recovery_state="WAITING";
           }
         else
            snapshot.recovery_state=(snapshot.recovery_required ?
                                     "REQUIRED" : "NONE");
        }

      const bool entry_resumed=(snapshot.entry_resume_allowed &&
         (!had_previous || !runtime.previous.entry_resume_allowed));
      if(entry_resumed)
         m_entry_resume_count++;

      snapshot.recovery_audit_sequence=m_next_audit_sequence+1;
      CCommonRecoverySnapshotContract contract;
      contract.Finalize(snapshot);
      const bool changed=(!had_previous ||
                          SignificantChange(runtime.previous,snapshot));
      if(!changed)
        {
         m_runtimes[index]=runtime;
         return(true);
        }

      m_next_audit_sequence++;
      snapshot.recovery_audit_sequence=m_next_audit_sequence;
      contract.Finalize(snapshot);
      if(!snapshot.data_leak_safe)
         m_data_leak_count++;
      if(!snapshot.is_valid)
         m_invalid_count++;
      if(!m_snapshot_store.SetRecoverySnapshot(snapshot.symbol,m_timeframe,snapshot))
         return(false);
      LogSnapshot((had_previous ? runtime.previous.recovery_state : "UNAVAILABLE"),
                  snapshot);
      runtime.previous=snapshot;
      runtime.has_previous=true;
      m_runtimes[index]=runtime;
      emitted=true;
      return(true);
     }

   int               OpenLifecycleCount(void)
     {
      int count=0;
      for(int index=0;index<ArraySize(m_runtimes);index++)
         if(m_runtimes[index].lifecycle_open)
            count++;
      return(count);
     }

   void              LogSummary(const string context_name="")
     {
      const string prefix=(StringLen(context_name)==0 ?
         "[COMMON_RECOVERY_SUMMARY] " :
         "[CONTEXT_RECOVERY_SUMMARY] Context="+context_name+";");
      CLogger::Info(prefix+StringFormat(
         "RecoveryAuditCount=%I64d;RecoveryStartedCount=%I64d;RecoveryCompletedCount=%I64d;RecoveryFailedCount=%I64d;RecoveryEscalatedCount=%I64d;OpenLifecycleCount=%d;EntryResumeCount=%I64d;StandbySourceCount=%I64d;RiskSourceCount=%I64d;OtherSourceCount=%I64d;DataLeakCount=%I64d;InvalidCount=%I64d;CurrentSnapshotCount=%d;BoundedHistoryCount=%d;HistoryLimit=%d;GlobalKeys=0;PerSymbolKeys=0",
         m_next_audit_sequence,m_recovery_started_count,
         m_recovery_completed_count,m_recovery_failed_count,
         m_recovery_escalated_count,OpenLifecycleCount(),m_entry_resume_count,
         m_standby_source_count,m_risk_source_count,m_other_source_count,
         m_data_leak_count,m_invalid_count,
         (m_snapshot_store==NULL ? 0 :
          m_snapshot_store.RecoverySnapshotCount()),
         (m_snapshot_store==NULL ? 0 :
          m_snapshot_store.RecoveryHistoryCount()),
         FENX_COMMON_RECOVERY_HISTORY_LIMIT));
     }
  };

#endif // FENX_COMMON_RECOVERY_ENGINE_ADAPTER_MQH
