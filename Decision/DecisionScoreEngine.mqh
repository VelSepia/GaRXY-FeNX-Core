//+------------------------------------------------------------------+
//|                           Decision/DecisionScoreEngine.mqh      |
//+------------------------------------------------------------------+
#ifndef FENX_DECISION_SCORE_ENGINE_MQH
#define FENX_DECISION_SCORE_ENGINE_MQH

#include "../Common/Constants.mqh"
#include "../Common/CommonSnapshotStore.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"
#include "DecisionScoreSnapshot.mqh"

//--- Collects five audited, same-direction pipeline suitability scores into a
//--- shadow-only typed snapshot. It never normalizes, weights, thresholds, or
//--- exposes a decision that can affect trading behavior.
class CDecisionScoreEngine : public CBaseEngine
  {
private:
   int                   m_freshness_limit_seconds;
   string                m_symbols[];
   bool                  m_consistency_verified[];
   bool                  m_initial_status_logged[];
   bool                  m_valid_snapshot_logged[];
   datetime              m_last_telemetry_bar[];

   ENUM_TIMEFRAMES RuntimeTimeframe(void)
     {
      SRuntimeContextId context_id;
      if(m_data_bus!=NULL && m_data_bus.GetActiveContextId(context_id))
         return(context_id.timeframe);
      return((ENUM_TIMEFRAMES)_Period);
     }
   CCommonSnapshotStore *m_snapshot_store;

   void ResetSource(SDecisionScoreSourceSnapshot &source,const string source_name)
     {
      source.source_name=source_name;
      source.score=0.0;
      source.is_present=false;
      source.is_valid=false;
      source.is_fresh=false;
      source.updated_at=0;
      source.invalid_reason="missing";
     }

   void ResetSnapshot(SDecisionScoreSnapshot &snapshot,const string symbol)
     {
      snapshot.symbol=symbol;
      snapshot.timeframe=EnumToString(RuntimeTimeframe());
      snapshot.snapshot_version=FENX_COMMON_DECISION_SNAPSHOT_VERSION;
      snapshot.updated_at=TimeCurrent();
      snapshot.validity_state="INVALID";
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="No valid and fresh decision score sources.";
      snapshot.expected_source_count=FENX_COMMON_DECISION_EXPECTED_SOURCE_COUNT;
      snapshot.valid_source_count=0;
      snapshot.missing_source_count=FENX_COMMON_DECISION_EXPECTED_SOURCE_COUNT;
      snapshot.unavailable_source_count=0;
      snapshot.invalid_source_count=0;
      snapshot.stale_source_count=0;
      snapshot.completeness_ratio=0.0;
      ResetSource(snapshot.market_selection_score,"MarketSelection");
      ResetSource(snapshot.pair_ranking_score,"PairRanking");
      ResetSource(snapshot.capital_allocation_score,"CapitalAllocation");
      ResetSource(snapshot.trading_style_score,"TradingStyle");
      ResetSource(snapshot.strategy_selection_score,"StrategySelection");
      snapshot.average_score=0.0;
      snapshot.minimum_score=0.0;
      snapshot.maximum_score=0.0;
      snapshot.score_range=0.0;
      snapshot.score_variance=0.0;
      snapshot.score_standard_deviation=0.0;
      snapshot.bottleneck_stage="";
      snapshot.strongest_stage="";
      snapshot.all_sources_aligned=false;
      snapshot.source_disagreement=false;
      snapshot.disagreement_magnitude=0.0;
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

   bool TryParseScore(const string text,double &value)
     {
      if(!IsNumericText(text))
         return(false);
      value=StringToDouble(text);
      return(MathIsValidNumber(value) && value>=0.0 && value<=100.0);
     }

   bool TryParseBoolean(const string text,bool &value)
     {
      if(text=="true" || text=="TRUE" || text=="1")
        {
         value=true;
         return(true);
        }
      if(text=="false" || text=="FALSE" || text=="0")
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

   void LoadSymbolSource(const string source_name,const string name_space,
                         const string symbol,const string score_field,
                         const string timestamp_field,
                         SDecisionScoreSourceSnapshot &source)
     {
      ResetSource(source,source_name);
      if(m_data_bus==NULL)
         return;

      string score_text="";
      string timestamp_text="";
      if(!m_data_bus.TryGetSymbolText(name_space,symbol,score_field,score_text) ||
         !m_data_bus.TryGetSymbolText(name_space,symbol,timestamp_field,timestamp_text))
         return;

      source.is_present=true;
      if(!TryParseScore(score_text,source.score))
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
                               SDecisionScoreSourceSnapshot &source)
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
         source.invalid_reason="publisher-invalid";
        }
     }

   void FinalizeFreshness(SDecisionScoreSourceSnapshot &source)
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

   void CountSource(const SDecisionScoreSourceSnapshot &source,
                    SDecisionScoreSnapshot &snapshot)
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

   void IncludeSource(const SDecisionScoreSourceSnapshot &source,int &count,
                      double &sum,double &sum_of_squares,double &minimum,
                      double &maximum,string &bottleneck,string &strongest)
     {
      if(!source.is_valid || !source.is_fresh)
         return;
      if(count==0 || source.score<minimum)
        {
         minimum=source.score;
         bottleneck=source.source_name;
        }
      if(count==0 || source.score>maximum)
        {
         maximum=source.score;
         strongest=source.source_name;
        }
      sum+=source.score;
      sum_of_squares+=source.score*source.score;
      count++;
     }

   void AppendSourceIssue(const SDecisionScoreSourceSnapshot &source,string &reason)
     {
      if(source.is_valid && source.is_fresh)
         return;
      AppendReason(reason,source.source_name+":"+source.invalid_reason);
     }

   void CalculateStatistics(SDecisionScoreSnapshot &snapshot)
     {
      CountSource(snapshot.market_selection_score,snapshot);
      CountSource(snapshot.pair_ranking_score,snapshot);
      CountSource(snapshot.capital_allocation_score,snapshot);
      CountSource(snapshot.trading_style_score,snapshot);
      CountSource(snapshot.strategy_selection_score,snapshot);
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
      IncludeSource(snapshot.market_selection_score,count,sum,sum_of_squares,
                    minimum,maximum,bottleneck,strongest);
      IncludeSource(snapshot.pair_ranking_score,count,sum,sum_of_squares,
                    minimum,maximum,bottleneck,strongest);
      IncludeSource(snapshot.capital_allocation_score,count,sum,sum_of_squares,
                    minimum,maximum,bottleneck,strongest);
      IncludeSource(snapshot.trading_style_score,count,sum,sum_of_squares,
                    minimum,maximum,bottleneck,strongest);
      IncludeSource(snapshot.strategy_selection_score,count,sum,sum_of_squares,
                    minimum,maximum,bottleneck,strongest);

      if(count>0)
        {
         snapshot.average_score=sum/(double)count;
         snapshot.minimum_score=minimum;
         snapshot.maximum_score=maximum;
         snapshot.score_range=maximum-minimum;
         snapshot.score_variance=(sum_of_squares/(double)count)-
                                 snapshot.average_score*snapshot.average_score;
         if(snapshot.score_variance<0.0 &&
            snapshot.score_variance>-FENX_COMMON_DECISION_COMPARE_EPSILON)
            snapshot.score_variance=0.0;
         snapshot.score_standard_deviation=MathSqrt(snapshot.score_variance);
         snapshot.bottleneck_stage=bottleneck;
         snapshot.strongest_stage=strongest;
         snapshot.disagreement_magnitude=snapshot.score_range;
         snapshot.source_disagreement=
            (snapshot.score_range>FENX_COMMON_DECISION_COMPARE_EPSILON);
        }

      snapshot.is_valid=(snapshot.valid_source_count==snapshot.expected_source_count);
      //--- INVALID/no-source snapshots are not described as fresh merely
      //--- because no stale timestamp was available to count.
      snapshot.is_fresh=(snapshot.valid_source_count>0 &&
                         snapshot.stale_source_count==0);
      snapshot.all_sources_aligned=(snapshot.is_valid &&
                                    !snapshot.source_disagreement);
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
      AppendSourceIssue(snapshot.market_selection_score,reason);
      AppendSourceIssue(snapshot.pair_ranking_score,reason);
      AppendSourceIssue(snapshot.capital_allocation_score,reason);
      AppendSourceIssue(snapshot.trading_style_score,reason);
      AppendSourceIssue(snapshot.strategy_selection_score,reason);
      snapshot.invalid_reason=reason;
     }

   bool BuildSnapshot(const string symbol,SDecisionScoreSnapshot &snapshot)
     {
      ResetSnapshot(snapshot,symbol);
      if(m_data_bus==NULL)
         return(false);

      LoadSymbolSource("MarketSelection",FENX_DATABUS_NAMESPACE_MARKET_SELECTION,
                       symbol,FENX_DATABUS_FIELD_MARKET_SELECTION_SCORE,
                       FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT,
                       snapshot.market_selection_score);
      LoadSymbolSource("PairRanking",FENX_DATABUS_NAMESPACE_PAIR_RANKING,
                       symbol,FENX_DATABUS_FIELD_PAIR_RANKING_SCORE,
                       FENX_DATABUS_FIELD_PAIR_RANKING_UPDATED_AT,
                       snapshot.pair_ranking_score);
      LoadSymbolSource("CapitalAllocation",FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,
                       symbol,FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_SCORE,
                       FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_UPDATED_AT,
                       snapshot.capital_allocation_score);
      LoadSymbolSource("TradingStyle",FENX_DATABUS_NAMESPACE_TRADING_STYLE,
                       symbol,FENX_DATABUS_FIELD_TRADING_STYLE_SCORE,
                       FENX_DATABUS_FIELD_TRADING_STYLE_UPDATED_AT,
                       snapshot.trading_style_score);
      LoadSymbolSource("StrategySelection",FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,
                       symbol,FENX_DATABUS_FIELD_STRATEGY_SELECTION_SCORE,
                       FENX_DATABUS_FIELD_STRATEGY_SELECTION_UPDATED_AT,
                       snapshot.strategy_selection_score);

      bool validity=false;
      bool found=ReadGlobalBoolean(FENX_DATABUS_KEY_PAIR_RANKING_DATA_VALID,validity);
      ApplyPublishedValidity(found,validity,snapshot.pair_ranking_score);
      found=ReadGlobalBoolean(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_DATA_VALID,validity);
      ApplyPublishedValidity(found,validity,snapshot.capital_allocation_score);
      found=ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                              FENX_DATABUS_FIELD_TRADING_STYLE_IS_VALID,validity);
      ApplyPublishedValidity(found,validity,snapshot.trading_style_score);
      found=ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,symbol,
                              FENX_DATABUS_FIELD_STRATEGY_SELECTION_IS_VALID,validity);
      ApplyPublishedValidity(found,validity,snapshot.strategy_selection_score);

      FinalizeFreshness(snapshot.market_selection_score);
      FinalizeFreshness(snapshot.pair_ranking_score);
      FinalizeFreshness(snapshot.capital_allocation_score);
      FinalizeFreshness(snapshot.trading_style_score);
      FinalizeFreshness(snapshot.strategy_selection_score);
      CalculateStatistics(snapshot);
      return(true);
     }

   bool SameSource(const SDecisionScoreSourceSnapshot &left,
                   const SDecisionScoreSourceSnapshot &right)
     {
      return(left.source_name==right.source_name && left.score==right.score &&
             left.is_present==right.is_present && left.is_valid==right.is_valid &&
             left.is_fresh==right.is_fresh && left.updated_at==right.updated_at &&
             left.invalid_reason==right.invalid_reason);
     }

   bool SameSnapshot(const SDecisionScoreSnapshot &left,
                     const SDecisionScoreSnapshot &right)
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
             SameSource(left.market_selection_score,right.market_selection_score) &&
             SameSource(left.pair_ranking_score,right.pair_ranking_score) &&
             SameSource(left.capital_allocation_score,right.capital_allocation_score) &&
             SameSource(left.trading_style_score,right.trading_style_score) &&
             SameSource(left.strategy_selection_score,right.strategy_selection_score) &&
             left.average_score==right.average_score &&
             left.minimum_score==right.minimum_score &&
             left.maximum_score==right.maximum_score &&
             left.score_range==right.score_range &&
             left.score_variance==right.score_variance &&
             left.score_standard_deviation==right.score_standard_deviation &&
             left.bottleneck_stage==right.bottleneck_stage &&
             left.strongest_stage==right.strongest_stage &&
             left.all_sources_aligned==right.all_sources_aligned &&
             left.source_disagreement==right.source_disagreement &&
             left.disagreement_magnitude==right.disagreement_magnitude);
     }

   bool StoreTypedSnapshot(const int symbol_index,const SDecisionScoreSnapshot &snapshot)
     {
      if(m_snapshot_store==NULL ||
         !m_snapshot_store.SetDecisionScoreSnapshot(snapshot.symbol,RuntimeTimeframe(),snapshot))
         return(false);
      if(m_consistency_verified[symbol_index])
         return(true);
      SDecisionScoreSnapshot stored;
      if(!m_snapshot_store.GetDecisionScoreSnapshot(snapshot.symbol,RuntimeTimeframe(),stored))
         return(false);
      return(SameSnapshot(snapshot,stored));
     }

   bool PublishField(const string symbol,const string field,const string value,
                     const bool verify)
     {
      if(m_data_bus==NULL ||
         !m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_COMMON_DECISION,
                                   symbol,field,value))
         return(false);
      if(verify)
        {
         string stored="";
         if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_COMMON_DECISION,
                                         symbol,field,stored) || stored!=value)
            return(false);
        }
      return(true);
     }

   bool PublishSnapshot(const int symbol_index,const SDecisionScoreSnapshot &snapshot)
     {
      const bool verify=!m_consistency_verified[symbol_index];
      bool success=true;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_DECISION_VALID,
                       (snapshot.is_valid ? "true" : "false"),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_DECISION_FRESH,
                       (snapshot.is_fresh ? "true" : "false"),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_DECISION_STATE,
                       snapshot.validity_state,verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_DECISION_VERSION,
                       snapshot.snapshot_version,verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_DECISION_UPDATED_AT,
                       TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS),verify)) success=false;
      // Timeframe is the only extra summary field required by the Task011
      // consumer. Publishing the snapshot identity prevents a score produced
      // for another chart period from being used to block an entry.
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_DECISION_TIMEFRAME,
                       snapshot.timeframe,verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_DECISION_AVERAGE,
                       DoubleToString(snapshot.average_score,6),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_DECISION_MINIMUM,
                       DoubleToString(snapshot.minimum_score,6),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_DECISION_MAXIMUM,
                       DoubleToString(snapshot.maximum_score,6),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_DECISION_VARIANCE,
                       DoubleToString(snapshot.score_variance,6),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_DECISION_COMPLETENESS,
                       DoubleToString(snapshot.completeness_ratio,2),verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_DECISION_BOTTLENECK_STAGE,
                       snapshot.bottleneck_stage,verify)) success=false;
      if(!PublishField(snapshot.symbol,FENX_DATABUS_FIELD_COMMON_DECISION_STRONGEST_STAGE,
                       snapshot.strongest_stage,verify)) success=false;
      return(success);
     }

   void PublishTelemetry(const int symbol_index,const SDecisionScoreSnapshot &snapshot)
     {
      if(m_data_bus!=NULL && m_data_bus.ContextViewActive())
         return;
      const datetime bar_time=iTime(snapshot.symbol,RuntimeTimeframe(),0);
      if(bar_time<=0 || bar_time==m_last_telemetry_bar[symbol_index])
         return;
      m_last_telemetry_bar[symbol_index]=bar_time;
      CLogger::Info(StringFormat(
         "[DECISION_SCORE_TELEMETRY] Time=%s;Symbol=%s;Timeframe=%s;Direction=UNKNOWN;Average=%.6f;Minimum=%.6f;Maximum=%.6f;Variance=%.6f;Completeness=%.2f;BottleneckStage=%s;StrongestStage=%s;Validity=%s;AllSourcesAligned=%s;SourceDisagreement=%s;DisagreementMagnitude=%.6f;Task007Block=UNKNOWN;C3Block=UNKNOWN;EntryAllowed=UNKNOWN;EntryQualityScore=NA",
         TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS),snapshot.symbol,
         snapshot.timeframe,snapshot.average_score,snapshot.minimum_score,
         snapshot.maximum_score,snapshot.score_variance,snapshot.completeness_ratio,
         snapshot.bottleneck_stage,snapshot.strongest_stage,snapshot.validity_state,
         (snapshot.all_sources_aligned ? "true" : "false"),
         (snapshot.source_disagreement ? "true" : "false"),
         snapshot.disagreement_magnitude));
     }

   bool LoadSymbols(CParameterManager &parameters)
     {
      SRuntimeContextId context_id;
      const bool context_bound=(m_data_bus!=NULL &&
                                m_data_bus.GetActiveContextId(context_id));
      const int symbol_count=(context_bound ? 1 :
                              parameters.MarketSelectionSymbolCount());
      if(symbol_count<1 ||
         ArrayResize(m_symbols,symbol_count)!=symbol_count ||
         ArrayResize(m_consistency_verified,symbol_count)!=symbol_count ||
         ArrayResize(m_initial_status_logged,symbol_count)!=symbol_count ||
         ArrayResize(m_valid_snapshot_logged,symbol_count)!=symbol_count ||
         ArrayResize(m_last_telemetry_bar,symbol_count)!=symbol_count)
         return(false);
      for(int index=0;index<symbol_count;index++)
        {
         if(context_bound)
            m_symbols[index]=context_id.symbol;
         else if(!parameters.TryGetMarketSelectionSymbol(index,m_symbols[index]))
            return(false);
         m_consistency_verified[index]=false;
         m_initial_status_logged[index]=false;
         m_valid_snapshot_logged[index]=false;
         m_last_telemetry_bar[index]=0;
        }
      return(true);
     }

public:
                     CDecisionScoreEngine(void)
     {
      SetName("DecisionScoreEngine");
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
         CLogger::Error("DecisionScoreEngine requires CommonSnapshotStore before initialization.");
         return(false);
        }
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);
      m_freshness_limit_seconds=parameters.RiskStaleDataLimitSeconds();
      if(m_freshness_limit_seconds<1 || !LoadSymbols(parameters))
        {
         CLogger::Error("DecisionScoreEngine could not load its source contract.");
         CBaseEngine::Shutdown();
         return(false);
        }
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;
      for(int index=0;index<ArraySize(m_symbols);index++)
        {
         SDecisionScoreSnapshot snapshot;
         if(!BuildSnapshot(m_symbols[index],snapshot))
           {
            CLogger::Error("DecisionScoreEngine could not collect its source contract.");
            continue;
           }
         if(!StoreTypedSnapshot(index,snapshot))
           {
            CLogger::Error("DecisionScoreEngine could not store or verify its typed snapshot.");
            continue;
           }
         if(!PublishSnapshot(index,snapshot))
           {
            CLogger::Error("DecisionScoreEngine could not publish its shadow summary.");
            continue;
           }

         if(!m_consistency_verified[index])
           {
            CLogger::Info(StringFormat(
               "[COMMON_DECISION] typed_databus_consistency=PASS;symbol=%s;timeframe=%s;store_count=%d;keys=%d",
               snapshot.symbol,snapshot.timeframe,
               m_snapshot_store.DecisionScoreSnapshotCount(),
               FENX_COMMON_DECISION_PER_SYMBOL_KEY_COUNT));
            m_consistency_verified[index]=true;
           }
         if(!m_initial_status_logged[index])
           {
            CLogger::Info(StringFormat(
               "[COMMON_DECISION] initial_status=%s;symbol=%s;valid_sources=%d;missing_sources=%d;completeness=%.2f;reason=%s",
               snapshot.validity_state,snapshot.symbol,snapshot.valid_source_count,
               snapshot.missing_source_count,snapshot.completeness_ratio,
               snapshot.invalid_reason));
            m_initial_status_logged[index]=true;
           }
         if(snapshot.is_valid && !m_valid_snapshot_logged[index])
           {
            CLogger::Info(StringFormat(
               "[COMMON_DECISION] snapshot=VALID;symbol=%s;average=%.6f;minimum=%.6f;maximum=%.6f;variance=%.6f;bottleneck=%s;strongest=%s",
               snapshot.symbol,snapshot.average_score,snapshot.minimum_score,
               snapshot.maximum_score,snapshot.score_variance,
               snapshot.bottleneck_stage,snapshot.strongest_stage));
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
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_DECISION_SCORE_ENGINE_MQH
