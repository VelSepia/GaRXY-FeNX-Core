//+------------------------------------------------------------------+
//|                         Strategy/RangeMeanReversionStrategy.mqh |
//+------------------------------------------------------------------+
#ifndef FENX_RANGE_MEAN_REVERSION_STRATEGY_MQH
#define FENX_RANGE_MEAN_REVERSION_STRATEGY_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Core/DataBus.mqh"

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
         return(ApproveEntry(ORDER_TYPE_BUY,
                             "Completed-bar close is near RangeLower.",intent));
      if(m_allow_sell && MathAbs(close_price-upper)<=boundary)
        {
         string filter_reason="";
         if(!PassesTask015C3SellFilter(intent.bar_time,filter_reason))
           {
            intent.reason=filter_reason;
            return(false);
           }
         return(ApproveEntry(ORDER_TYPE_SELL,
                             "Completed-bar close is near RangeUpper.",intent));
        }
      intent.reason="Completed-bar close is away from both range boundaries.";
      return(false);
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
