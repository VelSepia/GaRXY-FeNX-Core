//+------------------------------------------------------------------+
//|                                      Risk/RiskSnapshot.mqh      |
//+------------------------------------------------------------------+
#ifndef FENX_RISK_SNAPSHOT_MQH
#define FENX_RISK_SNAPSHOT_MQH

#include "../Common/Constants.mqh"

//--- Typed representation of the existing CRiskEngine result. The legacy
//--- fields remain first and unchanged so every Risk DataBus publisher and
//--- consumer keeps the established contract.
struct SRiskSnapshot
  {
   //--- Existing per-symbol Risk output
   string   symbol;
   string   state;
   string   action;
   bool     is_risk_approved;
   bool     are_new_entries_risk_approved;
   double   allocation_multiplier;
   double   score;
   double   confidence;
   string   reason;
   bool     preserve_existing_positions;
   bool     escalation_required;
   bool     data_valid;
   datetime updated_at;

   //--- Common snapshot identity and validity
   string   timeframe;
   string   snapshot_version;
   bool     is_valid;
   bool     is_fresh;
   string   invalid_reason;

   //--- Existing system and symbol scope decisions
   string   system_risk_state;
   string   symbol_risk_state;
   bool     system_entry_allowed;
   bool     symbol_entry_allowed;

   //--- Existing Risk Stop request and observed Core state
   bool     risk_stop_requested;
   bool     risk_stop_active;
   string   risk_stop_reason;
   datetime risk_stop_started_at;

   //--- Existing hysteresis observations. RecoveryStartedAt is deliberately
   //--- unavailable because the legacy runtime stores a count but no start.
   bool     recovery_allowed;
   bool     recovery_condition_met;
   int      recovery_confirmation_count;
   int      required_confirmation_count;
   datetime recovery_started_at;
   bool     recovery_started_at_available;
   datetime cooldown_until;
   string   hysteresis_state;

   //--- Existing-source metadata copied without adding a Risk predicate
   string   standby_state;
   bool     standby_entry_allowed;
   string   market_state;
   string   strategy;
   string   allocation_state;
   datetime source_updated_at;
   string   state_manager_state;
  };

//--- Validates typed identity and the already-decided Risk result. It never
//--- recalculates score, confidence, permission, multiplier, state, action,
//--- Risk Stop, recovery, cooldown, or hysteresis.
class CRiskSnapshotContract
  {
private:
   bool              IsKnownRiskState(const string state)
     {
      return(state=="SAFE" || state=="CAUTION" || state=="REDUCED" ||
             state=="SUSPENDED" || state=="RISK_STOP_REQUIRED");
     }

   bool              IsKnownSystemState(const string state)
     {
      return(state=="SYSTEM_SAFE" || state=="SYSTEM_CAUTION" ||
             state=="SYSTEM_REDUCED" || state=="SYSTEM_SUSPENDED" ||
             state=="SYSTEM_RISK_STOP_REQUIRED");
     }

   bool              IsKnownAction(const string action)
     {
      return(action=="ALLOW" || action=="ALLOW_REDUCED" ||
             action=="BLOCK_NEW_ENTRIES" ||
             action=="ESCALATE_DYNAMIC_ZONE" ||
             action=="REQUEST_RISK_STOP");
     }

   bool              IsKnownCoreState(const string state)
     {
      return(state=="INIT" || state=="NORMAL" || state=="STANDBY" ||
             state=="DYNAMIC_ZONE" || state=="RISK_STOP" ||
             state=="SHUTDOWN");
     }

public:
   bool              Finalize(SRiskSnapshot &snapshot,
                              const datetime evaluation_time,
                              const int freshness_limit_seconds)
     {
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="";

      if(StringLen(snapshot.symbol)==0 || StringLen(snapshot.timeframe)==0 ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0)
        {
         snapshot.invalid_reason="Risk snapshot identity is invalid.";
         return(false);
        }
      if(snapshot.source_updated_at<=0 || evaluation_time<=0 ||
         freshness_limit_seconds<=0)
        {
         snapshot.invalid_reason="Risk source timestamp is invalid.";
         return(false);
        }

      const long age_seconds=(long)(evaluation_time-snapshot.source_updated_at);
      snapshot.is_fresh=(age_seconds>=0 && age_seconds<=freshness_limit_seconds);
      if(!snapshot.is_fresh)
        {
         snapshot.invalid_reason=(age_seconds<0 ?
                                  "Risk source is future-dated." :
                                  "Risk source is stale.");
         return(false);
        }
      if(!snapshot.data_valid)
        {
         snapshot.invalid_reason="Risk source is unavailable or invalid.";
         return(false);
        }
      if(!IsKnownRiskState(snapshot.state) ||
         snapshot.symbol_risk_state!=snapshot.state ||
         !IsKnownSystemState(snapshot.system_risk_state) ||
         !IsKnownAction(snapshot.action) ||
         !IsKnownCoreState(snapshot.state_manager_state))
        {
         snapshot.invalid_reason="Risk state or action integrity is invalid.";
         return(false);
        }
      if(!MathIsValidNumber(snapshot.allocation_multiplier) ||
         !MathIsValidNumber(snapshot.score) ||
         !MathIsValidNumber(snapshot.confidence) ||
         snapshot.allocation_multiplier<0.0 ||
         snapshot.allocation_multiplier>1.0 || snapshot.score<0.0 ||
         snapshot.score>100.0 || snapshot.confidence<0.0 ||
         snapshot.confidence>100.0)
        {
         snapshot.invalid_reason="Risk numeric integrity is invalid.";
         return(false);
        }

      const bool approved=(snapshot.state=="SAFE" || snapshot.state=="CAUTION" ||
                           snapshot.state=="REDUCED");
      const bool action_matches=
         ((snapshot.state!="RISK_STOP_REQUIRED" &&
           snapshot.escalation_required &&
           snapshot.action=="ESCALATE_DYNAMIC_ZONE") ||
          (snapshot.state=="SAFE" && snapshot.action=="ALLOW") ||
          ((snapshot.state=="CAUTION" || snapshot.state=="REDUCED") &&
           snapshot.action=="ALLOW_REDUCED") ||
          (snapshot.state=="SUSPENDED" &&
           (snapshot.action=="BLOCK_NEW_ENTRIES" ||
            snapshot.action=="ESCALATE_DYNAMIC_ZONE")) ||
          (snapshot.state=="RISK_STOP_REQUIRED" &&
           snapshot.action=="REQUEST_RISK_STOP"));
      if(snapshot.is_risk_approved!=approved ||
         !action_matches ||
         snapshot.symbol_entry_allowed!=
            snapshot.are_new_entries_risk_approved ||
         (snapshot.are_new_entries_risk_approved &&
          (!snapshot.is_risk_approved || !snapshot.standby_entry_allowed)) ||
         (snapshot.state=="SAFE" && snapshot.allocation_multiplier!=1.0) ||
         ((snapshot.state=="SUSPENDED" ||
           snapshot.state=="RISK_STOP_REQUIRED") &&
          snapshot.allocation_multiplier!=0.0) ||
         ((snapshot.state=="CAUTION" || snapshot.state=="REDUCED") &&
          (snapshot.allocation_multiplier<=0.0 ||
           snapshot.allocation_multiplier>=1.0)) ||
         !snapshot.preserve_existing_positions)
        {
         snapshot.invalid_reason="Risk permission or multiplier mapping is invalid.";
         return(false);
        }

      if(snapshot.risk_stop_requested!=
            (snapshot.state=="RISK_STOP_REQUIRED" ||
             snapshot.action=="REQUEST_RISK_STOP") ||
         snapshot.risk_stop_active!=
            (snapshot.state_manager_state=="RISK_STOP") ||
         (snapshot.risk_stop_requested &&
          StringLen(snapshot.risk_stop_reason)==0) ||
         snapshot.recovery_confirmation_count<0 ||
         snapshot.recovery_confirmation_count>
            snapshot.required_confirmation_count ||
         snapshot.required_confirmation_count<1 ||
         snapshot.hysteresis_state!=snapshot.state ||
         snapshot.recovery_started_at_available ||
         snapshot.recovery_started_at!=0 ||
         (snapshot.cooldown_until>0 && snapshot.risk_stop_started_at>0 &&
          snapshot.cooldown_until<snapshot.risk_stop_started_at))
        {
         snapshot.invalid_reason="Risk Stop or hysteresis integrity is invalid.";
         return(false);
        }
      if((snapshot.market_state!="RANGING" &&
          snapshot.market_state!="TRENDING" &&
          snapshot.market_state!="VOLATILE" &&
          snapshot.market_state!="TRANSITION") ||
         (snapshot.allocation_state!="ALLOCATED" &&
          snapshot.allocation_state!="NOT_ALLOCATED") ||
         StringLen(snapshot.strategy)==0)
        {
         snapshot.invalid_reason="Risk source metadata integrity is invalid.";
         return(false);
        }

      snapshot.is_valid=true;
      return(true);
     }
  };

#endif // FENX_RISK_SNAPSHOT_MQH
