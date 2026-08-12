//+------------------------------------------------------------------+
//|                               Standby/StandbySnapshot.mqh       |
//+------------------------------------------------------------------+
#ifndef FENX_STANDBY_SNAPSHOT_MQH
#define FENX_STANDBY_SNAPSHOT_MQH

#include "../Common/Constants.mqh"

//--- Typed representation of the existing StandbyEngine result. The first
//--- fields retain the legacy names so publishing and all consumers remain
//--- byte-for-byte compatible with the existing Standby DataBus contract.
struct SStandbySnapshot
  {
   //--- Existing per-symbol Standby output
   string   symbol;
   string   state;
   bool     is_active;
   bool     are_new_entries_allowed;
   bool     preserve_existing_positions;
   string   reason;
   double   confidence;
   datetime entered_at;
   long     duration_seconds;
   double   recovery_progress;
   double   escalation_score;
   string   recommended_next_state;
   bool     is_data_valid;
   datetime updated_at;

   //--- Common snapshot identity and validity
   string   timeframe;
   string   snapshot_version;
   bool     is_valid;
   bool     is_fresh;
   string   invalid_reason;

   //--- Existing state-machine outcome; these values observe but never drive
   //--- transitions, entry permission, escalation, or Risk Stop requests.
   bool     is_standby;
   bool     is_recovering;
   bool     escalation_requested;
   bool     risk_stop_requested;

   //--- Existing recovery confirmation and timing facts
   bool     recovery_condition_met;
   int      recovery_confirmation_count;
   int      required_confirmation_count;
   datetime recovery_started_at;
   datetime last_recovery_check_at;

   //--- Existing Standby timing facts
   datetime standby_started_at;
   long     standby_duration_seconds;
   datetime cooldown_until;
   datetime last_state_changed_at;

   //--- Existing reasons captured without introducing new decisions
   string   standby_reason;
   string   recovery_reason;
   string   escalation_reason;

   //--- Existing-source metadata. Market Selection currently publishes no
   //--- dedicated validity field, so availability is explicitly represented.
   string   market_state;
   datetime market_state_updated_at;
   bool     market_selection_valid_available;
   bool     market_selection_valid;
   bool     is_market_eligible;
   bool     strategy_selection_valid;
   datetime source_updated_at;
   string   state_manager_state;
  };

//--- Validates typed identity, freshness, and the already-decided Standby
//--- result. It intentionally does not recalculate entry, recovery,
//--- escalation, cooldown, or Risk Stop predicates.
class CStandbySnapshotContract
  {
private:
   bool              IsKnownState(const string state)
     {
      return(state=="NORMAL" || state=="ENTERING_STANDBY" ||
             state=="STANDBY" || state=="RECOVERY_PENDING" ||
             state=="ESCALATION_PENDING" || state=="RISK_STOP_PENDING");
     }

   string            ExpectedNextState(const string state)
     {
      if(state=="ESCALATION_PENDING")
         return("DYNAMIC_ZONE");
      if(state=="RISK_STOP_PENDING")
         return("RISK_STOP");
      if(state=="ENTERING_STANDBY" || state=="STANDBY" ||
         state=="RECOVERY_PENDING")
         return("STANDBY");
      return("NORMAL");
     }

   bool              IsKnownCoreState(const string state)
     {
      return(state=="INIT" || state=="NORMAL" || state=="STANDBY" ||
             state=="DYNAMIC_ZONE" || state=="RISK_STOP" ||
             state=="SHUTDOWN");
     }

public:
   bool              Finalize(SStandbySnapshot &snapshot,
                              const datetime evaluation_time,
                              const int freshness_limit_seconds)
     {
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="";

      if(StringLen(snapshot.symbol)==0 || StringLen(snapshot.timeframe)==0 ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0)
        {
         snapshot.invalid_reason="Standby snapshot identity is invalid.";
         return(false);
        }
      if(snapshot.source_updated_at<=0 || evaluation_time<=0 ||
         freshness_limit_seconds<=0)
        {
         snapshot.invalid_reason="Standby source timestamp is invalid.";
         return(false);
        }

      const long age_seconds=(long)(evaluation_time-snapshot.source_updated_at);
      snapshot.is_fresh=(age_seconds>=0 && age_seconds<=freshness_limit_seconds);
      if(!snapshot.is_fresh)
        {
         snapshot.invalid_reason=(age_seconds<0 ?
                                  "Standby source is future-dated." :
                                  "Standby source is stale.");
         return(false);
        }
      if(!snapshot.is_data_valid)
        {
         snapshot.invalid_reason="Standby source is unavailable or invalid.";
         return(false);
        }
      if(!IsKnownState(snapshot.state) ||
         !IsKnownCoreState(snapshot.state_manager_state))
        {
         snapshot.invalid_reason="Standby state integrity is invalid.";
         return(false);
        }
      if(snapshot.market_state!="RANGING" && snapshot.market_state!="TRENDING" &&
         snapshot.market_state!="VOLATILE" &&
         snapshot.market_state!="TRANSITION")
        {
         snapshot.invalid_reason="Standby Market State metadata is invalid.";
         return(false);
        }
      if(!MathIsValidNumber(snapshot.confidence) ||
         !MathIsValidNumber(snapshot.recovery_progress) ||
         !MathIsValidNumber(snapshot.escalation_score) ||
         snapshot.confidence<0.0 || snapshot.confidence>100.0 ||
         snapshot.recovery_progress<0.0 || snapshot.recovery_progress>100.0 ||
         snapshot.escalation_score<0.0 || snapshot.escalation_score>100.0 ||
         snapshot.duration_seconds<0 || snapshot.standby_duration_seconds<0)
        {
         snapshot.invalid_reason="Standby value integrity is invalid.";
         return(false);
        }
      if(snapshot.required_confirmation_count<1 ||
         snapshot.recovery_confirmation_count<0 ||
         snapshot.recovery_confirmation_count>
            snapshot.required_confirmation_count)
        {
         snapshot.invalid_reason="Standby confirmation integrity is invalid.";
         return(false);
        }

      const bool expected_active=(snapshot.state!="NORMAL");
      const bool expected_recovering=(snapshot.state=="RECOVERY_PENDING");
      const bool expected_escalation=(snapshot.state=="ESCALATION_PENDING");
      const bool expected_risk_stop=(snapshot.state=="RISK_STOP_PENDING");
      if(snapshot.is_active!=expected_active ||
         snapshot.is_standby!=expected_active ||
         snapshot.is_recovering!=expected_recovering ||
         snapshot.escalation_requested!=expected_escalation ||
         snapshot.risk_stop_requested!=expected_risk_stop ||
         (snapshot.are_new_entries_allowed && snapshot.state!="NORMAL") ||
         snapshot.recommended_next_state!=ExpectedNextState(snapshot.state) ||
         !snapshot.preserve_existing_positions ||
         snapshot.entered_at!=snapshot.standby_started_at ||
         snapshot.duration_seconds!=snapshot.standby_duration_seconds)
        {
         snapshot.invalid_reason="Standby output mapping is invalid.";
         return(false);
        }
      if((expected_recovering && snapshot.recovery_started_at<=0) ||
         (!expected_recovering && snapshot.recovery_confirmation_count!=0) ||
         (snapshot.last_state_changed_at>0 && snapshot.cooldown_until<
          snapshot.last_state_changed_at) || StringLen(snapshot.reason)==0 ||
         snapshot.reason!=snapshot.standby_reason ||
         snapshot.market_state_updated_at<=0 ||
         snapshot.strategy_selection_valid==false)
        {
         snapshot.invalid_reason="Standby metadata integrity is invalid.";
         return(false);
        }
      // No dedicated MarketSelection validity output exists in the current
      // contract; reporting a fabricated value would violate source fidelity.
      if(snapshot.market_selection_valid_available ||
         snapshot.market_selection_valid)
        {
         snapshot.invalid_reason="Standby Market Selection validity was inferred.";
         return(false);
        }

      snapshot.is_valid=true;
      return(true);
     }
  };

#endif // FENX_STANDBY_SNAPSHOT_MQH
