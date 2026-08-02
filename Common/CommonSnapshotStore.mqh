//+------------------------------------------------------------------+
//|                                Common/CommonSnapshotStore.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_SNAPSHOT_STORE_MQH
#define FENX_COMMON_SNAPSHOT_STORE_MQH

#include "../Environment/EnvironmentSnapshot.mqh"
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

//--- Shadow-only typed storage shared by future Original/Personal engines.
//--- Task004 stores Environment snapshots without changing trading consumers.
class CCommonSnapshotStore
  {
private:
   SCommonEnvironmentSnapshotRecord m_environment_records[];
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
      ArrayFree(m_confidence_records);
      ArrayFree(m_decision_score_records);
     }
  };

#endif // FENX_COMMON_SNAPSHOT_STORE_MQH
