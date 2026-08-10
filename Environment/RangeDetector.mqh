//+------------------------------------------------------------------+
//|                                   Environment/RangeDetector.mqh |
//+------------------------------------------------------------------+
#ifndef FENX_ENVIRONMENT_RANGE_DETECTOR_MQH
#define FENX_ENVIRONMENT_RANGE_DETECTOR_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Common/CommonSnapshotStore.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Detects stable, non-directional price ranges from completed candles only.
class CRangeDetector : public CBaseEngine
  {
private:
   int    m_lookback_bars;
   double m_boundary_trim_fraction;
   int    m_min_boundary_touches;
   double m_min_width_points;
   double m_min_width_atr_multiple;
   double m_max_width_atr_multiple;
   double m_touch_tolerance_atr_fraction;
   double m_break_buffer_atr_fraction;
   int    m_max_break_events;
   double m_score_threshold;
   int    m_freshness_limit_seconds;
   bool   m_consistency_verified;
   CCommonSnapshotStore *m_snapshot_store;

   void ResetSnapshot(SRangeSnapshot &snapshot)
     {
      snapshot.upper=0.0;
      snapshot.lower=0.0;
      snapshot.width_points=0.0;
      snapshot.midpoint=0.0;
      snapshot.position=0.0;
      snapshot.score=0.0;
      snapshot.is_range=false;
      snapshot.is_data_valid=false;
      snapshot.updated_at=TimeCurrent();
      snapshot.closed_bar_time=0;
     }

   bool ReadAtrFromDataBus(double &atr)
     {
      if(m_data_bus==NULL)
         return(false);

      string atr_text="";
      if(!m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_ATR,atr_text))
         return(false);

      atr=StringToDouble(atr_text);
      return(atr>0.0);
     }

   bool CalculateStableBoundaries(MqlRates &rates[],const int bar_count,
                                  double &upper,double &lower)
     {
      if(bar_count<=0)
         return(false);

      double highs[];
      double lows[];
      if(ArrayResize(highs,bar_count)!=bar_count || ArrayResize(lows,bar_count)!=bar_count)
         return(false);

      for(int index=0;index<bar_count;index++)
        {
         highs[index]=rates[index].high;
         lows[index]=rates[index].low;
        }

      ArraySort(highs);
      ArraySort(lows);

      const int last_index=bar_count-1;
      int lower_index=(int)MathFloor(last_index*m_boundary_trim_fraction);
      int upper_index=(int)MathFloor(last_index*(1.0-m_boundary_trim_fraction));
      lower_index=(int)MathMax(0,MathMin(last_index,lower_index));
      upper_index=(int)MathMax(0,MathMin(last_index,upper_index));

      lower=lows[lower_index];
      upper=highs[upper_index];
      return(upper>lower);
     }

   double CalculateContainmentScore(MqlRates &rates[],const int bar_count,
                                    const double upper,const double lower)
     {
      int contained_bars=0;
      for(int index=0;index<bar_count;index++)
        {
         if(rates[index].close>=lower && rates[index].close<=upper)
            contained_bars++;
        }

      return(100.0*contained_bars/bar_count);
     }

   double CalculateTouchScore(MqlRates &rates[],const int bar_count,
                              const double upper,const double lower,
                              const double touch_tolerance)
     {
      int upper_touches=0;
      int lower_touches=0;
      for(int index=0;index<bar_count;index++)
        {
         if(rates[index].high>=upper-touch_tolerance)
            upper_touches++;
         if(rates[index].low<=lower+touch_tolerance)
            lower_touches++;
        }

      const double upper_score=100.0*MathMin(1.0,(double)upper_touches/m_min_boundary_touches);
      const double lower_score=100.0*MathMin(1.0,(double)lower_touches/m_min_boundary_touches);
      return((upper_score+lower_score)/2.0);
     }

   double CalculateEfficiencyScore(MqlRates &rates[],const int bar_count)
     {
      double total_movement=0.0;
      for(int index=1;index<bar_count;index++)
         total_movement+=MathAbs(rates[index].close-rates[index-1].close);

      if(total_movement<=0.0)
         return(100.0);

      const double net_movement=MathAbs(rates[bar_count-1].close-rates[0].close);
      const double efficiency=MathMin(1.0,net_movement/total_movement);
      return(100.0*(1.0-efficiency));
     }

   double CalculateWidthScore(const double width,const double atr)
     {
      if(width<=0.0 || atr<=0.0)
         return(0.0);

      const double atr_multiple=width/atr;
      if(atr_multiple<m_min_width_atr_multiple)
         return(100.0*atr_multiple/m_min_width_atr_multiple);
      if(atr_multiple>m_max_width_atr_multiple)
         return(100.0*m_max_width_atr_multiple/atr_multiple);

      return(100.0);
     }

   double CalculateBreakScore(MqlRates &rates[],const int bar_count,
                              const double upper,const double lower,
                              const double break_buffer)
     {
      int false_breaks=0;
      int excessive_breaks=0;
      for(int index=0;index<bar_count;index++)
        {
         if(rates[index].high>upper+break_buffer)
           {
            if(rates[index].close<=upper)
               false_breaks++;
            else
               excessive_breaks++;
           }

         if(rates[index].low<lower-break_buffer)
           {
            if(rates[index].close>=lower)
               false_breaks++;
            else
               excessive_breaks++;
           }
        }

      const double weighted_breaks=false_breaks+(2.0*excessive_breaks);
      const double penalty=MathMin(100.0,100.0*weighted_breaks/m_max_break_events);
      return(100.0-penalty);
     }

   bool BuildSnapshot(MqlRates &rates[],const int bar_count,const double atr,
                      SRangeSnapshot &snapshot)
     {
      ResetSnapshot(snapshot);
      if(bar_count!=m_lookback_bars || atr<=0.0)
         return(false);

      double upper=0.0;
      double lower=0.0;
      if(!CalculateStableBoundaries(rates,bar_count,upper,lower))
         return(false);

      const double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      const double width=upper-lower;
      if(point<=0.0 || width<=0.0)
         return(false);

      const double width_points=width/point;
      if(width_points<m_min_width_points)
         return(false);

      const double touch_tolerance=MathMax(point,atr*m_touch_tolerance_atr_fraction);
      const double break_buffer=MathMax(point,atr*m_break_buffer_atr_fraction);
      const double containment_score=CalculateContainmentScore(rates,bar_count,upper,lower);
      const double touch_score=CalculateTouchScore(rates,bar_count,upper,lower,touch_tolerance);
      const double efficiency_score=CalculateEfficiencyScore(rates,bar_count);
      const double width_score=CalculateWidthScore(width,atr);
      const double break_score=CalculateBreakScore(rates,bar_count,upper,lower,break_buffer);
      const double atr_multiple=width/atr;

      snapshot.upper=upper;
      snapshot.lower=lower;
      snapshot.width_points=width_points;
      snapshot.midpoint=(upper+lower)/2.0;
      snapshot.position=MathMax(0.0,MathMin(1.0,
                                (rates[bar_count-1].close-lower)/width));
      snapshot.score=(0.30*containment_score)+
                     (0.20*touch_score)+
                     (0.25*efficiency_score)+
                     (0.15*width_score)+
                     (0.10*break_score);
      snapshot.is_data_valid=true;
      snapshot.is_range=(snapshot.score>=m_score_threshold &&
                         atr_multiple>=m_min_width_atr_multiple &&
                         atr_multiple<=m_max_width_atr_multiple &&
                         touch_score>=100.0);
      snapshot.updated_at=TimeCurrent();
      snapshot.closed_bar_time=rates[bar_count-1].time;
      return(true);
     }

   bool PublishSnapshot(SRangeSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      const int symbol_digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      bool success=true;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPPER,
                             DoubleToString(snapshot.upper,symbol_digits)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_LOWER,
                             DoubleToString(snapshot.lower,symbol_digits)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_WIDTH_POINTS,
                             DoubleToString(snapshot.width_points,2)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_MIDPOINT,
                             DoubleToString(snapshot.midpoint,symbol_digits)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_POSITION,
                             DoubleToString(snapshot.position,4)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,
                             DoubleToString(snapshot.score,2)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_IS_RANGE,
                             (snapshot.is_range ? "true" : "false")))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,
                             (snapshot.is_data_valid ? "true" : "false")))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPDATED_AT,
                             TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_CLOSED_BAR_TIME,
                             TimeToString(snapshot.closed_bar_time,TIME_DATE|TIME_SECONDS)))
         success=false;

      return(success);
     }

   //--- Completes the typed mirror only after legacy publication. The source
   //--- values are normalized to the exact existing DataBus precision; no
   //--- boundary, score, or IsRange calculation is repeated here.
   void BuildTypedSnapshot(SRangeSnapshot &snapshot,const double atr)
     {
      const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      snapshot.upper=StringToDouble(DoubleToString(snapshot.upper,digits));
      snapshot.lower=StringToDouble(DoubleToString(snapshot.lower,digits));
      snapshot.width_points=StringToDouble(DoubleToString(snapshot.width_points,2));
      snapshot.midpoint=StringToDouble(DoubleToString(snapshot.midpoint,digits));
      snapshot.position=StringToDouble(DoubleToString(snapshot.position,4));
      snapshot.score=StringToDouble(DoubleToString(snapshot.score,2));
      snapshot.symbol=_Symbol;
      snapshot.timeframe=EnumToString(_Period);
      snapshot.snapshot_version=FENX_COMMON_RANGE_SNAPSHOT_VERSION;
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="";
      snapshot.source_updated_at=snapshot.updated_at;
      snapshot.source_bar_time=snapshot.closed_bar_time;
      snapshot.lookback=m_lookback_bars;
      snapshot.price_digits=digits;
      snapshot.point_size=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      snapshot.source_atr=atr;
      snapshot.atr_updated_at=0;
      CRangeSnapshotContract contract;
      contract.Finalize(snapshot,TimeCurrent(),m_freshness_limit_seconds);
     }

   bool SameTypedSnapshot(const SRangeSnapshot &left,
                          const SRangeSnapshot &right)
     {
      return(left.upper==right.upper && left.lower==right.lower &&
             left.width_points==right.width_points &&
             left.midpoint==right.midpoint && left.position==right.position &&
             left.score==right.score && left.is_range==right.is_range &&
             left.is_data_valid==right.is_data_valid &&
             left.updated_at==right.updated_at &&
             left.closed_bar_time==right.closed_bar_time &&
             left.symbol==right.symbol && left.timeframe==right.timeframe &&
             left.snapshot_version==right.snapshot_version &&
             left.is_valid==right.is_valid && left.is_fresh==right.is_fresh &&
             left.invalid_reason==right.invalid_reason &&
             left.source_updated_at==right.source_updated_at &&
             left.source_bar_time==right.source_bar_time &&
             left.lookback==right.lookback &&
             left.price_digits==right.price_digits &&
             left.point_size==right.point_size &&
             left.source_atr==right.source_atr &&
             left.atr_updated_at==right.atr_updated_at);
     }

   bool StoreTypedSnapshot(const SRangeSnapshot &snapshot)
     {
      if(m_snapshot_store==NULL ||
         !m_snapshot_store.SetRangeSnapshot(_Symbol,_Period,snapshot))
         return(false);
      if(m_consistency_verified)
         return(true);

      SRangeSnapshot stored;
      if(!m_snapshot_store.GetRangeSnapshot(_Symbol,_Period,stored) ||
         !SameTypedSnapshot(snapshot,stored))
         return(false);

      string upper="",lower="",width="",midpoint="",position="",score="";
      string is_range="",is_valid="",updated="",closed_bar="";
      const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      if(m_data_bus==NULL ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPPER,upper) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_LOWER,lower) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_WIDTH_POINTS,width) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_MIDPOINT,midpoint) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_POSITION,position) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,score) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_IS_RANGE,is_range) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,is_valid) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPDATED_AT,updated) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_CLOSED_BAR_TIME,closed_bar))
         return(false);

      return(upper==DoubleToString(snapshot.upper,digits) &&
             lower==DoubleToString(snapshot.lower,digits) &&
             width==DoubleToString(snapshot.width_points,2) &&
             midpoint==DoubleToString(snapshot.midpoint,digits) &&
             position==DoubleToString(snapshot.position,4) &&
             score==DoubleToString(snapshot.score,2) &&
             is_range==(snapshot.is_range ? "true" : "false") &&
             is_valid==(snapshot.is_data_valid ? "true" : "false") &&
             updated==TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS) &&
             closed_bar==TimeToString(snapshot.closed_bar_time,TIME_DATE|TIME_SECONDS));
     }

public:
                     CRangeDetector(void)
     {
      SetName("RangeDetector");
      m_lookback_bars=0;
      m_boundary_trim_fraction=0.0;
      m_min_boundary_touches=0;
      m_min_width_points=0.0;
      m_min_width_atr_multiple=0.0;
      m_max_width_atr_multiple=0.0;
      m_touch_tolerance_atr_fraction=0.0;
      m_break_buffer_atr_fraction=0.0;
      m_max_break_events=0;
      m_score_threshold=0.0;
      m_freshness_limit_seconds=0;
      m_consistency_verified=false;
      m_snapshot_store=NULL;
     }

   //--- Injects the non-owning typed store before framework initialization.
   //--- All trading consumers continue to use the legacy Range DataBus keys.
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
         CLogger::Error("RangeDetector requires CommonSnapshotStore before initialization.");
         return(false);
        }
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_lookback_bars=parameters.RangeLookbackBars();
      m_boundary_trim_fraction=parameters.RangeBoundaryTrimFraction();
      m_min_boundary_touches=parameters.RangeMinBoundaryTouches();
      m_min_width_points=parameters.RangeMinWidthPoints();
      m_min_width_atr_multiple=parameters.RangeMinWidthAtrMultiple();
      m_max_width_atr_multiple=parameters.RangeMaxWidthAtrMultiple();
      m_touch_tolerance_atr_fraction=parameters.RangeTouchToleranceAtrFraction();
      m_break_buffer_atr_fraction=parameters.RangeBreakBufferAtrFraction();
      m_max_break_events=parameters.RangeMaxBreakEvents();
      m_score_threshold=parameters.RangeScoreThreshold();
      m_freshness_limit_seconds=parameters.RiskStaleDataLimitSeconds();

      if(m_lookback_bars<10 || m_boundary_trim_fraction<0.0 ||
         m_boundary_trim_fraction>=0.5 || m_min_boundary_touches<1 ||
         m_min_width_points<0.0 || m_min_width_atr_multiple<=0.0 ||
         m_max_width_atr_multiple<=m_min_width_atr_multiple ||
         m_touch_tolerance_atr_fraction<=0.0 ||
         m_break_buffer_atr_fraction<=0.0 || m_max_break_events<1 ||
         m_score_threshold<0.0 || m_score_threshold>100.0 ||
         m_freshness_limit_seconds<=0)
        {
         CLogger::Error("RangeDetector received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      CLogger::Info(StringFormat("RangeDetector configured with %d completed bars.",
                                 m_lookback_bars));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;

      SRangeSnapshot snapshot;
      ResetSnapshot(snapshot);

      double atr=0.0;
      MqlRates rates[];
      // start_pos=1 excludes the current forming candle; the copied array is oldest to newest.
      const int copied=CopyRates(_Symbol,PERIOD_CURRENT,1,m_lookback_bars,rates);
      if(!ReadAtrFromDataBus(atr) || copied!=m_lookback_bars ||
         !BuildSnapshot(rates,copied,atr,snapshot))
        {
         CLogger::Warning("RangeDetector is waiting for valid ATR or completed-bar history.");
        }

      if(!PublishSnapshot(snapshot))
        {
         CLogger::Error("RangeDetector could not publish its snapshot to DataBus.");
         return;
        }

      BuildTypedSnapshot(snapshot,atr);
      if(!StoreTypedSnapshot(snapshot))
        {
         CLogger::Error("RangeDetector could not store or verify its typed snapshot.");
         return;
        }
      if(!m_consistency_verified)
        {
         CLogger::Info(StringFormat(
            "[COMMON_RANGE] typed_databus_consistency=PASS;symbol=%s;timeframe=%s;store_count=%d;keys=0;lookback=%d;price_digits=%d;atr_updated_at_available=false",
            snapshot.symbol,snapshot.timeframe,
            m_snapshot_store.RangeSnapshotCount(),snapshot.lookback,
            snapshot.price_digits));
         m_consistency_verified=true;
        }
     }

   virtual void       Shutdown(void)
     {
      // No indicator handles are owned by RangeDetector.
      m_consistency_verified=false;
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_ENVIRONMENT_RANGE_DETECTOR_MQH
