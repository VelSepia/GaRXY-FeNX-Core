//+------------------------------------------------------------------+
//|                                   Environment/TrendDetector.mqh |
//+------------------------------------------------------------------+
#ifndef FENX_ENVIRONMENT_TREND_DETECTOR_MQH
#define FENX_ENVIRONMENT_TREND_DETECTOR_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Common/CommonSnapshotStore.mqh"
#include "../Core/AnalysisContextBinding.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Detects directional market facts from completed bars without making decisions.
class CTrendDetector : public CBaseEngine
  {
private:
   int    m_ma_handle;
   int    m_adx_handle;
   int    m_lookback_bars;
   int    m_ma_period;
   int    m_slope_bars;
   int    m_adx_period;
   double m_min_adx;
   double m_min_slope_atr_fraction;
   double m_min_atr_movement;
   double m_noise_atr_fraction;
   double m_direction_score_threshold;
   double m_strength_threshold;
   double m_confidence_threshold;
   int    m_freshness_limit_seconds;
   bool   m_consistency_verified;
   CCommonSnapshotStore *m_snapshot_store;
   CAnalysisContextBinding m_context;
   long   m_update_count;
   long   m_snapshot_count;

   void ResetSnapshot(STrendSnapshot &snapshot)
     {
      snapshot.direction="NEUTRAL";
      snapshot.strength=0.0;
      snapshot.score=0.0;
      snapshot.slope_points=0.0;
      snapshot.confidence=0.0;
      snapshot.adx=0.0;
      snapshot.plus_di=0.0;
      snapshot.minus_di=0.0;
      snapshot.is_trend=false;
      snapshot.is_data_valid=false;
      snapshot.updated_at=TimeCurrent();
      snapshot.symbol="";
      snapshot.timeframe="";
      snapshot.snapshot_version="";
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="";
      snapshot.source_updated_at=0;
      snapshot.source_bar_time=0;
      snapshot.ema_period=0;
      snapshot.ema_shift=0;
      snapshot.adx_period=0;
      snapshot.adx_shift=0;
     }

   bool ReadAtrFromDataBus(double &atr)
     {
      if(m_data_bus==NULL)
         return(false);

      string atr_text="";
      if(!m_context.ReadText(m_data_bus,
            FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,"ATR",atr_text))
         return(false);

      atr=StringToDouble(atr_text);
      return(atr>0.0);
     }

   bool CopyClosedValue(const int handle,const int buffer_index,double &value)
     {
      if(handle==INVALID_HANDLE)
         return(false);

      double values[];
      ResetLastError();
      if(CopyBuffer(handle,buffer_index,1,1,values)!=1)
         return(false);

      value=values[0];
      return(true);
     }

   bool ReadClosedIndicators(double &ma_first,double &ma_last,double &adx,
                             double &plus_di,double &minus_di)
     {
      if(m_ma_handle==INVALID_HANDLE || m_adx_handle==INVALID_HANDLE)
         return(false);

      const int required_values=m_slope_bars+1;
      double ma_values[];
      ResetLastError();
      if(CopyBuffer(m_ma_handle,0,1,required_values,ma_values)!=required_values)
         return(false);

      // CopyBuffer writes the oldest requested closed-bar value at index zero.
      ma_first=ma_values[0];
      ma_last=ma_values[required_values-1];
      return(CopyClosedValue(m_adx_handle,0,adx) &&
             CopyClosedValue(m_adx_handle,1,plus_di) &&
             CopyClosedValue(m_adx_handle,2,minus_di));
     }

   void CalculateStructureScores(MqlRates &rates[],const int bar_count,
                                 const double noise_band,double &up_score,
                                 double &down_score)
     {
      int higher_highs=0;
      int higher_lows=0;
      int lower_highs=0;
      int lower_lows=0;
      const int comparisons=bar_count-1;

      for(int index=1;index<bar_count;index++)
        {
         if(rates[index].high>rates[index-1].high+noise_band)
            higher_highs++;
         if(rates[index].low>rates[index-1].low+noise_band)
            higher_lows++;
         if(rates[index].high<rates[index-1].high-noise_band)
            lower_highs++;
         if(rates[index].low<rates[index-1].low-noise_band)
            lower_lows++;
        }

      up_score=50.0*((double)higher_highs/comparisons+
                     (double)higher_lows/comparisons);
      down_score=50.0*((double)lower_highs/comparisons+
                       (double)lower_lows/comparisons);
     }

   double CalculateNoiseScore(MqlRates &rates[],const int bar_count,
                              const double noise_band)
     {
      double total_movement=0.0;
      double meaningful_movement=0.0;
      for(int index=1;index<bar_count;index++)
        {
         const double movement=MathAbs(rates[index].close-rates[index-1].close);
         total_movement+=movement;
         if(movement>noise_band)
            meaningful_movement+=movement;
        }

      if(total_movement<=0.0)
         return(0.0);

      return(100.0*meaningful_movement/total_movement);
     }

   double CalculateAdxStrength(const double adx)
     {
      if(adx<=0.0)
         return(0.0);

      return(MathMin(100.0,100.0*adx/50.0));
     }

   double CalculateConfidence(const string direction,const double slope_atr,
                              const double up_structure,const double down_structure,
                              const double plus_di,const double minus_di,
                              const double net_movement,const double noise_score)
     {
      if(direction=="NEUTRAL")
         return(0.0);

      const bool is_up=(direction=="UP");
      double agreement=0.0;
      if((is_up && slope_atr>0.0) || (!is_up && slope_atr<0.0))
         agreement+=30.0;
      if((is_up && up_structure>down_structure) ||
         (!is_up && down_structure>up_structure))
         agreement+=25.0;
      if((is_up && plus_di>minus_di) || (!is_up && minus_di>plus_di))
         agreement+=20.0;
      if((is_up && net_movement>0.0) || (!is_up && net_movement<0.0))
         agreement+=15.0;

      return(MathMin(100.0,agreement+(0.10*noise_score)));
     }

   bool BuildSnapshot(MqlRates &rates[],const int bar_count,const double atr,
                      const double ma_first,const double ma_last,const double adx,
                      const double plus_di,const double minus_di,STrendSnapshot &snapshot)
     {
      ResetSnapshot(snapshot);
      if(bar_count!=m_lookback_bars || atr<=0.0)
         return(false);

      const double point=SymbolInfoDouble(m_context.Symbol(),SYMBOL_POINT);
      if(point<=0.0)
         return(false);

      const double noise_band=MathMax(point,atr*m_noise_atr_fraction);
      const double slope_price=(ma_last-ma_first)/m_slope_bars;
      const double slope_atr=slope_price/atr;
      const double slope_strength=MathMin(100.0,
                                          100.0*MathAbs(slope_atr)/m_min_slope_atr_fraction);
      const double net_movement=rates[bar_count-1].close-rates[0].close;
      const double movement_strength=MathMin(100.0,
                                             100.0*MathAbs(net_movement)/(atr*m_min_atr_movement));
      const double noise_score=CalculateNoiseScore(rates,bar_count,noise_band);
      double up_structure=0.0;
      double down_structure=0.0;
      CalculateStructureScores(rates,bar_count,noise_band,up_structure,down_structure);
      const double adx_strength=CalculateAdxStrength(adx);

      double up_evidence=0.10*noise_score;
      double down_evidence=0.10*noise_score;
      if(slope_atr>m_min_slope_atr_fraction)
         up_evidence+=0.30*slope_strength;
      if(slope_atr<-m_min_slope_atr_fraction)
         down_evidence+=0.30*slope_strength;
      up_evidence+=0.25*up_structure;
      down_evidence+=0.25*down_structure;
      if(plus_di>minus_di)
         up_evidence+=0.20*adx_strength;
      if(minus_di>plus_di)
         down_evidence+=0.20*adx_strength;
      if(net_movement>noise_band)
         up_evidence+=0.15*movement_strength;
      if(net_movement<-noise_band)
         down_evidence+=0.15*movement_strength;

      snapshot.score=up_evidence-down_evidence;
      snapshot.strength=MathMax(up_evidence,down_evidence);
      if(snapshot.score>=m_direction_score_threshold)
         snapshot.direction="UP";
      else if(snapshot.score<=-m_direction_score_threshold)
         snapshot.direction="DOWN";
      else
         snapshot.direction="NEUTRAL";

      snapshot.slope_points=slope_price/point;
      snapshot.confidence=CalculateConfidence(snapshot.direction,slope_atr,
                                              up_structure,down_structure,plus_di,
                                              minus_di,net_movement,noise_score);
      snapshot.adx=adx;
      snapshot.plus_di=plus_di;
      snapshot.minus_di=minus_di;
      snapshot.is_data_valid=true;
      snapshot.is_trend=(snapshot.direction!="NEUTRAL" &&
                         snapshot.strength>=m_strength_threshold &&
                         snapshot.confidence>=m_confidence_threshold &&
                         adx>=m_min_adx);
      snapshot.updated_at=TimeCurrent();
      return(true);
     }

   bool PublishSnapshot(STrendSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      bool success=true;
      if(!m_context.PublishText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,
             "Direction",
             snapshot.direction))
         success=false;
      if(!m_context.PublishText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,
             "Strength",
             DoubleToString(snapshot.strength,2)))
         success=false;
      if(!m_context.PublishText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,
             "Score",
             DoubleToString(snapshot.score,2)))
         success=false;
      if(!m_context.PublishText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,
             "Slope",
             DoubleToString(snapshot.slope_points,4)))
         success=false;
      if(!m_context.PublishText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,
             "Confidence",
             DoubleToString(snapshot.confidence,2)))
         success=false;
      if(!m_context.PublishText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,
             "ADX",
             DoubleToString(snapshot.adx,2)))
         success=false;
      if(!m_context.PublishText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,
             "IsTrend",
             (snapshot.is_trend ? "true" : "false")))
         success=false;
      if(!m_context.PublishText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,
             "IsDataValid",
             (snapshot.is_data_valid ? "true" : "false")))
         success=false;
      if(!m_context.PublishText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,
             "UpdatedAt",
             TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS)))
         success=false;

      return(success);
     }

   //--- Completes the typed mirror only after canonical publication. The source
   //--- values are normalized to the exact existing DataBus precision after
   //--- integrity validation; EMA, ADX, DI, and scores are not recalculated.
   void BuildTypedSnapshot(STrendSnapshot &snapshot,
                           const datetime source_bar_time)
     {
      snapshot.symbol=m_context.Symbol();
      snapshot.timeframe=EnumToString(m_context.Timeframe());
      snapshot.snapshot_version=FENX_COMMON_TREND_SNAPSHOT_VERSION;
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="";
      snapshot.source_updated_at=snapshot.updated_at;
      snapshot.source_bar_time=source_bar_time;
      //--- CopyBuffer start_pos=1 is the latest completed source value.
      snapshot.ema_period=m_ma_period;
      snapshot.ema_shift=1;
      snapshot.adx_period=m_adx_period;
      snapshot.adx_shift=1;

      CTrendSnapshotContract contract;
      contract.Finalize(snapshot,TimeCurrent(),m_freshness_limit_seconds,
                        m_direction_score_threshold,m_strength_threshold,
                        m_confidence_threshold,m_min_adx);

      snapshot.strength=StringToDouble(DoubleToString(snapshot.strength,2));
      snapshot.score=StringToDouble(DoubleToString(snapshot.score,2));
      snapshot.slope_points=StringToDouble(DoubleToString(snapshot.slope_points,4));
      snapshot.confidence=StringToDouble(DoubleToString(snapshot.confidence,2));
      snapshot.adx=StringToDouble(DoubleToString(snapshot.adx,2));
     }

   bool SameTypedSnapshot(const STrendSnapshot &left,
                          const STrendSnapshot &right)
     {
      return(left.direction==right.direction &&
             left.strength==right.strength && left.score==right.score &&
             left.slope_points==right.slope_points &&
             left.confidence==right.confidence && left.adx==right.adx &&
             left.is_trend==right.is_trend &&
             left.is_data_valid==right.is_data_valid &&
             left.updated_at==right.updated_at &&
             left.symbol==right.symbol && left.timeframe==right.timeframe &&
             left.snapshot_version==right.snapshot_version &&
             left.is_valid==right.is_valid && left.is_fresh==right.is_fresh &&
             left.invalid_reason==right.invalid_reason &&
             left.plus_di==right.plus_di && left.minus_di==right.minus_di &&
             left.source_updated_at==right.source_updated_at &&
             left.source_bar_time==right.source_bar_time &&
             left.ema_period==right.ema_period &&
             left.ema_shift==right.ema_shift &&
             left.adx_period==right.adx_period &&
             left.adx_shift==right.adx_shift);
     }

   bool StoreTypedSnapshot(const STrendSnapshot &snapshot)
     {
      if(m_snapshot_store==NULL ||
         !m_snapshot_store.SetTrendSnapshot(m_context.Symbol(),m_context.Timeframe(),snapshot))
         return(false);
      if(m_consistency_verified)
         return(true);

      STrendSnapshot stored;
      if(!m_snapshot_store.GetTrendSnapshot(m_context.Symbol(),m_context.Timeframe(),stored) ||
         !SameTypedSnapshot(snapshot,stored))
         return(false);

      string direction="",strength="",score="",slope="",confidence="";
      string adx="",is_trend="",is_valid="",updated="";
      if(m_data_bus==NULL ||
         !m_context.ReadText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"Direction",direction) ||
         !m_context.ReadText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"Strength",strength) ||
         !m_context.ReadText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"Score",score) ||
         !m_context.ReadText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"Slope",slope) ||
         !m_context.ReadText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"Confidence",confidence) ||
         !m_context.ReadText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"ADX",adx) ||
         !m_context.ReadText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"IsTrend",is_trend) ||
         !m_context.ReadText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"IsDataValid",is_valid) ||
         !m_context.ReadText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"UpdatedAt",updated))
         return(false);

      return(direction==snapshot.direction &&
             strength==DoubleToString(snapshot.strength,2) &&
             score==DoubleToString(snapshot.score,2) &&
             slope==DoubleToString(snapshot.slope_points,4) &&
             confidence==DoubleToString(snapshot.confidence,2) &&
             adx==DoubleToString(snapshot.adx,2) &&
             is_trend==(snapshot.is_trend ? "true" : "false") &&
             is_valid==(snapshot.is_data_valid ? "true" : "false") &&
             updated==TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS));
     }

public:
                     CTrendDetector(void)
     {
      SetName("TrendDetector");
      m_ma_handle=INVALID_HANDLE;
      m_adx_handle=INVALID_HANDLE;
      m_lookback_bars=0;
      m_ma_period=0;
      m_slope_bars=0;
      m_adx_period=0;
      m_min_adx=0.0;
      m_min_slope_atr_fraction=0.0;
      m_min_atr_movement=0.0;
      m_noise_atr_fraction=0.0;
      m_direction_score_threshold=0.0;
      m_strength_threshold=0.0;
      m_confidence_threshold=0.0;
      m_freshness_limit_seconds=0;
      m_consistency_verified=false;
      m_snapshot_store=NULL;
      m_update_count=0;
      m_snapshot_count=0;
     }

   bool              SetRuntimeContext(const SRuntimeContextId &context_id)
     {
      return(!m_initialized && m_context.Configure(context_id));
     }

   //--- Injects the non-owning typed store before framework initialization.
   //--- All consumers use the canonical Trend context contract.
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
         CLogger::Error("TrendDetector requires CommonSnapshotStore before initialization.");
         return(false);
        }
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_lookback_bars=parameters.TrendLookbackBars();
      m_ma_period=parameters.TrendMaPeriod();
      m_slope_bars=parameters.TrendSlopeBars();
      m_adx_period=parameters.TrendAdxPeriod();
      m_min_adx=parameters.TrendMinAdx();
      m_min_slope_atr_fraction=parameters.TrendMinSlopeAtrFraction();
      m_min_atr_movement=parameters.TrendMinAtrMovement();
      m_noise_atr_fraction=parameters.TrendNoiseAtrFraction();
      m_direction_score_threshold=parameters.TrendDirectionScoreThreshold();
      m_strength_threshold=parameters.TrendStrengthThreshold();
      m_confidence_threshold=parameters.TrendConfidenceThreshold();
      m_freshness_limit_seconds=parameters.RiskStaleDataLimitSeconds();

      if(m_lookback_bars<10 || m_ma_period<2 || m_slope_bars<1 ||
         m_adx_period<2 || m_min_adx<0.0 || m_min_adx>100.0 ||
         m_min_slope_atr_fraction<=0.0 || m_min_atr_movement<=0.0 ||
         m_noise_atr_fraction<=0.0 || m_direction_score_threshold<0.0 ||
          m_direction_score_threshold>100.0 || m_strength_threshold<0.0 ||
          m_strength_threshold>100.0 || m_confidence_threshold<0.0 ||
          m_confidence_threshold>100.0 || m_freshness_limit_seconds<=0)
        {
         CLogger::Error("TrendDetector received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      ResetLastError();
      m_ma_handle=iMA(m_context.Symbol(),m_context.Timeframe(),m_ma_period,0,
                      MODE_EMA,PRICE_CLOSE);
      m_adx_handle=iADX(m_context.Symbol(),m_context.Timeframe(),m_adx_period);
      if(m_ma_handle==INVALID_HANDLE || m_adx_handle==INVALID_HANDLE)
        {
         CLogger::Error(StringFormat("TrendDetector could not create indicator handles. Error: %d",
                                     GetLastError()));
         Shutdown();
         return(false);
        }

      CLogger::Info(StringFormat("TrendDetector configured with EMA(%d), ADX(%d), and %d completed bars.",
                                 m_ma_period,m_adx_period,m_lookback_bars));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;
      m_update_count++;

      STrendSnapshot snapshot;
      ResetSnapshot(snapshot);
      double atr=0.0;
      double ma_first=0.0;
      double ma_last=0.0;
      double adx=0.0;
      double plus_di=0.0;
      double minus_di=0.0;
      MqlRates rates[];
      // start_pos=1 excludes the current forming candle; the copied array is oldest to newest.
      const int copied=CopyRates(m_context.Symbol(),m_context.Timeframe(),1,
                                 m_lookback_bars,rates);
      if(!ReadAtrFromDataBus(atr) || copied!=m_lookback_bars ||
         !ReadClosedIndicators(ma_first,ma_last,adx,plus_di,minus_di) ||
         !BuildSnapshot(rates,copied,atr,ma_first,ma_last,adx,plus_di,minus_di,snapshot))
        {
         CLogger::Warning("TrendDetector is waiting for valid ATR, indicators, or completed-bar history.");
        }

      if(!PublishSnapshot(snapshot))
        {
         CLogger::Error("TrendDetector could not publish its snapshot to DataBus.");
         return;
        }

      const datetime source_bar_time=(copied==m_lookback_bars ?
                                      rates[copied-1].time : 0);
      BuildTypedSnapshot(snapshot,source_bar_time);
      if(!StoreTypedSnapshot(snapshot))
        {
         CLogger::Error("TrendDetector could not store or verify its typed snapshot.");
         return;
        }
      m_snapshot_count++;
      if(!m_consistency_verified)
        {
         CLogger::Info(StringFormat(
            "[COMMON_TREND] typed_databus_consistency=PASS;symbol=%s;timeframe=%s;store_count=%d;keys=0;ema_period=%d;ema_shift=1;adx_period=%d;adx_shift=1;di_databus_available=false",
            snapshot.symbol,snapshot.timeframe,
            m_snapshot_store.TrendSnapshotCount(),snapshot.ema_period,
            snapshot.adx_period));
         m_consistency_verified=true;
        }
     }

   virtual void       Shutdown(void)
     {
      if(m_ma_handle!=INVALID_HANDLE)
        {
         IndicatorRelease(m_ma_handle);
         m_ma_handle=INVALID_HANDLE;
        }
      if(m_adx_handle!=INVALID_HANDLE)
        {
         IndicatorRelease(m_adx_handle);
         m_adx_handle=INVALID_HANDLE;
        }

      m_consistency_verified=false;
      CBaseEngine::Shutdown();
     }

   int               MaHandle(void) { return(m_ma_handle); }
   int               AdxHandle(void) { return(m_adx_handle); }
   long              UpdateCount(void) { return(m_update_count); }
   long              SnapshotCount(void) { return(m_snapshot_count); }
   SRuntimeContextId ContextId(void) { return(m_context.Id()); }
  };

#endif // FENX_ENVIRONMENT_TREND_DETECTOR_MQH

