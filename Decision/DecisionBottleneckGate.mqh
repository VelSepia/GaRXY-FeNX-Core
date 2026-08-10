//+------------------------------------------------------------------+
//|                       Decision/DecisionBottleneckGate.mqh       |
//+------------------------------------------------------------------+
#ifndef FENX_DECISION_BOTTLENECK_GATE_MQH
#define FENX_DECISION_BOTTLENECK_GATE_MQH

//--- Immutable gate_input assembled from the already-published Decision Score
//--- summary at entry-evaluation time. The gate intentionally receives the
//--- existing bottleneck result; it never recalculates scores or tie breaks.
struct SDecisionBottleneckGateInput
  {
   ENUM_ORDER_TYPE direction;
   string          entry_symbol;
   string          entry_timeframe;
   datetime        evaluation_time;
   bool            snapshot_loaded;
   string          snapshot_symbol;
   string          snapshot_timeframe;
   bool            snapshot_valid;
   bool            snapshot_fresh;
   datetime        snapshot_updated_at;
   string          bottleneck_stage;
   double          minimum_score;
   double          average_score;
   bool            capital_score_available;
   double          capital_allocation_score;
  };

//--- Explicit result used by both production telemetry and the independent
//--- harness. Invalid, incomplete, stale, mismatched, or future data always
//--- fails open so Task008 behavior remains the compatibility fallback.
struct SDecisionBottleneckGateResult
  {
   bool   applicable;
   bool   snapshot_accepted;
   bool   condition_matched;
   bool   allowed;
   bool   blocked;
   string reason;
  };

//--- Issues a monotonically increasing identifier for every Task011 block
//--- audit record. The production caller requests an identifier only in the
//--- same branch that increments its summary block counter, preserving the
//--- required one-counter/one-record relationship without relaxing general
//--- per-bar telemetry suppression.
class CTask011BlockAuditSequence
  {
private:
   long m_current;

public:
                     CTask011BlockAuditSequence(void) { Reset(); }

   void              Reset(void) { m_current=0; }

   long              Next(void)
     {
      m_current++;
      return(m_current);
     }

   long              Current(void) { return(m_current); }
  };

class CDecisionBottleneckGate
  {
private:
   void ResetResult(SDecisionBottleneckGateResult &result)
     {
      result.applicable=false;
      result.snapshot_accepted=false;
      result.condition_matched=false;
      result.allowed=true;
      result.blocked=false;
      result.reason="NOT_APPLICABLE";
     }

public:
   //--- Blocks only the frozen Task009 candidate: a SELL whose accepted,
   //--- same-symbol/same-timeframe snapshot names CapitalAllocation exactly.
   void Evaluate(const SDecisionBottleneckGateInput &gate_input,
                 SDecisionBottleneckGateResult &result)
     {
      ResetResult(result);
      if(gate_input.direction!=ORDER_TYPE_SELL)
        {
         result.reason="BUY_NOT_APPLICABLE";
         return;
        }

      result.applicable=true;
      if(!gate_input.snapshot_loaded)
        {
         result.reason="DECISION_SNAPSHOT_UNAVAILABLE";
         return;
        }
      if(!gate_input.snapshot_valid)
        {
         result.reason="DECISION_SNAPSHOT_INVALID";
         return;
        }
      if(!gate_input.snapshot_fresh)
        {
         result.reason="DECISION_SNAPSHOT_STALE";
         return;
        }
      if(gate_input.entry_symbol!=gate_input.snapshot_symbol)
        {
         result.reason="DECISION_SYMBOL_MISMATCH";
         return;
        }
      if(gate_input.entry_timeframe!=gate_input.snapshot_timeframe)
        {
         result.reason="DECISION_TIMEFRAME_MISMATCH";
         return;
        }
      if(gate_input.snapshot_updated_at<=0 || gate_input.evaluation_time<=0)
        {
         result.reason="DECISION_TIMESTAMP_INVALID";
         return;
        }
      if(gate_input.snapshot_updated_at>gate_input.evaluation_time)
        {
         result.reason="DECISION_SNAPSHOT_FROM_FUTURE";
         return;
        }

      result.snapshot_accepted=true;
      if(gate_input.bottleneck_stage!="CapitalAllocation")
        {
         result.reason="BOTTLENECK_NOT_CAPITAL_ALLOCATION";
         return;
        }

      result.condition_matched=true;
      result.allowed=false;
      result.blocked=true;
      result.reason="TASK011_SELL_CAPITAL_ALLOCATION_BOTTLENECK";
     }
  };

#endif // FENX_DECISION_BOTTLENECK_GATE_MQH
