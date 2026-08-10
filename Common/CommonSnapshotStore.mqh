//+------------------------------------------------------------------+
//|                                Common/CommonSnapshotStore.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_SNAPSHOT_STORE_MQH
#define FENX_COMMON_SNAPSHOT_STORE_MQH

#include "../Environment/EnvironmentSnapshot.mqh"
#include "../Environment/VolatilitySnapshot.mqh"
#include "../Environment/RangeSnapshot.mqh"
#include "../Environment/TrendSnapshot.mqh"
#include "../Confidence/ConfidenceSnapshot.mqh"
#include "../Decision/DecisionScoreSnapshot.mqh"

//--- Metadata and typed payload for one Environment snapshot identity.
struct SCommonEnvironmentSnapshotRecord
  {
   string               symbol;
   ENUM_TIMEFRAMES      timeframe;
   string               snapshot_type;
   string               snapshot_version;
   datetime             updated_at;
   bool                 is_valid;
   SEnvironmentSnapshot environment;
  };

//--- Metadata and typed payload for one Common Volatility identity.
struct SCommonVolatilitySnapshotRecord
  {
   string              symbol;
   ENUM_TIMEFRAMES     timeframe;
   string              snapshot_type;
   string              snapshot_version;
   datetime            updated_at;
   bool                is_valid;
   SVolatilitySnapshot volatility;
  };

//--- Metadata and typed payload for one Common Range identity.
struct SCommonRangeSnapshotRecord
  {
   string         symbol;
   ENUM_TIMEFRAMES timeframe;
   string         snapshot_type;
   string         snapshot_version;
   datetime       updated_at;
   bool           is_valid;
   SRangeSnapshot range;
  };

//--- Metadata and typed payload for one Common Trend identity.
struct SCommonTrendSnapshotRecord
  {
   string          symbol;
   ENUM_TIMEFRAMES timeframe;
   string          snapshot_type;
   string          snapshot_version;
   datetime        updated_at;
   bool            is_valid;
   STrendSnapshot  trend;
  };

//--- Metadata and typed payload for one Common Confidence identity.
struct SCommonConfidenceSnapshotRecord
  {
   string              symbol;
   ENUM_TIMEFRAMES     timeframe;
   string              snapshot_type;
   string              snapshot_version;
   datetime            updated_at;
   bool                is_valid;
   SConfidenceSnapshot confidence;
  };

//--- Metadata and typed payload for one Common Decision Score identity.
struct SCommonDecisionScoreSnapshotRecord
  {
   string                 symbol;
   ENUM_TIMEFRAMES        timeframe;
   string                 snapshot_type;
   string                 snapshot_version;
   datetime               updated_at;
   bool                   is_valid;
   SDecisionScoreSnapshot decision_score;
  };

//--- Shadow-only typed storage shared by Original/Personal common engines.
//--- Each API keeps its existing Symbol+Timeframe identity and does not change
//--- legacy DataBus consumers or their trading behavior.
class CCommonSnapshotStore
  {
private:
   SCommonEnvironmentSnapshotRecord m_environment_records[];
   SCommonVolatilitySnapshotRecord  m_volatility_records[];
   SCommonRangeSnapshotRecord       m_range_records[];
   SCommonTrendSnapshotRecord       m_trend_records[];
   SCommonConfidenceSnapshotRecord  m_confidence_records[];
   SCommonDecisionScoreSnapshotRecord m_decision_score_records[];

   int               FindEnvironmentIndex(const string symbol,
                                          const ENUM_TIMEFRAMES timeframe)
     {
      for(int index=0;index<ArraySize(m_environment_records);index++)
        {
         if(m_environment_records[index].symbol==symbol &&
            m_environment_records[index].timeframe==timeframe)
            return(index);
        }
      return(-1);
     }

   int               FindConfidenceIndex(const string symbol,
                                         const ENUM_TIMEFRAMES timeframe)
     {
      for(int index=0;index<ArraySize(m_confidence_records);index++)
        {
         if(m_confidence_records[index].symbol==symbol &&
            m_confidence_records[index].timeframe==timeframe)
            return(index);
        }
      return(-1);
     }

   int               FindVolatilityIndex(const string symbol,
                                         const ENUM_TIMEFRAMES timeframe)
     {
      for(int index=0;index<ArraySize(m_volatility_records);index++)
        {
         if(m_volatility_records[index].symbol==symbol &&
            m_volatility_records[index].timeframe==timeframe)
            return(index);
        }
      return(-1);
     }

   int               FindDecisionScoreIndex(const string symbol,
                                            const ENUM_TIMEFRAMES timeframe)
     {
      for(int index=0;index<ArraySize(m_decision_score_records);index++)
        {
         if(m_decision_score_records[index].symbol==symbol &&
            m_decision_score_records[index].timeframe==timeframe)
            return(index);
        }
      return(-1);
     }

   int               FindRangeIndex(const string symbol,
                                    const ENUM_TIMEFRAMES timeframe)
     {
      for(int index=0;index<ArraySize(m_range_records);index++)
        {
         if(m_range_records[index].symbol==symbol &&
            m_range_records[index].timeframe==timeframe)
            return(index);
        }
      return(-1);
     }

   int               FindTrendIndex(const string symbol,
                                    const ENUM_TIMEFRAMES timeframe)
     {
      for(int index=0;index<ArraySize(m_trend_records);index++)
        {
         if(m_trend_records[index].symbol==symbol &&
            m_trend_records[index].timeframe==timeframe)
            return(index);
        }
      return(-1);
     }

public:
   //--- Adds or replaces one typed snapshot for a Symbol+Timeframe identity.
   bool              SetEnvironmentSnapshot(const string symbol,
                                            const ENUM_TIMEFRAMES timeframe,
                                            const SEnvironmentSnapshot &snapshot)
     {
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0 ||
         snapshot.symbol!=symbol ||
         snapshot.timeframe!=EnumToString(timeframe) ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0)
         return(false);

      int index=FindEnvironmentIndex(symbol,timeframe);
      if(index<0)
        {
         const int count=ArraySize(m_environment_records);
         if(ArrayResize(m_environment_records,count+1)!=(count+1))
            return(false);
         index=count;
        }

      m_environment_records[index].symbol=symbol;
      m_environment_records[index].timeframe=timeframe;
      m_environment_records[index].snapshot_type="Environment";
      m_environment_records[index].snapshot_version=snapshot.snapshot_version;
      m_environment_records[index].updated_at=snapshot.updated_at;
      m_environment_records[index].is_valid=snapshot.is_valid;
      m_environment_records[index].environment=snapshot;
      return(true);
     }

   bool              GetEnvironmentSnapshot(const string symbol,
                                            const ENUM_TIMEFRAMES timeframe,
                                            SEnvironmentSnapshot &snapshot)
     {
      const int index=FindEnvironmentIndex(symbol,timeframe);
      if(index<0)
         return(false);
      snapshot=m_environment_records[index].environment;
      return(true);
     }

   bool              HasEnvironmentSnapshot(const string symbol,
                                            const ENUM_TIMEFRAMES timeframe)
     {
      return(FindEnvironmentIndex(symbol,timeframe)>=0);
     }

   int               Count(void)
     {
      return(ArraySize(m_environment_records));
     }

   //--- Adds or replaces one typed Common Volatility snapshot. The payload is
   //--- already calculated by VolatilityAnalyzer; this store never derives or
   //--- recalculates ATR, score, or level.
   bool              SetVolatilitySnapshot(const string symbol,
                                           const ENUM_TIMEFRAMES timeframe,
                                           const SVolatilitySnapshot &snapshot)
     {
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0 ||
         snapshot.symbol!=symbol ||
         snapshot.timeframe!=EnumToString(timeframe) ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0)
         return(false);

      int index=FindVolatilityIndex(symbol,timeframe);
      if(index<0)
        {
         const int count=ArraySize(m_volatility_records);
         if(ArrayResize(m_volatility_records,count+1)!=(count+1))
            return(false);
         index=count;
        }

      m_volatility_records[index].symbol=symbol;
      m_volatility_records[index].timeframe=timeframe;
      m_volatility_records[index].snapshot_type="Volatility";
      m_volatility_records[index].snapshot_version=snapshot.snapshot_version;
      m_volatility_records[index].updated_at=snapshot.updated_at;
      m_volatility_records[index].is_valid=snapshot.is_valid;
      m_volatility_records[index].volatility=snapshot;
      return(true);
     }

   bool              GetVolatilitySnapshot(const string symbol,
                                           const ENUM_TIMEFRAMES timeframe,
                                           SVolatilitySnapshot &snapshot)
     {
      const int index=FindVolatilityIndex(symbol,timeframe);
      if(index<0)
         return(false);
      snapshot=m_volatility_records[index].volatility;
      return(true);
     }

   bool              HasVolatilitySnapshot(const string symbol,
                                           const ENUM_TIMEFRAMES timeframe)
     {
      return(FindVolatilityIndex(symbol,timeframe)>=0);
     }

   int               VolatilitySnapshotCount(void)
     {
      return(ArraySize(m_volatility_records));
     }

   //--- Adds or replaces one typed Common Range snapshot without calculating
   //--- or modifying any of the source detector values.
   bool              SetRangeSnapshot(const string symbol,
                                      const ENUM_TIMEFRAMES timeframe,
                                      const SRangeSnapshot &snapshot)
     {
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0 ||
         snapshot.symbol!=symbol ||
         snapshot.timeframe!=EnumToString(timeframe) ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0)
         return(false);

      int index=FindRangeIndex(symbol,timeframe);
      if(index<0)
        {
         const int count=ArraySize(m_range_records);
         if(ArrayResize(m_range_records,count+1)!=(count+1))
            return(false);
         index=count;
        }

      m_range_records[index].symbol=symbol;
      m_range_records[index].timeframe=timeframe;
      m_range_records[index].snapshot_type="Range";
      m_range_records[index].snapshot_version=snapshot.snapshot_version;
      m_range_records[index].updated_at=snapshot.updated_at;
      m_range_records[index].is_valid=snapshot.is_valid;
      m_range_records[index].range=snapshot;
      return(true);
     }

   bool              GetRangeSnapshot(const string symbol,
                                      const ENUM_TIMEFRAMES timeframe,
                                      SRangeSnapshot &snapshot)
     {
      const int index=FindRangeIndex(symbol,timeframe);
      if(index<0)
         return(false);
      snapshot=m_range_records[index].range;
      return(true);
     }

   bool              HasRangeSnapshot(const string symbol,
                                      const ENUM_TIMEFRAMES timeframe)
     {
      return(FindRangeIndex(symbol,timeframe)>=0);
     }

   int               RangeSnapshotCount(void)
     {
      return(ArraySize(m_range_records));
     }

   //--- Adds or replaces one typed Common Trend snapshot without calculating
   //--- or modifying any of the source detector values.
   bool              SetTrendSnapshot(const string symbol,
                                      const ENUM_TIMEFRAMES timeframe,
                                      const STrendSnapshot &snapshot)
     {
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0 ||
         snapshot.symbol!=symbol ||
         snapshot.timeframe!=EnumToString(timeframe) ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0)
         return(false);

      int index=FindTrendIndex(symbol,timeframe);
      if(index<0)
        {
         const int count=ArraySize(m_trend_records);
         if(ArrayResize(m_trend_records,count+1)!=(count+1))
            return(false);
         index=count;
        }

      m_trend_records[index].symbol=symbol;
      m_trend_records[index].timeframe=timeframe;
      m_trend_records[index].snapshot_type="Trend";
      m_trend_records[index].snapshot_version=snapshot.snapshot_version;
      m_trend_records[index].updated_at=snapshot.updated_at;
      m_trend_records[index].is_valid=snapshot.is_valid;
      m_trend_records[index].trend=snapshot;
      return(true);
     }

   bool              GetTrendSnapshot(const string symbol,
                                      const ENUM_TIMEFRAMES timeframe,
                                      STrendSnapshot &snapshot)
     {
      const int index=FindTrendIndex(symbol,timeframe);
      if(index<0)
         return(false);
      snapshot=m_trend_records[index].trend;
      return(true);
     }

   bool              HasTrendSnapshot(const string symbol,
                                      const ENUM_TIMEFRAMES timeframe)
     {
      return(FindTrendIndex(symbol,timeframe)>=0);
     }

   int               TrendSnapshotCount(void)
     {
      return(ArraySize(m_trend_records));
     }

   //--- Adds or replaces one typed Common Confidence snapshot for a stable
   //--- Symbol+Timeframe identity without altering Environment records.
   bool              SetConfidenceSnapshot(const string symbol,
                                           const ENUM_TIMEFRAMES timeframe,
                                           const SConfidenceSnapshot &snapshot)
     {
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0 ||
         snapshot.symbol!=symbol ||
         snapshot.timeframe!=EnumToString(timeframe) ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0)
         return(false);

      int index=FindConfidenceIndex(symbol,timeframe);
      if(index<0)
        {
         const int count=ArraySize(m_confidence_records);
         if(ArrayResize(m_confidence_records,count+1)!=(count+1))
            return(false);
         index=count;
        }

      m_confidence_records[index].symbol=symbol;
      m_confidence_records[index].timeframe=timeframe;
      m_confidence_records[index].snapshot_type="Confidence";
      m_confidence_records[index].snapshot_version=snapshot.snapshot_version;
      m_confidence_records[index].updated_at=snapshot.updated_at;
      m_confidence_records[index].is_valid=snapshot.is_valid;
      m_confidence_records[index].confidence=snapshot;
      return(true);
     }

   bool              GetConfidenceSnapshot(const string symbol,
                                           const ENUM_TIMEFRAMES timeframe,
                                           SConfidenceSnapshot &snapshot)
     {
      const int index=FindConfidenceIndex(symbol,timeframe);
      if(index<0)
         return(false);
      snapshot=m_confidence_records[index].confidence;
      return(true);
     }

   bool              HasConfidenceSnapshot(const string symbol,
                                           const ENUM_TIMEFRAMES timeframe)
     {
      return(FindConfidenceIndex(symbol,timeframe)>=0);
     }

   int               ConfidenceSnapshotCount(void)
     {
      return(ArraySize(m_confidence_records));
     }

   //--- Adds or replaces one typed Common Decision Score snapshot. The
   //--- Symbol+Timeframe identity is validated before any record is mutated.
   bool              SetDecisionScoreSnapshot(const string symbol,
                                              const ENUM_TIMEFRAMES timeframe,
                                              const SDecisionScoreSnapshot &snapshot)
     {
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0 ||
         snapshot.symbol!=symbol ||
         snapshot.timeframe!=EnumToString(timeframe) ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0)
         return(false);

      int index=FindDecisionScoreIndex(symbol,timeframe);
      if(index<0)
        {
         const int count=ArraySize(m_decision_score_records);
         if(ArrayResize(m_decision_score_records,count+1)!=(count+1))
            return(false);
         index=count;
        }

      m_decision_score_records[index].symbol=symbol;
      m_decision_score_records[index].timeframe=timeframe;
      m_decision_score_records[index].snapshot_type="DecisionScore";
      m_decision_score_records[index].snapshot_version=snapshot.snapshot_version;
      m_decision_score_records[index].updated_at=snapshot.updated_at;
      m_decision_score_records[index].is_valid=snapshot.is_valid;
      m_decision_score_records[index].decision_score=snapshot;
      return(true);
     }

   bool              GetDecisionScoreSnapshot(const string symbol,
                                              const ENUM_TIMEFRAMES timeframe,
                                              SDecisionScoreSnapshot &snapshot)
     {
      const int index=FindDecisionScoreIndex(symbol,timeframe);
      if(index<0)
         return(false);
      snapshot=m_decision_score_records[index].decision_score;
      return(true);
     }

   bool              HasDecisionScoreSnapshot(const string symbol,
                                              const ENUM_TIMEFRAMES timeframe)
     {
      return(FindDecisionScoreIndex(symbol,timeframe)>=0);
     }

   int               DecisionScoreSnapshotCount(void)
     {
      return(ArraySize(m_decision_score_records));
     }

   void              Clear(void)
     {
      ArrayFree(m_environment_records);
      ArrayFree(m_volatility_records);
      ArrayFree(m_range_records);
      ArrayFree(m_trend_records);
      ArrayFree(m_confidence_records);
      ArrayFree(m_decision_score_records);
     }
  };

#endif // FENX_COMMON_SNAPSHOT_STORE_MQH
