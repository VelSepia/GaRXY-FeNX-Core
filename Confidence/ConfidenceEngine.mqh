//+------------------------------------------------------------------+
//|                                Confidence/ConfidenceEngine.mqh  |
//+------------------------------------------------------------------+
#ifndef FENX_CONFIDENCE_ENGINE_MQH
#define FENX_CONFIDENCE_ENGINE_MQH

#include "../Common/Constants.mqh"
#include "../Common/CommonSnapshotStore.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"
#include "ConfidenceSnapshot.mqh"

//--- Aggregates existing confidence contracts into descriptive, shadow-only
//--- snapshots. It does not weight, normalize, threshold, or consume results
//--- for trading decisions.
class CConfidenceEngine : public CBaseEngine
  {
private:
   int                   m_freshness_limit_seconds;
   string                m_symbols[];
   bool                  m_consistency_verified[];
   bool                  m_initial_status_logged[];
   bool                  m_valid_snapshot_logged[];
   datetime              m_last_telemetry_bar[];
   SConfidenceCompletenessHistory m_transition_histories[];
   CCommonSnapshotStore *m_snapshot_store;

   void ResetSource(SConfidenceSourceSnapshot &source,const string stage)
     {
      source.stage=stage;
      source.value=0.0;
      source.is_present=false;
      source.is_valid=false;
      source.updated_at=0;
      source.is_fresh=false;
      source.invalid_reason="missing";
     }

   void ResetSnapshot(SConfidenceSnapshot &snapshot,const string symbol)
     {
      snapshot.symbol=symbol;
      snapshot.timeframe=EnumToString(_Period);
      snapshot.snapshot_version=FENX_COMMON_CONFIDENCE_SNAPSHOT_VERSION;
      snapshot.updated_at=TimeCurrent();
      snapshot.validity_state="INVALID";
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="No valid and fresh confidence sources.";
      snapshot.expected_source_count=FENX_COMMON_CONFIDENCE_EXPECTED_SOURCE_COUNT;
      snapshot.valid_source_count=0;
      snapshot.missing_source_count=FENX_COMMON_CONFIDENCE_EXPECTED_SOURCE_COUNT;
      snapshot.unavailable_source_count=0;
      snapshot.invalid_source_count=0;
      snapshot.stale_source_count=0;
      snapshot.completeness_ratio=0.0;
      snapshot.completeness_transition="WINDOW_INCOMPLETE";
      snapshot.transition_window_size=0;
      snapshot.transition_valid=false;
      snapshot.transition_updated_at=0;
      snapshot.transition_invalid_reason="transition-history-empty";
      ResetSource(snapshot.market_state_confidence,"MarketState");
      ResetSource(snapshot.market_selection_confidence,"MarketSelection");
      ResetSource(snapshot.pair_ranking_confidence,"PairRanking");
      ResetSource(snapshot.capital_allocation_confidence,"CapitalAllocation");
      ResetSource(snapshot.trading_style_confidence,"TradingStyle");
      ResetSource(snapshot.strategy_selection_confidence,"StrategySelection");
      ResetSource(snapshot.standby_confidence,"Standby");
      ResetSource(snapshot.risk_confidence,"Risk");
      snapshot.average_confidence=0.0;
      snapshot.minimum_confidence=0.0;
      snapshot.maximum_confidence=0.0;
      snapshot.confidence_range=0.0;
      snapshot.confidence_variance=0.0;
      snapshot.confidence_standard_deviation=0.0;
      snapshot.bottleneck_stage="";
      snapshot.strongest_stage="";
      snapshot.market_state="UNKNOWN";
     }

   //--- Copies the bounded per-symbol history into the typed transition
   //--- summary. Only the first snapshot from each new bar is appended so the
   //--- six observations exactly match Task005/Task006 telemetry cadence.
   void ApplyCompletenessTransition(const int symbol_index,
                                    SConfidenceSnapshot &snapshot)
     {
      const datetime bar_time=iTime(snapshot.symbol,_Period,0);
      if(bar_time<=0)
        {
         snapshot.completeness_transition="WINDOW_INCOMPLETE";
         snapshot.transition_window_size=m_transition_histories[symbol_index].count;
         snapshot.transition_valid=false;
         snapshot.transition_updated_at=0;
         snapshot.transition_invalid_reason="current-bar-time-unavailable";
         return;
        }

      FenxAppendConfidenceCompletenessSnapshot(
         m_transition_histories[symbol_index],bar_time,snapshot.updated_at,
         snapshot.completeness_ratio,
         snapshot.validity_state);
      snapshot.transition_window_size=m_transition_histories[symbol_index].count;
      if(m_transition_histories[symbol_index].count>0)
         snapshot.transition_updated_at=
            m_transition_histories[symbol_index].snapshot_updated_at[
               m_transition_histories[symbol_index].count-1];
      snapshot.completeness_transition=
         FenxClassifyConfidenceCompletenessTransition(
            m_transition_histories[symbol_index]);

      if(m_transition_histories[symbol_index].count<
         FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE)
        {
         snapshot.transition_valid=false;
         snapshot.transition_invalid_reason=StringFormat(
            "window-incomplete:%d/%d",
            m_transition_histories[symbol_index].count,
            FENX_COMMON_CONFIDENCE_TRANSITION_WINDOW_SIZE);
         return;
        }
      if(snapshot.completeness_transition=="INVALID_OR_STALE_AT_ENTRY")
        {
         snapshot.transition_valid=false;
         snapshot.transition_invalid_reason="current-snapshot-invalid-or-stale";
         return;
        }

      snapshot.transition_valid=true;
      snapshot.transition_invalid_reason="";
     }

   void AppendReason(string &target,const string value)
     {
      if(StringLen(value)==0)
         return;
      if(StringLen(target)>0)
         target+="|";
      target+=value;
     }

   bool IsNumericText(const string raw_value)
     {
      string text=raw_value;
      StringTrimLeft(text);
      StringTrimRight(text);
      const int length=StringLen(text);
      if(length<1)
         return(false);

      bool digit_found=false;
      bool decimal_found=false;
      for(int index=0;index<length;index++)
        {
         const ushort character=StringGetCharacter(text,index);
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

   bool TryParseConfidence(const string text,double &value)
     {
      if(!IsNumericText(text))
         return(false);
      value=StringToDouble(text);
      return(MathIsValidNumber(value) && value>=0.0 && value<=100.0);
     }

   bool TryParseBoolean(const string text,bool &value)
     {
      if(text=="true" || text=="1")
        {
         value=true;
         return(true);
        }
      if(text=="false" || text=="0")
        {
         value=false;
         return(true);
        }
      return(false);
     }

   bool TryParseTimestamp(const string text,datetime &value)
     {
      value=StringToTime(text);
      return(value>0);
     }

   bool ReadGlobalBoolean(const string key,bool &value)
     {
      string text="";
      return(m_data_bus!=NULL && m_data_bus.TryGetText(key,text) &&
             TryParseBoolean(text,value));
     }

   bool ReadSymbolBoolean(const string name_space,const string symbol,
                          const string field,bool &value)
     {
      string text="";
      return(m_data_bus!=NULL &&
             m_data_bus.TryGetSymbolText(name_space,symbol,field,text) &&
             TryParseBoolean(text,value));
     }

   void LoadGlobalSource(const string stage,const string value_key,
                         const string timestamp_key,SConfidenceSourceSnapshot &source)
     {
      ResetSource(source,stage);
      if(m_data_bus==NULL)
         return;

      string value_text="";
      string timestamp_text="";
      if(!m_data_bus.TryGetText(value_key,value_text) ||
         !m_data_bus.TryGetText(timestamp_key,timestamp_text))
         return;

      source.is_present=true;
      if(!TryParseConfidence(value_text,source.value))
        {
         source.invalid_reason="invalid-range-or-nonnumeric";
         return;
        }
      if(!TryParseTimestamp(timestamp_text,source.updated_at))
        {
         source.invalid_reason="invalid-timestamp";
         return;
        }
      source.is_valid=true;
      source.invalid_reason="";
     }

   void LoadSymbolSource(const string stage,const string name_space,
                         const string symbol,const string value_field,
                         const string timestamp_field,SConfidenceSourceSnapshot &source)
     {
      ResetSource(source,stage);
      if(m_data_bus==NULL)
         return;

      string value_text="";
      string timestamp_text="";
      if(!m_data_bus.TryGetSymbolText(name_space,symbol,value_field,value_text) ||
         !m_data_bus.TryGetSymbolText(name_space,symbol,timestamp_field,timestamp_text))
         return;

      source.is_present=true;
      if(!TryParseConfidence(value_text,source.value))
        {
         source.invalid_reason="invalid-range-or-nonnumeric";
         return;
        }
      if(!TryParseTimestamp(timestamp_text,source.updated_at))
        {
         source.invalid_reason="invalid-timestamp";
         return;
        }
      source.is_valid=true;
      source.invalid_reason="";
     }

   void ApplyPublishedValidity(const bool validity_found,const bool validity,
                               SConfidenceSourceSnapshot &source)
     {
      if(!validity_found)
        {
         source.is_present=false;
         source.is_valid=false;
         source.is_fresh=false;
         source.invalid_reason="validity-missing";
         return;
        }
      if(!validity)
        {
         source.is_valid=false;
         source.is_fresh=false;
         if(StringLen(source.invalid_reason)==0)
            source.invalid_reason="publisher-invalid";
        }
     }

   void FinalizeFreshness(SConfidenceSourceSnapshot &source)
     {
      source.is_fresh=false;
      if(!source.is_present || !source.is_valid)
         return;

      const long age_seconds=(long)(TimeCurrent()-source.updated_at);
      if(age_seconds<0)
        {
         source.is_valid=false;
         source.invalid_reason="future-timestamp";
         return;
        }
      if(age_seconds>m_freshness_limit_seconds)
        {
         source.invalid_reason="stale";
         return;
        }
      source.is_fresh=true;
      source.invalid_reason="";
     }

   void CountSource(const SConfidenceSourceSnapshot &source,
                    SConfidenceSnapshot &snapshot)
     {
      if(!source.is_present)
         snapshot.unavailable_source_count++;
      else if(!source.is_valid)
         snapshot.invalid_source_count++;
      else if(!source.is_fresh)
         snapshot.stale_source_count++;
      else
         snapshot.valid_source_count++;
     }

   void IncludeSource(const SConfidenceSourceSnapshot &source,int &count,
                      double &sum,double &sum_of_squares,double &minimum,
                      double &maximum,string &bottleneck,string &strongest)
     {
      if(!source.is_valid || !source.is_fresh)
         return;

      if(count==0 || source.value<minimum)
        {
         minimum=source.value;
         bottleneck=source.stage;
        }
      if(count==0 || source.value>maximum)
        {
         maximum=source.value;
         strongest=source.stage;
        }
      sum+=source.value;
      sum_of_squares+=source.value*source.value;
      count++;
     }

   void AppendSourceIssue(const SConfidenceSourceSnapshot &source,string &reason)
     {
      if(source.is_valid && source.is_fresh)
         return;
      AppendReason(reason,source.stage+":"+source.invalid_reason);
     }

   void CalculateStatistics(SConfidenceSnapshot &snapshot)
     {
      snapshot.valid_source_count=0;
      snapshot.unavailable_source_count=0;
      snapshot.invalid_source_count=0;
      snapshot.stale_source_count=0;
      CountSource(snapshot.market_state_confidence,snapshot);
      CountSource(snapshot.market_selection_confidence,snapshot);
      CountSource(snapshot.pair_ranking_confidence,snapshot);
      CountSource(snapshot.capital_allocation_confidence,snapshot);
      CountSource(snapshot.trading_style_confidence,snapshot);
      CountSource(snapshot.strategy_selection_confidence,snapshot);
      CountSource(snapshot.standby_confidence,snapshot);
      CountSource(snapshot.risk_confidence,snapshot);

      snapshot.missing_source_count=snapshot.expected_source_count-
                                    snapshot.valid_source_count;
      snapshot.completeness_ratio=100.0*(double)snapshot.valid_source_count/
                                  (double)snapshot.expected_source_count;

      int count=0;
      double sum=0.0;
      double sum_of_squares=0.0;
      double minimum=0.0;
      double maximum=0.0;
      string bottleneck="";
      string strongest="";
      IncludeSource(snapshot.market_state_confidence,count,sum,sum_of_squares,
                    minimum,maximum,bottleneck,strongest);
      IncludeSource(snapshot.market_selection_confidence,count,sum,sum_of_squares,
                    minimum,maximum,bottleneck,strongest);
      IncludeSource(snapshot.pair_ranking_confidence,count,sum,sum_of_squares,
                    minimum,maximum,bottleneck,strongest);
      IncludeSource(snapshot.capital_allocation_confidence,count,sum,sum_of_squares,
                    minimum,maximum,bottleneck,strongest);
      IncludeSource(snapshot.trading_style_confidence,count,sum,sum_of_squares,
                    minimum,maximum,bottleneck,strongest);
      IncludeSource(snapshot.strategy_selection_confidence,count,sum,sum_of_squares,
                    minimum,maximum,bottleneck,strongest);
      IncludeSource(snapshot.standby_confidence,count,sum,sum_of_squares,
                    minimum,maximum,bottleneck,strongest);
      IncludeSource(snapshot.risk_confidence,count,sum,sum_of_squares,
                    minimum,maximum,bottleneck,strongest);

      if(count>0)
        {
         snapshot.average_confidence=sum/(double)count;
         snapshot.minimum_confidence=minimum;
         snapshot.maximum_confidence=maximum;
         snapshot.confidence_range=maximum-minimum;
         snapshot.confidence_variance=(sum_of_squares/(double)count)-
                                      snapshot.average_confidence*
                                      snapshot.average_confidence;
         if(snapshot.confidence_variance<0.0 &&
            snapshot.confidence_variance>-0.000000001)
            snapshot.confidence_variance=0.0;
         snapshot.confidence_standard_deviation=
            MathSqrt(snapshot.confidence_variance);
         snapshot.bottleneck_stage=bottleneck;
         snapshot.strongest_stage=strongest;
        }

      snapshot.is_valid=(snapshot.valid_source_count==snapshot.expected_source_count);
      snapshot.is_fresh=(snapshot.stale_source_count==0);
      if(snapshot.is_valid)
         snapshot.validity_state="VALID";
      else if(snapshot.valid_source_count==0)
         snapshot.validity_state="INVALID";
      else if(snapshot.stale_source_count>0 &&
              snapshot.unavailable_source_count==0 &&
              snapshot.invalid_source_count==0)
         snapshot.validity_state="STALE";
      else
         snapshot.validity_state="PARTIAL";

      string reason="";
      AppendSourceIssue(snapshot.market_state_confidence,reason);
      AppendSourceIssue(snapshot.market_selection_confidence,reason);
      AppendSourceIssue(snapshot.pair_ranking_confidence,reason);
      AppendSourceIssue(snapshot.capital_allocation_confidence,reason);
      AppendSourceIssue(snapshot.trading_style_confidence,reason);
      AppendSourceIssue(snapshot.strategy_selection_confidence,reason);
      AppendSourceIssue(snapshot.standby_confidence,reason);
      AppendSourceIssue(snapshot.risk_confidence,reason);
      snapshot.invalid_reason=reason;
     }

   bool BuildSnapshot(const string symbol,SConfidenceSnapshot &snapshot)
     {
      ResetSnapshot(snapshot,symbol);
      if(m_data_bus==NULL)
         return(false);

      m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE,
                            snapshot.market_state);
      LoadGlobalSource("MarketState",FENX_DATABUS_KEY_ENVIRONMENT_MARKET_CONFIDENCE,
                       FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT,
                       snapshot.market_state_confidence);
      LoadSymbolSource("MarketSelection",FENX_DATABUS_NAMESPACE_MARKET_SELECTION,
                       symbol,FENX_DATABUS_FIELD_MARKET_SELECTION_CONFIDENCE,
                       FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT,
                       snapshot.market_selection_confidence);
      LoadSymbolSource("PairRanking",FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                       FENX_DATABUS_FIELD_PAIR_RANKING_CONFIDENCE,
                       FENX_DATABUS_FIELD_PAIR_RANKING_UPDATED_AT,
                       snapshot.pair_ranking_confidence);
      LoadSymbolSource("CapitalAllocation",FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,
                       symbol,FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_CONFIDENCE,
                       FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_UPDATED_AT,
                       snapshot.capital_allocation_confidence);
      LoadSymbolSource("TradingStyle",FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                       FENX_DATABUS_FIELD_TRADING_STYLE_CONFIDENCE,
                       FENX_DATABUS_FIELD_TRADING_STYLE_UPDATED_AT,
                       snapshot.trading_style_confidence);
      LoadSymbolSource("StrategySelection",FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,
                       symbol,FENX_DATABUS_FIELD_STRATEGY_SELECTION_CONFIDENCE,
                       FENX_DATABUS_FIELD_STRATEGY_SELECTION_UPDATED_AT,
                       snapshot.strategy_selection_confidence);
      LoadSymbolSource("Standby",FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                       FENX_DATABUS_FIELD_STANDBY_CONFIDENCE,
                       FENX_DATABUS_FIELD_STANDBY_UPDATED_AT,
                       snapshot.standby_confidence);
      LoadSymbolSource("Risk",FENX_DATABUS_NAMESPACE_RISK,symbol,
                       FENX_DATABUS_FIELD_RISK_CONFIDENCE,
                       FENX_DATABUS_FIELD_RISK_UPDATED_AT,
                       snapshot.risk_confidence);

      bool validity=false;
      bool found=ReadGlobalBoolean(FENX_DATABUS_KEY_PAIR_RANKING_DATA_VALID,validity);
      ApplyPublishedValidity(found,validity,snapshot.pair_ranking_confidence);
      found=ReadGlobalBoolean(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_DATA_VALID,validity);
      ApplyPublishedValidity(found,validity,snapshot.capital_allocation_confidence);
      found=ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                              FENX_DATABUS_FIELD_TRADING_STYLE_IS_VALID,validity);
      ApplyPublishedValidity(found,validity,snapshot.trading_style_confidence);
      found=ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,symbol,
                              FENX_DATABUS_FIELD_STRATEGY_SELECTION_IS_VALID,validity);
      ApplyPublishedValidity(found,validity,snapshot.strategy_selection_confidence);
      found=ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                              FENX_DATABUS_FIELD_STANDBY_DATA_VALID,validity);
      ApplyPublishedValidity(found,validity,snapshot.standby_confidence);
      found=ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_RISK,symbol,
                              FENX_DATABUS_FIELD_RISK_DATA_VALID,validity);
      ApplyPublishedValidity(found,validity,snapshot.risk_confidence);

      FinalizeFreshness(snapshot.market_state_confidence);
      FinalizeFreshness(snapshot.market_selection_confidence);
      FinalizeFreshness(snapshot.pair_ranking_confidence);
      FinalizeFreshness(snapshot.capital_allocation_confidence);
      FinalizeFreshness(snapshot.trading_style_confidence);
      FinalizeFreshness(snapshot.strategy_selection_confidence);
      FinalizeFreshness(snapshot.standby_confidence);
      FinalizeFreshness(snapshot.risk_confidence);
      CalculateStatistics(snapshot);
      return(true);
     }

   bool SameSource(const SConfidenceSourceSnapshot &left,
                   const SConfidenceSourceSnapshot &right)
     {
      return(left.stage==right.stage && left.value==right.value &&
             left.is_present==right.is_present && left.is_valid==right.is_valid &&
             left.updated_at==right.updated_at && left.is_fresh==right.is_fresh &&
             left.invalid_reason==right.invalid_reason);
     }

   bool SameSnapshot(const SConfidenceSnapshot &left,
                     const SConfidenceSnapshot &right)
     {
      return(left.symbol==right.symbol && left.timeframe==right.timeframe &&
             left.snapshot_version==right.snapshot_version &&
             left.updated_at==right.updated_at &&
             left.validity_state==right.validity_state &&
             left.is_valid==right.is_valid && left.is_fresh==right.is_fresh &&
             left.invalid_reason==right.invalid_reason &&
             left.expected_source_count==right.expected_source_count &&
             left.valid_source_count==right.valid_source_count &&
             left.missing_source_count==right.missing_source_count &&
             left.unavailable_source_count==right.unavailable_source_count &&
             left.invalid_source_count==right.invalid_source_count &&
             left.stale_source_count==right.stale_source_count &&
             left.completeness_ratio==right.completeness_ratio &&
             left.completeness_transition==right.completeness_transition &&
             left.transition_window_size==right.transition_window_size &&
             left.transition_valid==right.transition_valid &&
             left.transition_updated_at==right.transition_updated_at &&
             left.transition_invalid_reason==right.transition_invalid_reason &&
             SameSource(left.market_state_confidence,right.market_state_confidence) &&
             SameSource(left.market_selection_confidence,right.market_selection_confidence) &&
             SameSource(left.pair_ranking_confidence,right.pair_ranking_confidence) &&
             SameSource(left.capital_allocation_confidence,right.capital_allocation_confidence) &&
             SameSource(left.trading_style_confidence,right.trading_style_confidence) &&
             SameSource(left.strategy_selection_confidence,right.strategy_selection_confidence) &&
             SameSource(left.standby_confidence,right.standby_confidence) &&
             SameSource(left.risk_confidence,right.risk_confidence) &&
             left.average_confidence==right.average_confidence &&
             left.minimum_confidence==right.minimum_confidence &&
             left.maximum_confidence==right.maximum_confidence &&
             left.confidence_range==right.confidence_range &&
             left.confidence_variance==right.confidence_variance &&
             left.confidence_standard_deviation==right.confidence_standard_deviation &&
             left.bottleneck_stage==right.bottleneck_stage &&
             left.strongest_stage==right.strongest_stage &&
             left.market_state==right.market_state);
     }

   bool StoreTypedSnapshot(const int symbol_index,const SConfidenceSnapshot &snapshot)
     {
      if(m_snapshot_store==NULL ||
         !m_snapshot_store.SetConfidenceSnapshot(snapshot.symbol,_Period,snapshot))
         return(false);
      if(m_consistency_verified[symbol_index])
         return(true);

      SConfidenceSnapshot stored;
      if(!m_snapshot_store.GetConfidenceSnapshot(snapshot.symbol,_Period,stored))
         return(false);
      return(SameSnapshot(snapshot,stored));
     }

   bool PublishField(const string symbol,const string field,const string value,
                     const bool verify)
     {
      if(m_data_bus==NULL ||
         !m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_COMMON_CONFIDENCE,
                                   symbol,field,value))
         return(false);
      if(verify)
        {
         string stored="";
         if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_COMMON_CONFIDENCE,
                                         symbol,field,stored) || stored!=value)
            return(false);
        }
      return(true);
     }

   bool PublishSnapshot(const int symbol_index,const SConfidenceSnapshot &snapshot)
     {
      const bool verify=!m_consistency_verified[symbol_index];
      bool success=true;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_VALID,
                       (snapshot.is_valid ? "true" : "false"),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_FRESH,
                       (snapshot.is_fresh ? "true" : "false"),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_VERSION,
                       snapshot.snapshot_version,verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_UPDATED_AT,
                       TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_AVERAGE,
                       DoubleToString(snapshot.average_confidence,6),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_MINIMUM,
                       DoubleToString(snapshot.minimum_confidence,6),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_MAXIMUM,
                       DoubleToString(snapshot.maximum_confidence,6),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_VARIANCE,
                       DoubleToString(snapshot.confidence_variance,6),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_COMPLETENESS,
                       DoubleToString(snapshot.completeness_ratio,2),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_VALID_SOURCE_COUNT,
                       IntegerToString(snapshot.valid_source_count),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_MISSING_SOURCE_COUNT,
                       IntegerToString(snapshot.missing_source_count),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_BOTTLENECK_STAGE,
                       snapshot.bottleneck_stage,verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_TRANSITION,
                       snapshot.completeness_transition,verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_TRANSITION_WINDOW,
                       IntegerToString(snapshot.transition_window_size),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_TRANSITION_VALID,
                       (snapshot.transition_valid ? "true" : "false"),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_CONFIDENCE_TRANSITION_UPDATED_AT,
                       TimeToString(snapshot.transition_updated_at,
                                    TIME_DATE|TIME_SECONDS),verify)) success=false;
      return(success);
     }

   void PublishTelemetry(const int symbol_index,const SConfidenceSnapshot &snapshot)
     {
      const datetime bar_time=iTime(snapshot.symbol,_Period,0);
      if(bar_time<=0 || bar_time==m_last_telemetry_bar[symbol_index])
         return;
      m_last_telemetry_bar[symbol_index]=bar_time;

      CLogger::Info(StringFormat(
         "[CONFIDENCE_TELEMETRY] Time=%s;Symbol=%s;Timeframe=%s;MarketState=%s;Average=%.6f;Minimum=%.6f;Maximum=%.6f;Variance=%.6f;Completeness=%.2f;BottleneckStage=%s;Validity=%s;CompletenessTransition=%s;TransitionWindowSize=%d;TransitionValid=%s;TransitionUpdatedAt=%s;Direction=UNKNOWN;EntryAllowed=UNKNOWN;EntryBlocked=UNKNOWN;C3Block=UNKNOWN",
         TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS),snapshot.symbol,
         snapshot.timeframe,snapshot.market_state,snapshot.average_confidence,
         snapshot.minimum_confidence,snapshot.maximum_confidence,
         snapshot.confidence_variance,snapshot.completeness_ratio,
         snapshot.bottleneck_stage,snapshot.validity_state,
         snapshot.completeness_transition,snapshot.transition_window_size,
         (snapshot.transition_valid ? "true" : "false"),
         TimeToString(snapshot.transition_updated_at,TIME_DATE|TIME_SECONDS)));
     }

   bool LoadSymbols(CParameterManager &parameters)
     {
      const int symbol_count=parameters.MarketSelectionSymbolCount();
      if(symbol_count<1 ||
         ArrayResize(m_symbols,symbol_count)!=symbol_count ||
         ArrayResize(m_consistency_verified,symbol_count)!=symbol_count ||
         ArrayResize(m_initial_status_logged,symbol_count)!=symbol_count ||
         ArrayResize(m_valid_snapshot_logged,symbol_count)!=symbol_count ||
         ArrayResize(m_last_telemetry_bar,symbol_count)!=symbol_count ||
         ArrayResize(m_transition_histories,symbol_count)!=symbol_count)
         return(false);

      for(int index=0;index<symbol_count;index++)
        {
         if(!parameters.TryGetMarketSelectionSymbol(index,m_symbols[index]))
            return(false);
         m_consistency_verified[index]=false;
         m_initial_status_logged[index]=false;
         m_valid_snapshot_logged[index]=false;
         m_last_telemetry_bar[index]=0;
         FenxResetConfidenceCompletenessHistory(
            m_transition_histories[index],m_symbols[index],_Period);
        }
      return(true);
     }

public:
                     CConfidenceEngine(void)
     {
      SetName("ConfidenceEngine");
      m_freshness_limit_seconds=0;
      m_snapshot_store=NULL;
     }

   //--- Injects the non-owning common store before framework initialization.
   bool              SetSnapshotStore(CCommonSnapshotStore &snapshot_store)
     {
      if(m_initialized)
         return(false);
      m_snapshot_store=GetPointer(snapshot_store);
      return(m_snapshot_store!=NULL);
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(m_snapshot_store==NULL)
        {
         CLogger::Error("ConfidenceEngine requires CommonSnapshotStore before initialization.");
         return(false);
        }
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);
      m_freshness_limit_seconds=parameters.RiskStaleDataLimitSeconds();
      if(m_freshness_limit_seconds<1 || !LoadSymbols(parameters))
        {
         CLogger::Error("ConfidenceEngine could not load its source contract.");
         CBaseEngine::Shutdown();
         return(false);
        }
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;

      const int symbol_count=ArraySize(m_symbols);
      for(int index=0;index<symbol_count;index++)
        {
         SConfidenceSnapshot snapshot;
         if(!BuildSnapshot(m_symbols[index],snapshot))
           {
            CLogger::Error("ConfidenceEngine could not collect its source contract.");
            continue;
           }
         ApplyCompletenessTransition(index,snapshot);
         if(!StoreTypedSnapshot(index,snapshot))
           {
            CLogger::Error("ConfidenceEngine could not store or verify its typed snapshot.");
            continue;
           }
         if(!PublishSnapshot(index,snapshot))
           {
            CLogger::Error("ConfidenceEngine could not publish its shadow summary.");
            continue;
           }

         if(!m_consistency_verified[index])
           {
            CLogger::Info(StringFormat(
               "[COMMON_CONFIDENCE] typed_databus_consistency=PASS;symbol=%s;timeframe=%s;store_count=%d;keys=%d",
               snapshot.symbol,snapshot.timeframe,
               m_snapshot_store.ConfidenceSnapshotCount(),
               FENX_COMMON_CONFIDENCE_PER_SYMBOL_KEY_COUNT));
            m_consistency_verified[index]=true;
           }
         if(!m_initial_status_logged[index])
           {
            CLogger::Info(StringFormat(
               "[COMMON_CONFIDENCE] initial_status=%s;symbol=%s;valid_sources=%d;missing_sources=%d;completeness=%.2f;reason=%s",
               snapshot.validity_state,snapshot.symbol,snapshot.valid_source_count,
               snapshot.missing_source_count,snapshot.completeness_ratio,
               snapshot.invalid_reason));
            m_initial_status_logged[index]=true;
           }
         if(snapshot.is_valid && !m_valid_snapshot_logged[index])
           {
            CLogger::Info(StringFormat(
               "[COMMON_CONFIDENCE] snapshot=VALID;symbol=%s;average=%.6f;minimum=%.6f;maximum=%.6f;variance=%.6f;bottleneck=%s",
               snapshot.symbol,snapshot.average_confidence,
               snapshot.minimum_confidence,snapshot.maximum_confidence,
               snapshot.confidence_variance,snapshot.bottleneck_stage));
            m_valid_snapshot_logged[index]=true;
           }
         PublishTelemetry(index,snapshot);
        }
     }

   virtual void       Shutdown(void)
     {
      ArrayFree(m_symbols);
      ArrayFree(m_consistency_verified);
      ArrayFree(m_initial_status_logged);
      ArrayFree(m_valid_snapshot_logged);
      ArrayFree(m_last_telemetry_bar);
      ArrayFree(m_transition_histories);
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_CONFIDENCE_ENGINE_MQH
