//+------------------------------------------------------------------+
//|                              Recovery/RecoverySnapshot.mqh      |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_RECOVERY_SNAPSHOT_MQH
#define FENX_COMMON_RECOVERY_SNAPSHOT_MQH

#include "../Common/Constants.mqh"
#include "../Common/Types.mqh"

//--- Passive, typed view of recovery facts already decided by StandbyEngine,
//--- RiskEngine, and StateManager. No field in this structure grants trading
//--- permission or requests a state transition.
struct SCommonRecoverySnapshot
  {
   //--- Identity
   SRuntimeContextId runtime_context_id;
   SRuntimeContextId entry_context_id;
   string   symbol;
   string   timeframe;
   string   snapshot_version;
   datetime updated_at;
   datetime recovery_evaluation_time;
   long     recovery_sequence;
   long     recovery_audit_sequence;

   //--- Validity and source fidelity
   bool     is_valid;
   bool     is_fresh;
   bool     data_leak_safe;
   string   invalid_reason;

   //--- Unified observation of the existing recovery state
   bool     recovery_required;
   bool     recovery_active;
   string   recovery_state;
   string   recovery_source;
   string   recovery_reason;

   //--- Existing condition and permission outcomes
   bool     recovery_condition_met;
   bool     recovery_allowed;
   bool     entry_resume_allowed;

   //--- Existing confirmation observations
   int      confirmation_count;
   int      required_confirmation_count;
   bool     confirmation_complete;

   //--- Existing or directly observed timing facts
   datetime recovery_started_at;
   datetime last_recovery_check_at;
   datetime cooldown_started_at;
   bool     cooldown_started_at_available;
   datetime cooldown_until;
   datetime recovery_completed_at;
   long     recovery_duration_seconds;

   //--- Existing Risk hysteresis observations
   bool     hysteresis_active;
   string   hysteresis_state;

   //--- Standby source
   bool     standby_snapshot_valid;
   bool     standby_snapshot_fresh;
   string   standby_state;
   bool     standby_recovery_condition;
   bool     standby_entry_allowed;
   datetime standby_updated_at;

   //--- Risk source
   bool     risk_snapshot_valid;
   bool     risk_snapshot_fresh;
   string   risk_state;
   bool     risk_stop_active;
   bool     risk_recovery_condition;
   bool     risk_entry_allowed;
   datetime risk_updated_at;

   //--- Market State and StateManager observations
   string   market_state;
   bool     market_state_available;
   datetime market_state_updated_at;
   string   state_manager_state;
   datetime state_manager_observed_at;

   //--- Entry-resume audit linkage. A missing Entry evaluation stays explicit;
   //--- the adapter never fabricates a sequence or ExecutionGate result.
   bool     entry_snapshot_available;
   long     entry_evaluation_sequence;
   datetime entry_snapshot_updated_at;
   bool     execution_gate_allowed;

   //--- Lifecycle outcome
   bool     recovery_completed;
   bool     recovery_escalated;
   bool     recovery_failed;
   string   final_recovery_reason;
  };

//--- Validates only identity, source chronology, and internal consistency of
//--- the passive observation. It never recalculates a Standby/Risk predicate.
class CCommonRecoverySnapshotContract
  {
private:
   bool              IsKnownRecoveryState(const string state)
     {
      return(state=="NONE" || state=="REQUIRED" || state=="WAITING" ||
             state=="CONFIRMING" || state=="COOLDOWN" || state=="READY" ||
             state=="COMPLETED" || state=="ESCALATED" || state=="FAILED");
     }

   bool              IsKnownRecoverySource(const string source)
     {
      return(source=="NONE" || source=="STANDBY" || source=="RISK_STOP" ||
             source=="ESCALATION" || source=="DYNAMIC_ZONE" ||
             source=="SYSTEM_STATE");
     }

   bool              IsKnownCoreState(const string state)
     {
      return(state=="INIT" || state=="NORMAL" || state=="STANDBY" ||
             state=="DYNAMIC_ZONE" || state=="RISK_STOP" ||
             state=="SHUTDOWN");
     }

   bool              TimestampSafe(const datetime source_time,
                                   const datetime evaluation_time)
     {
      return(source_time>0 && evaluation_time>0 &&
             source_time<=evaluation_time);
     }

public:
   bool              Finalize(SCommonRecoverySnapshot &snapshot)
     {
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.data_leak_safe=false;
      snapshot.invalid_reason="";

      if(StringLen(snapshot.symbol)==0 || StringLen(snapshot.timeframe)==0 ||
         !IsValidRuntimeContextId(snapshot.runtime_context_id) ||
         snapshot.runtime_context_id.symbol!=snapshot.symbol ||
         EnumToString(snapshot.runtime_context_id.timeframe)!=snapshot.timeframe ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0 ||
         snapshot.recovery_evaluation_time<=0 ||
         snapshot.updated_at<snapshot.recovery_evaluation_time ||
         snapshot.recovery_audit_sequence<=0)
        {
         snapshot.invalid_reason="Recovery snapshot identity is invalid.";
         return(false);
        }
      if(!IsKnownRecoveryState(snapshot.recovery_state) ||
         !IsKnownRecoverySource(snapshot.recovery_source) ||
         !IsKnownCoreState(snapshot.state_manager_state))
        {
         snapshot.invalid_reason="Recovery state or source is invalid.";
         return(false);
        }
      if(!TimestampSafe(snapshot.standby_updated_at,
                        snapshot.recovery_evaluation_time) ||
         !TimestampSafe(snapshot.risk_updated_at,
                        snapshot.recovery_evaluation_time) ||
         !TimestampSafe(snapshot.state_manager_observed_at,
                        snapshot.recovery_evaluation_time) ||
         (snapshot.market_state_available &&
          !TimestampSafe(snapshot.market_state_updated_at,
                         snapshot.recovery_evaluation_time)) ||
         (snapshot.entry_snapshot_available &&
          !TimestampSafe(snapshot.entry_snapshot_updated_at,
                         snapshot.recovery_evaluation_time)))
        {
         snapshot.invalid_reason="Recovery source is future-dated or unavailable.";
         return(false);
        }
      snapshot.data_leak_safe=true;
      snapshot.is_fresh=(snapshot.standby_snapshot_fresh &&
                         snapshot.risk_snapshot_fresh);
      if(!snapshot.is_fresh)
        {
         snapshot.invalid_reason="Recovery source is stale.";
         return(false);
        }
      if(!snapshot.standby_snapshot_valid || !snapshot.risk_snapshot_valid)
        {
         snapshot.invalid_reason="Recovery source snapshot is invalid.";
         return(false);
        }
      if(snapshot.confirmation_count<0 ||
         snapshot.required_confirmation_count<1 ||
         snapshot.confirmation_count>snapshot.required_confirmation_count ||
         snapshot.confirmation_complete!=
            (snapshot.confirmation_count>=snapshot.required_confirmation_count))
        {
         snapshot.invalid_reason="Recovery confirmation integrity is invalid.";
         return(false);
        }
      if(snapshot.recovery_duration_seconds<0 ||
         (snapshot.cooldown_started_at_available &&
          snapshot.cooldown_started_at<=0) ||
         (snapshot.cooldown_until>0 && snapshot.cooldown_started_at_available &&
          snapshot.cooldown_until<snapshot.cooldown_started_at) ||
         (snapshot.recovery_completed && snapshot.recovery_completed_at<=0))
        {
         snapshot.invalid_reason="Recovery timing integrity is invalid.";
         return(false);
        }
      if(snapshot.entry_snapshot_available &&
         (!IsValidRuntimeContextId(snapshot.entry_context_id) ||
          !RuntimeContextEquals(snapshot.entry_context_id,
                                snapshot.runtime_context_id) ||
          snapshot.entry_evaluation_sequence<=0 ||
          snapshot.entry_snapshot_updated_at<=0))
        {
         snapshot.invalid_reason="Recovery Entry linkage is invalid.";
         return(false);
        }
      if(!snapshot.entry_snapshot_available &&
         (IsValidRuntimeContextId(snapshot.entry_context_id) ||
          snapshot.entry_evaluation_sequence!=0 ||
          snapshot.entry_snapshot_updated_at!=0 ||
          snapshot.execution_gate_allowed))
        {
         snapshot.invalid_reason="Unavailable Recovery Entry linkage was inferred.";
         return(false);
        }

      const bool terminal=(snapshot.recovery_completed ||
                           snapshot.recovery_escalated ||
                           snapshot.recovery_failed);
      if((snapshot.recovery_completed &&
          snapshot.recovery_state!="COMPLETED") ||
         (snapshot.recovery_escalated &&
          snapshot.recovery_state!="ESCALATED") ||
         (snapshot.recovery_failed && snapshot.recovery_state!="FAILED") ||
         ((snapshot.recovery_completed ? 1 : 0)+
          (snapshot.recovery_escalated ? 1 : 0)+
          (snapshot.recovery_failed ? 1 : 0)>1) ||
         ((snapshot.recovery_active || terminal) &&
          snapshot.recovery_sequence<=0) ||
         (!snapshot.recovery_active && !terminal &&
          snapshot.recovery_sequence!=0))
        {
         snapshot.invalid_reason="Recovery lifecycle outcome is inconsistent.";
         return(false);
        }
      if(snapshot.recovery_active && snapshot.recovery_started_at<=0)
        {
         snapshot.invalid_reason="Active Recovery lifecycle has no observed start.";
         return(false);
        }
      if(snapshot.recovery_state=="NONE" && snapshot.recovery_required)
        {
         snapshot.invalid_reason="Recovery requirement mapping is inconsistent.";
         return(false);
        }

      snapshot.is_valid=true;
      return(true);
     }
  };

#endif // FENX_COMMON_RECOVERY_SNAPSHOT_MQH
