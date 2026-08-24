//+------------------------------------------------------------------+
//|                       MarketSelection/MarketSelectionEngine.mqh |
//+------------------------------------------------------------------+
#ifndef FENX_MARKET_SELECTION_ENGINE_MQH
#define FENX_MARKET_SELECTION_ENGINE_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Core/AnalysisContextBinding.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Immutable environment facts read from CDataBus for one update cycle.
struct SSelectionEnvironment
  {
   double atr;
   double volatility_score;
   double range_score;
   double trend_score;
   double market_confidence;
   bool   is_range;
   bool   is_trend;
   bool   range_data_valid;
   bool   trend_data_valid;
   string market_state;
  };

//--- Per-symbol participation result. It is published only through CDataBus.
struct SMarketSelectionSnapshot
  {
   string   symbol;
   bool     is_eligible;
   double   score;
   double   confidence;
   double   spread_points;
   double   spread_to_atr_ratio;
   string   rejection_reason;
   datetime updated_at;
  };

//--- Evaluates market participation conditions without ranking, allocation, or trading.
class CMarketSelectionEngine : public CBaseEngine
  {
private:
   string m_symbols[];
   int    m_min_history_bars;
   double m_max_spread_points;
   double m_max_spread_to_atr_ratio;
   double m_min_volatility_score;
   double m_max_volatility_score;
   double m_min_selection_score;
   double m_transition_penalty;
   CAnalysisContextBinding m_context;
   long   m_update_count;
   long   m_snapshot_count;

   void ResetSnapshot(SMarketSelectionSnapshot &snapshot,const string symbol)
     {
      snapshot.symbol=symbol;
      snapshot.is_eligible=false;
      snapshot.score=0.0;
      snapshot.confidence=0.0;
      snapshot.spread_points=0.0;
      snapshot.spread_to_atr_ratio=0.0;
      snapshot.rejection_reason="";
      snapshot.updated_at=TimeCurrent();
     }

   double ClampScore(const double value)
     {
      return(MathMax(0.0,MathMin(100.0,value)));
     }

   bool ReadDouble(const string name_space,const string field,double &value)
     {
      if(m_data_bus==NULL)
         return(false);

      string text="";
      if(!m_context.ReadText(m_data_bus,name_space,field,text) ||
         StringLen(text)==0)
         return(false);

      value=StringToDouble(text);
      return(true);
     }

   bool ReadBoolean(const string name_space,const string field,bool &value)
     {
      if(m_data_bus==NULL)
         return(false);

      string text="";
      if(!m_context.ReadText(m_data_bus,name_space,field,text))
         return(false);

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

   bool ReadEnvironment(SSelectionEnvironment &environment)
     {
      if(m_data_bus==NULL)
         return(false);

      if(!ReadDouble(FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,"ATR",environment.atr) ||
         !ReadDouble(FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,"Score",
                     environment.volatility_score) ||
         !ReadDouble(FENX_DATABUS_NAMESPACE_CONTEXT_RANGE,"Score",environment.range_score) ||
         !ReadDouble(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"Score",environment.trend_score) ||
         !ReadDouble(FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,"Confidence",
                     environment.market_confidence) ||
         !ReadBoolean(FENX_DATABUS_NAMESPACE_CONTEXT_RANGE,"IsRange",environment.is_range) ||
         !ReadBoolean(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"IsTrend",environment.is_trend) ||
         !ReadBoolean(FENX_DATABUS_NAMESPACE_CONTEXT_RANGE,"IsDataValid",
                       environment.range_data_valid) ||
         !ReadBoolean(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"IsDataValid",
                       environment.trend_data_valid) ||
         !m_context.ReadText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,"State",
             environment.market_state))
         return(false);

      if(environment.atr<=0.0 || environment.volatility_score<0.0 ||
         environment.volatility_score>100.0 || environment.range_score<0.0 ||
         environment.range_score>100.0 || environment.market_confidence<0.0 ||
         environment.market_confidence>100.0 || !environment.range_data_valid ||
         !environment.trend_data_valid)
         return(false);

      return(environment.market_state=="RANGING" || environment.market_state=="TRENDING" ||
             environment.market_state=="VOLATILE" || environment.market_state=="TRANSITION");
     }

   bool EnsureSymbolAvailable(const string symbol,string &reason)
     {
      bool is_custom_symbol=false;
      if(!SymbolExist(symbol,is_custom_symbol))
        {
         reason="Symbol is unavailable.";
         return(false);
        }

      if(!SymbolSelect(symbol,true))
        {
         reason="Symbol could not be selected for market data.";
         return(false);
        }

      return(true);
     }

   bool ReadSymbolMarketData(const string symbol,const double atr,
                             SMarketSelectionSnapshot &snapshot,string &reason)
     {
      const double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      if(point<=0.0)
        {
         reason="Symbol point size is invalid.";
         return(false);
        }

      const long trade_mode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
      if(trade_mode==SYMBOL_TRADE_MODE_DISABLED || trade_mode==SYMBOL_TRADE_MODE_CLOSEONLY)
        {
         reason="Symbol is not open-tradable in its current trade mode.";
         return(false);
        }

      const int bar_count=Bars(symbol,m_context.Timeframe());
      if(bar_count<m_min_history_bars)
        {
         reason=StringFormat("Insufficient history: %d of %d bars.",bar_count,m_min_history_bars);
         return(false);
        }

      MqlTick tick;
      if(!SymbolInfoTick(symbol,tick) || tick.ask<=0.0 || tick.bid<=0.0 || tick.ask<tick.bid)
        {
         reason="Current bid/ask data is unavailable.";
         return(false);
        }

      snapshot.spread_points=(tick.ask-tick.bid)/point;
      snapshot.spread_to_atr_ratio=(tick.ask-tick.bid)/atr;
      if(snapshot.spread_points>m_max_spread_points)
        {
         reason="Spread exceeds the configured point limit.";
         return(false);
        }
      if(snapshot.spread_to_atr_ratio>m_max_spread_to_atr_ratio)
        {
         reason="Spread is too large relative to ATR.";
         return(false);
        }

      return(true);
     }

   double CalculateSpreadScore(const SMarketSelectionSnapshot &snapshot)
     {
      if(m_max_spread_points<=0.0 || m_max_spread_to_atr_ratio<=0.0)
         return(0.0);

      const double point_score=ClampScore(100.0*(1.0-(snapshot.spread_points/
                                                      m_max_spread_points)));
      const double atr_score=ClampScore(100.0*(1.0-(snapshot.spread_to_atr_ratio/
                                                    m_max_spread_to_atr_ratio)));
      return(0.50*point_score+0.50*atr_score);
     }

   double CalculateVolatilityScore(const double volatility_score)
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

   double CalculateRegimeScore(const SSelectionEnvironment &environment)
     {
      if(environment.market_state=="RANGING")
         return(environment.is_range ? ClampScore(environment.range_score) : 0.0);
      if(environment.market_state=="TRENDING")
         return(environment.is_trend ? ClampScore(MathAbs(environment.trend_score)) : 0.0);
      if(environment.market_state=="TRANSITION")
         return(50.0);

      return(0.0);
     }

   bool EvaluateSymbol(const SSelectionEnvironment &environment,
                       SMarketSelectionSnapshot &snapshot)
     {
      string reason="";
      if(!EnsureSymbolAvailable(snapshot.symbol,reason) ||
         !ReadSymbolMarketData(snapshot.symbol,environment.atr,snapshot,reason))
        {
         snapshot.rejection_reason=reason;
         return(false);
        }

      if(environment.market_state=="VOLATILE")
        {
         snapshot.rejection_reason="Market state is VOLATILE.";
         return(false);
        }

      const double spread_score=CalculateSpreadScore(snapshot);
      const double volatility_score=CalculateVolatilityScore(environment.volatility_score);
      const double regime_score=CalculateRegimeScore(environment);
      snapshot.score=ClampScore((0.35*spread_score)+(0.25*volatility_score)+
                                (0.40*regime_score));
      if(environment.market_state=="TRANSITION")
         snapshot.score=ClampScore(snapshot.score*(1.0-(m_transition_penalty/100.0)));

      const double history_confidence=ClampScore(100.0*(double)Bars(
                                                 snapshot.symbol,m_context.Timeframe())/
                                                 (2.0*m_min_history_bars));
      snapshot.confidence=ClampScore((0.50*environment.market_confidence)+
                                     (0.25*history_confidence)+(0.25*snapshot.score));
      if(snapshot.score<m_min_selection_score)
        {
         snapshot.rejection_reason="Selection score is below the configured threshold.";
         return(false);
        }

      snapshot.is_eligible=true;
      return(true);
     }

   bool PublishSnapshot(SMarketSelectionSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      bool success=true;
      if(!m_context.PublishSymbolFor(m_data_bus,
             FENX_DATABUS_NAMESPACE_MARKET_SELECTION,snapshot.symbol,
             FENX_DATABUS_FIELD_MARKET_SELECTION_SYMBOL,snapshot.symbol))
         success=false;
      if(!m_context.PublishSymbolFor(m_data_bus,
             FENX_DATABUS_NAMESPACE_MARKET_SELECTION,snapshot.symbol,
             FENX_DATABUS_FIELD_MARKET_SELECTION_IS_ELIGIBLE,
             (snapshot.is_eligible ? "true" : "false")))
         success=false;
      if(!m_context.PublishSymbolFor(m_data_bus,
             FENX_DATABUS_NAMESPACE_MARKET_SELECTION,snapshot.symbol,
             FENX_DATABUS_FIELD_MARKET_SELECTION_SCORE,
             DoubleToString(snapshot.score,2)))
         success=false;
      if(!m_context.PublishSymbolFor(m_data_bus,
             FENX_DATABUS_NAMESPACE_MARKET_SELECTION,snapshot.symbol,
             FENX_DATABUS_FIELD_MARKET_SELECTION_CONFIDENCE,
             DoubleToString(snapshot.confidence,2)))
         success=false;
      if(!m_context.PublishSymbolFor(m_data_bus,
             FENX_DATABUS_NAMESPACE_MARKET_SELECTION,snapshot.symbol,
             FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_POINTS,
             DoubleToString(snapshot.spread_points,2)))
         success=false;
      if(!m_context.PublishSymbolFor(m_data_bus,
             FENX_DATABUS_NAMESPACE_MARKET_SELECTION,snapshot.symbol,
             FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_ATR,
             DoubleToString(snapshot.spread_to_atr_ratio,4)))
         success=false;
      if(!m_context.PublishSymbolFor(m_data_bus,
             FENX_DATABUS_NAMESPACE_MARKET_SELECTION,snapshot.symbol,
             FENX_DATABUS_FIELD_MARKET_SELECTION_REJECTION,
             snapshot.rejection_reason))
         success=false;
      if(!m_context.PublishSymbolFor(m_data_bus,
             FENX_DATABUS_NAMESPACE_MARKET_SELECTION,snapshot.symbol,
             FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT,
             TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS)))
         success=false;

      return(success);
     }

   bool LoadSymbols(CParameterManager &parameters)
     {
      if(m_context.IsConfigured())
        {
         if(ArrayResize(m_symbols,1)!=1)
            return(false);
         m_symbols[0]=m_context.Symbol();
         return(true);
        }

      const int symbol_count=parameters.MarketSelectionSymbolCount();
      if(symbol_count<1 || symbol_count>FENX_MARKET_SELECTION_MAX_SYMBOLS ||
         ArrayResize(m_symbols,symbol_count)!=symbol_count)
         return(false);

      for(int index=0;index<symbol_count;index++)
        {
         if(!parameters.TryGetMarketSelectionSymbol(index,m_symbols[index]))
            return(false);
        }

      return(true);
     }

public:
                     CMarketSelectionEngine(void)
     {
      SetName("MarketSelectionEngine");
      m_min_history_bars=0;
      m_max_spread_points=0.0;
      m_max_spread_to_atr_ratio=0.0;
      m_min_volatility_score=0.0;
      m_max_volatility_score=0.0;
      m_min_selection_score=0.0;
      m_transition_penalty=0.0;
      m_update_count=0;
      m_snapshot_count=0;
     }

   bool              SetRuntimeContext(const SRuntimeContextId &context_id)
     {
      return(!m_initialized && m_context.Configure(context_id));
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_min_history_bars=parameters.MarketSelectionMinHistoryBars();
      m_max_spread_points=parameters.MarketSelectionMaxSpreadPoints();
      m_max_spread_to_atr_ratio=parameters.MarketSelectionMaxSpreadToAtrRatio();
      m_min_volatility_score=parameters.MarketSelectionMinVolatilityScore();
      m_max_volatility_score=parameters.MarketSelectionMaxVolatilityScore();
      m_min_selection_score=parameters.MarketSelectionMinScore();
      m_transition_penalty=parameters.MarketSelectionTransitionPenalty();

      if(!LoadSymbols(parameters) || m_min_history_bars<10 || m_max_spread_points<=0.0 ||
         m_max_spread_to_atr_ratio<=0.0 || m_min_volatility_score<=0.0 ||
         m_max_volatility_score<=m_min_volatility_score || m_min_selection_score<0.0 ||
         m_min_selection_score>100.0 || m_transition_penalty<0.0 ||
         m_transition_penalty>100.0)
        {
         CLogger::Error("MarketSelectionEngine received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      CLogger::Info(StringFormat("MarketSelectionEngine configured for %d symbol(s).",
                                 ArraySize(m_symbols)));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;
      m_update_count++;

      SSelectionEnvironment environment;
      const bool environment_valid=ReadEnvironment(environment);
      if(!environment_valid)
         CLogger::Warning("MarketSelectionEngine is waiting for valid Environment Engine data.");

      for(int index=0;index<ArraySize(m_symbols);index++)
        {
         SMarketSelectionSnapshot snapshot;
         ResetSnapshot(snapshot,m_symbols[index]);
         if(!environment_valid)
            snapshot.rejection_reason="Environment Engine data is unavailable or invalid.";
         else
            EvaluateSymbol(environment,snapshot);

         if(!PublishSnapshot(snapshot))
            CLogger::Error(StringFormat("MarketSelectionEngine could not publish %s.",
                                        snapshot.symbol));
         else
            m_snapshot_count++;
        }
     }

   virtual void       Shutdown(void)
     {
      ArrayFree(m_symbols);
      CBaseEngine::Shutdown();
     }

   long              UpdateCount(void) { return(m_update_count); }
   long              SnapshotCount(void) { return(m_snapshot_count); }
   SRuntimeContextId ContextId(void) { return(m_context.Id()); }
  };

#endif // FENX_MARKET_SELECTION_ENGINE_MQH

