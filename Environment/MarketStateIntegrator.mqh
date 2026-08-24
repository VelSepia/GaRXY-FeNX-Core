//+------------------------------------------------------------------+
//|                         Environment/MarketStateIntegrator.mqh  |
//+------------------------------------------------------------------+
#ifndef FENX_ENVIRONMENT_MARKET_STATE_INTEGRATOR_MQH
#define FENX_ENVIRONMENT_MARKET_STATE_INTEGRATOR_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Common/CommonSnapshotStore.mqh"
#include "../Core/AnalysisContextBinding.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Combines published environment facts into one non-trading market-state description.
class CMarketStateIntegrator : public CBaseEngine
  {
private:
   double m_range_score_threshold;
   double m_range_max_trend_score;
   double m_trend_score_threshold;
   double m_volatility_score_threshold;
   double m_trend_min_adx;
   int    m_freshness_limit_seconds;
   bool   m_consistency_verified;
   CCommonSnapshotStore *m_snapshot_store;
   CAnalysisContextBinding m_context;
   long   m_update_count;
   long   m_snapshot_count;

   void ResetSnapshot(SMarketStateSnapshot &snapshot)
     {
      snapshot.market_state="TRANSITION";
      snapshot.confidence=0.0;
      snapshot.recommended_trading_style="Standby";
      snapshot.recommended_risk_level="Low";
      snapshot.updated_at=TimeCurrent();
      snapshot.is_data_valid=false;
      snapshot.symbol="";
      snapshot.timeframe="";
      snapshot.snapshot_version="";
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="";
      snapshot.volatility_valid=false;
      snapshot.range_valid=false;
      snapshot.trend_valid=false;
      snapshot.volatility_score=0.0;
      snapshot.volatility_level="";
      snapshot.range_score=0.0;
      snapshot.is_range=false;
      snapshot.trend_direction="";
      snapshot.trend_strength=0.0;
      snapshot.trend_score=0.0;
      snapshot.trend_confidence=0.0;
      snapshot.is_trend=false;
      snapshot.source_updated_at=0;
      snapshot.volatility_updated_at=0;
      snapshot.range_updated_at=0;
      snapshot.trend_updated_at=0;
      snapshot.source_bar_time=0;
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
      if(!m_context.ReadText(m_data_bus,name_space,field,text) || StringLen(text)==0)
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

   bool ReadText(const string name_space,const string field,string &value)
     {
      if(m_data_bus==NULL || !m_context.ReadText(m_data_bus,name_space,field,value))
         return(false);
      return(StringLen(value)>0);
     }

   bool ReadTimestamp(const string name_space,const string field,datetime &value)
     {
      string text="";
      if(!ReadText(name_space,field,text))
         return(false);
      value=StringToTime(text);
      return(value>0);
     }

   bool ReadInputs(double &range_score,bool &is_range,double &trend_score,
                   double &trend_strength,double &volatility_score,double &atr,
                   double &adx)
     {
      return(ReadDouble(FENX_DATABUS_NAMESPACE_CONTEXT_RANGE,"Score",range_score) &&
             ReadBoolean(FENX_DATABUS_NAMESPACE_CONTEXT_RANGE,"IsRange",is_range) &&
             ReadDouble(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"Score",trend_score) &&
             ReadDouble(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"Strength",trend_strength) &&
             ReadDouble(FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,"Score",volatility_score) &&
             ReadDouble(FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,"ATR",atr) &&
             ReadDouble(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"ADX",adx));
     }

   bool BuildSnapshot(const double range_score,const bool is_range,
                      const double trend_score,const double trend_strength,
                      const double volatility_score,const double atr,const double adx,
                      SMarketStateSnapshot &snapshot)
     {
      ResetSnapshot(snapshot);
      if(atr<=0.0)
         return(false);

      const double normalized_range_score=ClampScore(range_score);
      // TrendScore is signed; use its magnitude so UP and DOWN trends are treated symmetrically.
      const double trend_magnitude=ClampScore(MathAbs(trend_score));
      const double normalized_trend_strength=ClampScore(trend_strength);
      const double normalized_volatility_score=ClampScore(volatility_score);
      const double normalized_adx=ClampScore(adx);
      const double adx_strength=ClampScore(2.0*normalized_adx);

      if(is_range && normalized_range_score>m_range_score_threshold &&
         trend_magnitude<m_range_max_trend_score)
        {
         snapshot.market_state="RANGING";
         snapshot.confidence=ClampScore((0.50*normalized_range_score)+
                                        (0.30*(100.0-trend_magnitude))+20.0);
         snapshot.recommended_trading_style="Range";
         snapshot.recommended_risk_level=(normalized_volatility_score>
                                          m_volatility_score_threshold ? "High" : "Medium");
        }
      else if(trend_magnitude>m_trend_score_threshold && normalized_adx>=m_trend_min_adx)
        {
         snapshot.market_state="TRENDING";
         snapshot.confidence=ClampScore((0.45*trend_magnitude)+
                                        (0.30*normalized_trend_strength)+
                                        (0.25*adx_strength));
         snapshot.recommended_trading_style="Trend";
         snapshot.recommended_risk_level=(normalized_volatility_score>
                                          m_volatility_score_threshold ? "High" : "Medium");
        }
      else if(normalized_volatility_score>m_volatility_score_threshold)
        {
         snapshot.market_state="VOLATILE";
         snapshot.confidence=normalized_volatility_score;
         snapshot.recommended_trading_style="Standby";
         snapshot.recommended_risk_level="High";
        }
      else
        {
         const double strongest_evidence=MathMax(normalized_range_score,
                                         MathMax(trend_magnitude,normalized_volatility_score));
         snapshot.market_state="TRANSITION";
         snapshot.confidence=ClampScore(100.0-strongest_evidence);
         snapshot.recommended_trading_style="Standby";
         snapshot.recommended_risk_level="Low";
        }

      snapshot.updated_at=TimeCurrent();
      snapshot.is_data_valid=true;
      return(true);
     }

   bool PublishSnapshot(SMarketStateSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      bool success=true;
      if(!m_context.PublishText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,
             "State",
             snapshot.market_state))
         success=false;
      if(!m_context.PublishText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,
             "Confidence",
             DoubleToString(snapshot.confidence,2)))
         success=false;
      if(!m_context.PublishText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,
             "RecommendedTradingStyle",
             snapshot.recommended_trading_style))
         success=false;
      if(!m_context.PublishText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,
             "RecommendedRiskLevel",
             snapshot.recommended_risk_level))
         success=false;
      if(!m_context.PublishText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,
             "UpdatedAt",
             TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS)))
         success=false;

      return(success);
     }

   //--- Mirrors the exact canonical source values after Market State has already
   //--- been classified and published. These reads never participate in the
   //--- existing classification predicates or their priority.
   void BuildTypedSnapshot(SMarketStateSnapshot &snapshot,
                           const double range_score,const bool is_range,
                           const double trend_score,const double trend_strength,
                           const double volatility_score,const double atr)
     {
      snapshot.symbol=m_context.Symbol();
      snapshot.timeframe=EnumToString(m_context.Timeframe());
      snapshot.snapshot_version=FENX_COMMON_MARKET_STATE_SNAPSHOT_VERSION;
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="";
      snapshot.range_score=range_score;
      snapshot.is_range=is_range;
      snapshot.trend_score=trend_score;
      snapshot.trend_strength=trend_strength;
      snapshot.volatility_score=volatility_score;

      bool range_source_valid=false;
      bool trend_source_valid=false;
      const bool range_valid_read=
         ReadBoolean(FENX_DATABUS_NAMESPACE_CONTEXT_RANGE,"IsDataValid",
                      range_source_valid);
      const bool trend_valid_read=
         ReadBoolean(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"IsDataValid",
                      trend_source_valid);
      const bool volatility_level_read=
         ReadText(FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,"Level",
                   snapshot.volatility_level);
      const bool trend_direction_read=
         ReadText(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"Direction",
                   snapshot.trend_direction);
      const bool trend_confidence_read=
         ReadDouble(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"Confidence",
                     snapshot.trend_confidence);
      const bool is_trend_read=
         ReadBoolean(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"IsTrend",snapshot.is_trend);
      const bool range_time_read=
         ReadTimestamp(FENX_DATABUS_NAMESPACE_CONTEXT_RANGE,"UpdatedAt",
                        snapshot.range_updated_at);
      const bool trend_time_read=
         ReadTimestamp(FENX_DATABUS_NAMESPACE_CONTEXT_TREND,"UpdatedAt",
                        snapshot.trend_updated_at);
      ReadTimestamp(FENX_DATABUS_NAMESPACE_CONTEXT_RANGE,"ClosedBarTime",
                     snapshot.source_bar_time);

      snapshot.volatility_valid=(snapshot.is_data_valid &&
                                  volatility_level_read && atr>0.0 &&
                                  volatility_score>=0.0 &&
                                  volatility_score<=100.0);
      snapshot.range_valid=(range_valid_read && range_source_valid);
      snapshot.trend_valid=(trend_valid_read && trend_source_valid &&
                            trend_direction_read && trend_confidence_read &&
                            is_trend_read);
      //--- No legacy Volatility timestamp exists; do not infer one.
      snapshot.volatility_updated_at=0;
      snapshot.source_updated_at=
         (range_time_read && trend_time_read ?
          (snapshot.range_updated_at<=snapshot.trend_updated_at ?
           snapshot.range_updated_at : snapshot.trend_updated_at) : 0);

      CMarketStateSnapshotContract contract;
      contract.Finalize(snapshot,TimeCurrent(),m_freshness_limit_seconds);

      //--- Match the existing public precision without changing DataBus.
      snapshot.confidence=StringToDouble(DoubleToString(snapshot.confidence,2));
     }

   bool SameTypedSnapshot(const SMarketStateSnapshot &left,
                          const SMarketStateSnapshot &right)
     {
      return(left.market_state==right.market_state &&
             left.confidence==right.confidence &&
             left.recommended_trading_style==right.recommended_trading_style &&
             left.recommended_risk_level==right.recommended_risk_level &&
             left.updated_at==right.updated_at &&
             left.is_data_valid==right.is_data_valid &&
             left.symbol==right.symbol && left.timeframe==right.timeframe &&
             left.snapshot_version==right.snapshot_version &&
             left.is_valid==right.is_valid && left.is_fresh==right.is_fresh &&
             left.invalid_reason==right.invalid_reason &&
             left.volatility_valid==right.volatility_valid &&
             left.range_valid==right.range_valid &&
             left.trend_valid==right.trend_valid &&
             left.volatility_score==right.volatility_score &&
             left.volatility_level==right.volatility_level &&
             left.range_score==right.range_score &&
             left.is_range==right.is_range &&
             left.trend_direction==right.trend_direction &&
             left.trend_strength==right.trend_strength &&
             left.trend_score==right.trend_score &&
             left.trend_confidence==right.trend_confidence &&
             left.is_trend==right.is_trend &&
             left.source_updated_at==right.source_updated_at &&
             left.volatility_updated_at==right.volatility_updated_at &&
             left.range_updated_at==right.range_updated_at &&
             left.trend_updated_at==right.trend_updated_at &&
             left.source_bar_time==right.source_bar_time);
     }

   bool StoreTypedSnapshot(const SMarketStateSnapshot &snapshot)
     {
      if(m_snapshot_store==NULL ||
         !m_snapshot_store.SetMarketStateSnapshot(m_context.Symbol(),m_context.Timeframe(),snapshot))
         return(false);
      if(m_consistency_verified)
         return(true);

      SMarketStateSnapshot stored;
      if(!m_snapshot_store.GetMarketStateSnapshot(m_context.Symbol(),m_context.Timeframe(),stored) ||
         !SameTypedSnapshot(snapshot,stored))
         return(false);

      string state="",confidence="",style="",risk="",updated="";
      if(m_data_bus==NULL ||
         !m_context.ReadText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,"State",state) ||
         !m_context.ReadText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,"Confidence",confidence) ||
         !m_context.ReadText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,"RecommendedTradingStyle",style) ||
         !m_context.ReadText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,"RecommendedRiskLevel",risk) ||
         !m_context.ReadText(m_data_bus,FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,"UpdatedAt",updated))
         return(false);

      return(state==snapshot.market_state &&
             confidence==DoubleToString(snapshot.confidence,2) &&
             style==snapshot.recommended_trading_style &&
             risk==snapshot.recommended_risk_level &&
             updated==TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS));
     }

public:
                     CMarketStateIntegrator(void)
     {
      SetName("MarketStateIntegrator");
      m_range_score_threshold=0.0;
      m_range_max_trend_score=0.0;
      m_trend_score_threshold=0.0;
      m_volatility_score_threshold=0.0;
      m_trend_min_adx=0.0;
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
   //--- All consumers use the canonical Market context contract.
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
         CLogger::Error("MarketStateIntegrator requires CommonSnapshotStore before initialization.");
         return(false);
        }
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_range_score_threshold=parameters.MarketRangeScoreThreshold();
      m_range_max_trend_score=parameters.MarketRangeMaxTrendScore();
      m_trend_score_threshold=parameters.MarketTrendScoreThreshold();
      m_volatility_score_threshold=parameters.MarketVolatilityScoreThreshold();
      m_trend_min_adx=parameters.MarketTrendMinAdx();
      m_freshness_limit_seconds=parameters.RiskStaleDataLimitSeconds();

      if(m_range_score_threshold<0.0 || m_range_score_threshold>100.0 ||
         m_range_max_trend_score<0.0 || m_range_max_trend_score>100.0 ||
          m_trend_score_threshold<0.0 || m_trend_score_threshold>100.0 ||
          m_volatility_score_threshold<0.0 || m_volatility_score_threshold>100.0 ||
          m_trend_min_adx<0.0 || m_trend_min_adx>100.0 ||
          m_freshness_limit_seconds<=0)
        {
         CLogger::Error("MarketStateIntegrator received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      CLogger::Info("MarketStateIntegrator initialized with DataBus-only inputs.");
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;
      m_update_count++;

      SMarketStateSnapshot snapshot;
      ResetSnapshot(snapshot);
      double range_score=0.0;
      bool is_range=false;
      double trend_score=0.0;
      double trend_strength=0.0;
      double volatility_score=0.0;
      double atr=0.0;
      double adx=0.0;
      if(!ReadInputs(range_score,is_range,trend_score,trend_strength,
                     volatility_score,atr,adx) ||
         !BuildSnapshot(range_score,is_range,trend_score,trend_strength,
                        volatility_score,atr,adx,snapshot))
        {
         CLogger::Warning("MarketStateIntegrator is waiting for complete DataBus inputs.");
        }

      if(!PublishSnapshot(snapshot))
        {
         CLogger::Error("MarketStateIntegrator could not publish its snapshot to DataBus.");
         return;
        }

      BuildTypedSnapshot(snapshot,range_score,is_range,trend_score,
                         trend_strength,volatility_score,atr);
      if(!StoreTypedSnapshot(snapshot))
        {
         CLogger::Error("MarketStateIntegrator could not store or verify its typed snapshot.");
         return;
        }
      m_snapshot_count++;
      if(!m_consistency_verified)
        {
         CLogger::Info(StringFormat(
            "[COMMON_MARKET_STATE] typed_databus_consistency=PASS;symbol=%s;timeframe=%s;store_count=%d;keys=0;volatility_timestamp_available=false;priority=RANGING,TRENDING,VOLATILE,TRANSITION",
            snapshot.symbol,snapshot.timeframe,
            m_snapshot_store.MarketStateSnapshotCount()));
         m_consistency_verified=true;
        }
     }

   virtual void       Shutdown(void)
     {
      // MarketStateIntegrator owns no indicator or account resources.
      m_consistency_verified=false;
      CBaseEngine::Shutdown();
     }

   long              UpdateCount(void) { return(m_update_count); }
   long              SnapshotCount(void) { return(m_snapshot_count); }
   SRuntimeContextId ContextId(void) { return(m_context.Id()); }
  };

#endif // FENX_ENVIRONMENT_MARKET_STATE_INTEGRATOR_MQH

