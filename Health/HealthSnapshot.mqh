//+------------------------------------------------------------------+
//|                                  Health/HealthSnapshot.mqh      |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_HEALTH_SNAPSHOT_MQH
#define FENX_COMMON_HEALTH_SNAPSHOT_MQH

#include "../Common/Constants.mqh"
#include "../Common/Types.mqh"

//--- Passive system-health classification. These values are diagnostic only;
//--- no trading, permission, StateManager, or recovery consumer reads them.
enum ENUM_FENX_COMMON_HEALTH_STATE
  {
   FENX_COMMON_HEALTH_UNKNOWN = 0,
   FENX_COMMON_HEALTH_HEALTHY,
   FENX_COMMON_HEALTH_DEGRADED,
   FENX_COMMON_HEALTH_CRITICAL
  };

//--- Lightweight metadata read from one existing Common Engine snapshot.
//--- LastSeenAt is observation time, while UpdatedAt remains the source time.
struct SCommonEngineHealthStatus
  {
   string   engine_name;
   bool     available;
   bool     valid;
   bool     fresh;
   datetime updated_at;
   string   snapshot_version;
   datetime last_seen_at;
   string   invalid_reason;
  };

//--- Read-only measurement assembled by CommonSnapshotStore and HealthEngine.
//--- The raw contract fields are existing outcomes; they are never recomputed
//--- into a trading decision. Explicit error counts support isolated harness
//--- injection and are zero in production.
struct SCommonHealthMeasurement
  {
   string   symbol;
   string   timeframe;

   SCommonEngineHealthStatus environment;
   SCommonEngineHealthStatus confidence;
   SCommonEngineHealthStatus decision_score;
   SCommonEngineHealthStatus volatility;
   SCommonEngineHealthStatus range;
   SCommonEngineHealthStatus trend;
   SCommonEngineHealthStatus market_state;
   SCommonEngineHealthStatus standby;
   SCommonEngineHealthStatus risk;
   SCommonEngineHealthStatus entry;
   SCommonEngineHealthStatus exit_status;
   SCommonEngineHealthStatus execution;
   SCommonEngineHealthStatus recovery;

   int      snapshot_current_count;
   int      entry_history_count;
   int      exit_history_count;
   int      execution_history_count;
   int      recovery_history_count;
   int      health_history_count;
   bool     snapshot_store_available;
   bool     snapshot_identity_consistent;
   bool     snapshot_history_bounded;

   int      databus_usage;
   int      databus_capacity;
   int      databus_remaining;
   bool     databus_overflow_detected;
   bool     databus_preflight_passed;

   string   state_manager_state;
   bool     state_manager_state_known;

   long     entry_sequence;
   bool     entry_allowed;
   bool     entry_final_order_ready;
   bool     entry_order_submitted;
   bool     entry_order_succeeded;
   bool     entry_data_leak_safe;

   long     exit_sequence;
   ulong    exit_lifecycle_id;
   bool     exit_position_closed;
   bool     exit_close_requested;
   bool     exit_close_accepted;
   bool     exit_close_succeeded;
   bool     exit_close_failed;
   int      exit_retry_count;
   string   exit_reason;
   string   exit_final_close_reason;
   bool     exit_data_leak_safe;

   long     execution_sequence;
   string   execution_request_type;
   bool     execution_order_submitted;
   bool     execution_order_accepted;
   bool     execution_order_rejected;
   int      execution_retry_count;
   long     execution_entry_sequence;
   long     execution_exit_sequence;
   bool     execution_position_opened;
   bool     execution_position_closed;
   bool     execution_data_leak_safe;

   long     recovery_audit_sequence;
   long     recovery_sequence;
   bool     recovery_active;
   bool     recovery_completed;
   bool     recovery_failed;
   bool     recovery_escalated;
   bool     recovery_entry_resume_allowed;
   bool     recovery_entry_snapshot_available;
   long     recovery_entry_sequence;
   bool     recovery_execution_gate_allowed;
   bool     recovery_data_leak_safe;

   int      runtime_error_count;
   bool     runtime_error_count_available;
   int      sequence_error_count;
   int      lifecycle_error_count;
   int      state_transition_error_count;
   bool     state_transition_error_count_available;
   bool     data_leak_detected;
  };

//--- Typed output stored in the Hybrid snapshot store. It reports health but
//--- intentionally exposes no permission, block, repair, or transition field.
struct SCommonHealthSnapshot
  {
   //--- Identity and audit sequence
   SRuntimeContextId runtime_context_id;
   string   symbol;
   string   timeframe;
   string   snapshot_version;
   datetime updated_at;
   datetime health_evaluation_time;
   long     health_evaluation_sequence;
   bool     is_valid;
   bool     is_fresh;
   bool     data_leak_safe;
   string   invalid_reason;

   //--- Overall diagnostic state
   ENUM_FENX_COMMON_HEALTH_STATE health_state;
   double   health_score;
   string   health_reason;
   bool     is_healthy;
   bool     is_degraded;
   bool     is_critical;

   //--- Existing Common Engine health
   SCommonEngineHealthStatus environment;
   SCommonEngineHealthStatus confidence;
   SCommonEngineHealthStatus decision_score;
   SCommonEngineHealthStatus volatility;
   SCommonEngineHealthStatus range;
   SCommonEngineHealthStatus trend;
   SCommonEngineHealthStatus market_state;
   SCommonEngineHealthStatus standby;
   SCommonEngineHealthStatus risk;
   SCommonEngineHealthStatus entry;
   SCommonEngineHealthStatus exit_status;
   SCommonEngineHealthStatus execution;
   SCommonEngineHealthStatus recovery;

   //--- Infrastructure health
   int      databus_usage;
   int      databus_capacity;
   int      databus_remaining;
   double   databus_usage_percent;
   bool     databus_overflow_detected;
   bool     databus_preflight_passed;
   bool     snapshot_store_healthy;
   int      snapshot_current_count;
   int      health_history_count;
   bool     state_manager_healthy;
   string   state_manager_state;

   //--- Formal Common Contract health
   bool     entry_contract_healthy;
   bool     exit_contract_healthy;
   bool     execution_contract_healthy;
   bool     recovery_contract_healthy;

   //--- Existing execution-result observations
   long     order_requested_count;
   long     order_accepted_count;
   long     order_rejected_count;
   long     close_requested_count;
   long     close_accepted_count;
   long     close_failed_count;
   long     retry_count;
   long     runtime_error_count;
   bool     runtime_error_count_available;

   //--- Integrity observations
   long     sequence_error_count;
   long     lifecycle_error_count;
   long     state_transition_error_count;
   bool     state_transition_error_count_available;
   bool     data_leak_detected;
   int      expected_unavailable_count;
   int      expected_invalid_count;
   int      expected_stale_count;
   int      contract_violation_count;
   int      infrastructure_failure_count;

   //--- Evaluation-state metadata
   long     healthy_count;
   long     degraded_count;
   long     critical_count;
   datetime last_healthy_at;
   datetime last_degraded_at;
   datetime last_critical_at;
  };

//--- Stable names are used in telemetry and reports only.
string FenxCommonHealthStateName(const ENUM_FENX_COMMON_HEALTH_STATE state)
  {
   switch(state)
     {
      case FENX_COMMON_HEALTH_UNKNOWN:  return("UNKNOWN");
      case FENX_COMMON_HEALTH_HEALTHY:  return("HEALTHY");
      case FENX_COMMON_HEALTH_DEGRADED: return("DEGRADED");
      case FENX_COMMON_HEALTH_CRITICAL: return("CRITICAL");
     }
   return("UNKNOWN");
  }

//--- Resets one source status without inventing availability or timestamps.
void FenxResetCommonEngineHealthStatus(SCommonEngineHealthStatus &status,
                                       const string engine_name)
  {
   status.engine_name=engine_name;
   status.available=false;
   status.valid=false;
   status.fresh=false;
   status.updated_at=0;
   status.snapshot_version="";
   status.last_seen_at=0;
   status.invalid_reason="";
  }

//--- Provides a deterministic empty measurement for production and harnesses.
void FenxResetCommonHealthMeasurement(SCommonHealthMeasurement &measurement)
  {
   measurement.symbol="";
   measurement.timeframe="";
   FenxResetCommonEngineHealthStatus(measurement.environment,"Environment");
   FenxResetCommonEngineHealthStatus(measurement.confidence,"Confidence");
   FenxResetCommonEngineHealthStatus(measurement.decision_score,"DecisionScore");
   FenxResetCommonEngineHealthStatus(measurement.volatility,"Volatility");
   FenxResetCommonEngineHealthStatus(measurement.range,"Range");
   FenxResetCommonEngineHealthStatus(measurement.trend,"Trend");
   FenxResetCommonEngineHealthStatus(measurement.market_state,"MarketState");
   FenxResetCommonEngineHealthStatus(measurement.standby,"Standby");
   FenxResetCommonEngineHealthStatus(measurement.risk,"Risk");
   FenxResetCommonEngineHealthStatus(measurement.entry,"Entry");
   FenxResetCommonEngineHealthStatus(measurement.exit_status,"Exit");
   FenxResetCommonEngineHealthStatus(measurement.execution,"Execution");
   FenxResetCommonEngineHealthStatus(measurement.recovery,"Recovery");
   measurement.snapshot_current_count=0;
   measurement.entry_history_count=0;
   measurement.exit_history_count=0;
   measurement.execution_history_count=0;
   measurement.recovery_history_count=0;
   measurement.health_history_count=0;
   measurement.snapshot_store_available=false;
   measurement.snapshot_identity_consistent=false;
   measurement.snapshot_history_bounded=false;
   measurement.databus_usage=0;
   measurement.databus_capacity=0;
   measurement.databus_remaining=0;
   measurement.databus_overflow_detected=false;
   measurement.databus_preflight_passed=false;
   measurement.state_manager_state="UNKNOWN";
   measurement.state_manager_state_known=false;
   measurement.entry_sequence=0;
   measurement.entry_allowed=false;
   measurement.entry_final_order_ready=false;
   measurement.entry_order_submitted=false;
   measurement.entry_order_succeeded=false;
   measurement.entry_data_leak_safe=true;
   measurement.exit_sequence=0;
   measurement.exit_lifecycle_id=0;
   measurement.exit_position_closed=false;
   measurement.exit_close_requested=false;
   measurement.exit_close_accepted=false;
   measurement.exit_close_succeeded=false;
   measurement.exit_close_failed=false;
   measurement.exit_retry_count=0;
   measurement.exit_reason="";
   measurement.exit_final_close_reason="";
   measurement.exit_data_leak_safe=true;
   measurement.execution_sequence=0;
   measurement.execution_request_type="";
   measurement.execution_order_submitted=false;
   measurement.execution_order_accepted=false;
   measurement.execution_order_rejected=false;
   measurement.execution_retry_count=0;
   measurement.execution_entry_sequence=0;
   measurement.execution_exit_sequence=0;
   measurement.execution_position_opened=false;
   measurement.execution_position_closed=false;
   measurement.execution_data_leak_safe=true;
   measurement.recovery_audit_sequence=0;
   measurement.recovery_sequence=0;
   measurement.recovery_active=false;
   measurement.recovery_completed=false;
   measurement.recovery_failed=false;
   measurement.recovery_escalated=false;
   measurement.recovery_entry_resume_allowed=false;
   measurement.recovery_entry_snapshot_available=false;
   measurement.recovery_entry_sequence=0;
   measurement.recovery_execution_gate_allowed=false;
   measurement.recovery_data_leak_safe=true;
   measurement.runtime_error_count=0;
   measurement.runtime_error_count_available=false;
   measurement.sequence_error_count=0;
   measurement.lifecycle_error_count=0;
   measurement.state_transition_error_count=0;
   measurement.state_transition_error_count_available=false;
   measurement.data_leak_detected=false;
  }

//--- Structural contract for a Health snapshot. Classification stays inside
//--- the adapter; this validator never controls or re-evaluates trading.
class CCommonHealthSnapshotContract
  {
public:
   bool              Finalize(SCommonHealthSnapshot &snapshot)
     {
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="";
      if(StringLen(snapshot.symbol)==0 || StringLen(snapshot.timeframe)==0 ||
         !IsValidRuntimeContextId(snapshot.runtime_context_id) ||
         snapshot.runtime_context_id.symbol!=snapshot.symbol ||
         EnumToString(snapshot.runtime_context_id.timeframe)!=snapshot.timeframe ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0 ||
         snapshot.health_evaluation_time<=0 ||
         snapshot.updated_at<snapshot.health_evaluation_time ||
         snapshot.health_evaluation_sequence<=0)
        {
         snapshot.invalid_reason="Health snapshot identity is invalid.";
         return(false);
        }
      if(!MathIsValidNumber(snapshot.health_score) ||
         snapshot.health_score<0.0 || snapshot.health_score>100.0 ||
         StringLen(snapshot.health_reason)==0 ||
         ((snapshot.is_healthy ? 1 : 0)+
          (snapshot.is_degraded ? 1 : 0)+
          (snapshot.is_critical ? 1 : 0)>1))
        {
         snapshot.invalid_reason="Health classification is inconsistent.";
         return(false);
        }
      if(snapshot.databus_usage<0 || snapshot.databus_capacity<=0 ||
         snapshot.databus_remaining<0 ||
         snapshot.databus_usage>snapshot.databus_capacity ||
         !MathIsValidNumber(snapshot.databus_usage_percent) ||
         snapshot.databus_usage_percent<0.0 ||
         snapshot.databus_usage_percent>100.0 ||
         snapshot.snapshot_current_count<0 || snapshot.health_history_count<0 ||
         snapshot.order_requested_count<0 || snapshot.order_accepted_count<0 ||
         snapshot.order_rejected_count<0 || snapshot.close_requested_count<0 ||
         snapshot.close_accepted_count<0 || snapshot.close_failed_count<0 ||
         snapshot.retry_count<0 || snapshot.runtime_error_count<0 ||
         snapshot.sequence_error_count<0 || snapshot.lifecycle_error_count<0 ||
         snapshot.state_transition_error_count<0)
        {
         snapshot.invalid_reason="Health infrastructure or counter values are invalid.";
         return(false);
        }
      snapshot.is_fresh=true;
      snapshot.is_valid=true;
      return(true);
     }
  };

#endif // FENX_COMMON_HEALTH_SNAPSHOT_MQH
