//+------------------------------------------------------------------+
//|                         Strategy/RangeMeanReversionStrategy.mqh |
//+------------------------------------------------------------------+
#ifndef FENX_RANGE_MEAN_REVERSION_STRATEGY_MQH
#define FENX_RANGE_MEAN_REVERSION_STRATEGY_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Core/DataBus.mqh"
#include "../Decision/DecisionBottleneckGate.mqh"

//--- Completed-bar entry intent. It contains no execution behavior.
struct SRangeEntryIntent
  {
   bool            has_signal;
   ENUM_ORDER_TYPE direction;
   double          signal_price;
   double          score;
   double          confidence;
   double          range_lower;
   double          range_upper;
   double          range_midpoint;
   datetime        bar_time;
   string          reason;
  };

//--- Completed-bar exit intent for an existing range mean-reversion position.
struct SRangeExitIntent
  {
   bool     should_close;
   double   signal_price;
   double   range_midpoint;
   datetime bar_time;
   string   reason;
  };

//--- Read-only Task007 gate state published by Common Confidence. Detailed
//--- history remains typed inside ConfidenceEngine and is not duplicated here.
struct STask007ConfidenceGateState
  {
   string   transition;
   int      window_size;
   bool     is_valid;
   double   current_completeness;
   datetime snapshot_updated_at;
   string   invalid_reason;
  };

//--- Produces a BUY near RangeLower or SELL near RangeUpper from completed candles only.
class CRangeMeanReversionStrategy
  {
private:
   CDataBus *m_data_bus;
   string    m_symbol;
   double    m_boundary_distance_points;
   double    m_boundary_distance_atr_ratio;
   double    m_minimum_range_score;
   double    m_minimum_decision_quality;
   double    m_minimum_sell_decision_quality;
   double    m_minimum_adaptive_quality;
   double    m_minimum_refined_quality;
   double    m_minimum_sell_refined_quality;
   bool      m_allow_buy;
   bool      m_allow_sell;
   long      m_c3_block_count;
   datetime  m_c3_last_block_bar_time;
   long      m_task007_block_count;
   long      m_task007_only_block_count;
   long      m_task007_overlap_count;
   long      m_task007_window_shortage_count;
   long      m_task007_invalid_count;
   long      m_task007_buy_misapplication_count;
   datetime  m_task007_last_block_bar_time;
   datetime  m_task007_last_overlap_bar_time;
   datetime  m_task007_last_buy_telemetry_bar_time;
   datetime  m_task007_last_sell_telemetry_bar_time;
   long      m_task011_block_count;
   long      m_task011_only_block_count;
   long      m_task011_task007_overlap_count;
   long      m_task011_c3_overlap_count;
   long      m_task011_triple_overlap_count;
   long      m_task011_buy_misapplication_count;
   long      m_task011_invalid_count;
   long      m_task011_stale_count;
   long      m_task011_year_block_count[10];
   CTask011BlockAuditSequence m_task011_block_audit_sequence;
   datetime  m_task011_last_block_bar_time;
   datetime  m_task011_last_buy_telemetry_bar_time;
   datetime  m_task011_last_sell_telemetry_bar_time;

   bool ReadBooleanText(const string text,bool &value)
     {
      if(text=="true" || text=="TRUE")
        {
         value=true;
         return(true);
        }
      if(text=="false" || text=="FALSE")
        {
         value=false;
         return(true);
        }
      return(false);
     }

   bool ReadDouble(const string key,double &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      if(!m_data_bus.TryGetText(key,text) || StringLen(text)==0)
         return(false);
      value=StringToDouble(text);
      return(true);
     }

   bool ReadSymbolDouble(const string name_space,const string field,double &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      if(!m_data_bus.TryGetSymbolText(name_space,m_symbol,field,text) ||
         StringLen(text)==0)
         return(false);
      value=StringToDouble(text);
      return(true);
     }

   bool ReadSymbolText(const string name_space,const string field,string &value)
     {
      value="";
      return(m_data_bus!=NULL &&
             m_data_bus.TryGetSymbolText(name_space,m_symbol,field,value) &&
             StringLen(value)>0);
     }

   //--- Rejects malformed numeric text instead of allowing StringToDouble to
   //--- silently turn it into zero. An incomplete audit summary must fail open.
   bool IsTask011NumericText(const string raw_value)
     {
      string value=raw_value;
      StringTrimLeft(value);
      StringTrimRight(value);
      const int length=StringLen(value);
      if(length<1)
         return(false);
      bool digit_found=false;
      bool decimal_found=false;
      for(int index=0;index<length;index++)
        {
         const ushort character=StringGetCharacter(value,index);
         if(character>=48 && character<=57)
           {
            digit_found=true;
            continue;
           }
         if(character==46 && !decimal_found)
           {
            decimal_found=true;
            continue;
           }
         if((character==43 || character==45) && index==0)
            continue;
         return(false);
        }
      return(digit_found);
     }

   void ResetTask011Input(const ENUM_ORDER_TYPE direction,
                          SDecisionBottleneckGateInput &gate_input)
     {
      gate_input.direction=direction;
      gate_input.entry_symbol=m_symbol;
      gate_input.entry_timeframe=EnumToString(_Period);
      gate_input.evaluation_time=TimeCurrent();
      gate_input.snapshot_loaded=false;
      // A per-symbol DataBus key is itself the snapshot symbol identity.
      gate_input.snapshot_symbol=m_symbol;
      gate_input.snapshot_timeframe="";
      gate_input.snapshot_valid=false;
      gate_input.snapshot_fresh=false;
      gate_input.snapshot_updated_at=0;
      gate_input.bottleneck_stage="";
      gate_input.minimum_score=0.0;
      gate_input.average_score=0.0;
      gate_input.capital_score_available=false;
      gate_input.capital_allocation_score=0.0;
     }

   //--- Reads the existing Decision Score result without recomputing a score,
   //--- selecting a minimum, changing tie behavior, or adding a threshold.
   bool ReadTask011Input(const ENUM_ORDER_TYPE direction,
                         SDecisionBottleneckGateInput &gate_input)
     {
      ResetTask011Input(direction,gate_input);
      string valid_text="",fresh_text="",updated_text="";
      string minimum_text="",average_text="",capital_text="";
      if(!ReadSymbolText(FENX_DATABUS_NAMESPACE_COMMON_DECISION,
                         FENX_DATABUS_FIELD_COMMON_DECISION_VALID,valid_text) ||
         !ReadSymbolText(FENX_DATABUS_NAMESPACE_COMMON_DECISION,
                         FENX_DATABUS_FIELD_COMMON_DECISION_FRESH,fresh_text) ||
         !ReadSymbolText(FENX_DATABUS_NAMESPACE_COMMON_DECISION,
                         FENX_DATABUS_FIELD_COMMON_DECISION_UPDATED_AT,updated_text) ||
         !ReadSymbolText(FENX_DATABUS_NAMESPACE_COMMON_DECISION,
                         FENX_DATABUS_FIELD_COMMON_DECISION_TIMEFRAME,
                         gate_input.snapshot_timeframe) ||
         !ReadSymbolText(FENX_DATABUS_NAMESPACE_COMMON_DECISION,
                         FENX_DATABUS_FIELD_COMMON_DECISION_BOTTLENECK_STAGE,
                         gate_input.bottleneck_stage) ||
         !ReadSymbolText(FENX_DATABUS_NAMESPACE_COMMON_DECISION,
                         FENX_DATABUS_FIELD_COMMON_DECISION_MINIMUM,minimum_text) ||
         !ReadSymbolText(FENX_DATABUS_NAMESPACE_COMMON_DECISION,
                         FENX_DATABUS_FIELD_COMMON_DECISION_AVERAGE,average_text) ||
         !ReadSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,
                         FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_SCORE,capital_text) ||
         !ReadBooleanText(valid_text,gate_input.snapshot_valid) ||
         !ReadBooleanText(fresh_text,gate_input.snapshot_fresh) ||
         !IsTask011NumericText(minimum_text) ||
         !IsTask011NumericText(average_text) ||
         !IsTask011NumericText(capital_text))
         return(false);

      gate_input.snapshot_updated_at=StringToTime(updated_text);
      gate_input.minimum_score=StringToDouble(minimum_text);
      gate_input.average_score=StringToDouble(average_text);
      gate_input.capital_allocation_score=StringToDouble(capital_text);
      gate_input.capital_score_available=
         (MathIsValidNumber(gate_input.capital_allocation_score) &&
          gate_input.capital_allocation_score>=0.0 &&
          gate_input.capital_allocation_score<=100.0);
      gate_input.snapshot_loaded=
         (gate_input.snapshot_updated_at>0 &&
          MathIsValidNumber(gate_input.minimum_score) &&
          MathIsValidNumber(gate_input.average_score) &&
          gate_input.minimum_score>=0.0 && gate_input.minimum_score<=100.0 &&
          gate_input.average_score>=0.0 && gate_input.average_score<=100.0 &&
          gate_input.capital_score_available);
      return(gate_input.snapshot_loaded);
     }

   bool BeginTask011Telemetry(const ENUM_ORDER_TYPE direction,
                              const datetime signal_bar_time)
     {
      if(direction==ORDER_TYPE_BUY)
        {
         if(signal_bar_time==m_task011_last_buy_telemetry_bar_time)
            return(false);
         m_task011_last_buy_telemetry_bar_time=signal_bar_time;
         return(true);
        }
      if(signal_bar_time==m_task011_last_sell_telemetry_bar_time)
         return(false);
      m_task011_last_sell_telemetry_bar_time=signal_bar_time;
      return(true);
     }

   void CountTask011YearBlock(const datetime signal_bar_time)
     {
      MqlDateTime value;
      if(TimeToStruct(signal_bar_time,value) && value.year>=2016 && value.year<=2025)
         m_task011_year_block_count[value.year-2016]++;
     }

   void LogTask011Telemetry(const datetime signal_bar_time,
                            const SDecisionBottleneckGateInput &gate_input,
                            const SDecisionBottleneckGateResult &result,
                            const bool task007_match,const bool c3_match,
                            const bool upstream_blocked)
     {
      CLogger::Info(StringFormat(
         "[TASK011_GATE] Time=%s;SignalBarTime=%s;Symbol=%s;Direction=%s;DecisionSnapshotUpdatedAt=%s;DecisionValidity=%s;DecisionFreshness=%s;DecisionTimeframe=%s;BottleneckStage=%s;MinimumScore=%.6f;AverageScore=%.6f;CapitalAllocationScore=%.6f;Task007Match=%s;C3Match=%s;Task011Matched=%s;Task011Allowed=%s;Task011Blocked=%s;FinalEntryAllowed=%s;FinalEntryBlocked=%s;UpstreamBlocked=%s;BlockReason=%s;OrderCreated=UNKNOWN;DataLeakSafe=%s;Task011BlockCount=%I64d;Task011OnlyBlockCount=%I64d;Task007OverlapCount=%I64d;C3OverlapCount=%I64d;TripleOverlapCount=%I64d;BUYMisapplicationCount=%I64d;InvalidCount=%I64d;StaleCount=%I64d",
         TimeToString(gate_input.evaluation_time,TIME_DATE|TIME_SECONDS),
         TimeToString(signal_bar_time,TIME_DATE|TIME_SECONDS),m_symbol,
         (gate_input.direction==ORDER_TYPE_BUY ? "BUY" : "SELL"),
         TimeToString(gate_input.snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         (gate_input.snapshot_valid ? "true" : "false"),
         (gate_input.snapshot_fresh ? "true" : "false"),gate_input.snapshot_timeframe,
         gate_input.bottleneck_stage,gate_input.minimum_score,gate_input.average_score,
         gate_input.capital_allocation_score,(task007_match ? "true" : "false"),
         (c3_match ? "true" : "false"),
         (result.condition_matched ? "true" : "false"),
         (result.allowed ? "true" : "false"),
         (result.blocked ? "true" : "false"),
         (!upstream_blocked && result.allowed ? "true" : "false"),
         (upstream_blocked || result.blocked ? "true" : "false"),
         (upstream_blocked ? "true" : "false"),result.reason,
         (gate_input.snapshot_updated_at>0 &&
          gate_input.snapshot_updated_at<=gate_input.evaluation_time ? "true" : "false"),
         m_task011_block_count,m_task011_only_block_count,
         m_task011_task007_overlap_count,m_task011_c3_overlap_count,
         m_task011_triple_overlap_count,m_task011_buy_misapplication_count,
         m_task011_invalid_count,m_task011_stale_count));
     }

   //--- Dedicated block audit is intentionally independent from the bounded
   //--- general telemetry stream. It is called only beside a summary counter
   //--- increment, so a later re-evaluation of an already-telemetried signal
   //--- bar cannot leave a counted Task011 block without an audit record.
   void LogTask011BlockAudit(const long block_sequence,
                             const datetime signal_bar_time,
                             const SDecisionBottleneckGateInput &gate_input,
                             const SDecisionBottleneckGateResult &result,
                             const bool task007_condition,
                             const bool c3_condition)
     {
      CLogger::Info(StringFormat(
         "[TASK011_BLOCK_AUDIT] BlockSequence=%I64d;EntryEvaluationTime=%s;Symbol=%s;Timeframe=%s;Direction=%s;SignalBarTime=%s;DecisionSymbol=%s;DecisionTimeframe=%s;DecisionSnapshotUpdatedAt=%s;DecisionValid=%s;DecisionFresh=%s;BottleneckStage=%s;Task007Condition=%s;C3Condition=%s;Task011Condition=%s;FinalBlockReason=%s;SummaryBlockCount=%I64d;DataLeakSafe=%s",
         block_sequence,
         TimeToString(gate_input.evaluation_time,TIME_DATE|TIME_SECONDS),
         gate_input.entry_symbol,gate_input.entry_timeframe,
         (gate_input.direction==ORDER_TYPE_BUY ? "BUY" : "SELL"),
         TimeToString(signal_bar_time,TIME_DATE|TIME_SECONDS),
         gate_input.snapshot_symbol,gate_input.snapshot_timeframe,
         TimeToString(gate_input.snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         (gate_input.snapshot_valid ? "true" : "false"),
         (gate_input.snapshot_fresh ? "true" : "false"),
         gate_input.bottleneck_stage,
         (task007_condition ? "true" : "false"),
         (c3_condition ? "true" : "false"),
         (result.condition_matched ? "true" : "false"),result.reason,
         m_task011_block_count,
         (gate_input.snapshot_updated_at>0 &&
          gate_input.snapshot_updated_at<=gate_input.evaluation_time ? "true" : "false")));
     }

   //--- Audits the frozen Task011 predicate even when an earlier gate owns the
   //--- actual rejection. This changes counters/logging only, never precedence.
   void AuditTask011UpstreamBlock(const ENUM_ORDER_TYPE direction,
                                  const datetime signal_bar_time,
                                  const bool task007_match,const bool c3_match)
     {
      SDecisionBottleneckGateInput gate_input;
      const bool loaded=ReadTask011Input(direction,gate_input);
      if(!loaded)
         gate_input.snapshot_loaded=false;
      CDecisionBottleneckGate gate;
      SDecisionBottleneckGateResult result;
      gate.Evaluate(gate_input,result);
      const bool record=BeginTask011Telemetry(direction,signal_bar_time);
      // The entry evaluator can revisit a completed bar. Keep overlap totals
      // aligned with the bounded one-record-per-bar telemetry contract.
      if(record && result.condition_matched)
        {
         if(task007_match)
            m_task011_task007_overlap_count++;
         if(c3_match)
            m_task011_c3_overlap_count++;
         if(task007_match && c3_match)
            m_task011_triple_overlap_count++;
        }
      if(record)
         LogTask011Telemetry(signal_bar_time,gate_input,result,task007_match,c3_match,true);
     }

   //--- Runs after C3 and Task007. BUY is audit-only; all bad snapshot states
   //--- preserve the pre-Task011 entry result (fail open).
   bool PassesTask011BottleneckGate(const ENUM_ORDER_TYPE direction,
                                    const datetime signal_bar_time,string &reason)
     {
      SDecisionBottleneckGateInput gate_input;
      const bool loaded=ReadTask011Input(direction,gate_input);
      if(!loaded)
         gate_input.snapshot_loaded=false;
      CDecisionBottleneckGate gate;
      SDecisionBottleneckGateResult result;
      gate.Evaluate(gate_input,result);
      const bool record=BeginTask011Telemetry(direction,signal_bar_time);

      if(direction==ORDER_TYPE_BUY && result.blocked)
         m_task011_buy_misapplication_count++;
      if(record && direction==ORDER_TYPE_SELL && !result.snapshot_accepted)
        {
         if(gate_input.snapshot_loaded && gate_input.snapshot_valid && !gate_input.snapshot_fresh)
            m_task011_stale_count++;
         else
            m_task011_invalid_count++;
        }
      if(result.blocked)
        {
         reason=result.reason;
         if(signal_bar_time!=m_task011_last_block_bar_time)
           {
            m_task011_last_block_bar_time=signal_bar_time;
            m_task011_block_count++;
            m_task011_only_block_count++;
            CountTask011YearBlock(signal_bar_time);
            const long block_sequence=m_task011_block_audit_sequence.Next();
            LogTask011BlockAudit(block_sequence,signal_bar_time,gate_input,
                                 result,false,false);
           }
        }
      if(record)
         LogTask011Telemetry(signal_bar_time,gate_input,result,false,false,false);
      return(result.allowed);
     }

   void ResetTask007GateState(STask007ConfidenceGateState &state)
     {
      state.transition="UNAVAILABLE";
      state.window_size=0;
      state.is_valid=false;
      state.current_completeness=0.0;
      state.snapshot_updated_at=0;
      state.invalid_reason="databus-summary-unavailable";
     }

   //--- Reads only the four new transition summaries plus the existing
   //--- completeness value. A future timestamp is rejected to prevent leakage.
   bool ReadTask007GateState(STask007ConfidenceGateState &state)
     {
      ResetTask007GateState(state);
      string window_text="";
      string valid_text="";
      string completeness_text="";
      string updated_text="";
      if(!ReadSymbolText(FENX_DATABUS_NAMESPACE_COMMON_CONFIDENCE,
                         FENX_DATABUS_FIELD_COMMON_CONFIDENCE_TRANSITION,
                         state.transition) ||
         !ReadSymbolText(FENX_DATABUS_NAMESPACE_COMMON_CONFIDENCE,
                         FENX_DATABUS_FIELD_COMMON_CONFIDENCE_TRANSITION_WINDOW,
                         window_text) ||
         !ReadSymbolText(FENX_DATABUS_NAMESPACE_COMMON_CONFIDENCE,
                         FENX_DATABUS_FIELD_COMMON_CONFIDENCE_TRANSITION_VALID,
                         valid_text) ||
         !ReadSymbolText(FENX_DATABUS_NAMESPACE_COMMON_CONFIDENCE,
                         FENX_DATABUS_FIELD_COMMON_CONFIDENCE_COMPLETENESS,
                         completeness_text) ||
         !ReadSymbolText(FENX_DATABUS_NAMESPACE_COMMON_CONFIDENCE,
                         FENX_DATABUS_FIELD_COMMON_CONFIDENCE_TRANSITION_UPDATED_AT,
                         updated_text) ||
         !ReadBooleanText(valid_text,state.is_valid))
         return(false);

      state.window_size=(int)StringToInteger(window_text);
      state.current_completeness=StringToDouble(completeness_text);
      state.snapshot_updated_at=StringToTime(updated_text);
      if(state.window_size<0 ||
         state.window_size>FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE ||
         state.current_completeness<0.0 ||
         state.current_completeness>100.0 ||
         state.snapshot_updated_at<=0)
        {
         state.is_valid=false;
         state.invalid_reason="transition-summary-out-of-range";
         return(true);
        }
      if(state.snapshot_updated_at>TimeCurrent())
        {
         state.is_valid=false;
         state.invalid_reason="future-transition-snapshot";
         return(true);
        }

      if(state.window_size<FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE)
         state.invalid_reason="transition-window-incomplete";
      else if(!state.is_valid)
         state.invalid_reason="transition-invalid";
      else
         state.invalid_reason="";
      return(true);
     }

   bool BeginTask007Telemetry(const ENUM_ORDER_TYPE direction,
                              const datetime signal_bar_time)
     {
      if(direction==ORDER_TYPE_BUY)
        {
         if(signal_bar_time==m_task007_last_buy_telemetry_bar_time)
            return(false);
         m_task007_last_buy_telemetry_bar_time=signal_bar_time;
         return(true);
        }
      if(signal_bar_time==m_task007_last_sell_telemetry_bar_time)
         return(false);
      m_task007_last_sell_telemetry_bar_time=signal_bar_time;
      return(true);
     }

   void LogTask007Telemetry(const ENUM_ORDER_TYPE direction,
                            const datetime signal_bar_time,
                            const STask007ConfidenceGateState &state,
                            const bool gate_allowed,const bool gate_blocked,
                            const string block_reason,const bool c3_match)
     {
      const datetime evaluation_time=TimeCurrent();
      CLogger::Info(StringFormat(
         "[TASK007_GATE] Time=%s;SignalBarTime=%s;Symbol=%s;Direction=%s;CompletenessTransition=%s;TransitionWindowSize=%d;TransitionValid=%s;CurrentCompleteness=%.2f;GateAllowed=%s;GateBlocked=%s;BlockReason=%s;C3Match=%s;ConfidenceSnapshotUpdatedAt=%s;EntryEvaluationTime=%s;DataLeakSafe=%s;Task007BlockCount=%I64d;Task007OnlyBlockCount=%I64d;C3OverlapCount=%I64d;BUYMisapplicationCount=%I64d;WindowShortageCount=%I64d;InvalidCount=%I64d",
         TimeToString(evaluation_time,TIME_DATE|TIME_SECONDS),
         TimeToString(signal_bar_time,TIME_DATE|TIME_SECONDS),m_symbol,
         (direction==ORDER_TYPE_BUY ? "BUY" : "SELL"),state.transition,
         state.window_size,(state.is_valid ? "true" : "false"),
         state.current_completeness,(gate_allowed ? "true" : "false"),
         (gate_blocked ? "true" : "false"),block_reason,
         (c3_match ? "true" : "false"),
         TimeToString(state.snapshot_updated_at,TIME_DATE|TIME_SECONDS),
         TimeToString(evaluation_time,TIME_DATE|TIME_SECONDS),
         (state.snapshot_updated_at>0 &&
          state.snapshot_updated_at<=evaluation_time ? "true" : "false"),
         m_task007_block_count,m_task007_only_block_count,
         m_task007_overlap_count,m_task007_buy_misapplication_count,
         m_task007_window_shortage_count,m_task007_invalid_count));
     }

   //--- The C3 result is evaluated first. When it blocks, this audit records
   //--- whether Task007 would also have matched without changing C3 behavior.
   void AuditTask007C3Overlap(const datetime signal_bar_time)
     {
      STask007ConfidenceGateState state;
      const bool loaded=ReadTask007GateState(state);
      const bool full_maintained=
         (loaded && state.is_valid &&
          state.window_size==FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE &&
          state.transition=="FULL_MAINTAINED");
      if(full_maintained && signal_bar_time!=m_task007_last_overlap_bar_time)
        {
         m_task007_last_overlap_bar_time=signal_bar_time;
         m_task007_overlap_count++;
        }
      if(!BeginTask007Telemetry(ORDER_TYPE_SELL,signal_bar_time))
         return;
      if(!loaded || !state.is_valid)
        {
         if(state.window_size<FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE)
            m_task007_window_shortage_count++;
         else
            m_task007_invalid_count++;
        }
      LogTask007Telemetry(ORDER_TYPE_SELL,signal_bar_time,state,false,false,
                          (full_maintained ?
                           "C3_PRECEDENCE_TASK007_MATCH" :
                           "C3_PRECEDENCE_TASK007_NO_MATCH"),true);
     }

   //--- Applies Task007 only to an already approved SELL entry. BUY and any
   //--- unavailable/incomplete/invalid transition preserve baseline behavior.
   bool PassesTask007ConfidenceGate(const ENUM_ORDER_TYPE direction,
                                    const datetime signal_bar_time,
                                    string &reason)
     {
      STask007ConfidenceGateState state;
      const bool loaded=ReadTask007GateState(state);
      const bool record=BeginTask007Telemetry(direction,signal_bar_time);
      if(direction==ORDER_TYPE_BUY)
        {
         if(record)
            LogTask007Telemetry(direction,signal_bar_time,state,true,false,
                                "BUY_NOT_APPLICABLE",false);
         return(true);
        }

      if(!loaded)
        {
         if(record)
           {
            m_task007_invalid_count++;
            LogTask007Telemetry(direction,signal_bar_time,state,true,false,
                                "TRANSITION_DATA_UNAVAILABLE",false);
           }
         return(true);
        }
      if(state.window_size<FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE)
        {
         if(record)
           {
            m_task007_window_shortage_count++;
            LogTask007Telemetry(direction,signal_bar_time,state,true,false,
                                "TRANSITION_WINDOW_INCOMPLETE",false);
           }
         return(true);
        }
      if(!state.is_valid)
        {
         if(record)
           {
            m_task007_invalid_count++;
            LogTask007Telemetry(direction,signal_bar_time,state,true,false,
                                state.invalid_reason,false);
           }
         return(true);
        }
      if(state.transition!="FULL_MAINTAINED")
        {
         if(record)
            LogTask007Telemetry(direction,signal_bar_time,state,true,false,
                                "TRANSITION_NOT_FULL_MAINTAINED",false);
         return(true);
        }

      reason="TASK007_SELL_FULL_MAINTAINED";
      if(signal_bar_time!=m_task007_last_block_bar_time)
        {
         m_task007_last_block_bar_time=signal_bar_time;
         m_task007_block_count++;
         m_task007_only_block_count++;
        }
      if(record)
         LogTask007Telemetry(direction,signal_bar_time,state,false,true,reason,false);
      return(false);
     }

   double ClampScore(const double value)
     {
      return(MathMax(0.0,MathMin(100.0,value)));
     }

   bool ReadBoolean(const string key,bool &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      return(m_data_bus.TryGetText(key,text) && ReadBooleanText(text,value));
     }

   void ResetIntent(SRangeEntryIntent &intent)
     {
      intent.has_signal=false;
      intent.direction=ORDER_TYPE_BUY;
      intent.signal_price=0.0;
      intent.score=0.0;
      intent.confidence=0.0;
      intent.range_lower=0.0;
      intent.range_upper=0.0;
      intent.range_midpoint=0.0;
      intent.bar_time=0;
      intent.reason="No completed-bar range entry is available.";
     }

   void ResetExitIntent(SRangeExitIntent &intent)
     {
      intent.should_close=false;
      intent.signal_price=0.0;
      intent.range_midpoint=0.0;
      intent.bar_time=0;
      intent.reason="No completed-bar range exit is available.";
     }

   //--- Combines existing Environment and downstream Engine facts into one
   //--- direction-symmetric entry-quality score. The Task #006 score remains
   //--- the compatibility gate; Task #007 then adapts the evidence weights
   //--- using Trend confidence and explicitly includes published Spread facts.
   bool EvaluateDecisionQuality(const ENUM_ORDER_TYPE direction,
                                const double range_score,double &quality,
                                string &reason)
     {
      quality=0.0;
      double trend_score=0.0;
      double trend_adx=0.0;
      double trend_confidence=0.0;
      double range_position=0.0;
      double volatility_score=0.0;
      double market_selection_score=0.0;
      double market_selection_confidence=0.0;
      double spread_points=0.0;
      double spread_to_atr_ratio=0.0;
      double trading_style_confidence=0.0;
      double strategy_selection_confidence=0.0;
      double risk_score=0.0;
      double risk_confidence=0.0;
      if(!ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_SCORE,trend_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_ADX,trend_adx) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_CONFIDENCE,
                     trend_confidence) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_POSITION,range_position) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,
                     volatility_score) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,
                           FENX_DATABUS_FIELD_MARKET_SELECTION_SCORE,
                           market_selection_score) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,
                           FENX_DATABUS_FIELD_MARKET_SELECTION_CONFIDENCE,
                           market_selection_confidence) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,
                           FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_POINTS,
                           spread_points) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,
                           FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_ATR,
                           spread_to_atr_ratio) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_TRADING_STYLE,
                           FENX_DATABUS_FIELD_TRADING_STYLE_CONFIDENCE,
                           trading_style_confidence) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,
                           FENX_DATABUS_FIELD_STRATEGY_SELECTION_CONFIDENCE,
                           strategy_selection_confidence) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_RISK,
                           FENX_DATABUS_FIELD_RISK_SCORE,risk_score) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_RISK,
                           FENX_DATABUS_FIELD_RISK_CONFIDENCE,risk_confidence))
        {
         reason="Decision quality inputs are unavailable.";
         return(false);
        }
      if(range_position<0.0 || range_position>1.0 || trend_adx<0.0 ||
         trend_confidence<0.0 || trend_confidence>100.0 ||
         volatility_score<0.0 || volatility_score>100.0 ||
         market_selection_score<0.0 || market_selection_score>100.0 ||
         market_selection_confidence<0.0 || market_selection_confidence>100.0 ||
         spread_points<0.0 || spread_to_atr_ratio<0.0 ||
         trading_style_confidence<0.0 || trading_style_confidence>100.0 ||
         strategy_selection_confidence<0.0 ||
         strategy_selection_confidence>100.0 ||
         risk_score<0.0 || risk_score>100.0 ||
         risk_confidence<0.0 || risk_confidence>100.0)
        {
         reason="Decision quality inputs are outside their valid ranges.";
         return(false);
        }

      const double contrarian_trend_quality=
         ClampScore(50.0+(0.5*(direction==ORDER_TYPE_BUY ?
                               -trend_score : trend_score)));
      const double edge_quality=
         ClampScore(100.0*(direction==ORDER_TYPE_BUY ?
                           1.0-range_position : range_position));
      const double confidence_consensus=
         (market_selection_confidence+trading_style_confidence+
          strategy_selection_confidence)/3.0;
      const double trend_calm_quality=
         ClampScore(100.0-MathMin(100.0,2.0*trend_adx));

      const double task006_quality=
         (0.20*contrarian_trend_quality)+
         (0.15*edge_quality)+
         (0.15*ClampScore(range_score))+
         (0.15*market_selection_score)+
         (0.10*volatility_score)+
         (0.10*confidence_consensus)+
         (0.15*trend_calm_quality);
      // Task #006 observations showed materially weaker SELL separation than
      // BUY. Keep the same weighted evidence, but require a stronger composite
      // result for SELL rather than reducing quality on the stronger BUY side.
      const double minimum_base_quality=
         (direction==ORDER_TYPE_SELL ?
          m_minimum_sell_decision_quality : m_minimum_decision_quality);
      if(task006_quality<minimum_base_quality)
        {
         quality=task006_quality;
         reason=StringFormat("Composite decision quality %.2f is below %.2f.",
                             task006_quality,minimum_base_quality);
         return(false);
        }

      // MarketSelection uses these eligibility ceilings when it publishes the
      // raw Spread values. Reusing the same scales makes Spread comparable to
      // the other 0..100 evidence without introducing another market filter.
      const double spread_point_quality=
         ClampScore(100.0*(1.0-(spread_points/30.0)));
      const double spread_atr_quality=
         ClampScore(100.0*(1.0-(spread_to_atr_ratio/0.30)));
      const double spread_quality=
         (0.50*spread_point_quality)+(0.50*spread_atr_quality);

      // Trend confidence controls where evidence weight is placed. Reliable
      // Trend output earns up to 15 percentage points; when confidence is low,
      // the same weight moves to Market, Spread, and cross-engine Confidence.
      // The coefficients always total 1.0, so thresholds remain interpretable.
      const double trend_share=trend_confidence/100.0;
      quality=
         ((0.10+(0.10*trend_share))*contrarian_trend_quality)+
         ((0.10+(0.05*trend_share))*trend_calm_quality)+
         (0.10*edge_quality)+
         (0.10*ClampScore(range_score))+
         (0.10*volatility_score)+
         ((0.20-(0.05*trend_share))*market_selection_score)+
         ((0.15-(0.05*trend_share))*spread_quality)+
         ((0.15-(0.05*trend_share))*confidence_consensus);
      if(quality<m_minimum_adaptive_quality)
        {
         reason=StringFormat("Adaptive decision quality %.2f is below %.2f.",
                             quality,m_minimum_adaptive_quality);
         return(false);
        }

      // Task #008 observations showed that averaging only downstream
      // Confidence overvalued the weakest SELL entries. Preserve both earlier
      // compatibility gates, retain the adaptive score (including Spread),
      // then refine it with conservative published Confidence and Risk.
      const double confidence_floor=
         MathMin(MathMin(market_selection_confidence,
                          trading_style_confidence),
                 MathMin(strategy_selection_confidence,risk_confidence));
      const double risk_quality=ClampScore(100.0-risk_score);
      const double adaptive_quality=quality;
      quality=(0.70*adaptive_quality)+
              (0.20*risk_quality)+
              (0.10*confidence_floor);
      // Annual Task #007 observations isolated the low refined-score SELL
      // band as statistically adverse. BUY retains its established behavior;
      // only that adverse SELL band receives the stronger final threshold.
      const double minimum_refined_quality=
         (direction==ORDER_TYPE_SELL ?
          m_minimum_sell_refined_quality : m_minimum_refined_quality);
      if(quality<minimum_refined_quality)
        {
         reason=StringFormat("Refined decision quality %.2f is below %.2f.",
                             quality,minimum_refined_quality);
         return(false);
        }

      reason=StringFormat("Refined decision quality %.2f (adaptive %.2f, base %.2f) is approved.",
                          quality,adaptive_quality,task006_quality);
      return(true);
     }

   //--- Official Task015 Lite C3 filter. Only a SELL signal can be rejected,
   //--- and only when the existing Environment output reports a neutral trend
   //--- with ADX inside the frozen inclusive range [20.000, 25.945].
   //--- Missing inputs preserve Task008 behavior for backward compatibility.
   bool PassesTask015C3SellFilter(const datetime signal_bar_time,string &reason)
     {
      double trend_adx=0.0;
      string trend_direction="";
      if(!ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_ADX,trend_adx) ||
         m_data_bus==NULL ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DIRECTION,
                                trend_direction) ||
         StringLen(trend_direction)==0)
         return(true);

      if(trend_direction!="NEUTRAL" ||
         trend_adx<20.000 || trend_adx>25.945)
         return(true);

      reason="C3_SELL_NEUTRAL_ADX";
      // Evaluate can be called more than once for the same completed bar.
      // Count and journal each blocked signal bar once without altering the
      // rejection result on subsequent calls.
      if(signal_bar_time!=m_c3_last_block_bar_time)
        {
         m_c3_last_block_bar_time=signal_bar_time;
         m_c3_block_count++;
         CLogger::Info(StringFormat(
            "[ENTRY BLOCK] DateTime=%s;Symbol=%s;Direction=SELL;"
            "Trend=%s;ADX=%.3f;Reason=%s;C3BlockCount=%I64d",
            TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
            m_symbol,trend_direction,trend_adx,reason,m_c3_block_count));
        }
      return(false);
     }

   bool ApproveEntry(const ENUM_ORDER_TYPE direction,
                     const string signal_reason,SRangeEntryIntent &intent)
     {
      const double range_score=intent.score;
      double quality=0.0;
      string quality_reason="";
      if(!EvaluateDecisionQuality(direction,range_score,quality,quality_reason))
        {
         intent.score=quality;
         intent.confidence=quality;
         intent.reason=quality_reason;
         return(false);
        }

      intent.has_signal=true;
      intent.direction=direction;
      intent.score=quality;
      intent.confidence=quality;
      intent.reason=signal_reason+" "+quality_reason;
      return(true);
     }

public:
                     CRangeMeanReversionStrategy(void)
     {
      m_data_bus=NULL;
      m_symbol="";
      m_boundary_distance_points=0.0;
      m_boundary_distance_atr_ratio=0.0;
      m_minimum_range_score=0.0;
      m_minimum_decision_quality=66.5;
      m_minimum_sell_decision_quality=69.25;
      m_minimum_adaptive_quality=64.5;
      m_minimum_refined_quality=68.0;
      m_minimum_sell_refined_quality=76.5;
      m_allow_buy=true;
      m_allow_sell=true;
      m_c3_block_count=0;
      m_c3_last_block_bar_time=0;
      m_task007_block_count=0;
      m_task007_only_block_count=0;
      m_task007_overlap_count=0;
      m_task007_window_shortage_count=0;
      m_task007_invalid_count=0;
      m_task007_buy_misapplication_count=0;
      m_task007_last_block_bar_time=0;
      m_task007_last_overlap_bar_time=0;
      m_task007_last_buy_telemetry_bar_time=0;
      m_task007_last_sell_telemetry_bar_time=0;
      m_task011_block_count=0;
      m_task011_only_block_count=0;
      m_task011_task007_overlap_count=0;
      m_task011_c3_overlap_count=0;
      m_task011_triple_overlap_count=0;
      m_task011_buy_misapplication_count=0;
      m_task011_invalid_count=0;
      m_task011_stale_count=0;
      ArrayInitialize(m_task011_year_block_count,0);
      m_task011_block_audit_sequence.Reset();
      m_task011_last_block_bar_time=0;
      m_task011_last_buy_telemetry_bar_time=0;
      m_task011_last_sell_telemetry_bar_time=0;
     }

   void              Configure(CDataBus &data_bus,const string symbol,
                               const double boundary_distance_points,
                               const double boundary_distance_atr_ratio,
                               const double minimum_range_score,
                               const bool allow_buy,const bool allow_sell)
     {
      m_data_bus=GetPointer(data_bus);
      m_symbol=symbol;
      m_boundary_distance_points=boundary_distance_points;
      m_boundary_distance_atr_ratio=boundary_distance_atr_ratio;
      m_minimum_range_score=minimum_range_score;
      m_allow_buy=allow_buy;
      m_allow_sell=allow_sell;
      m_c3_block_count=0;
      m_c3_last_block_bar_time=0;
      m_task007_block_count=0;
      m_task007_only_block_count=0;
      m_task007_overlap_count=0;
      m_task007_window_shortage_count=0;
      m_task007_invalid_count=0;
      m_task007_buy_misapplication_count=0;
      m_task007_last_block_bar_time=0;
      m_task007_last_overlap_bar_time=0;
      m_task007_last_buy_telemetry_bar_time=0;
      m_task007_last_sell_telemetry_bar_time=0;
      m_task011_block_count=0;
      m_task011_only_block_count=0;
      m_task011_task007_overlap_count=0;
      m_task011_c3_overlap_count=0;
      m_task011_triple_overlap_count=0;
      m_task011_buy_misapplication_count=0;
      m_task011_invalid_count=0;
      m_task011_stale_count=0;
      ArrayInitialize(m_task011_year_block_count,0);
      m_task011_block_audit_sequence.Reset();
      m_task011_last_block_bar_time=0;
      m_task011_last_buy_telemetry_bar_time=0;
      m_task011_last_sell_telemetry_bar_time=0;
     }

   bool              Evaluate(SRangeEntryIntent &intent)
     {
      ResetIntent(intent);
      if(m_data_bus==NULL || m_symbol!="USDJPY")
        {
         intent.reason="Range strategy supports USDJPY only.";
         return(false);
        }

      double lower=0.0,upper=0.0,midpoint=0.0,range_score=0.0,atr=0.0;
      bool is_range=false,range_data_valid=false;
      if(!ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_LOWER,lower) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPPER,upper) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_MIDPOINT,midpoint) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,range_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_ATR,atr) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_IS_RANGE,is_range) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,range_data_valid) ||
         lower>=upper || atr<=0.0 || !is_range || !range_data_valid ||
         range_score<m_minimum_range_score)
        {
         intent.reason="Range facts are not valid for a mean-reversion entry.";
         return(false);
        }

      MqlRates rates[];
      // start_pos=1 explicitly excludes the forming bar and prevents look-ahead bias.
      if(CopyRates(m_symbol,PERIOD_CURRENT,1,1,rates)!=1)
        {
         intent.reason="The latest completed candle is unavailable.";
         return(false);
        }
      const double point=SymbolInfoDouble(m_symbol,SYMBOL_POINT);
      if(point<=0.0)
        {
         intent.reason="The execution symbol has no valid point size.";
         return(false);
        }
      const double boundary=MathMax(m_boundary_distance_points*point,
                                    atr*m_boundary_distance_atr_ratio);
      const double close_price=rates[0].close;
      intent.signal_price=close_price;
      intent.range_lower=lower;
      intent.range_upper=upper;
      intent.range_midpoint=midpoint;
      intent.bar_time=rates[0].time;
      intent.score=range_score;
      intent.confidence=range_score;

      // Task #005 entry-quality evidence showed that Tuesday entries degraded
      // both BUY and SELL results across most 2024 months. This categorical
      // filter avoids changing Environment facts, range thresholds, or exits.
      MqlDateTime entry_time;
      if(TimeToStruct(TimeCurrent(),entry_time) && entry_time.day_of_week==2)
        {
         intent.reason="Entry quality filter rejected a Tuesday range signal.";
         return(false);
        }

      if(m_allow_buy && MathAbs(close_price-lower)<=boundary)
        {
         if(!ApproveEntry(ORDER_TYPE_BUY,
                          "Completed-bar close is near RangeLower.",intent))
            return(false);
         string gate_reason="";
         // BUY is audited but can never be blocked by the SELL-only gate.
         PassesTask007ConfidenceGate(ORDER_TYPE_BUY,intent.bar_time,gate_reason);
         PassesTask011BottleneckGate(ORDER_TYPE_BUY,intent.bar_time,gate_reason);
         return(true);
        }
      if(m_allow_sell && MathAbs(close_price-upper)<=boundary)
        {
         string filter_reason="";
         if(!PassesTask015C3SellFilter(intent.bar_time,filter_reason))
           {
            STask007ConfidenceGateState overlap_state;
            const bool overlap_loaded=ReadTask007GateState(overlap_state);
            const bool task007_match=
               (overlap_loaded && overlap_state.is_valid &&
                overlap_state.window_size==FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE &&
                overlap_state.transition=="FULL_MAINTAINED");
            AuditTask007C3Overlap(intent.bar_time);
            AuditTask011UpstreamBlock(ORDER_TYPE_SELL,intent.bar_time,
                                      task007_match,true);
            intent.reason=filter_reason;
            return(false);
           }
         if(!ApproveEntry(ORDER_TYPE_SELL,
                          "Completed-bar close is near RangeUpper.",intent))
            return(false);
         string gate_reason="";
         if(!PassesTask007ConfidenceGate(ORDER_TYPE_SELL,intent.bar_time,
                                         gate_reason))
           {
            AuditTask011UpstreamBlock(ORDER_TYPE_SELL,intent.bar_time,true,false);
            intent.has_signal=false;
            intent.reason=gate_reason;
            return(false);
           }
         if(!PassesTask011BottleneckGate(ORDER_TYPE_SELL,intent.bar_time,
                                         gate_reason))
           {
            intent.has_signal=false;
            intent.reason=gate_reason;
            return(false);
           }
         return(true);
        }
      intent.reason="Completed-bar close is away from both range boundaries.";
      return(false);
     }

   //--- Emits one bounded end-of-run aggregate for Strategy Tester auditing.
   void              LogTask007Summary(void)
     {
      CLogger::Info(StringFormat(
         "[TASK007_SUMMARY] Task007BlockCount=%I64d;Task007OnlyBlockCount=%I64d;C3OverlapCount=%I64d;BUYMisapplicationCount=%I64d;WindowShortageCount=%I64d;InvalidCount=%I64d;WindowSize=%d;FullThreshold=%.3f",
         m_task007_block_count,m_task007_only_block_count,
         m_task007_overlap_count,m_task007_buy_misapplication_count,
         m_task007_window_shortage_count,m_task007_invalid_count,
         FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE,
         FENX_COMMON_CONFIDENCE_FULL_COMPLETENESS_THRESHOLD));
      string yearly="";
      for(int index=0;index<10;index++)
        {
         if(StringLen(yearly)>0)
            yearly+=",";
         yearly+=IntegerToString(2016+index)+":"+
                 IntegerToString((int)m_task011_year_block_count[index]);
        }
      const long discovery_blocks=
         m_task011_year_block_count[0]+m_task011_year_block_count[1]+
         m_task011_year_block_count[2]+m_task011_year_block_count[3]+
         m_task011_year_block_count[4]+m_task011_year_block_count[5]+
         m_task011_year_block_count[6]+m_task011_year_block_count[7];
      const long holdout_blocks=
         m_task011_year_block_count[8]+m_task011_year_block_count[9];
      CLogger::Info(StringFormat(
         "[TASK011_SUMMARY] Task011BlockCount=%I64d;Task011OnlyBlockCount=%I64d;Task011BlockSequenceCount=%I64d;Task007OverlapCount=%I64d;C3OverlapCount=%I64d;TripleOverlapCount=%I64d;BUYMisapplicationCount=%I64d;InvalidCount=%I64d;StaleCount=%I64d;DiscoveryBlockCount=%I64d;HoldoutBlockCount=%I64d;YearBlocks=%s",
         m_task011_block_count,m_task011_only_block_count,
         m_task011_block_audit_sequence.Current(),
         m_task011_task007_overlap_count,m_task011_c3_overlap_count,
         m_task011_triple_overlap_count,m_task011_buy_misapplication_count,
         m_task011_invalid_count,m_task011_stale_count,discovery_blocks,
         holdout_blocks,yearly));
     }

   //--- Closes at the current range midpoint using completed bars only.
   bool              EvaluateExit(const ENUM_POSITION_TYPE position_type,
                                  SRangeExitIntent &intent)
     {
      ResetExitIntent(intent);
      if(m_data_bus==NULL || m_symbol!="USDJPY")
        {
         intent.reason="Range exit supports USDJPY only.";
         return(false);
        }

      double midpoint=0.0;
      bool range_data_valid=false;
      if(!ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_MIDPOINT,midpoint) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,range_data_valid) ||
         midpoint<=0.0 || !range_data_valid)
        {
         intent.reason="Range midpoint is not valid for position exit.";
         return(false);
        }

      MqlRates rates[];
      // The close decision uses only the latest completed candle.
      if(CopyRates(m_symbol,PERIOD_CURRENT,1,1,rates)!=1)
        {
         intent.reason="The latest completed candle is unavailable for position exit.";
         return(false);
        }

      intent.signal_price=rates[0].close;
      intent.range_midpoint=midpoint;
      intent.bar_time=rates[0].time;
      if(position_type==POSITION_TYPE_BUY)
        {
         intent.should_close=(intent.signal_price>=midpoint);
         intent.reason=(intent.should_close ?
                        "Completed-bar close reached the range midpoint for BUY exit." :
                        "BUY position is waiting for the range midpoint.");
         return(intent.should_close);
        }
      if(position_type==POSITION_TYPE_SELL)
        {
         intent.should_close=(intent.signal_price<=midpoint);
         intent.reason=(intent.should_close ?
                        "Completed-bar close reached the range midpoint for SELL exit." :
                        "SELL position is waiting for the range midpoint.");
         return(intent.should_close);
        }

      intent.reason="Unsupported position type for range exit.";
      return(false);
     }

   bool              BuildProtection(const SRangeEntryIntent &intent,const double entry_price,
                                     const string exit_mode,const double fixed_take_profit_points,
                                     const double fixed_stop_loss_points,
                                     const double range_stop_buffer_points,
                                     double &stop_loss,double &take_profit,string &reason)
     {
      stop_loss=0.0;
      take_profit=0.0;
      const double point=SymbolInfoDouble(m_symbol,SYMBOL_POINT);
      if(point<=0.0 || entry_price<=0.0)
        {
         reason="Entry price or point size is invalid for protection calculation.";
         return(false);
        }
      if(exit_mode=="FIXED_POINTS")
        {
         if(fixed_take_profit_points<=0.0 || fixed_stop_loss_points<=0.0)
           {
            reason="Fixed protection points are invalid.";
            return(false);
           }
         if(intent.direction==ORDER_TYPE_BUY)
           {
            stop_loss=entry_price-(fixed_stop_loss_points*point);
            take_profit=entry_price+(fixed_take_profit_points*point);
           }
         else
           {
            stop_loss=entry_price+(fixed_stop_loss_points*point);
            take_profit=entry_price-(fixed_take_profit_points*point);
           }
        }
      else if(exit_mode=="RANGE_BASED")
        {
         if(range_stop_buffer_points<0.0)
           {
            reason="Range stop buffer is invalid.";
            return(false);
           }
         if(intent.direction==ORDER_TYPE_BUY)
           {
            stop_loss=intent.range_lower-(range_stop_buffer_points*point);
            take_profit=intent.range_midpoint;
           }
         else
           {
            stop_loss=intent.range_upper+(range_stop_buffer_points*point);
            take_profit=intent.range_midpoint;
           }
        }
      else
        {
         reason="Unsupported execution exit mode.";
         return(false);
        }

      if((intent.direction==ORDER_TYPE_BUY && (stop_loss>=entry_price || take_profit<=entry_price)) ||
         (intent.direction==ORDER_TYPE_SELL && (stop_loss<=entry_price || take_profit>=entry_price)))
        {
         reason="Range protection is not valid relative to the market entry price.";
         return(false);
        }
      reason="";
      return(true);
     }
  };

#endif // FENX_RANGE_MEAN_REVERSION_STRATEGY_MQH
