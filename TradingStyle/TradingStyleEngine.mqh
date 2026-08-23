//+------------------------------------------------------------------+
//|                               TradingStyle/TradingStyleEngine.mqh |
//+------------------------------------------------------------------+
#ifndef FENX_TRADING_STYLE_ENGINE_MQH
#define FENX_TRADING_STYLE_ENGINE_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Shared Environment facts read through CDataBus for one style cycle.
struct STradingStyleEnvironment
  {
   string   market_state;
   double   market_confidence;
   double   volatility_score;
   double   trend_score;
   double   trend_confidence;
   double   range_score;
   bool     range_data_valid;
   bool     trend_data_valid;
   datetime market_updated_at;
   datetime range_updated_at;
   datetime trend_updated_at;
  };

//--- Global validity and freshness facts supplied by Pair Ranking.
struct STradingStylePairGlobal
  {
   bool     data_valid;
   datetime updated_at;
  };

//--- Global validity and freshness facts supplied by Capital Allocation.
struct STradingStyleAllocationGlobal
  {
   bool     data_valid;
   datetime updated_at;
  };

//--- Per-symbol ranking and allocation facts read only through CDataBus.
struct STradingStyleInput
  {
   string   symbol;
   bool     is_pair_ranked;
   int      pair_rank;
   double   pair_ranking_score;
   double   pair_ranking_confidence;
   datetime pair_ranking_updated_at;
   bool     is_capital_allocated;
   double   allocation_percent;
   double   allocation_score;
   double   allocation_confidence;
   datetime allocation_updated_at;
  };

//--- Per-symbol recommendation. It does not represent a strategy or execution command.
struct STradingStyleSnapshot
  {
   string   symbol;
   string   style;
   double   score;
   double   confidence;
   string   reason;
   datetime updated_at;
   bool     is_valid;
  };

//--- Global style facts published after each update cycle.
struct SGlobalTradingStyleSnapshot
  {
   int      active_style_count;
   bool     data_valid;
   datetime updated_at;
  };

//--- Chooses an approved trading style from published facts without selecting a strategy.
class CTradingStyleEngine : public CBaseEngine
  {
private:
   string m_symbols[];
   double m_trend_confidence_threshold;
   double m_range_confidence_threshold;
   double m_max_volatility_score;
   double m_transition_penalty;
   int    m_stale_data_limit_seconds;
   double m_stale_data_penalty;
   double m_min_allocation_percent;

   void ResetSnapshot(STradingStyleSnapshot &snapshot,const string symbol)
     {
      snapshot.symbol=symbol;
      snapshot.style="STANDBY";
      snapshot.score=0.0;
      snapshot.confidence=0.0;
      snapshot.reason="";
      snapshot.updated_at=TimeCurrent();
      snapshot.is_valid=false;
     }

   void ResetGlobalSnapshot(SGlobalTradingStyleSnapshot &snapshot)
     {
      snapshot.active_style_count=0;
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

   bool ReadEnvironment(STradingStyleEnvironment &environment)
     {
      if(m_data_bus==NULL)
         return(false);

      string market_state="";
      double market_confidence=0.0;
      double volatility_score=0.0;
      double trend_score=0.0;
      double trend_confidence=0.0;
      double range_score=0.0;
      bool range_data_valid=false;
      bool trend_data_valid=false;
      string market_updated_at_text="";
      string range_updated_at_text="";
      string trend_updated_at_text="";
      datetime market_updated_at=0;
      datetime range_updated_at=0;
      datetime trend_updated_at=0;
      if(!m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE,market_state) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_CONFIDENCE,market_confidence) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,volatility_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_SCORE,trend_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_CONFIDENCE,trend_confidence) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,range_score) ||
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
      environment.market_confidence=market_confidence;
      environment.volatility_score=volatility_score;
      // TrendScore is directional (-100..100); downstream style thresholds use magnitude.
      environment.trend_score=MathAbs(trend_score);
      environment.trend_confidence=trend_confidence;
      environment.range_score=range_score;
      environment.range_data_valid=range_data_valid;
      environment.trend_data_valid=trend_data_valid;
      environment.market_updated_at=market_updated_at;
      environment.range_updated_at=range_updated_at;
      environment.trend_updated_at=trend_updated_at;

      if(environment.market_confidence<0.0 || environment.market_confidence>100.0 ||
         environment.volatility_score<0.0 || environment.volatility_score>100.0 ||
         environment.trend_score<0.0 || environment.trend_score>100.0 ||
         environment.trend_confidence<0.0 || environment.trend_confidence>100.0 ||
         environment.range_score<0.0 || environment.range_score>100.0 ||
         !environment.range_data_valid || !environment.trend_data_valid)
         return(false);

      return(environment.market_state=="RANGING" || environment.market_state=="TRENDING" ||
             environment.market_state=="VOLATILE" || environment.market_state=="TRANSITION");
     }

   bool ReadPairGlobal(STradingStylePairGlobal &ranking)
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

   bool ReadAllocationGlobal(STradingStyleAllocationGlobal &allocation)
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

   bool ReadSymbolInput(const string symbol,STradingStyleInput &source)
     {
      if(m_data_bus==NULL)
         return(false);

      string input_symbol="";
      string text="";
      string pair_updated_at_text="";
      string allocation_updated_at_text="";
      bool is_pair_ranked=false;
      bool is_capital_allocated=false;
      datetime pair_ranking_updated_at=0;
      datetime allocation_updated_at=0;
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_SYMBOL,input_symbol) ||
         input_symbol!=symbol ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_IS_RANKED,text) ||
         !ReadBooleanText(text,is_pair_ranked) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_RANK,text))
         return(false);

      source.symbol=input_symbol;
      source.is_pair_ranked=is_pair_ranked;
      source.pair_rank=(int)StringToInteger(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_SCORE,text))
         return(false);
      source.pair_ranking_score=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_CONFIDENCE,text))
         return(false);
      source.pair_ranking_confidence=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_UPDATED_AT,
                                      pair_updated_at_text) ||
         !ReadTimestampText(pair_updated_at_text,pair_ranking_updated_at) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,symbol,
                                      FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_SYMBOL,text) ||
         text!=symbol ||
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
                                      FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_SCORE,text))
         return(false);
      source.allocation_score=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,symbol,
                                      FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_CONFIDENCE,text))
         return(false);
      source.allocation_confidence=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,symbol,
                                      FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_UPDATED_AT,
                                      allocation_updated_at_text) ||
         !ReadTimestampText(allocation_updated_at_text,allocation_updated_at))
         return(false);

      source.allocation_updated_at=allocation_updated_at;
      return(source.pair_rank>=0 && source.pair_ranking_score>=0.0 &&
             source.pair_ranking_score<=100.0 && source.pair_ranking_confidence>=0.0 &&
             source.pair_ranking_confidence<=100.0 && source.allocation_percent>=0.0 &&
             source.allocation_percent<=100.0 && source.allocation_score>=0.0 &&
             source.allocation_score<=100.0 && source.allocation_confidence>=0.0 &&
             source.allocation_confidence<=100.0);
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

   double CalculateStyleConfidence(const STradingStyleEnvironment &environment,
                                   const STradingStyleInput &source,
                                   const double freshness)
     {
      double confidence=MathMin(environment.market_confidence,
                                MathMin(source.pair_ranking_confidence,
                                source.allocation_confidence));
      confidence-=m_stale_data_penalty*(1.0-(freshness/100.0));
      if(environment.market_state=="TRANSITION")
         confidence-=m_transition_penalty;

      return(ClampPercent(confidence));
     }

   double CalculateStyleScore(const double signal_score,const STradingStyleInput &source,
                              const double style_confidence)
     {
      return(ClampPercent((0.50*signal_score)+(0.20*source.pair_ranking_score)+
                          (0.20*source.allocation_score)+(0.10*style_confidence)));
     }

   bool IsUnsafe(const STradingStyleEnvironment &environment,
                 const STradingStyleInput &source,string &reason)
     {
      if(!source.is_capital_allocated)
        {
         reason="Capital Allocation did not fund this symbol.";
         return(true);
        }
      if(!source.is_pair_ranked || source.pair_rank<1)
        {
         reason="Pair Ranking did not provide an active rank.";
         return(true);
        }
      if(source.allocation_percent<m_min_allocation_percent)
        {
         reason="Capital allocation is below the Trading Style threshold.";
         return(true);
        }
      if(environment.market_state=="VOLATILE" ||
         environment.volatility_score>m_max_volatility_score)
        {
         reason="Volatility is outside the approved Trading Style limit.";
         return(true);
        }

      return(false);
     }

   void DecideStyle(const STradingStyleEnvironment &environment,
                    const STradingStyleInput &source,const double freshness,
                    STradingStyleSnapshot &snapshot)
     {
      string unsafe_reason="";
      if(IsUnsafe(environment,source,unsafe_reason))
        {
         snapshot.reason=unsafe_reason;
         snapshot.is_valid=true;
         return;
        }

      const double style_confidence=CalculateStyleConfidence(environment,source,freshness);
      const bool range_ready=(environment.market_state=="RANGING" &&
                              environment.range_score>=m_range_confidence_threshold &&
                              style_confidence>=m_range_confidence_threshold);
      const bool trend_ready=(environment.market_state=="TRENDING" &&
                              environment.trend_score>=m_trend_confidence_threshold &&
                              environment.trend_confidence>=m_trend_confidence_threshold &&
                              style_confidence>=m_trend_confidence_threshold);
      const double mixed_range_floor=0.70*m_range_confidence_threshold;
      const double mixed_trend_floor=0.70*m_trend_confidence_threshold;
      const bool hybrid_ready=(environment.market_state=="TRANSITION" &&
                               environment.range_score>=mixed_range_floor &&
                               environment.trend_score>=mixed_trend_floor &&
                               environment.trend_confidence>=mixed_trend_floor &&
                               style_confidence>=MathMin(mixed_range_floor,mixed_trend_floor));

      snapshot.confidence=style_confidence;
      snapshot.is_valid=true;
      if(range_ready)
        {
         snapshot.style="RANGE";
         snapshot.score=CalculateStyleScore(environment.range_score,source,style_confidence);
         snapshot.reason="RANGING state meets the range-confidence threshold.";
         return;
        }
      if(trend_ready)
        {
         snapshot.style="TREND";
         snapshot.score=CalculateStyleScore(environment.trend_score,source,style_confidence);
         snapshot.reason="TRENDING state meets the strong-trend confidence threshold.";
         return;
        }
      if(hybrid_ready)
        {
         snapshot.style="HYBRID";
         const double hybrid_signal=(environment.range_score+
                                     MathMin(environment.trend_score,
                                             environment.trend_confidence))/2.0;
         snapshot.score=CalculateStyleScore(hybrid_signal,source,style_confidence);
         snapshot.reason="TRANSITION state has sufficient mixed range and trend evidence.";
         return;
        }

      snapshot.reason="No approved style met the configured confidence thresholds.";
     }

   bool PublishSnapshot(STradingStyleSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      bool success=true;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_TRADING_STYLE,snapshot.symbol,
                                   FENX_DATABUS_FIELD_TRADING_STYLE,snapshot.style))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_TRADING_STYLE,snapshot.symbol,
                                   FENX_DATABUS_FIELD_TRADING_STYLE_SCORE,
                                   DoubleToString(snapshot.score,2)))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_TRADING_STYLE,snapshot.symbol,
                                   FENX_DATABUS_FIELD_TRADING_STYLE_CONFIDENCE,
                                   DoubleToString(snapshot.confidence,2)))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_TRADING_STYLE,snapshot.symbol,
                                   FENX_DATABUS_FIELD_TRADING_STYLE_REASON,snapshot.reason))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_TRADING_STYLE,snapshot.symbol,
                                   FENX_DATABUS_FIELD_TRADING_STYLE_UPDATED_AT,
                                   TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS)))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_TRADING_STYLE,snapshot.symbol,
                                   FENX_DATABUS_FIELD_TRADING_STYLE_IS_VALID,
                                   (snapshot.is_valid ? "true" : "false")))
         success=false;

      return(success);
     }

   bool PublishGlobalSnapshot(SGlobalTradingStyleSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      bool success=true;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_TRADING_STYLE_ACTIVE_COUNT,
                             IntegerToString(snapshot.active_style_count)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_TRADING_STYLE_DATA_VALID,
                             (snapshot.data_valid ? "true" : "false")))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_TRADING_STYLE_UPDATED_AT,
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
                     CTradingStyleEngine(void)
     {
      SetName("TradingStyleEngine");
      m_trend_confidence_threshold=0.0;
      m_range_confidence_threshold=0.0;
      m_max_volatility_score=0.0;
      m_transition_penalty=0.0;
      m_stale_data_limit_seconds=0;
      m_stale_data_penalty=0.0;
      m_min_allocation_percent=0.0;
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_trend_confidence_threshold=parameters.TradingStyleTrendConfidenceThreshold();
      m_range_confidence_threshold=parameters.TradingStyleRangeConfidenceThreshold();
      m_max_volatility_score=parameters.TradingStyleMaxVolatilityScore();
      m_transition_penalty=parameters.TradingStyleTransitionPenalty();
      m_stale_data_limit_seconds=parameters.TradingStyleStaleDataLimitSeconds();
      m_stale_data_penalty=parameters.TradingStyleStaleDataPenalty();
      m_min_allocation_percent=parameters.TradingStyleMinAllocationPercent();

      if(!LoadSymbols(parameters) || m_trend_confidence_threshold<=0.0 ||
         m_trend_confidence_threshold>100.0 || m_range_confidence_threshold<=0.0 ||
         m_range_confidence_threshold>100.0 || m_max_volatility_score<=0.0 ||
         m_max_volatility_score>100.0 || m_transition_penalty<0.0 ||
         m_transition_penalty>100.0 || m_stale_data_limit_seconds<=0 ||
         m_stale_data_penalty<0.0 || m_stale_data_penalty>100.0 ||
         m_min_allocation_percent<=0.0 || m_min_allocation_percent>100.0)
        {
         CLogger::Error("TradingStyleEngine received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      CLogger::Info(StringFormat("TradingStyleEngine configured for %d symbol(s).",
                                 ArraySize(m_symbols)));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;

      STradingStyleEnvironment environment;
      STradingStylePairGlobal ranking_global;
      STradingStyleAllocationGlobal allocation_global;
      double environment_freshness=0.0;
      double ranking_global_freshness=0.0;
      double allocation_global_freshness=0.0;
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
      if((!environment_valid || !ranking_global_valid || !allocation_global_valid) &&
         (m_data_bus==NULL || !m_data_bus.ContextViewActive()))
         CLogger::Warning("TradingStyleEngine is waiting for valid, fresh Environment, ranking, and allocation data.");

      const int symbol_count=ArraySize(m_symbols);
      STradingStyleSnapshot snapshots[];
      if(ArrayResize(snapshots,symbol_count)!=symbol_count)
        {
         CLogger::Error("TradingStyleEngine could not allocate per-symbol snapshots.");
         return;
        }

      bool all_symbol_data_valid=true;
      for(int index=0;index<symbol_count;index++)
        {
         ResetSnapshot(snapshots[index],m_symbols[index]);
         if(!environment_valid || !ranking_global_valid || !allocation_global_valid)
           {
            snapshots[index].reason="Environment, Pair Ranking, or Capital Allocation data is unavailable, invalid, or stale.";
            continue;
           }

         STradingStyleInput source;
         if(!ReadSymbolInput(m_symbols[index],source))
           {
            snapshots[index].reason="Pair Ranking or Capital Allocation symbol data is unavailable or invalid.";
            all_symbol_data_valid=false;
            continue;
           }

         double pair_freshness=0.0;
         double allocation_freshness=0.0;
         if(!CalculateFreshness(source.pair_ranking_updated_at,pair_freshness) ||
            !CalculateFreshness(source.allocation_updated_at,allocation_freshness))
           {
            snapshots[index].reason="Pair Ranking or Capital Allocation symbol data is stale.";
            all_symbol_data_valid=false;
            continue;
           }

         const double freshness=MathMin(environment_freshness,
                                 MathMin(ranking_global_freshness,
                                 MathMin(allocation_global_freshness,
                                 MathMin(pair_freshness,allocation_freshness))));
         DecideStyle(environment,source,freshness,snapshots[index]);
        }

      SGlobalTradingStyleSnapshot global_snapshot;
      ResetGlobalSnapshot(global_snapshot);
      global_snapshot.data_valid=(environment_valid && ranking_global_valid &&
                                  allocation_global_valid && all_symbol_data_valid);
      for(int index=0;index<symbol_count;index++)
        {
         if(snapshots[index].is_valid && snapshots[index].style!="STANDBY")
            global_snapshot.active_style_count++;

         if(!PublishSnapshot(snapshots[index]))
            CLogger::Error(StringFormat("TradingStyleEngine could not publish %s.",
                                        snapshots[index].symbol));
        }
      if(!PublishGlobalSnapshot(global_snapshot))
         CLogger::Error("TradingStyleEngine could not publish global style data.");
     }

   virtual void       Shutdown(void)
     {
      ArrayFree(m_symbols);
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_TRADING_STYLE_ENGINE_MQH

