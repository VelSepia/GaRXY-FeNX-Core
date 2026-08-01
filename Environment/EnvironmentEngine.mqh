//+------------------------------------------------------------------+
//|                           Environment/EnvironmentEngine.mqh     |
//+------------------------------------------------------------------+
#ifndef FENX_ENVIRONMENT_ENGINE_MQH
#define FENX_ENVIRONMENT_ENGINE_MQH

#include "../Common/Constants.mqh"
#include "../Common/CommonSnapshotStore.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"
#include "EnvironmentSnapshot.mqh"

//--- Consolidates existing Environment facts into a shadow-only snapshot.
//--- This engine does not recalculate indicators and does not make decisions.
class CEnvironmentEngine : public CBaseEngine
  {
private:
   int    m_freshness_limit_seconds;
   string m_last_invalid_reason;
   bool   m_valid_snapshot_logged;
   bool   m_consistency_logged;
   CCommonSnapshotStore *m_snapshot_store;

   void ResetSnapshot(SEnvironmentSnapshot &snapshot)
     {
      snapshot.symbol=_Symbol;
      snapshot.timeframe=EnumToString(_Period);
      snapshot.snapshot_version=FENX_COMMON_ENVIRONMENT_SNAPSHOT_VERSION;
      snapshot.updated_at=TimeCurrent();
      snapshot.is_valid=false;
      snapshot.is_fresh=false;
      snapshot.invalid_reason="";

      snapshot.atr=0.0;
      snapshot.volatility_score=0.0;
      snapshot.volatility_level="";
      snapshot.volatility_updated_at=0;
      snapshot.volatility_valid=false;

      snapshot.range_upper=0.0;
      snapshot.range_lower=0.0;
      snapshot.range_midpoint=0.0;
      snapshot.range_width_points=0.0;
      snapshot.range_position=0.0;
      snapshot.range_score=0.0;
      snapshot.is_range=false;
      snapshot.range_updated_at=0;
      snapshot.range_valid=false;

      snapshot.trend_direction="";
      snapshot.trend_strength=0.0;
      snapshot.trend_score=0.0;
      snapshot.trend_slope=0.0;
      snapshot.trend_confidence=0.0;
      snapshot.adx=0.0;
      snapshot.is_trend=false;
      snapshot.trend_updated_at=0;
      snapshot.trend_valid=false;

      snapshot.market_state="";
      snapshot.market_confidence=0.0;
      snapshot.recommended_style="";
      snapshot.recommended_risk="";
      snapshot.market_state_updated_at=0;
      snapshot.market_state_valid=false;
     }

   void AppendInvalidReason(string &reason,const string value)
     {
      if(StringLen(value)==0)
         return;
      if(StringLen(reason)>0)
         reason+="; ";
      reason+=value;
     }

   bool ReadText(const string key,string &value)
     {
      value="";
      return(m_data_bus!=NULL && m_data_bus.TryGetText(key,value) &&
             StringLen(value)>0);
     }

   bool ReadDouble(const string key,double &value)
     {
      string text="";
      value=0.0;
      if(!ReadText(key,text))
         return(false);
      value=StringToDouble(text);
      return(true);
     }

   bool ReadBoolean(const string key,bool &value)
     {
      string text="";
      value=false;
      if(!ReadText(key,text))
         return(false);
      if(text=="true" || text=="TRUE")
        {
         value=true;
         return(true);
        }
      if(text=="false" || text=="FALSE")
         return(true);
      return(false);
     }

   bool ReadTimestamp(const string key,datetime &value)
     {
      string text="";
      value=0;
      if(!ReadText(key,text))
         return(false);
      value=StringToTime(text);
      return(value>0);
     }

   bool IsScore(const double value)
     {
      return(value>=0.0 && value<=100.0);
     }

   bool IsFreshTimestamp(const datetime value)
     {
      if(value<=0 || m_freshness_limit_seconds<=0)
         return(false);
      const long age_seconds=(long)(TimeCurrent()-value);
      return(age_seconds>=0 && age_seconds<=m_freshness_limit_seconds);
     }

   datetime OldestTimestamp(const datetime first,const datetime second,
                            const datetime third)
     {
      if(first<=0 || second<=0 || third<=0)
         return(0);
      return((datetime)MathMin((long)first,MathMin((long)second,(long)third)));
     }

   bool ReadSnapshot(SEnvironmentSnapshot &snapshot)
     {
      bool range_source_valid=false;
      bool trend_source_valid=false;
      datetime range_closed_bar_time=0;

      const bool volatility_available=
         ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_ATR,snapshot.atr) &&
         ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,
                    snapshot.volatility_score) &&
         ReadText(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_LEVEL,
                  snapshot.volatility_level);

      const bool range_available=
         ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPPER,snapshot.range_upper) &&
         ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_LOWER,snapshot.range_lower) &&
         ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_MIDPOINT,
                    snapshot.range_midpoint) &&
         ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_WIDTH_POINTS,
                    snapshot.range_width_points) &&
         ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_POSITION,
                    snapshot.range_position) &&
         ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,snapshot.range_score) &&
         ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_IS_RANGE,snapshot.is_range) &&
         ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,
                     range_source_valid) &&
         ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPDATED_AT,
                       snapshot.range_updated_at) &&
         ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_CLOSED_BAR_TIME,
                       range_closed_bar_time);

      const bool trend_available=
         ReadText(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DIRECTION,
                  snapshot.trend_direction) &&
         ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_STRENGTH,
                    snapshot.trend_strength) &&
         ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_SCORE,snapshot.trend_score) &&
         ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_SLOPE,snapshot.trend_slope) &&
         ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_CONFIDENCE,
                    snapshot.trend_confidence) &&
         ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_ADX,snapshot.adx) &&
         ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_IS_TREND,snapshot.is_trend) &&
         ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DATA_VALID,
                     trend_source_valid) &&
         ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_TREND_UPDATED_AT,
                       snapshot.trend_updated_at);

      const bool market_state_available=
         ReadText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE,snapshot.market_state) &&
         ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_CONFIDENCE,
                    snapshot.market_confidence) &&
         ReadText(FENX_DATABUS_KEY_ENVIRONMENT_RECOMMENDED_STYLE,
                  snapshot.recommended_style) &&
         ReadText(FENX_DATABUS_KEY_ENVIRONMENT_RECOMMENDED_RISK,
                  snapshot.recommended_risk) &&
         ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT,
                       snapshot.market_state_updated_at);

      // VolatilityAnalyzer has no public timestamp in the legacy contract.
      // Range, Trend, and Market State all consume its current facts earlier in
      // this update, so their oldest timestamp is the conservative observation
      // time without modifying any existing engine or DataBus namespace.
      snapshot.volatility_updated_at=
         OldestTimestamp(snapshot.range_updated_at,snapshot.trend_updated_at,
                         snapshot.market_state_updated_at);

      snapshot.volatility_valid=
         (volatility_available && snapshot.atr>0.0 &&
          IsScore(snapshot.volatility_score) &&
          (snapshot.volatility_level=="LOW" ||
           snapshot.volatility_level=="NORMAL" ||
           snapshot.volatility_level=="HIGH") &&
          snapshot.volatility_updated_at>0);
      if(!snapshot.volatility_valid)
         AppendInvalidReason(snapshot.invalid_reason,
                             "Volatility source is missing or invalid");

      const datetime current_closed_bar=iTime(_Symbol,_Period,1);
      snapshot.range_valid=
         (range_available && range_source_valid &&
          snapshot.range_upper>snapshot.range_lower &&
          snapshot.range_midpoint>=snapshot.range_lower &&
          snapshot.range_midpoint<=snapshot.range_upper &&
          snapshot.range_width_points>0.0 &&
          snapshot.range_position>=0.0 && snapshot.range_position<=1.0 &&
          IsScore(snapshot.range_score) && current_closed_bar>0 &&
          range_closed_bar_time==current_closed_bar);
      if(!snapshot.range_valid)
         AppendInvalidReason(snapshot.invalid_reason,
                             "Range source is missing, invalid, or not on the current timeframe");

      snapshot.trend_valid=
         (trend_available && trend_source_valid &&
          (snapshot.trend_direction=="UP" ||
           snapshot.trend_direction=="DOWN" ||
           snapshot.trend_direction=="NEUTRAL") &&
          IsScore(snapshot.trend_strength) &&
          snapshot.trend_score>=-100.0 && snapshot.trend_score<=100.0 &&
          IsScore(snapshot.trend_confidence) && IsScore(snapshot.adx));
      if(!snapshot.trend_valid)
         AppendInvalidReason(snapshot.invalid_reason,
                             "Trend source is missing or invalid");

      snapshot.market_state_valid=
         (market_state_available &&
          (snapshot.market_state=="RANGING" ||
           snapshot.market_state=="TRENDING" ||
           snapshot.market_state=="VOLATILE" ||
           snapshot.market_state=="TRANSITION") &&
          IsScore(snapshot.market_confidence));
      if(!snapshot.market_state_valid)
         AppendInvalidReason(snapshot.invalid_reason,
                             "Market State source is missing or invalid");

      if(StringLen(snapshot.symbol)==0 || StringLen(snapshot.timeframe)==0 ||
         PeriodSeconds(_Period)<=0)
         AppendInvalidReason(snapshot.invalid_reason,
                             "Snapshot symbol or timeframe identity is invalid");

      snapshot.is_fresh=
         (IsFreshTimestamp(snapshot.volatility_updated_at) &&
          IsFreshTimestamp(snapshot.range_updated_at) &&
          IsFreshTimestamp(snapshot.trend_updated_at) &&
          IsFreshTimestamp(snapshot.market_state_updated_at));
      if(!snapshot.is_fresh)
         AppendInvalidReason(snapshot.invalid_reason,
                             "One or more source snapshots are stale or future-dated");

      snapshot.is_valid=(snapshot.volatility_valid && snapshot.range_valid &&
                         snapshot.trend_valid && snapshot.market_state_valid &&
                         snapshot.is_fresh &&
                         StringLen(snapshot.invalid_reason)==0);
      return(snapshot.is_valid);
     }

   bool SameSnapshot(const SEnvironmentSnapshot &left,
                     const SEnvironmentSnapshot &right)
     {
      return(left.symbol==right.symbol && left.timeframe==right.timeframe &&
             left.snapshot_version==right.snapshot_version &&
             left.updated_at==right.updated_at && left.is_valid==right.is_valid &&
             left.is_fresh==right.is_fresh &&
             left.invalid_reason==right.invalid_reason &&
             left.atr==right.atr &&
             left.volatility_score==right.volatility_score &&
             left.volatility_level==right.volatility_level &&
             left.volatility_updated_at==right.volatility_updated_at &&
             left.volatility_valid==right.volatility_valid &&
             left.range_upper==right.range_upper &&
             left.range_lower==right.range_lower &&
             left.range_midpoint==right.range_midpoint &&
             left.range_width_points==right.range_width_points &&
             left.range_position==right.range_position &&
             left.range_score==right.range_score &&
             left.is_range==right.is_range &&
             left.range_updated_at==right.range_updated_at &&
             left.range_valid==right.range_valid &&
             left.trend_direction==right.trend_direction &&
             left.trend_strength==right.trend_strength &&
             left.trend_score==right.trend_score &&
             left.trend_slope==right.trend_slope &&
             left.trend_confidence==right.trend_confidence &&
             left.adx==right.adx && left.is_trend==right.is_trend &&
             left.trend_updated_at==right.trend_updated_at &&
             left.trend_valid==right.trend_valid &&
             left.market_state==right.market_state &&
             left.market_confidence==right.market_confidence &&
             left.recommended_style==right.recommended_style &&
             left.recommended_risk==right.recommended_risk &&
             left.market_state_updated_at==right.market_state_updated_at &&
             left.market_state_valid==right.market_state_valid);
     }

   bool StoreTypedSnapshot(const SEnvironmentSnapshot &snapshot)
     {
      if(m_snapshot_store==NULL ||
         !m_snapshot_store.SetEnvironmentSnapshot(_Symbol,_Period,snapshot))
         return(false);

      // A full typed/DataBus comparison is required only for the first
      // successfully published snapshot.  Subsequent ticks still refresh the
      // typed record, but avoid a redundant lookup and field-by-field compare.
      if(m_consistency_logged)
         return(true);

      SEnvironmentSnapshot stored;
      if(!m_snapshot_store.GetEnvironmentSnapshot(_Symbol,_Period,stored))
         return(false);
      return(SameSnapshot(snapshot,stored));
     }

   bool PublishField(const string field,const string value)
     {
      if(m_data_bus==NULL ||
         !m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_COMMON_ENVIRONMENT,
                                   _Symbol,field,value))
         return(false);

      // Verify every serialized field on the first complete publication only.
      // Later ticks avoid the extra linear DataBus reads.
      if(!m_consistency_logged)
        {
         string stored="";
         if(!m_data_bus.TryGetSymbolText(
               FENX_DATABUS_NAMESPACE_COMMON_ENVIRONMENT,_Symbol,field,stored) ||
            stored!=value)
            return(false);
        }
      return(true);
     }

   bool PublishSnapshot(const SEnvironmentSnapshot &snapshot)
     {
      const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      bool success=true;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_VALID,
                       (snapshot.is_valid ? "true" : "false"))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_FRESH,
                       (snapshot.is_fresh ? "true" : "false"))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_VERSION,
                       snapshot.snapshot_version)) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_UPDATED_AT,
                       TimeToString(snapshot.updated_at,
                                    TIME_DATE|TIME_SECONDS))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_INVALID_REASON,
                       snapshot.invalid_reason)) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_SYMBOL,
                       snapshot.symbol)) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_TIMEFRAME,
                       snapshot.timeframe)) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_VOLATILITY_VALID,
                       (snapshot.volatility_valid ? "true" : "false"))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RANGE_VALID,
                       (snapshot.range_valid ? "true" : "false"))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_TREND_VALID,
                       (snapshot.trend_valid ? "true" : "false"))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_MARKET_STATE_VALID,
                       (snapshot.market_state_valid ? "true" : "false"))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_ATR,
                       DoubleToString(snapshot.atr,digits))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_VOLATILITY_SCORE,
                       DoubleToString(snapshot.volatility_score,2))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_VOLATILITY_LEVEL,
                       snapshot.volatility_level)) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RANGE_UPPER,
                       DoubleToString(snapshot.range_upper,digits))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RANGE_LOWER,
                       DoubleToString(snapshot.range_lower,digits))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RANGE_MIDPOINT,
                       DoubleToString(snapshot.range_midpoint,digits))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RANGE_WIDTH_POINTS,
                       DoubleToString(snapshot.range_width_points,2))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RANGE_POSITION,
                       DoubleToString(snapshot.range_position,4))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RANGE_SCORE,
                       DoubleToString(snapshot.range_score,2))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_IS_RANGE,
                       (snapshot.is_range ? "true" : "false"))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_TREND_DIRECTION,
                       snapshot.trend_direction)) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_TREND_STRENGTH,
                       DoubleToString(snapshot.trend_strength,2))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_TREND_SCORE,
                       DoubleToString(snapshot.trend_score,2))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_TREND_SLOPE,
                       DoubleToString(snapshot.trend_slope,4))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_TREND_CONFIDENCE,
                       DoubleToString(snapshot.trend_confidence,2))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_ADX,
                       DoubleToString(snapshot.adx,2))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_IS_TREND,
                       (snapshot.is_trend ? "true" : "false"))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_MARKET_STATE,
                       snapshot.market_state)) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_MARKET_CONFIDENCE,
                       DoubleToString(snapshot.market_confidence,2))) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RECOMMENDED_STYLE,
                       snapshot.recommended_style)) success=false;
      if(!PublishField(FENX_DATABUS_FIELD_COMMON_ENVIRONMENT_RECOMMENDED_RISK,
                       snapshot.recommended_risk)) success=false;
      return(success);
     }

public:
                     CEnvironmentEngine(void)
     {
      SetName("EnvironmentEngine");
      m_freshness_limit_seconds=0;
      m_last_invalid_reason="";
      m_valid_snapshot_logged=false;
      m_consistency_logged=false;
      m_snapshot_store=NULL;
     }

   //--- Injects the non-owning typed store before framework initialization.
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
         CLogger::Error("EnvironmentEngine requires CommonSnapshotStore before initialization.");
         return(false);
        }
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);
      m_freshness_limit_seconds=parameters.RiskStaleDataLimitSeconds();
      if(m_freshness_limit_seconds<=0)
        {
         CLogger::Error("EnvironmentEngine received an invalid freshness limit.");
         CBaseEngine::Shutdown();
         return(false);
        }
      CLogger::Info(StringFormat(
         "EnvironmentEngine initialized in shadow-only mode with a %d-second freshness limit.",
         m_freshness_limit_seconds));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;

      SEnvironmentSnapshot snapshot;
      ResetSnapshot(snapshot);
      ReadSnapshot(snapshot);
      if(!StoreTypedSnapshot(snapshot))
        {
         CLogger::Error("EnvironmentEngine could not store or verify its typed snapshot.");
         return;
        }
      if(!PublishSnapshot(snapshot))
        {
         CLogger::Error("EnvironmentEngine could not publish its shadow snapshot.");
         return;
        }

      if(!m_consistency_logged)
        {
         CLogger::Info(StringFormat(
            "[COMMON_SNAPSHOT] typed_databus_consistency=PASS;symbol=%s;timeframe=%s;store_count=%d;keys=%d",
            snapshot.symbol,snapshot.timeframe,m_snapshot_store.Count(),
            FENX_COMMON_ENVIRONMENT_KEY_COUNT));
         m_consistency_logged=true;
        }

      if(snapshot.is_valid && !m_valid_snapshot_logged)
        {
         CLogger::Info(StringFormat(
            "[COMMON_ENVIRONMENT] snapshot=VALID;symbol=%s;timeframe=%s;version=%s;keys=%d",
            snapshot.symbol,snapshot.timeframe,snapshot.snapshot_version,
            FENX_COMMON_ENVIRONMENT_KEY_COUNT));
         m_valid_snapshot_logged=true;
        }
      if(!snapshot.is_valid && snapshot.invalid_reason!=m_last_invalid_reason)
         CLogger::Warning("[COMMON_ENVIRONMENT] snapshot=INVALID;reason="+
                          snapshot.invalid_reason);
      m_last_invalid_reason=snapshot.invalid_reason;
     }

   virtual void       Shutdown(void)
     {
      m_last_invalid_reason="";
      m_valid_snapshot_logged=false;
      m_consistency_logged=false;
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_ENVIRONMENT_ENGINE_MQH
