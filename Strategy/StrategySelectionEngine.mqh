//+------------------------------------------------------------------+
//|                       Strategy/StrategySelectionEngine.mqh     |
//+------------------------------------------------------------------+
#ifndef FENX_STRATEGY_SELECTION_ENGINE_MQH
#define FENX_STRATEGY_SELECTION_ENGINE_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Shared Environment facts read through CDataBus for one selection cycle.
struct SStrategySelectionEnvironment
  {
   string   market_state;
   double   range_score;
   double   trend_score;
   double   volatility_score;
   bool     range_data_valid;
   bool     trend_data_valid;
   datetime market_updated_at;
   datetime range_updated_at;
   datetime trend_updated_at;
  };

//--- Global validity and freshness facts supplied by upstream recommendation engines.
struct SStrategySelectionPairGlobal
  {
   bool     data_valid;
   datetime updated_at;
  };

struct SStrategySelectionAllocationGlobal
  {
   bool     data_valid;
   datetime updated_at;
  };

struct SStrategySelectionStyleGlobal
  {
   bool     data_valid;
   datetime updated_at;
  };

//--- Per-symbol published facts needed to choose a non-executable strategy.
struct SStrategySelectionInput
  {
   string   symbol;
   string   trading_style;
   double   trading_style_score;
   double   trading_style_confidence;
   bool     is_trading_style_valid;
   datetime trading_style_updated_at;
   bool     is_pair_ranked;
   double   pair_ranking_score;
   datetime pair_ranking_updated_at;
   bool     is_capital_allocated;
   double   allocation_percent;
   datetime allocation_updated_at;
  };

//--- Per-symbol strategy recommendation. It contains no entry, exit, risk, or execution data.
struct SStrategySelectionSnapshot
  {
   string   symbol;
   string   selected_strategy;
   double   score;
   double   confidence;
   string   reason;
   bool     is_valid;
   datetime updated_at;
  };

//--- Global selection facts published after each update cycle.
struct SGlobalStrategySelectionSnapshot
  {
   int      active_strategy_count;
   int      no_trade_symbol_count;
   bool     data_valid;
   datetime updated_at;
  };

//--- Maps approved styles and factual market context to strategy recommendations only.
class CStrategySelectionEngine : public CBaseEngine
  {
private:
   string m_symbols[];
   double m_min_confidence;
   double m_min_allocation_percent;
   double m_min_ranking_score;
   double m_range_threshold;
   double m_trend_threshold;
   double m_breakout_volatility_threshold;
   double m_transition_penalty;
   int    m_stale_data_limit_seconds;
   double m_no_trade_safety_threshold;

   void ResetSnapshot(SStrategySelectionSnapshot &snapshot,const string symbol)
     {
      snapshot.symbol=symbol;
      snapshot.selected_strategy="NO_TRADE";
      snapshot.score=0.0;
      snapshot.confidence=0.0;
      snapshot.reason="";
      snapshot.is_valid=false;
      snapshot.updated_at=TimeCurrent();
     }

   void ResetGlobalSnapshot(SGlobalStrategySelectionSnapshot &snapshot)
     {
      snapshot.active_strategy_count=0;
      snapshot.no_trade_symbol_count=0;
      snapshot.data_valid=false;
      snapshot.updated_at=TimeCurrent();
     }

   double ClampPercent(const double value)
     {
      return(MathMax(0.0,MathMin(100.0,value)));
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

   bool ReadTimestampText(const string text,datetime &value)
     {
      if(StringLen(text)==0)
         return(false);

      value=StringToTime(text);
      return(value>0);
     }

   bool ReadEnvironment(SStrategySelectionEnvironment &environment)
     {
      if(m_data_bus==NULL)
         return(false);

      string market_state="";
      double range_score=0.0;
      double trend_score=0.0;
      double volatility_score=0.0;
      bool range_data_valid=false;
      bool trend_data_valid=false;
      string market_updated_at_text="";
      string range_updated_at_text="";
      string trend_updated_at_text="";
      datetime market_updated_at=0;
      datetime range_updated_at=0;
      datetime trend_updated_at=0;
      if(!m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE,market_state) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,range_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_SCORE,trend_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,volatility_score) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,range_data_valid) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DATA_VALID,trend_data_valid) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT,
                                market_updated_at_text) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPDATED_AT,
                                range_updated_at_text) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_TREND_UPDATED_AT,
                                trend_updated_at_text) ||
         !ReadTimestampText(market_updated_at_text,market_updated_at) ||
         !ReadTimestampText(range_updated_at_text,range_updated_at) ||
         !ReadTimestampText(trend_updated_at_text,trend_updated_at))
         return(false);

      environment.market_state=market_state;
      environment.range_score=range_score;
      // TrendScore is directional (-100..100); strategy thresholds use magnitude.
      environment.trend_score=MathAbs(trend_score);
      environment.volatility_score=volatility_score;
      environment.range_data_valid=range_data_valid;
      environment.trend_data_valid=trend_data_valid;
      environment.market_updated_at=market_updated_at;
      environment.range_updated_at=range_updated_at;
      environment.trend_updated_at=trend_updated_at;

      if(environment.range_score<0.0 || environment.range_score>100.0 ||
         environment.trend_score<0.0 || environment.trend_score>100.0 ||
         environment.volatility_score<0.0 || environment.volatility_score>100.0 ||
         !environment.range_data_valid || !environment.trend_data_valid)
         return(false);

      return(environment.market_state=="RANGING" || environment.market_state=="TRENDING" ||
             environment.market_state=="VOLATILE" || environment.market_state=="TRANSITION");
     }

   bool ReadPairGlobal(SStrategySelectionPairGlobal &ranking)
     {
      if(m_data_bus==NULL)
         return(false);

      bool data_valid=false;
      string updated_at_text="";
      datetime updated_at=0;
      if(!ReadBoolean(FENX_DATABUS_KEY_PAIR_RANKING_DATA_VALID,data_valid) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_PAIR_RANKING_UPDATED_AT,updated_at_text) ||
         !ReadTimestampText(updated_at_text,updated_at))
         return(false);

      ranking.data_valid=data_valid;
      ranking.updated_at=updated_at;
      return(true);
     }

   bool ReadAllocationGlobal(SStrategySelectionAllocationGlobal &allocation)
     {
      if(m_data_bus==NULL)
         return(false);

      bool data_valid=false;
      string updated_at_text="";
      datetime updated_at=0;
      if(!ReadBoolean(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_DATA_VALID,data_valid) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_UPDATED_AT,
                                updated_at_text) ||
         !ReadTimestampText(updated_at_text,updated_at))
         return(false);

      allocation.data_valid=data_valid;
      allocation.updated_at=updated_at;
      return(true);
     }

   bool ReadStyleGlobal(SStrategySelectionStyleGlobal &style)
     {
      if(m_data_bus==NULL)
         return(false);

      bool data_valid=false;
      string updated_at_text="";
      datetime updated_at=0;
      if(!ReadBoolean(FENX_DATABUS_KEY_TRADING_STYLE_DATA_VALID,data_valid) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_TRADING_STYLE_UPDATED_AT,
                                updated_at_text) ||
         !ReadTimestampText(updated_at_text,updated_at))
         return(false);

      style.data_valid=data_valid;
      style.updated_at=updated_at;
      return(true);
     }

   bool ReadSymbolInput(const string symbol,SStrategySelectionInput &source)
     {
      if(m_data_bus==NULL)
         return(false);

      string trading_style="";
      string text="";
      string style_updated_at_text="";
      string pair_updated_at_text="";
      string allocation_updated_at_text="";
      bool is_trading_style_valid=false;
      bool is_pair_ranked=false;
      bool is_capital_allocated=false;
      datetime trading_style_updated_at=0;
      datetime pair_ranking_updated_at=0;
      datetime allocation_updated_at=0;
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                                      FENX_DATABUS_FIELD_TRADING_STYLE,trading_style) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                                      FENX_DATABUS_FIELD_TRADING_STYLE_SCORE,text))
         return(false);

      source.trading_style=trading_style;
      source.trading_style_score=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                                      FENX_DATABUS_FIELD_TRADING_STYLE_CONFIDENCE,text))
         return(false);
      source.trading_style_confidence=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                                      FENX_DATABUS_FIELD_TRADING_STYLE_IS_VALID,text) ||
         !ReadBooleanText(text,is_trading_style_valid) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                                      FENX_DATABUS_FIELD_TRADING_STYLE_UPDATED_AT,
                                      style_updated_at_text) ||
         !ReadTimestampText(style_updated_at_text,trading_style_updated_at) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_IS_RANKED,text) ||
         !ReadBooleanText(text,is_pair_ranked) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_SCORE,text))
         return(false);

      source.is_trading_style_valid=is_trading_style_valid;
      source.trading_style_updated_at=trading_style_updated_at;
      source.is_pair_ranked=is_pair_ranked;
      source.pair_ranking_score=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_UPDATED_AT,
                                      pair_updated_at_text) ||
         !ReadTimestampText(pair_updated_at_text,pair_ranking_updated_at) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,symbol,
                                      FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_IS_ALLOCATED,text) ||
         !ReadBooleanText(text,is_capital_allocated) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,symbol,
                                      FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_PERCENT,text))
         return(false);

      source.pair_ranking_updated_at=pair_ranking_updated_at;
      source.is_capital_allocated=is_capital_allocated;
      source.allocation_percent=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,symbol,
                                      FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_UPDATED_AT,
                                      allocation_updated_at_text) ||
         !ReadTimestampText(allocation_updated_at_text,allocation_updated_at))
         return(false);

      source.allocation_updated_at=allocation_updated_at;
      return((source.trading_style=="RANGE" || source.trading_style=="TREND" ||
              source.trading_style=="HYBRID" || source.trading_style=="STANDBY") &&
             source.trading_style_score>=0.0 && source.trading_style_score<=100.0 &&
             source.trading_style_confidence>=0.0 && source.trading_style_confidence<=100.0 &&
             source.pair_ranking_score>=0.0 && source.pair_ranking_score<=100.0 &&
             source.allocation_percent>=0.0 && source.allocation_percent<=100.0);
     }

   bool CalculateFreshness(const datetime updated_at,double &freshness)
     {
      if(updated_at<=0 || m_stale_data_limit_seconds<=0)
         return(false);

      const long age_seconds=(long)(TimeCurrent()-updated_at);
      if(age_seconds<0 || age_seconds>m_stale_data_limit_seconds)
         return(false);

      freshness=ClampPercent(100.0*(1.0-((double)age_seconds/m_stale_data_limit_seconds)));
      return(true);
     }

   double CalculateSelectionConfidence(const SStrategySelectionEnvironment &environment,
                                       const SStrategySelectionInput &source,
                                       const double freshness)
     {
      double confidence=source.trading_style_confidence*(freshness/100.0);
      if(environment.market_state=="TRANSITION")
         confidence-=m_transition_penalty;

      return(ClampPercent(confidence));
     }

   double CalculateSelectionScore(const double signal_score,
                                  const SStrategySelectionInput &source,
                                  const double selection_confidence)
     {
      return(ClampPercent((0.40*signal_score)+(0.25*source.trading_style_score)+
                          (0.20*source.pair_ranking_score)+(0.15*selection_confidence)));
     }

   bool IsUnsafe(const SStrategySelectionEnvironment &environment,
                 const SStrategySelectionInput &source,string &reason)
     {
      if(!source.is_trading_style_valid)
        {
         reason="Trading Style data is invalid.";
         return(true);
        }
      if(source.trading_style=="STANDBY")
        {
         reason="Trading Style recommends STANDBY.";
         return(true);
        }
      if(!source.is_pair_ranked || source.pair_ranking_score<m_min_ranking_score)
        {
         reason="Pair Ranking score is below the strategy threshold.";
         return(true);
        }
      if(!source.is_capital_allocated || source.allocation_percent<m_min_allocation_percent)
        {
         reason="Capital allocation is below the strategy threshold.";
         return(true);
        }
      if(environment.market_state=="VOLATILE")
        {
         reason="VOLATILE market state is not approved for strategy selection.";
         return(true);
        }

      return(false);
     }

   void DecideStrategy(const SStrategySelectionEnvironment &environment,
                       const SStrategySelectionInput &source,const double freshness,
                       SStrategySelectionSnapshot &snapshot)
     {
      string unsafe_reason="";
      if(IsUnsafe(environment,source,unsafe_reason))
        {
         snapshot.reason=unsafe_reason;
         snapshot.is_valid=true;
         return;
        }

      if(source.trading_style_confidence<m_min_confidence)
        {
         snapshot.reason="Trading Style confidence is below the strategy threshold.";
         snapshot.confidence=source.trading_style_confidence;
         snapshot.is_valid=true;
         return;
        }

      const double confidence=CalculateSelectionConfidence(environment,source,freshness);
      if(confidence<m_no_trade_safety_threshold)
        {
         snapshot.reason="Post-penalty strategy confidence is below the NO_TRADE safety threshold.";
         snapshot.is_valid=true;
         snapshot.confidence=confidence;
         return;
        }

      const bool directional_breakout=(environment.market_state=="TRENDING" &&
                                       source.trading_style=="TREND" &&
                                       environment.trend_score>=m_trend_threshold);
      const bool transition_breakout=(environment.market_state=="TRANSITION" &&
                                      source.trading_style=="HYBRID" &&
                                      environment.trend_score>=0.70*m_trend_threshold &&
                                      environment.range_score>=0.70*m_range_threshold);
      const bool breakout_ready=(environment.volatility_score>=m_breakout_volatility_threshold &&
                                 (directional_breakout || transition_breakout));
      const bool range_ready=(source.trading_style=="RANGE" &&
                              environment.market_state=="RANGING" &&
                              environment.range_score>=m_range_threshold);
      const bool trend_ready=(source.trading_style=="TREND" &&
                              environment.market_state=="TRENDING" &&
                              environment.trend_score>=m_trend_threshold);
      const bool hybrid_ready=(source.trading_style=="HYBRID" &&
                               environment.market_state=="TRANSITION" &&
                               environment.range_score>=0.70*m_range_threshold &&
                               environment.trend_score>=0.70*m_trend_threshold);

      snapshot.confidence=confidence;
      snapshot.is_valid=true;
      if(breakout_ready)
        {
         snapshot.selected_strategy="BREAKOUT";
         snapshot.score=CalculateSelectionScore(environment.volatility_score,source,confidence);
         snapshot.reason="Strong volatility supports a directional or transition breakout mapping.";
         return;
        }
      if(range_ready)
        {
         snapshot.selected_strategy="RANGE_MEAN_REVERSION";
         snapshot.score=CalculateSelectionScore(environment.range_score,source,confidence);
         snapshot.reason="RANGE style and strong range conditions support mean reversion.";
         return;
        }
      if(trend_ready)
        {
         snapshot.selected_strategy="TREND_FOLLOWING";
         snapshot.score=CalculateSelectionScore(environment.trend_score,source,confidence);
         snapshot.reason="TREND style and strong trend conditions support trend following.";
         return;
        }
      if(hybrid_ready)
        {
         snapshot.selected_strategy="HYBRID_ADAPTIVE";
         const double mixed_signal=(environment.range_score+environment.trend_score)/2.0;
         snapshot.score=CalculateSelectionScore(mixed_signal,source,confidence);
         snapshot.reason="HYBRID style has valid mixed transition conditions.";
         return;
        }

      snapshot.reason="No strategy mapping met the configured safety and market thresholds.";
     }

   bool PublishSnapshot(SStrategySelectionSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      bool success=true;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_SELECTED_STRATEGY,
                                   snapshot.selected_strategy))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STRATEGY_SELECTION_SCORE,
                                   DoubleToString(snapshot.score,2)))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STRATEGY_SELECTION_CONFIDENCE,
                                   DoubleToString(snapshot.confidence,2)))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STRATEGY_SELECTION_REASON,snapshot.reason))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STRATEGY_SELECTION_IS_VALID,
                                   (snapshot.is_valid ? "true" : "false")))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STRATEGY_SELECTION_UPDATED_AT,
                                   TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS)))
         success=false;

      return(success);
     }

   bool PublishGlobalSnapshot(SGlobalStrategySelectionSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      bool success=true;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STRATEGY_SELECTION_ACTIVE_COUNT,
                             IntegerToString(snapshot.active_strategy_count)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STRATEGY_SELECTION_NO_TRADE_COUNT,
                             IntegerToString(snapshot.no_trade_symbol_count)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STRATEGY_SELECTION_DATA_VALID,
                             (snapshot.data_valid ? "true" : "false")))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STRATEGY_SELECTION_UPDATED_AT,
                             TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS)))
         success=false;

      return(success);
     }

   bool LoadSymbols(CParameterManager &parameters)
     {
      SRuntimeContextId context_id;
      if(m_data_bus!=NULL && m_data_bus.GetActiveContextId(context_id))
        {
         if(ArrayResize(m_symbols,1)!=1)
            return(false);
         m_symbols[0]=context_id.symbol;
         return(true);
        }
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

public:
                     CStrategySelectionEngine(void)
     {
      SetName("StrategySelectionEngine");
      m_min_confidence=0.0;
      m_min_allocation_percent=0.0;
      m_min_ranking_score=0.0;
      m_range_threshold=0.0;
      m_trend_threshold=0.0;
      m_breakout_volatility_threshold=0.0;
      m_transition_penalty=0.0;
      m_stale_data_limit_seconds=0;
      m_no_trade_safety_threshold=0.0;
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_min_confidence=parameters.StrategySelectionMinConfidence();
      m_min_allocation_percent=parameters.StrategySelectionMinAllocationPercent();
      m_min_ranking_score=parameters.StrategySelectionMinRankingScore();
      m_range_threshold=parameters.StrategySelectionRangeThreshold();
      m_trend_threshold=parameters.StrategySelectionTrendThreshold();
      m_breakout_volatility_threshold=parameters.StrategySelectionBreakoutVolatilityThreshold();
      m_transition_penalty=parameters.StrategySelectionTransitionPenalty();
      m_stale_data_limit_seconds=parameters.StrategySelectionStaleDataLimitSeconds();
      m_no_trade_safety_threshold=parameters.StrategySelectionNoTradeSafetyThreshold();

      if(!LoadSymbols(parameters) || m_min_confidence<=0.0 || m_min_confidence>100.0 ||
         m_min_allocation_percent<=0.0 || m_min_allocation_percent>100.0 ||
         m_min_ranking_score<=0.0 || m_min_ranking_score>100.0 ||
         m_range_threshold<=0.0 || m_range_threshold>100.0 ||
         m_trend_threshold<=0.0 || m_trend_threshold>100.0 ||
         m_breakout_volatility_threshold<=0.0 || m_breakout_volatility_threshold>100.0 ||
         m_transition_penalty<0.0 || m_transition_penalty>100.0 ||
         m_stale_data_limit_seconds<=0 || m_no_trade_safety_threshold<=0.0 ||
         m_no_trade_safety_threshold>100.0)
        {
         CLogger::Error("StrategySelectionEngine received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      CLogger::Info(StringFormat("StrategySelectionEngine configured for %d symbol(s).",
                                 ArraySize(m_symbols)));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;

      SStrategySelectionEnvironment environment;
      SStrategySelectionPairGlobal ranking_global;
      SStrategySelectionAllocationGlobal allocation_global;
      SStrategySelectionStyleGlobal style_global;
      double environment_freshness=0.0;
      double ranking_global_freshness=0.0;
      double allocation_global_freshness=0.0;
      double style_global_freshness=0.0;
      bool environment_valid=ReadEnvironment(environment);
      if(environment_valid)
        {
         double market_freshness=0.0;
         double range_freshness=0.0;
         double trend_freshness=0.0;
         environment_valid=CalculateFreshness(environment.market_updated_at,market_freshness) &&
                           CalculateFreshness(environment.range_updated_at,range_freshness) &&
                           CalculateFreshness(environment.trend_updated_at,trend_freshness);
         environment_freshness=MathMin(market_freshness,
                                       MathMin(range_freshness,trend_freshness));
        }

      bool ranking_global_valid=ReadPairGlobal(ranking_global);
      if(ranking_global_valid)
         ranking_global_valid=ranking_global.data_valid &&
                              CalculateFreshness(ranking_global.updated_at,
                                                 ranking_global_freshness);
      bool allocation_global_valid=ReadAllocationGlobal(allocation_global);
      if(allocation_global_valid)
         allocation_global_valid=allocation_global.data_valid &&
                                 CalculateFreshness(allocation_global.updated_at,
                                                    allocation_global_freshness);
      bool style_global_valid=ReadStyleGlobal(style_global);
      if(style_global_valid)
         style_global_valid=style_global.data_valid &&
                            CalculateFreshness(style_global.updated_at,style_global_freshness);
      if((!environment_valid || !ranking_global_valid || !allocation_global_valid ||
          !style_global_valid) &&
         (m_data_bus==NULL || !m_data_bus.ContextViewActive()))
         CLogger::Warning("StrategySelectionEngine is waiting for valid, fresh Environment, ranking, allocation, and style data.");

      const int symbol_count=ArraySize(m_symbols);
      SStrategySelectionSnapshot snapshots[];
      if(ArrayResize(snapshots,symbol_count)!=symbol_count)
        {
         CLogger::Error("StrategySelectionEngine could not allocate per-symbol snapshots.");
         return;
        }

      bool all_symbol_data_valid=true;
      for(int index=0;index<symbol_count;index++)
        {
         ResetSnapshot(snapshots[index],m_symbols[index]);
         if(!environment_valid || !ranking_global_valid || !allocation_global_valid ||
            !style_global_valid)
           {
            snapshots[index].reason="Environment, Pair Ranking, Capital Allocation, or Trading Style data is unavailable, invalid, or stale.";
            continue;
           }

         SStrategySelectionInput source;
         if(!ReadSymbolInput(m_symbols[index],source))
           {
            snapshots[index].reason="Trading Style, Pair Ranking, or Capital Allocation symbol data is unavailable or invalid.";
            all_symbol_data_valid=false;
            continue;
           }

         double style_freshness=0.0;
         double pair_freshness=0.0;
         double allocation_freshness=0.0;
         if(!CalculateFreshness(source.trading_style_updated_at,style_freshness) ||
            !CalculateFreshness(source.pair_ranking_updated_at,pair_freshness) ||
            !CalculateFreshness(source.allocation_updated_at,allocation_freshness))
           {
            snapshots[index].reason="Trading Style, Pair Ranking, or Capital Allocation symbol data is stale.";
            all_symbol_data_valid=false;
            continue;
           }

         const double freshness=MathMin(environment_freshness,
                                 MathMin(ranking_global_freshness,
                                 MathMin(allocation_global_freshness,
                                 MathMin(style_global_freshness,
                                 MathMin(style_freshness,
                                 MathMin(pair_freshness,allocation_freshness))))));
         DecideStrategy(environment,source,freshness,snapshots[index]);
        }

      SGlobalStrategySelectionSnapshot global_snapshot;
      ResetGlobalSnapshot(global_snapshot);
      global_snapshot.data_valid=(environment_valid && ranking_global_valid &&
                                  allocation_global_valid && style_global_valid &&
                                  all_symbol_data_valid);
      for(int index=0;index<symbol_count;index++)
        {
         if(snapshots[index].selected_strategy=="NO_TRADE")
            global_snapshot.no_trade_symbol_count++;
         else if(snapshots[index].is_valid)
            global_snapshot.active_strategy_count++;

         if(!PublishSnapshot(snapshots[index]))
            CLogger::Error(StringFormat("StrategySelectionEngine could not publish %s.",
                                        snapshots[index].symbol));
        }
      if(!PublishGlobalSnapshot(global_snapshot))
         CLogger::Error("StrategySelectionEngine could not publish global strategy data.");
     }

   virtual void       Shutdown(void)
     {
      ArrayFree(m_symbols);
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_STRATEGY_SELECTION_ENGINE_MQH

