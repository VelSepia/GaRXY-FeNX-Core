//+------------------------------------------------------------------+
//|                             PairRanking/PairRankingEngine.mqh  |
//+------------------------------------------------------------------+
#ifndef FENX_PAIR_RANKING_ENGINE_MQH
#define FENX_PAIR_RANKING_ENGINE_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Common/CommonSnapshotStore.mqh"
#include "../Engine/BaseEngine.mqh"
#include "../Portfolio/GlobalPortfolioSnapshotStore.mqh"

//--- Shared Environment facts read from CDataBus once for each ranking cycle.
struct SRankingEnvironment
  {
   double   atr;
   double   volatility_score;
   double   range_score;
   double   trend_score;
   double   market_confidence;
   bool     is_range;
   bool     is_trend;
   bool     range_data_valid;
   bool     trend_data_valid;
   string   market_state;
   datetime updated_at;
  };

//--- Per-symbol facts published by CMarketSelectionEngine through CDataBus.
struct SSelectionRankingInput
  {
   string   symbol;
   bool     is_market_eligible;
   double   selection_score;
   double   selection_confidence;
   double   spread_points;
   double   spread_to_atr_ratio;
   string   rejection_reason;
   datetime updated_at;
  };

//--- Per-symbol ranking output. No allocation or trading intent is represented here.
struct SPairRankingSnapshot
  {
   string   symbol;
   int      rank;
   double   score;
   double   confidence;
   bool     is_ranked;
   string   reason;
   datetime updated_at;
  };

//--- Candidate reference used only while deterministically sorting one update cycle.
struct SPairRankingCandidate
  {
   int    snapshot_index;
   double spread_cost;
  };

//--- Global ranking facts published after the per-symbol ranking pass.
struct SGlobalRankingSnapshot
  {
   int      ranked_symbol_count;
   string   top_ranked_symbol;
   double   top_ranking_score;
   bool     data_valid;
   datetime updated_at;
  };

//--- Compares eligible symbol facts without capital allocation, strategy selection, or execution.
class CPairRankingEngine : public CBaseEngine
  {
private:
   string m_symbols[];
   int    m_max_data_age_seconds;
   double m_max_spread_points;
   double m_max_spread_to_atr_ratio;
   double m_min_volatility_score;
   double m_max_volatility_score;
   double m_weight_selection_score;
   double m_weight_selection_confidence;
   double m_weight_spread_efficiency;
   double m_weight_environment_confidence;
   double m_weight_volatility_suitability;
   double m_weight_regime_suitability;
   double m_weight_freshness;
   CGlobalPortfolioSnapshotStore *m_portfolio_store;
   CCommonSnapshotStore          *m_common_snapshot_store;
   SPortfolioContextDefinition    m_portfolio_contexts[];

   void ResetPairSnapshot(SPairRankingSnapshot &snapshot,const string symbol)
     {
      snapshot.symbol=symbol;
      snapshot.rank=0;
      snapshot.score=0.0;
      snapshot.confidence=0.0;
      snapshot.is_ranked=false;
      snapshot.reason="";
      snapshot.updated_at=TimeCurrent();
     }

   void ResetGlobalSnapshot(SGlobalRankingSnapshot &snapshot)
     {
      snapshot.ranked_symbol_count=0;
      snapshot.top_ranked_symbol="";
      snapshot.top_ranking_score=0.0;
      snapshot.data_valid=false;
      snapshot.updated_at=TimeCurrent();
     }

   double ClampScore(const double value)
     {
      return(MathMax(0.0,MathMin(100.0,value)));
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

   bool ReadBoolean(const string key,bool &value)
     {
      if(m_data_bus==NULL)
         return(false);

      string text="";
      return(m_data_bus.TryGetText(key,text) && ReadBooleanText(text,value));
     }

   bool ReadTimestampText(const string text,datetime &value)
     {
      if(StringLen(text)==0)
         return(false);

      value=StringToTime(text);
      return(value>0);
     }

   bool ReadEnvironment(SRankingEnvironment &environment)
     {
      if(m_data_bus==NULL)
         return(false);

      double atr=0.0;
      double volatility_score=0.0;
      double range_score=0.0;
      double trend_score=0.0;
      double market_confidence=0.0;
      bool is_range=false;
      bool is_trend=false;
      bool range_data_valid=false;
      bool trend_data_valid=false;
      string market_state="";
      string updated_at_text="";
      datetime updated_at=0;
      if(!ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_ATR,atr) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,volatility_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,range_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_SCORE,trend_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_CONFIDENCE,market_confidence) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_IS_RANGE,is_range) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_IS_TREND,is_trend) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,range_data_valid) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DATA_VALID,trend_data_valid) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE,market_state) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT,
                                updated_at_text) ||
         !ReadTimestampText(updated_at_text,updated_at))
         return(false);

      environment.atr=atr;
      environment.volatility_score=volatility_score;
      environment.range_score=range_score;
      environment.trend_score=trend_score;
      environment.market_confidence=market_confidence;
      environment.is_range=is_range;
      environment.is_trend=is_trend;
      environment.range_data_valid=range_data_valid;
      environment.trend_data_valid=trend_data_valid;
      environment.market_state=market_state;
      environment.updated_at=updated_at;

      if(environment.atr<=0.0 || environment.volatility_score<0.0 ||
         environment.volatility_score>100.0 || environment.range_score<0.0 ||
         environment.range_score>100.0 || environment.market_confidence<0.0 ||
         environment.market_confidence>100.0 || !environment.range_data_valid ||
         !environment.trend_data_valid)
         return(false);

      return(environment.market_state=="RANGING" || environment.market_state=="TRENDING" ||
             environment.market_state=="VOLATILE" || environment.market_state=="TRANSITION");
     }

   bool ReadSelectionInput(const string symbol,SSelectionRankingInput &source)
     {
      if(m_data_bus==NULL)
         return(false);

      string input_symbol="";
      string text="";
      string rejection_reason="";
      string updated_at_text="";
      bool is_market_eligible=false;
      datetime updated_at=0;
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_MARKET_SELECTION_SYMBOL,input_symbol) ||
         input_symbol!=symbol ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_MARKET_SELECTION_IS_ELIGIBLE,text) ||
         !ReadBooleanText(text,is_market_eligible) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_MARKET_SELECTION_SCORE,text))
         return(false);

      source.symbol=input_symbol;
      source.is_market_eligible=is_market_eligible;
      source.selection_score=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_MARKET_SELECTION_CONFIDENCE,text))
         return(false);
      source.selection_confidence=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_POINTS,text))
         return(false);
      source.spread_points=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_ATR,text))
         return(false);
      source.spread_to_atr_ratio=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_MARKET_SELECTION_REJECTION,
                                      rejection_reason) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT,
                                      updated_at_text) ||
         !ReadTimestampText(updated_at_text,updated_at))
         return(false);

      source.rejection_reason=rejection_reason;
      source.updated_at=updated_at;
      return(source.selection_score>=0.0 && source.selection_score<=100.0 &&
             source.selection_confidence>=0.0 && source.selection_confidence<=100.0 &&
             source.spread_points>=0.0 && source.spread_to_atr_ratio>=0.0);
     }

   bool CalculateFreshness(const datetime updated_at,double &freshness_score)
     {
      if(updated_at<=0 || m_max_data_age_seconds<=0)
         return(false);

      const long age_seconds=(long)(TimeCurrent()-updated_at);
      if(age_seconds<0 || age_seconds>m_max_data_age_seconds)
         return(false);

      freshness_score=ClampScore(100.0*(1.0-((double)age_seconds/m_max_data_age_seconds)));
      return(true);
     }

   double CalculateSpreadEfficiency(const SSelectionRankingInput &source)
     {
      if(m_max_spread_points<=0.0 || m_max_spread_to_atr_ratio<=0.0)
         return(0.0);

      // Point and ATR-relative spread are combined once as one spread-efficiency factor.
      const double point_score=ClampScore(100.0*(1.0-(source.spread_points/m_max_spread_points)));
      const double atr_score=ClampScore(100.0*(1.0-
                                    (source.spread_to_atr_ratio/m_max_spread_to_atr_ratio)));
      return((point_score+atr_score)/2.0);
     }

   double CalculateVolatilitySuitability(const double volatility_score)
     {
      if(volatility_score<=0.0 || m_min_volatility_score<=0.0 ||
         m_max_volatility_score<=m_min_volatility_score)
         return(0.0);

      if(volatility_score<m_min_volatility_score)
         return(ClampScore(100.0*volatility_score/m_min_volatility_score));
      if(volatility_score>m_max_volatility_score)
         return(ClampScore(100.0*m_max_volatility_score/volatility_score));

      return(100.0);
     }

   double CalculateRegimeSuitability(const SRankingEnvironment &environment)
     {
      // Only the regime compatible with MarketState contributes; range and trend are never added together.
      if(environment.market_state=="RANGING")
         return(environment.is_range ? ClampScore(environment.range_score) : 0.0);
      if(environment.market_state=="TRENDING")
         return(environment.is_trend ? ClampScore(MathAbs(environment.trend_score)) : 0.0);
      if(environment.market_state=="TRANSITION")
         return(50.0);

      return(0.0);
     }

   void BuildRankedSnapshot(const SSelectionRankingInput &source,
                            const SRankingEnvironment &environment,
                            const double freshness_score,SPairRankingSnapshot &snapshot)
     {
      const double spread_efficiency=CalculateSpreadEfficiency(source);
      const double volatility_suitability=CalculateVolatilitySuitability(environment.volatility_score);
      const double regime_suitability=CalculateRegimeSuitability(environment);
      snapshot.score=ClampScore((m_weight_selection_score*source.selection_score)+
                                (m_weight_selection_confidence*source.selection_confidence)+
                                (m_weight_spread_efficiency*spread_efficiency)+
                                (m_weight_environment_confidence*environment.market_confidence)+
                                (m_weight_volatility_suitability*volatility_suitability)+
                                (m_weight_regime_suitability*regime_suitability)+
                                (m_weight_freshness*freshness_score));
      snapshot.confidence=ClampScore((0.40*source.selection_confidence)+
                                     (0.35*environment.market_confidence)+
                                     (0.25*freshness_score));
      snapshot.is_ranked=true;
      snapshot.reason="Ranked eligible symbol.";
     }

   bool HasHigherPriority(const SPairRankingCandidate &left,
                          const SPairRankingCandidate &right,
                          SPairRankingSnapshot &snapshots[])
     {
      if(snapshots[left.snapshot_index].score>
         snapshots[right.snapshot_index].score+FENX_PAIR_RANKING_COMPARE_EPSILON)
         return(true);
      if(snapshots[right.snapshot_index].score>
         snapshots[left.snapshot_index].score+FENX_PAIR_RANKING_COMPARE_EPSILON)
         return(false);

      if(snapshots[left.snapshot_index].confidence>
         snapshots[right.snapshot_index].confidence+FENX_PAIR_RANKING_COMPARE_EPSILON)
         return(true);
      if(snapshots[right.snapshot_index].confidence>
         snapshots[left.snapshot_index].confidence+FENX_PAIR_RANKING_COMPARE_EPSILON)
         return(false);

      if(left.spread_cost<right.spread_cost-FENX_PAIR_RANKING_COMPARE_EPSILON)
         return(true);
      if(right.spread_cost<left.spread_cost-FENX_PAIR_RANKING_COMPARE_EPSILON)
         return(false);

      return(StringCompare(snapshots[left.snapshot_index].symbol,
                           snapshots[right.snapshot_index].symbol)<0);
     }

   void SortCandidates(SPairRankingCandidate &candidates[],SPairRankingSnapshot &snapshots[])
     {
      for(int first=0;first<ArraySize(candidates)-1;first++)
        {
         int best=first;
         for(int next=first+1;next<ArraySize(candidates);next++)
           {
            if(HasHigherPriority(candidates[next],candidates[best],snapshots))
               best=next;
           }

         if(best!=first)
           {
            const int first_snapshot_index=candidates[first].snapshot_index;
            const double first_spread_cost=candidates[first].spread_cost;
            candidates[first].snapshot_index=candidates[best].snapshot_index;
            candidates[first].spread_cost=candidates[best].spread_cost;
            candidates[best].snapshot_index=first_snapshot_index;
            candidates[best].spread_cost=first_spread_cost;
           }
        }
     }

   bool PublishPairSnapshot(SPairRankingSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      bool success=true;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,snapshot.symbol,
                                   FENX_DATABUS_FIELD_PAIR_RANKING_SYMBOL,snapshot.symbol))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,snapshot.symbol,
                                   FENX_DATABUS_FIELD_PAIR_RANKING_RANK,
                                   IntegerToString(snapshot.rank)))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,snapshot.symbol,
                                   FENX_DATABUS_FIELD_PAIR_RANKING_SCORE,
                                   DoubleToString(snapshot.score,2)))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,snapshot.symbol,
                                   FENX_DATABUS_FIELD_PAIR_RANKING_CONFIDENCE,
                                   DoubleToString(snapshot.confidence,2)))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,snapshot.symbol,
                                   FENX_DATABUS_FIELD_PAIR_RANKING_IS_RANKED,
                                   (snapshot.is_ranked ? "true" : "false")))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,snapshot.symbol,
                                   FENX_DATABUS_FIELD_PAIR_RANKING_REASON,snapshot.reason))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,snapshot.symbol,
                                   FENX_DATABUS_FIELD_PAIR_RANKING_UPDATED_AT,
                                   TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS)))
         success=false;

      return(success);
     }

   bool PublishGlobalSnapshot(SGlobalRankingSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      bool success=true;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_PAIR_RANKING_SYMBOL_COUNT,
                             IntegerToString(snapshot.ranked_symbol_count)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_PAIR_RANKING_TOP_SYMBOL,
                             snapshot.top_ranked_symbol))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_PAIR_RANKING_TOP_SCORE,
                             DoubleToString(snapshot.top_ranking_score,2)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_PAIR_RANKING_DATA_VALID,
                             (snapshot.data_valid ? "true" : "false")))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_PAIR_RANKING_UPDATED_AT,
                             TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS)))
         success=false;

      return(success);
     }

   bool LoadSymbols(CParameterManager &parameters)
     {
      const int symbol_count=parameters.MarketSelectionSymbolCount();
      if(symbol_count<1 || symbol_count>FENX_MARKET_SELECTION_MAX_SYMBOLS ||
         ArrayResize(m_symbols,symbol_count)!=symbol_count)
         return(false);

      for(int index=0;index<symbol_count;index++)
        {
         string configured_symbol="";

         if(!parameters.TryGetMarketSelectionSymbol(index,configured_symbol))

            return(false);

         m_symbols[index]=configured_symbol;
        }

      return(true);
     }

   bool ReadContextText(const string name_space,
                        const SRuntimeContextId &context_id,
                        const string field,string &value)
     {
      return(m_data_bus!=NULL && m_data_bus.TryGetContextText(
             name_space,context_id,field,value));
     }

   bool ReadContextDouble(const string name_space,
                          const SRuntimeContextId &context_id,
                          const string field,double &value)
     {
      string text="";
      if(!ReadContextText(name_space,context_id,field,text) || StringLen(text)==0)
         return(false);
      value=StringToDouble(text);
      return(true);
     }

   bool ReadContextBoolean(const string name_space,
                           const SRuntimeContextId &context_id,
                           const string field,bool &value)
     {
      string text="";
      return(ReadContextText(name_space,context_id,field,text) &&
             ReadBooleanText(text,value));
     }

   //--- Reads the same rounded context fields used by the primary legacy path.
   //--- The typed Environment snapshot is consulted only for source timestamps
   //--- and identity linkage; it is not a new score or filter.
   bool ReadContextEnvironment(const SRuntimeContextId &context_id,
                               SRankingEnvironment &environment,
                               SPortfolioCandidateSnapshot &audit)
     {
      string updated_text="";
      if(!ReadContextDouble(FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,context_id,
                            "ATR",environment.atr) ||
         !ReadContextDouble(FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,context_id,
                            "Score",environment.volatility_score) ||
         !ReadContextDouble(FENX_DATABUS_NAMESPACE_CONTEXT_RANGE,context_id,
                            "Score",environment.range_score) ||
         !ReadContextDouble(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,context_id,
                            "Score",environment.trend_score) ||
         !ReadContextDouble(FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,context_id,
                            "Confidence",environment.market_confidence) ||
         !ReadContextBoolean(FENX_DATABUS_NAMESPACE_CONTEXT_RANGE,context_id,
                             "IsRange",environment.is_range) ||
         !ReadContextBoolean(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,context_id,
                             "IsTrend",environment.is_trend) ||
         !ReadContextBoolean(FENX_DATABUS_NAMESPACE_CONTEXT_RANGE,context_id,
                             "IsDataValid",environment.range_data_valid) ||
         !ReadContextBoolean(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,context_id,
                             "IsDataValid",environment.trend_data_valid) ||
         !ReadContextText(FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,context_id,
                          "State",environment.market_state) ||
         !ReadContextText(FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,context_id,
                          "UpdatedAt",updated_text) ||
         !ReadTimestampText(updated_text,environment.updated_at))
         return(false);

      SEnvironmentSnapshot typed;
      if(m_common_snapshot_store==NULL ||
         !m_common_snapshot_store.GetEnvironmentSnapshot(
            context_id.symbol,context_id.timeframe,typed) ||
         typed.symbol!=context_id.symbol ||
         typed.timeframe!=EnumToString(context_id.timeframe))
         return(false);

      audit.environment_updated_at=environment.updated_at;
      audit.volatility_updated_at=typed.volatility_updated_at;
      audit.range_updated_at=typed.range_updated_at;
      audit.trend_updated_at=typed.trend_updated_at;
      audit.market_state_updated_at=typed.market_state_updated_at;
      audit.environment_atr=environment.atr;
      audit.environment_volatility_score=environment.volatility_score;
      audit.environment_range_score=environment.range_score;
      audit.environment_trend_score=environment.trend_score;
      audit.environment_confidence=environment.market_confidence;
      audit.environment_is_range=environment.is_range;
      audit.environment_is_trend=environment.is_trend;
      audit.environment_market_state=environment.market_state;

      if(environment.atr<=0.0 || environment.volatility_score<0.0 ||
         environment.volatility_score>100.0 || environment.range_score<0.0 ||
         environment.range_score>100.0 || environment.market_confidence<0.0 ||
         environment.market_confidence>100.0 || !environment.range_data_valid ||
         !environment.trend_data_valid)
         return(false);
      return(environment.market_state=="RANGING" ||
             environment.market_state=="TRENDING" ||
             environment.market_state=="VOLATILE" ||
             environment.market_state=="TRANSITION");
     }

   bool ReadContextSelection(const SRuntimeContextId &context_id,
                             SSelectionRankingInput &source,
                             SPortfolioCandidateSnapshot &audit)
     {
      string text="";
      string updated_text="";
      if(!ReadContextText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,context_id,
                          FENX_DATABUS_FIELD_MARKET_SELECTION_SYMBOL,source.symbol) ||
         source.symbol!=context_id.symbol ||
         !ReadContextText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,context_id,
                          FENX_DATABUS_FIELD_MARKET_SELECTION_IS_ELIGIBLE,text) ||
         !ReadBooleanText(text,source.is_market_eligible) ||
         !ReadContextDouble(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,context_id,
                            FENX_DATABUS_FIELD_MARKET_SELECTION_SCORE,
                            source.selection_score) ||
         !ReadContextDouble(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,context_id,
                            FENX_DATABUS_FIELD_MARKET_SELECTION_CONFIDENCE,
                            source.selection_confidence) ||
         !ReadContextDouble(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,context_id,
                            FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_POINTS,
                            source.spread_points) ||
         !ReadContextDouble(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,context_id,
                            FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_ATR,
                            source.spread_to_atr_ratio) ||
         !ReadContextText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,context_id,
                          FENX_DATABUS_FIELD_MARKET_SELECTION_REJECTION,
                          source.rejection_reason) ||
         !ReadContextText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,context_id,
                          FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT,
                          updated_text) ||
         !ReadTimestampText(updated_text,source.updated_at))
         return(false);

      audit.market_eligible=source.is_market_eligible;
      audit.selection_score=source.selection_score;
      audit.selection_confidence=source.selection_confidence;
      audit.spread_points=source.spread_points;
      audit.spread_to_atr_ratio=source.spread_to_atr_ratio;
      audit.selection_updated_at=source.updated_at;
      return(source.selection_score>=0.0 && source.selection_score<=100.0 &&
             source.selection_confidence>=0.0 && source.selection_confidence<=100.0 &&
             source.spread_points>=0.0 && source.spread_to_atr_ratio>=0.0);
     }

   //--- Primary context wins its symbol. Otherwise the earliest registered
   //--- available/eligible auxiliary owns the one portfolio unit for a symbol.
   //--- Registration order is only a duplicate-context selection policy; it is
   //--- never introduced into the established ranking tie-break.
   int PreferredPortfolioContext(const int context_index)
     {
      if(context_index<0 || context_index>=ArraySize(m_portfolio_contexts))
         return(-1);
      const string symbol=m_portfolio_contexts[context_index].config.id.symbol;
      int preferred=-1;
      for(int index=0;index<ArraySize(m_portfolio_contexts);index++)
        {
         const SPortfolioContextDefinition definition=m_portfolio_contexts[index];
         if(!definition.config.enabled || !definition.available ||
            definition.config.id.symbol!=symbol)
            continue;
         if(definition.config.role==FENX_CONTEXT_ROLE_PRIMARY_TRADING)
            return(index);
         if(preferred<0 || definition.registration_order<
                           m_portfolio_contexts[preferred].registration_order)
            preferred=index;
        }
      return(preferred);
     }

   void BuildShadowPortfolioRanking(void)
     {
      if(m_portfolio_store==NULL || m_common_snapshot_store==NULL ||
         ArraySize(m_portfolio_contexts)<1)
         return;

      const ulong started=GetMicrosecondCount();
      SGlobalPortfolioSnapshot portfolio;
      ResetGlobalPortfolioSnapshot(portfolio);
      portfolio.evaluation_sequence=m_portfolio_store.ExpectedSequence();
      portfolio.evaluation_time=TimeCurrent();
      portfolio.updated_at=portfolio.evaluation_time;
      portfolio.context_count=ArraySize(m_portfolio_contexts);

      SPortfolioCandidateSnapshot audits[];
      SPairRankingSnapshot ranking_snapshots[];
      if(ArrayResize(audits,portfolio.context_count)!=portfolio.context_count ||
         ArrayResize(ranking_snapshots,portfolio.context_count)!=portfolio.context_count)
         return;

      SPairRankingCandidate candidates[];
      bool all_source_data_valid=true;
      for(int index=0;index<portfolio.context_count;index++)
        {
         ResetPortfolioCandidateSnapshot(audits[index]);
         const SPortfolioContextDefinition definition=m_portfolio_contexts[index];
         audits[index].evaluation_sequence=portfolio.evaluation_sequence;
         audits[index].context_id=definition.config.id;
         audits[index].context_role=definition.config.role;
         audits[index].registration_order=definition.registration_order;
         audits[index].context_enabled=definition.config.enabled;
         audits[index].context_available=definition.available;
         audits[index].trade_enabled=definition.config.trade_enabled;
         audits[index].portfolio_eligible=(definition.config.enabled &&
                                           definition.available);
         audits[index].updated_at=portfolio.evaluation_time;
         ResetPairSnapshot(ranking_snapshots[index],definition.config.id.symbol);
         ranking_snapshots[index].updated_at=portfolio.evaluation_time;

         if(!definition.config.enabled)
           {
            audits[index].reason="Context is disabled.";
            continue;
           }
         if(!definition.available)
           {
            audits[index].reason="Context is unavailable.";
            continue;
           }
         portfolio.available_count++;
         const int preferred=PreferredPortfolioContext(index);
         if(preferred!=index)
           {
            audits[index].reason="Duplicate symbol timeframe is analysis-only.";
            portfolio.duplicate_symbol_context_count++;
            continue;
           }

         SRankingEnvironment environment;
         SSelectionRankingInput selection;
         if(!ReadContextEnvironment(definition.config.id,environment,audits[index]) ||
            !ReadContextSelection(definition.config.id,selection,audits[index]))
           {
            audits[index].reason="Context Environment or Market Selection data is unavailable or invalid.";
            all_source_data_valid=false;
            continue;
           }

         double environment_freshness=0.0;
         double selection_freshness=0.0;
         if(!CalculateFreshness(environment.updated_at,environment_freshness) ||
            !CalculateFreshness(selection.updated_at,selection_freshness))
           {
            audits[index].reason="Context Environment or Market Selection data is stale.";
            all_source_data_valid=false;
            continue;
           }
         if(!selection.is_market_eligible)
           {
            audits[index].reason="Market Selection rejected this context.";
            if(StringLen(selection.rejection_reason)>0)
               audits[index].reason=audits[index].reason+" "+selection.rejection_reason;
            continue;
           }
         portfolio.eligible_count++;
         if(environment.market_state=="VOLATILE")
           {
            audits[index].reason="Environment market state is VOLATILE.";
            continue;
           }

         const double freshness=MathMin(environment_freshness,selection_freshness);
         BuildRankedSnapshot(selection,environment,freshness,ranking_snapshots[index]);
         audits[index].is_candidate=true;
         audits[index].is_ranked=true;
         audits[index].ranking_score=ranking_snapshots[index].score;
         audits[index].ranking_confidence=ranking_snapshots[index].confidence;
         audits[index].ranking_updated_at=portfolio.evaluation_time;
         audits[index].reason=ranking_snapshots[index].reason;
         const int candidate_count=ArraySize(candidates);
         if(ArrayResize(candidates,candidate_count+1)!=(candidate_count+1))
            return;
         candidates[candidate_count].snapshot_index=index;
         candidates[candidate_count].spread_cost=selection.spread_to_atr_ratio;
        }

      SortCandidates(candidates,ranking_snapshots);
      for(int index=0;index<ArraySize(candidates);index++)
        {
         const int snapshot_index=candidates[index].snapshot_index;
         ranking_snapshots[snapshot_index].rank=index+1;
         audits[snapshot_index].rank=index+1;
        }
      portfolio.candidate_count=ArraySize(candidates);
      portfolio.excluded_count=portfolio.context_count-portfolio.candidate_count;
      portfolio.ranking_valid=all_source_data_valid;
      portfolio.is_fresh=all_source_data_valid;
      portfolio.ranking_runtime_microseconds=(long)(GetMicrosecondCount()-started);
      m_portfolio_store.BeginRankedEvaluation(portfolio,audits);
     }

public:
                     CPairRankingEngine(void)
     {
      SetName("PairRankingEngine");
      m_max_data_age_seconds=0;
      m_max_spread_points=0.0;
      m_max_spread_to_atr_ratio=0.0;
      m_min_volatility_score=0.0;
      m_max_volatility_score=0.0;
      m_weight_selection_score=0.0;
      m_weight_selection_confidence=0.0;
      m_weight_spread_efficiency=0.0;
      m_weight_environment_confidence=0.0;
      m_weight_volatility_suitability=0.0;
      m_weight_regime_suitability=0.0;
      m_weight_freshness=0.0;
      m_portfolio_store=NULL;
      m_common_snapshot_store=NULL;
     }

   //--- Optional shadow attachment. Legacy standalone callers need no change;
   //--- production and Task028 harnesses attach this before Initialize.
   bool              SetGlobalPortfolio(CGlobalPortfolioSnapshotStore &portfolio_store,
                                        CCommonSnapshotStore &snapshot_store,
                                        SPortfolioContextDefinition &contexts[])
     {
      if(m_initialized || ArraySize(contexts)<1 ||
         ArrayResize(m_portfolio_contexts,ArraySize(contexts))!=ArraySize(contexts))
         return(false);
      for(int index=0;index<ArraySize(contexts);index++)
        {
         if(!IsValidRuntimeContextId(contexts[index].config.id) ||
            contexts[index].registration_order<0)
            return(false);
         m_portfolio_contexts[index]=contexts[index];
        }
      m_portfolio_store=GetPointer(portfolio_store);
      m_common_snapshot_store=GetPointer(snapshot_store);
      return(true);
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_max_data_age_seconds=parameters.PairRankingMaxDataAgeSeconds();
      m_max_spread_points=parameters.MarketSelectionMaxSpreadPoints();
      m_max_spread_to_atr_ratio=parameters.MarketSelectionMaxSpreadToAtrRatio();
      m_min_volatility_score=parameters.MarketSelectionMinVolatilityScore();
      m_max_volatility_score=parameters.MarketSelectionMaxVolatilityScore();
      m_weight_selection_score=parameters.PairRankingWeightSelectionScore();
      m_weight_selection_confidence=parameters.PairRankingWeightSelectionConfidence();
      m_weight_spread_efficiency=parameters.PairRankingWeightSpreadEfficiency();
      m_weight_environment_confidence=parameters.PairRankingWeightEnvironmentConfidence();
      m_weight_volatility_suitability=parameters.PairRankingWeightVolatilitySuitability();
      m_weight_regime_suitability=parameters.PairRankingWeightRegimeSuitability();
      m_weight_freshness=parameters.PairRankingWeightFreshness();

      const double weight_total=m_weight_selection_score+m_weight_selection_confidence+
                                m_weight_spread_efficiency+m_weight_environment_confidence+
                                m_weight_volatility_suitability+m_weight_regime_suitability+
                                m_weight_freshness;
      if(!LoadSymbols(parameters) || m_max_data_age_seconds<=0 || m_max_spread_points<=0.0 ||
         m_max_spread_to_atr_ratio<=0.0 || m_min_volatility_score<=0.0 ||
         m_max_volatility_score<=m_min_volatility_score || m_weight_selection_score<0.0 ||
         m_weight_selection_confidence<0.0 || m_weight_spread_efficiency<0.0 ||
         m_weight_environment_confidence<0.0 || m_weight_volatility_suitability<0.0 ||
         m_weight_regime_suitability<0.0 || m_weight_freshness<0.0 ||
         MathAbs(weight_total-1.0)>FENX_PAIR_RANKING_COMPARE_EPSILON)
        {
         CLogger::Error("PairRankingEngine received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      CLogger::Info(StringFormat("PairRankingEngine configured for %d symbol(s).",
                                 ArraySize(m_symbols)));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;

      // Task032 production owns ranking through the typed global portfolio.
      // The retired single-symbol DataBus path is not executed once attached.
      if(m_portfolio_store!=NULL)
        {
         BuildShadowPortfolioRanking();
         return;
        }

      SRankingEnvironment environment;
      double environment_freshness=0.0;
      bool environment_valid=ReadEnvironment(environment);
      if(environment_valid)
         environment_valid=CalculateFreshness(environment.updated_at,environment_freshness);
      if(!environment_valid)
         CLogger::Warning("PairRankingEngine is waiting for valid, fresh Environment data.");

      const int symbol_count=ArraySize(m_symbols);
      SPairRankingSnapshot snapshots[];
      if(ArrayResize(snapshots,symbol_count)!=symbol_count)
        {
         CLogger::Error("PairRankingEngine could not allocate per-symbol snapshots.");
         return;
        }

      SPairRankingCandidate candidates[];
      bool all_selection_data_valid=true;
      for(int index=0;index<symbol_count;index++)
        {
         ResetPairSnapshot(snapshots[index],m_symbols[index]);
         if(!environment_valid)
           {
            snapshots[index].reason="Environment data is unavailable, invalid, or stale.";
            continue;
           }

         SSelectionRankingInput selection;
         if(!ReadSelectionInput(m_symbols[index],selection))
           {
            snapshots[index].reason="Market Selection data is unavailable or invalid.";
            all_selection_data_valid=false;
            continue;
           }

         double selection_freshness=0.0;
         if(!CalculateFreshness(selection.updated_at,selection_freshness))
           {
            snapshots[index].reason="Market Selection data is stale.";
            all_selection_data_valid=false;
            continue;
           }

         if(!selection.is_market_eligible)
           {
            snapshots[index].reason="Market Selection rejected this symbol.";
            if(StringLen(selection.rejection_reason)>0)
               snapshots[index].reason=snapshots[index].reason+" "+selection.rejection_reason;
            continue;
           }

         if(environment.market_state=="VOLATILE")
           {
            snapshots[index].reason="Environment market state is VOLATILE.";
            continue;
           }

         const double freshness_score=MathMin(environment_freshness,selection_freshness);
         BuildRankedSnapshot(selection,environment,freshness_score,snapshots[index]);
         const int candidate_count=ArraySize(candidates);
         if(ArrayResize(candidates,candidate_count+1)!=(candidate_count+1))
           {
            snapshots[index].is_ranked=false;
            snapshots[index].score=0.0;
            snapshots[index].confidence=0.0;
            snapshots[index].reason="Pair Ranking could not allocate a candidate.";
            all_selection_data_valid=false;
            CLogger::Error("PairRankingEngine could not allocate a ranking candidate.");
            continue;
           }

         candidates[candidate_count].snapshot_index=index;
         candidates[candidate_count].spread_cost=selection.spread_to_atr_ratio;
        }

      SortCandidates(candidates,snapshots);
      for(int index=0;index<ArraySize(candidates);index++)
        {
         const int snapshot_index=candidates[index].snapshot_index;
         snapshots[snapshot_index].rank=index+1;
        }

      SGlobalRankingSnapshot global_snapshot;
      ResetGlobalSnapshot(global_snapshot);
      global_snapshot.ranked_symbol_count=ArraySize(candidates);
      global_snapshot.data_valid=(environment_valid && all_selection_data_valid);
      if(ArraySize(candidates)>0)
        {
         const int top_snapshot_index=candidates[0].snapshot_index;
         global_snapshot.top_ranked_symbol=snapshots[top_snapshot_index].symbol;
         global_snapshot.top_ranking_score=snapshots[top_snapshot_index].score;
        }

      for(int index=0;index<symbol_count;index++)
        {
         if(!PublishPairSnapshot(snapshots[index]))
            CLogger::Error(StringFormat("PairRankingEngine could not publish %s.",
                                        snapshots[index].symbol));
        }
      if(!PublishGlobalSnapshot(global_snapshot))
         CLogger::Error("PairRankingEngine could not publish global ranking data.");

     }

   virtual void       Shutdown(void)
     {
      ArrayFree(m_symbols);
      ArrayFree(m_portfolio_contexts);
      m_portfolio_store=NULL;
      m_common_snapshot_store=NULL;
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_PAIR_RANKING_ENGINE_MQH

