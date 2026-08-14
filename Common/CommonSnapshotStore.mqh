//+------------------------------------------------------------------+
//|                                Common/CommonSnapshotStore.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_SNAPSHOT_STORE_MQH
#define FENX_COMMON_SNAPSHOT_STORE_MQH

#include "../Environment/EnvironmentSnapshot.mqh"
#include "../Environment/VolatilitySnapshot.mqh"
#include "../Environment/RangeSnapshot.mqh"
#include "../Environment/TrendSnapshot.mqh"
#include "../Environment/MarketStateSnapshot.mqh"
#include "../Standby/StandbySnapshot.mqh"
#include "../Risk/RiskSnapshot.mqh"
#include "../Entry/EntrySnapshot.mqh"
#include "../Exit/ExitSnapshot.mqh"
#include "../Execution/ExecutionSnapshot.mqh"
#include "../Recovery/RecoverySnapshot.mqh"
#include "../Confidence/ConfidenceSnapshot.mqh"
#include "../Decision/DecisionScoreSnapshot.mqh"
#include "../Health/HealthSnapshot.mqh"

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

//--- Metadata and typed payload for one Common Market State identity.
struct SCommonMarketStateSnapshotRecord
  {
   string               symbol;
   ENUM_TIMEFRAMES      timeframe;
   string               snapshot_type;
   string               snapshot_version;
   datetime             updated_at;
   bool                 is_valid;
   SMarketStateSnapshot market_state;
  };

//--- Metadata and typed payload for one Common Standby identity.
struct SCommonStandbySnapshotRecord
  {
   string           symbol;
   ENUM_TIMEFRAMES  timeframe;
   string           snapshot_type;
   string           snapshot_version;
   datetime         updated_at;
   bool             is_valid;
   SStandbySnapshot standby;
  };

//--- Metadata and typed payload for one Common Risk identity.
struct SCommonRiskSnapshotRecord
  {
   string          symbol;
   ENUM_TIMEFRAMES timeframe;
   string          snapshot_type;
   string          snapshot_version;
   datetime        updated_at;
   bool            is_valid;
   SRiskSnapshot   risk;
  };

//--- Current typed Common Entry result for one Symbol+Timeframe identity.
struct SCommonEntrySnapshotRecord
  {
   string          symbol;
   ENUM_TIMEFRAMES timeframe;
   string          snapshot_type;
   string          snapshot_version;
   datetime        updated_at;
   bool            is_valid;
   SEntrySnapshot  entry;
  };

//--- Current typed Common Exit result for one Symbol+Timeframe identity.
struct SCommonExitSnapshotRecord
  {
   string          symbol;
   ENUM_TIMEFRAMES timeframe;
   string          snapshot_type;
   string          snapshot_version;
   datetime        updated_at;
   bool            is_valid;
   SExitSnapshot   exit_snapshot;
  };

//--- Current typed Common Execution result for one Symbol+Timeframe identity.
struct SCommonExecutionSnapshotRecord
  {
   string                   symbol;
   ENUM_TIMEFRAMES          timeframe;
   string                   snapshot_type;
   string                   snapshot_version;
   datetime                 updated_at;
   bool                     is_valid;
   SCommonExecutionSnapshot execution;
  };

//--- Current typed Common Recovery observation for one Symbol+Timeframe.
struct SCommonRecoverySnapshotRecord
  {
   string                   symbol;
   ENUM_TIMEFRAMES          timeframe;
   string                   snapshot_type;
   string                   snapshot_version;
   datetime                 updated_at;
   bool                     is_valid;
   SCommonRecoverySnapshot  recovery;
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

//--- Current typed Common Health observation for one Symbol+Timeframe.
struct SCommonHealthSnapshotRecord
  {
   string                symbol;
   ENUM_TIMEFRAMES       timeframe;
   string                snapshot_type;
   string                snapshot_version;
   datetime              updated_at;
   bool                  is_valid;
   SCommonHealthSnapshot health;
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
   SCommonMarketStateSnapshotRecord m_market_state_records[];
   SCommonStandbySnapshotRecord     m_standby_records[];
   SCommonRiskSnapshotRecord        m_risk_records[];
   SCommonEntrySnapshotRecord       m_entry_records[];
   SEntrySnapshot                   m_entry_history[];
   SCommonExitSnapshotRecord        m_exit_records[];
   SExitSnapshot                    m_exit_history[];
   SCommonExecutionSnapshotRecord   m_execution_records[];
   SCommonExecutionSnapshot         m_execution_history[];
   SCommonRecoverySnapshotRecord    m_recovery_records[];
   SCommonRecoverySnapshot          m_recovery_history[];
   SCommonConfidenceSnapshotRecord  m_confidence_records[];
   SCommonDecisionScoreSnapshotRecord m_decision_score_records[];
   SCommonHealthSnapshotRecord      m_health_records[];
   SCommonHealthSnapshot            m_health_history[];

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

   int               FindMarketStateIndex(const string symbol,
                                          const ENUM_TIMEFRAMES timeframe)
     {
      for(int index=0;index<ArraySize(m_market_state_records);index++)
        {
         if(m_market_state_records[index].symbol==symbol &&
            m_market_state_records[index].timeframe==timeframe)
            return(index);
        }
      return(-1);
     }

   int               FindStandbyIndex(const string symbol,
                                      const ENUM_TIMEFRAMES timeframe)
     {
      for(int index=0;index<ArraySize(m_standby_records);index++)
        {
         if(m_standby_records[index].symbol==symbol &&
            m_standby_records[index].timeframe==timeframe)
            return(index);
        }
      return(-1);
     }

   int               FindRiskIndex(const string symbol,
                                   const ENUM_TIMEFRAMES timeframe)
     {
      for(int index=0;index<ArraySize(m_risk_records);index++)
        {
         if(m_risk_records[index].symbol==symbol &&
            m_risk_records[index].timeframe==timeframe)
            return(index);
        }
      return(-1);
     }

   int               FindEntryIndex(const string symbol,
                                    const ENUM_TIMEFRAMES timeframe)
     {
      for(int index=0;index<ArraySize(m_entry_records);index++)
        {
         if(m_entry_records[index].symbol==symbol &&
            m_entry_records[index].timeframe==timeframe)
            return(index);
        }
      return(-1);
     }

   int               FindExitIndex(const string symbol,
                                    const ENUM_TIMEFRAMES timeframe)
     {
      for(int index=0;index<ArraySize(m_exit_records);index++)
        {
         if(m_exit_records[index].symbol==symbol &&
            m_exit_records[index].timeframe==timeframe)
            return(index);
        }
      return(-1);
     }

   int               FindExecutionIndex(const string symbol,
                                         const ENUM_TIMEFRAMES timeframe)
     {
      for(int index=0;index<ArraySize(m_execution_records);index++)
        {
         if(m_execution_records[index].symbol==symbol &&
            m_execution_records[index].timeframe==timeframe)
            return(index);
        }
      return(-1);
     }

   int               FindRecoveryIndex(const string symbol,
                                        const ENUM_TIMEFRAMES timeframe)
     {
      for(int index=0;index<ArraySize(m_recovery_records);index++)
        {
         if(m_recovery_records[index].symbol==symbol &&
            m_recovery_records[index].timeframe==timeframe)
            return(index);
        }
      return(-1);
     }

   int               FindHealthIndex(const string symbol,
                                     const ENUM_TIMEFRAMES timeframe)
     {
      for(int index=0;index<ArraySize(m_health_records);index++)
        {
         if(m_health_records[index].symbol==symbol &&
            m_health_records[index].timeframe==timeframe)
            return(index);
        }
      return(-1);
     }

   void              FillHealthStatus(SCommonEngineHealthStatus &status,
                                      const string engine_name,
                                      const bool available,
                                      const bool valid,
                                      const bool fresh,
                                      const datetime updated_at,
                                      const string snapshot_version,
                                      const string invalid_reason)
     {
      FenxResetCommonEngineHealthStatus(status,engine_name);
      status.available=available;
      if(!available)
         return;
      status.valid=valid;
      status.fresh=fresh;
      status.updated_at=updated_at;
      status.snapshot_version=snapshot_version;
      status.invalid_reason=invalid_reason;
     }

   //--- Keeps a bounded chronological audit. Re-publishing the same evaluation
   //--- sequence updates its existing record rather than duplicating it.
   bool              StoreEntryHistory(const SEntrySnapshot &snapshot)
     {
      const int count=ArraySize(m_entry_history);
      for(int index=count-1;index>=0;index--)
        {
         if(m_entry_history[index].symbol==snapshot.symbol &&
            m_entry_history[index].timeframe==snapshot.timeframe &&
            m_entry_history[index].entry_evaluation_sequence==
               snapshot.entry_evaluation_sequence)
           {
            m_entry_history[index]=snapshot;
            return(true);
           }
        }

      if(count<FENX_COMMON_ENTRY_HISTORY_LIMIT)
        {
         if(ArrayResize(m_entry_history,count+1)!=(count+1))
            return(false);
         m_entry_history[count]=snapshot;
         return(true);
        }

      for(int index=1;index<count;index++)
         m_entry_history[index-1]=m_entry_history[index];
      m_entry_history[count-1]=snapshot;
      return(true);
     }

   //--- Retains only the latest bounded Exit evaluations. A close request,
   //--- result, or final deal updates the matching Sequence in place.
   bool              StoreExitHistory(const SExitSnapshot &snapshot)
     {
      const int count=ArraySize(m_exit_history);
      for(int index=count-1;index>=0;index--)
        {
         if(m_exit_history[index].symbol==snapshot.symbol &&
            m_exit_history[index].timeframe==snapshot.timeframe &&
            m_exit_history[index].exit_evaluation_sequence==
               snapshot.exit_evaluation_sequence)
           {
            m_exit_history[index]=snapshot;
            return(true);
           }
        }

      if(count<FENX_COMMON_EXIT_HISTORY_LIMIT)
        {
         if(ArrayResize(m_exit_history,count+1)!=(count+1))
            return(false);
         m_exit_history[count]=snapshot;
         return(true);
        }

      for(int index=1;index<count;index++)
         m_exit_history[index-1]=m_exit_history[index];
      m_exit_history[count-1]=snapshot;
      return(true);
     }

   //--- Retains the latest bounded request/result records. The Sequence is
   //--- unique per authorized Entry or Close request.
   bool              StoreExecutionHistory(const SCommonExecutionSnapshot &snapshot)
     {
      const int count=ArraySize(m_execution_history);
      for(int index=count-1;index>=0;index--)
        {
         if(m_execution_history[index].symbol==snapshot.symbol &&
            m_execution_history[index].timeframe==snapshot.timeframe &&
            m_execution_history[index].execution_sequence==
               snapshot.execution_sequence)
           {
            m_execution_history[index]=snapshot;
            return(true);
           }
        }

      if(count<FENX_COMMON_EXECUTION_HISTORY_LIMIT)
        {
         if(ArrayResize(m_execution_history,count+1)!=(count+1))
            return(false);
         m_execution_history[count]=snapshot;
         return(true);
        }

      for(int index=1;index<count;index++)
         m_execution_history[index-1]=m_execution_history[index];
      m_execution_history[count-1]=snapshot;
      return(true);
     }

   //--- Retains only state/condition-change Recovery audits. Each audit has a
   //--- unique sequence while RecoverySequence links one lifecycle end-to-end.
   bool              StoreRecoveryHistory(const SCommonRecoverySnapshot &snapshot)
     {
      const int count=ArraySize(m_recovery_history);
      for(int index=count-1;index>=0;index--)
        {
         if(m_recovery_history[index].symbol==snapshot.symbol &&
            m_recovery_history[index].timeframe==snapshot.timeframe &&
            m_recovery_history[index].recovery_audit_sequence==
               snapshot.recovery_audit_sequence)
           {
            m_recovery_history[index]=snapshot;
            return(true);
           }
        }

      if(count<FENX_COMMON_RECOVERY_HISTORY_LIMIT)
        {
         if(ArrayResize(m_recovery_history,count+1)!=(count+1))
            return(false);
         m_recovery_history[count]=snapshot;
         return(true);
        }

      for(int index=1;index<count;index++)
         m_recovery_history[index-1]=m_recovery_history[index];
      m_recovery_history[count-1]=snapshot;
      return(true);
     }

   //--- Retains a bounded, gap-free sequence of emitted Health evaluations.
   //--- Re-publishing one sequence updates it instead of creating a duplicate.
   bool              StoreHealthHistory(const SCommonHealthSnapshot &snapshot)
     {
      const int count=ArraySize(m_health_history);
      for(int index=count-1;index>=0;index--)
        {
         if(m_health_history[index].symbol==snapshot.symbol &&
            m_health_history[index].timeframe==snapshot.timeframe &&
            m_health_history[index].health_evaluation_sequence==
               snapshot.health_evaluation_sequence)
           {
            m_health_history[index]=snapshot;
            return(true);
           }
        }

      if(count<FENX_COMMON_HEALTH_HISTORY_LIMIT)
        {
         if(ArrayResize(m_health_history,count+1)!=(count+1))
            return(false);
         m_health_history[count]=snapshot;
         return(true);
        }

      for(int index=1;index<count;index++)
         m_health_history[index-1]=m_health_history[index];
      m_health_history[count-1]=snapshot;
      return(true);
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

   //--- Adds or replaces one typed Common Market State snapshot. The payload
   //--- is the already-classified legacy result; this store never classifies.
   bool              SetMarketStateSnapshot(const string symbol,
                                            const ENUM_TIMEFRAMES timeframe,
                                            const SMarketStateSnapshot &snapshot)
     {
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0 ||
         snapshot.symbol!=symbol ||
         snapshot.timeframe!=EnumToString(timeframe) ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0)
         return(false);

      int index=FindMarketStateIndex(symbol,timeframe);
      if(index<0)
        {
         const int count=ArraySize(m_market_state_records);
         if(ArrayResize(m_market_state_records,count+1)!=(count+1))
            return(false);
         index=count;
        }

      m_market_state_records[index].symbol=symbol;
      m_market_state_records[index].timeframe=timeframe;
      m_market_state_records[index].snapshot_type="MarketState";
      m_market_state_records[index].snapshot_version=snapshot.snapshot_version;
      m_market_state_records[index].updated_at=snapshot.updated_at;
      m_market_state_records[index].is_valid=snapshot.is_valid;
      m_market_state_records[index].market_state=snapshot;
      return(true);
     }

   bool              GetMarketStateSnapshot(const string symbol,
                                            const ENUM_TIMEFRAMES timeframe,
                                            SMarketStateSnapshot &snapshot)
     {
      const int index=FindMarketStateIndex(symbol,timeframe);
      if(index<0)
         return(false);
      snapshot=m_market_state_records[index].market_state;
      return(true);
     }

   bool              HasMarketStateSnapshot(const string symbol,
                                            const ENUM_TIMEFRAMES timeframe)
     {
      return(FindMarketStateIndex(symbol,timeframe)>=0);
     }

   int               MarketStateSnapshotCount(void)
     {
      return(ArraySize(m_market_state_records));
     }

   //--- Adds or replaces one already-decided Common Standby snapshot. The
   //--- store never executes or duplicates Standby state-machine transitions.
   bool              SetStandbySnapshot(const string symbol,
                                        const ENUM_TIMEFRAMES timeframe,
                                        const SStandbySnapshot &snapshot)
     {
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0 ||
         snapshot.symbol!=symbol ||
         snapshot.timeframe!=EnumToString(timeframe) ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0)
         return(false);

      int index=FindStandbyIndex(symbol,timeframe);
      if(index<0)
        {
         const int count=ArraySize(m_standby_records);
         if(ArrayResize(m_standby_records,count+1)!=(count+1))
            return(false);
         index=count;
        }

      m_standby_records[index].symbol=symbol;
      m_standby_records[index].timeframe=timeframe;
      m_standby_records[index].snapshot_type="Standby";
      m_standby_records[index].snapshot_version=snapshot.snapshot_version;
      m_standby_records[index].updated_at=snapshot.updated_at;
      m_standby_records[index].is_valid=snapshot.is_valid;
      m_standby_records[index].standby=snapshot;
      return(true);
     }

   bool              GetStandbySnapshot(const string symbol,
                                        const ENUM_TIMEFRAMES timeframe,
                                        SStandbySnapshot &snapshot)
     {
      const int index=FindStandbyIndex(symbol,timeframe);
      if(index<0)
         return(false);
      snapshot=m_standby_records[index].standby;
      return(true);
     }

   bool              HasStandbySnapshot(const string symbol,
                                        const ENUM_TIMEFRAMES timeframe)
     {
      return(FindStandbyIndex(symbol,timeframe)>=0);
     }

   int               StandbySnapshotCount(void)
     {
      return(ArraySize(m_standby_records));
     }

   //--- Adds or replaces one already-decided Common Risk snapshot. The store
   //--- never recalculates Risk score, permission, multiplier, or hysteresis.
   bool              SetRiskSnapshot(const string symbol,
                                     const ENUM_TIMEFRAMES timeframe,
                                     const SRiskSnapshot &snapshot)
     {
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0 ||
         snapshot.symbol!=symbol ||
         snapshot.timeframe!=EnumToString(timeframe) ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0)
         return(false);

      int index=FindRiskIndex(symbol,timeframe);
      if(index<0)
        {
         const int count=ArraySize(m_risk_records);
         if(ArrayResize(m_risk_records,count+1)!=(count+1))
            return(false);
         index=count;
        }

      m_risk_records[index].symbol=symbol;
      m_risk_records[index].timeframe=timeframe;
      m_risk_records[index].snapshot_type="Risk";
      m_risk_records[index].snapshot_version=snapshot.snapshot_version;
      m_risk_records[index].updated_at=snapshot.updated_at;
      m_risk_records[index].is_valid=snapshot.is_valid;
      m_risk_records[index].risk=snapshot;
      return(true);
     }

   bool              GetRiskSnapshot(const string symbol,
                                     const ENUM_TIMEFRAMES timeframe,
                                     SRiskSnapshot &snapshot)
     {
      const int index=FindRiskIndex(symbol,timeframe);
      if(index<0)
         return(false);
      snapshot=m_risk_records[index].risk;
      return(true);
     }

   bool              HasRiskSnapshot(const string symbol,
                                     const ENUM_TIMEFRAMES timeframe)
     {
      return(FindRiskIndex(symbol,timeframe)>=0);
     }

   int               RiskSnapshotCount(void)
     {
      return(ArraySize(m_risk_records));
     }

   //--- Stores the final result of an existing Entry evaluation. The current
   //--- identity is updated in place and a separate bounded history retains the
   //--- latest evaluation records without creating unbounded tester memory.
   bool              SetEntrySnapshot(const string symbol,
                                      const ENUM_TIMEFRAMES timeframe,
                                      const SEntrySnapshot &snapshot)
     {
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0 ||
         snapshot.symbol!=symbol ||
         snapshot.timeframe!=EnumToString(timeframe) ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0 ||
         snapshot.entry_evaluation_sequence<=0)
         return(false);

      int index=FindEntryIndex(symbol,timeframe);
      if(index<0)
        {
         const int count=ArraySize(m_entry_records);
         if(ArrayResize(m_entry_records,count+1)!=(count+1))
            return(false);
         index=count;
        }

      m_entry_records[index].symbol=symbol;
      m_entry_records[index].timeframe=timeframe;
      m_entry_records[index].snapshot_type="Entry";
      m_entry_records[index].snapshot_version=snapshot.snapshot_version;
      m_entry_records[index].updated_at=snapshot.updated_at;
      m_entry_records[index].is_valid=snapshot.is_valid;
      m_entry_records[index].entry=snapshot;
      return(StoreEntryHistory(snapshot));
     }

   bool              GetEntrySnapshot(const string symbol,
                                      const ENUM_TIMEFRAMES timeframe,
                                      SEntrySnapshot &snapshot)
     {
      const int index=FindEntryIndex(symbol,timeframe);
      if(index<0)
         return(false);
      snapshot=m_entry_records[index].entry;
      return(true);
     }

   bool              HasEntrySnapshot(const string symbol,
                                      const ENUM_TIMEFRAMES timeframe)
     {
      return(FindEntryIndex(symbol,timeframe)>=0);
     }

   int               EntrySnapshotCount(void)
     {
      return(ArraySize(m_entry_records));
     }

   int               EntryHistoryCount(void)
     {
      return(ArraySize(m_entry_history));
     }

   bool              GetEntryHistorySnapshot(const int index,
                                             SEntrySnapshot &snapshot)
     {
      if(index<0 || index>=ArraySize(m_entry_history))
         return(false);
      snapshot=m_entry_history[index];
      return(true);
     }

   //--- Stores an observed Exit evaluation or close lifecycle update. The
   //--- current identity is Symbol+Timeframe and the chronological audit is
   //--- bounded so long Strategy Tester runs cannot grow memory without limit.
   bool              SetExitSnapshot(const string symbol,
                                      const ENUM_TIMEFRAMES timeframe,
                                      const SExitSnapshot &snapshot)
     {
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0 ||
         snapshot.symbol!=symbol ||
         snapshot.timeframe!=EnumToString(timeframe) ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0 ||
         snapshot.exit_evaluation_sequence<=0)
         return(false);

      int index=FindExitIndex(symbol,timeframe);
      if(index<0)
        {
         const int count=ArraySize(m_exit_records);
         if(ArrayResize(m_exit_records,count+1)!=(count+1))
            return(false);
         index=count;
        }

      m_exit_records[index].symbol=symbol;
      m_exit_records[index].timeframe=timeframe;
      m_exit_records[index].snapshot_type="Exit";
      m_exit_records[index].snapshot_version=snapshot.snapshot_version;
      m_exit_records[index].updated_at=snapshot.updated_at;
      m_exit_records[index].is_valid=snapshot.is_valid;
      m_exit_records[index].exit_snapshot=snapshot;
      return(StoreExitHistory(snapshot));
     }

   bool              GetExitSnapshot(const string symbol,
                                      const ENUM_TIMEFRAMES timeframe,
                                      SExitSnapshot &snapshot)
     {
      const int index=FindExitIndex(symbol,timeframe);
      if(index<0)
         return(false);
      snapshot=m_exit_records[index].exit_snapshot;
      return(true);
     }

   bool              HasExitSnapshot(const string symbol,
                                      const ENUM_TIMEFRAMES timeframe)
     {
      return(FindExitIndex(symbol,timeframe)>=0);
     }

   int               ExitSnapshotCount(void)
     {
      return(ArraySize(m_exit_records));
     }

   int               ExitHistoryCount(void)
     {
      return(ArraySize(m_exit_history));
     }

   bool              GetExitHistorySnapshot(const int index,
                                             SExitSnapshot &snapshot)
     {
      if(index<0 || index>=ArraySize(m_exit_history))
         return(false);
      snapshot=m_exit_history[index];
      return(true);
     }

   //--- Confirms a terminal Exit observation from the bounded typed history.
   //--- OnTradeTransaction can finalize an SL/TP lifecycle after Health has
   //--- already observed that tick; consulting history prevents the next
   //--- position from being misclassified as an abandoned lifecycle.
   bool              HasFinalizedExitLifecycle(const string symbol,
                                               const ENUM_TIMEFRAMES timeframe,
                                               const ulong lifecycle_id)
     {
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0 ||
         lifecycle_id==0)
         return(false);
      const string timeframe_name=EnumToString(timeframe);
      for(int index=ArraySize(m_exit_history)-1;index>=0;index--)
        {
         const SExitSnapshot snapshot=m_exit_history[index];
         if(snapshot.symbol==symbol && snapshot.timeframe==timeframe_name &&
            snapshot.position_lifecycle_id==lifecycle_id &&
            snapshot.position_closed)
            return(true);
        }
      return(false);
     }

   //--- Stores one finalized request/result from the existing ExecutionEngine
   //--- without publishing new DataBus keys or changing legacy consumers.
   bool              SetExecutionSnapshot(const string symbol,
                                           const ENUM_TIMEFRAMES timeframe,
                                           const SCommonExecutionSnapshot &snapshot)
     {
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0 ||
         snapshot.symbol!=symbol ||
         snapshot.timeframe!=EnumToString(timeframe) ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0 ||
         snapshot.execution_sequence<=0)
         return(false);

      int index=FindExecutionIndex(symbol,timeframe);
      if(index<0)
        {
         const int count=ArraySize(m_execution_records);
         if(ArrayResize(m_execution_records,count+1)!=(count+1))
            return(false);
         index=count;
        }

      m_execution_records[index].symbol=symbol;
      m_execution_records[index].timeframe=timeframe;
      m_execution_records[index].snapshot_type="Execution";
      m_execution_records[index].snapshot_version=snapshot.snapshot_version;
      m_execution_records[index].updated_at=snapshot.updated_at;
      m_execution_records[index].is_valid=snapshot.is_valid;
      m_execution_records[index].execution=snapshot;
      return(StoreExecutionHistory(snapshot));
     }

   bool              GetExecutionSnapshot(const string symbol,
                                           const ENUM_TIMEFRAMES timeframe,
                                           SCommonExecutionSnapshot &snapshot)
     {
      const int index=FindExecutionIndex(symbol,timeframe);
      if(index<0)
         return(false);
      snapshot=m_execution_records[index].execution;
      return(true);
     }

   bool              HasExecutionSnapshot(const string symbol,
                                           const ENUM_TIMEFRAMES timeframe)
     {
      return(FindExecutionIndex(symbol,timeframe)>=0);
     }

   int               ExecutionSnapshotCount(void)
     {
      return(ArraySize(m_execution_records));
     }

   int               ExecutionHistoryCount(void)
     {
      return(ArraySize(m_execution_history));
     }

   bool              GetExecutionHistorySnapshot(const int index,
                                                  SCommonExecutionSnapshot &snapshot)
     {
      if(index<0 || index>=ArraySize(m_execution_history))
         return(false);
      snapshot=m_execution_history[index];
      return(true);
     }

   //--- Stores one passive, already-observed Common Recovery audit. The store
   //--- does not request recovery, grant Entry permission, or write StateManager.
   bool              SetRecoverySnapshot(const string symbol,
                                          const ENUM_TIMEFRAMES timeframe,
                                          const SCommonRecoverySnapshot &snapshot)
     {
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0 ||
         snapshot.symbol!=symbol ||
         snapshot.timeframe!=EnumToString(timeframe) ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0 ||
         snapshot.recovery_audit_sequence<=0)
         return(false);

      int index=FindRecoveryIndex(symbol,timeframe);
      if(index<0)
        {
         const int count=ArraySize(m_recovery_records);
         if(ArrayResize(m_recovery_records,count+1)!=(count+1))
            return(false);
         index=count;
        }

      m_recovery_records[index].symbol=symbol;
      m_recovery_records[index].timeframe=timeframe;
      m_recovery_records[index].snapshot_type="Recovery";
      m_recovery_records[index].snapshot_version=snapshot.snapshot_version;
      m_recovery_records[index].updated_at=snapshot.updated_at;
      m_recovery_records[index].is_valid=snapshot.is_valid;
      m_recovery_records[index].recovery=snapshot;
      return(StoreRecoveryHistory(snapshot));
     }

   bool              GetRecoverySnapshot(const string symbol,
                                          const ENUM_TIMEFRAMES timeframe,
                                          SCommonRecoverySnapshot &snapshot)
     {
      const int index=FindRecoveryIndex(symbol,timeframe);
      if(index<0)
         return(false);
      snapshot=m_recovery_records[index].recovery;
      return(true);
     }

   bool              HasRecoverySnapshot(const string symbol,
                                          const ENUM_TIMEFRAMES timeframe)
     {
      return(FindRecoveryIndex(symbol,timeframe)>=0);
     }

   int               RecoverySnapshotCount(void)
     {
      return(ArraySize(m_recovery_records));
     }

   int               RecoveryHistoryCount(void)
     {
      return(ArraySize(m_recovery_history));
     }

   bool              GetRecoveryHistorySnapshot(const int index,
                                                 SCommonRecoverySnapshot &snapshot)
     {
      if(index<0 || index>=ArraySize(m_recovery_history))
         return(false);
      snapshot=m_recovery_history[index];
      return(true);
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

   //--- Collects lightweight metadata and existing contract outcomes without
   //--- copying full indicator payloads or recalculating any Engine result.
   bool              CollectHealthMeasurement(const string symbol,
                                               const ENUM_TIMEFRAMES timeframe,
                                               SCommonHealthMeasurement &measurement)
     {
      FenxResetCommonHealthMeasurement(measurement);
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0)
         return(false);
      measurement.symbol=symbol;
      measurement.timeframe=EnumToString(timeframe);
      measurement.snapshot_store_available=true;

      const int environment_index=FindEnvironmentIndex(symbol,timeframe);
      const int confidence_index=FindConfidenceIndex(symbol,timeframe);
      const int decision_index=FindDecisionScoreIndex(symbol,timeframe);
      const int volatility_index=FindVolatilityIndex(symbol,timeframe);
      const int range_index=FindRangeIndex(symbol,timeframe);
      const int trend_index=FindTrendIndex(symbol,timeframe);
      const int market_state_index=FindMarketStateIndex(symbol,timeframe);
      const int standby_index=FindStandbyIndex(symbol,timeframe);
      const int risk_index=FindRiskIndex(symbol,timeframe);
      const int entry_index=FindEntryIndex(symbol,timeframe);
      const int exit_index=FindExitIndex(symbol,timeframe);
      const int execution_index=FindExecutionIndex(symbol,timeframe);
      const int recovery_index=FindRecoveryIndex(symbol,timeframe);

      FillHealthStatus(measurement.environment,"Environment",
         environment_index>=0,
         (environment_index>=0 ? m_environment_records[environment_index].environment.is_valid : false),
         (environment_index>=0 ? m_environment_records[environment_index].environment.is_fresh : false),
         (environment_index>=0 ? m_environment_records[environment_index].environment.updated_at : 0),
         (environment_index>=0 ? m_environment_records[environment_index].environment.snapshot_version : ""),
         (environment_index>=0 ? m_environment_records[environment_index].environment.invalid_reason : ""));
      FillHealthStatus(measurement.confidence,"Confidence",
         confidence_index>=0,
         (confidence_index>=0 ? m_confidence_records[confidence_index].confidence.is_valid : false),
         (confidence_index>=0 ? m_confidence_records[confidence_index].confidence.is_fresh : false),
         (confidence_index>=0 ? m_confidence_records[confidence_index].confidence.updated_at : 0),
         (confidence_index>=0 ? m_confidence_records[confidence_index].confidence.snapshot_version : ""),
         (confidence_index>=0 ? m_confidence_records[confidence_index].confidence.invalid_reason : ""));
      FillHealthStatus(measurement.decision_score,"DecisionScore",
         decision_index>=0,
         (decision_index>=0 ? m_decision_score_records[decision_index].decision_score.is_valid : false),
         (decision_index>=0 ? m_decision_score_records[decision_index].decision_score.is_fresh : false),
         (decision_index>=0 ? m_decision_score_records[decision_index].decision_score.updated_at : 0),
         (decision_index>=0 ? m_decision_score_records[decision_index].decision_score.snapshot_version : ""),
         (decision_index>=0 ? m_decision_score_records[decision_index].decision_score.invalid_reason : ""));
      FillHealthStatus(measurement.volatility,"Volatility",
         volatility_index>=0,
         (volatility_index>=0 ? m_volatility_records[volatility_index].volatility.is_valid : false),
         (volatility_index>=0 ? m_volatility_records[volatility_index].volatility.is_fresh : false),
         (volatility_index>=0 ? m_volatility_records[volatility_index].volatility.updated_at : 0),
         (volatility_index>=0 ? m_volatility_records[volatility_index].volatility.snapshot_version : ""),
         (volatility_index>=0 ? m_volatility_records[volatility_index].volatility.invalid_reason : ""));
      FillHealthStatus(measurement.range,"Range",range_index>=0,
         (range_index>=0 ? m_range_records[range_index].range.is_valid : false),
         (range_index>=0 ? m_range_records[range_index].range.is_fresh : false),
         (range_index>=0 ? m_range_records[range_index].range.updated_at : 0),
         (range_index>=0 ? m_range_records[range_index].range.snapshot_version : ""),
         (range_index>=0 ? m_range_records[range_index].range.invalid_reason : ""));
      FillHealthStatus(measurement.trend,"Trend",trend_index>=0,
         (trend_index>=0 ? m_trend_records[trend_index].trend.is_valid : false),
         (trend_index>=0 ? m_trend_records[trend_index].trend.is_fresh : false),
         (trend_index>=0 ? m_trend_records[trend_index].trend.updated_at : 0),
         (trend_index>=0 ? m_trend_records[trend_index].trend.snapshot_version : ""),
         (trend_index>=0 ? m_trend_records[trend_index].trend.invalid_reason : ""));
      FillHealthStatus(measurement.market_state,"MarketState",market_state_index>=0,
         (market_state_index>=0 ? m_market_state_records[market_state_index].market_state.is_valid : false),
         (market_state_index>=0 ? m_market_state_records[market_state_index].market_state.is_fresh : false),
         (market_state_index>=0 ? m_market_state_records[market_state_index].market_state.updated_at : 0),
         (market_state_index>=0 ? m_market_state_records[market_state_index].market_state.snapshot_version : ""),
         (market_state_index>=0 ? m_market_state_records[market_state_index].market_state.invalid_reason : ""));
      FillHealthStatus(measurement.standby,"Standby",standby_index>=0,
         (standby_index>=0 ? m_standby_records[standby_index].standby.is_valid : false),
         (standby_index>=0 ? m_standby_records[standby_index].standby.is_fresh : false),
         (standby_index>=0 ? m_standby_records[standby_index].standby.updated_at : 0),
         (standby_index>=0 ? m_standby_records[standby_index].standby.snapshot_version : ""),
         (standby_index>=0 ? m_standby_records[standby_index].standby.invalid_reason : ""));
      FillHealthStatus(measurement.risk,"Risk",risk_index>=0,
         (risk_index>=0 ? m_risk_records[risk_index].risk.is_valid : false),
         (risk_index>=0 ? m_risk_records[risk_index].risk.is_fresh : false),
         (risk_index>=0 ? m_risk_records[risk_index].risk.updated_at : 0),
         (risk_index>=0 ? m_risk_records[risk_index].risk.snapshot_version : ""),
         (risk_index>=0 ? m_risk_records[risk_index].risk.invalid_reason : ""));
      FillHealthStatus(measurement.entry,"Entry",entry_index>=0,
         (entry_index>=0 ? m_entry_records[entry_index].entry.is_valid : false),
         (entry_index>=0 ? m_entry_records[entry_index].entry.is_fresh : false),
         (entry_index>=0 ? m_entry_records[entry_index].entry.updated_at : 0),
         (entry_index>=0 ? m_entry_records[entry_index].entry.snapshot_version : ""),
         (entry_index>=0 ? m_entry_records[entry_index].entry.invalid_reason : ""));
      FillHealthStatus(measurement.exit_status,"Exit",exit_index>=0,
         (exit_index>=0 ? m_exit_records[exit_index].exit_snapshot.is_valid : false),
         (exit_index>=0 ? m_exit_records[exit_index].exit_snapshot.is_fresh : false),
         (exit_index>=0 ? m_exit_records[exit_index].exit_snapshot.updated_at : 0),
         (exit_index>=0 ? m_exit_records[exit_index].exit_snapshot.snapshot_version : ""),
         (exit_index>=0 ? m_exit_records[exit_index].exit_snapshot.invalid_reason : ""));
      FillHealthStatus(measurement.execution,"Execution",execution_index>=0,
         (execution_index>=0 ? m_execution_records[execution_index].execution.is_valid : false),
         (execution_index>=0 ? m_execution_records[execution_index].execution.is_fresh : false),
         (execution_index>=0 ? m_execution_records[execution_index].execution.updated_at : 0),
         (execution_index>=0 ? m_execution_records[execution_index].execution.snapshot_version : ""),
         (execution_index>=0 ? m_execution_records[execution_index].execution.invalid_reason : ""));
      FillHealthStatus(measurement.recovery,"Recovery",recovery_index>=0,
         (recovery_index>=0 ? m_recovery_records[recovery_index].recovery.is_valid : false),
         (recovery_index>=0 ? m_recovery_records[recovery_index].recovery.is_fresh : false),
         (recovery_index>=0 ? m_recovery_records[recovery_index].recovery.updated_at : 0),
         (recovery_index>=0 ? m_recovery_records[recovery_index].recovery.snapshot_version : ""),
         (recovery_index>=0 ? m_recovery_records[recovery_index].recovery.invalid_reason : ""));

      measurement.snapshot_current_count=
         ArraySize(m_environment_records)+ArraySize(m_confidence_records)+
         ArraySize(m_decision_score_records)+ArraySize(m_volatility_records)+
         ArraySize(m_range_records)+ArraySize(m_trend_records)+
         ArraySize(m_market_state_records)+ArraySize(m_standby_records)+
         ArraySize(m_risk_records)+ArraySize(m_entry_records)+
         ArraySize(m_exit_records)+ArraySize(m_execution_records)+
         ArraySize(m_recovery_records);
      measurement.entry_history_count=ArraySize(m_entry_history);
      measurement.exit_history_count=ArraySize(m_exit_history);
      measurement.execution_history_count=ArraySize(m_execution_history);
      measurement.recovery_history_count=ArraySize(m_recovery_history);
      measurement.health_history_count=ArraySize(m_health_history);
      measurement.snapshot_history_bounded=
         (measurement.entry_history_count<=FENX_COMMON_ENTRY_HISTORY_LIMIT &&
          measurement.exit_history_count<=FENX_COMMON_EXIT_HISTORY_LIMIT &&
          measurement.execution_history_count<=FENX_COMMON_EXECUTION_HISTORY_LIMIT &&
          measurement.recovery_history_count<=FENX_COMMON_RECOVERY_HISTORY_LIMIT &&
          measurement.health_history_count<=FENX_COMMON_HEALTH_HISTORY_LIMIT);

      bool identity_consistent=true;
      if(environment_index>=0)
         identity_consistent=(identity_consistent &&
            m_environment_records[environment_index].environment.symbol==symbol &&
            m_environment_records[environment_index].environment.timeframe==measurement.timeframe);
      if(confidence_index>=0)
         identity_consistent=(identity_consistent &&
            m_confidence_records[confidence_index].confidence.symbol==symbol &&
            m_confidence_records[confidence_index].confidence.timeframe==measurement.timeframe);
      if(decision_index>=0)
         identity_consistent=(identity_consistent &&
            m_decision_score_records[decision_index].decision_score.symbol==symbol &&
            m_decision_score_records[decision_index].decision_score.timeframe==measurement.timeframe);
      if(volatility_index>=0)
         identity_consistent=(identity_consistent &&
            m_volatility_records[volatility_index].volatility.symbol==symbol &&
            m_volatility_records[volatility_index].volatility.timeframe==measurement.timeframe);
      if(range_index>=0)
         identity_consistent=(identity_consistent &&
            m_range_records[range_index].range.symbol==symbol &&
            m_range_records[range_index].range.timeframe==measurement.timeframe);
      if(trend_index>=0)
         identity_consistent=(identity_consistent &&
            m_trend_records[trend_index].trend.symbol==symbol &&
            m_trend_records[trend_index].trend.timeframe==measurement.timeframe);
      if(market_state_index>=0)
         identity_consistent=(identity_consistent &&
            m_market_state_records[market_state_index].market_state.symbol==symbol &&
            m_market_state_records[market_state_index].market_state.timeframe==measurement.timeframe);
      if(standby_index>=0)
         identity_consistent=(identity_consistent &&
            m_standby_records[standby_index].standby.symbol==symbol &&
            m_standby_records[standby_index].standby.timeframe==measurement.timeframe);
      if(risk_index>=0)
         identity_consistent=(identity_consistent &&
            m_risk_records[risk_index].risk.symbol==symbol &&
            m_risk_records[risk_index].risk.timeframe==measurement.timeframe);
      if(entry_index>=0)
         identity_consistent=(identity_consistent &&
            m_entry_records[entry_index].entry.symbol==symbol &&
            m_entry_records[entry_index].entry.timeframe==measurement.timeframe);
      if(exit_index>=0)
         identity_consistent=(identity_consistent &&
            m_exit_records[exit_index].exit_snapshot.symbol==symbol &&
            m_exit_records[exit_index].exit_snapshot.timeframe==measurement.timeframe);
      if(execution_index>=0)
         identity_consistent=(identity_consistent &&
            m_execution_records[execution_index].execution.symbol==symbol &&
            m_execution_records[execution_index].execution.timeframe==measurement.timeframe);
      if(recovery_index>=0)
         identity_consistent=(identity_consistent &&
            m_recovery_records[recovery_index].recovery.symbol==symbol &&
            m_recovery_records[recovery_index].recovery.timeframe==measurement.timeframe);
      measurement.snapshot_identity_consistent=identity_consistent;

      if(entry_index>=0)
        {
         const SEntrySnapshot entry=m_entry_records[entry_index].entry;
         measurement.entry_sequence=entry.entry_evaluation_sequence;
         measurement.entry_allowed=entry.entry_allowed;
         measurement.entry_final_order_ready=entry.final_order_ready;
         measurement.entry_order_submitted=entry.order_submitted;
         measurement.entry_order_succeeded=entry.order_succeeded;
         measurement.entry_data_leak_safe=entry.data_leak_safe;
        }
      if(exit_index>=0)
        {
         const SExitSnapshot exit_snapshot=m_exit_records[exit_index].exit_snapshot;
         measurement.exit_sequence=exit_snapshot.exit_evaluation_sequence;
         measurement.exit_lifecycle_id=exit_snapshot.position_lifecycle_id;
         measurement.exit_position_closed=exit_snapshot.position_closed;
         measurement.exit_close_requested=exit_snapshot.close_requested;
         measurement.exit_close_accepted=exit_snapshot.close_request_accepted;
         measurement.exit_close_succeeded=exit_snapshot.close_succeeded;
         measurement.exit_close_failed=exit_snapshot.close_failed;
         measurement.exit_retry_count=exit_snapshot.retry_count;
         measurement.exit_reason=exit_snapshot.exit_reason;
         measurement.exit_final_close_reason=exit_snapshot.final_close_reason;
         measurement.exit_data_leak_safe=exit_snapshot.data_leak_safe;
        }
      if(execution_index>=0)
        {
         const SCommonExecutionSnapshot execution=
            m_execution_records[execution_index].execution;
         measurement.execution_sequence=execution.execution_sequence;
         measurement.execution_request_type=execution.request_type;
         measurement.execution_order_submitted=execution.order_submitted;
         measurement.execution_order_accepted=execution.order_accepted;
         measurement.execution_order_rejected=execution.order_rejected;
         measurement.execution_retry_count=execution.retry_count;
         measurement.execution_entry_sequence=execution.entry_evaluation_sequence;
         measurement.execution_exit_sequence=execution.exit_evaluation_sequence;
         measurement.execution_position_opened=execution.position_opened;
         measurement.execution_position_closed=execution.position_closed;
         measurement.execution_data_leak_safe=execution.data_leak_safe;
        }
      if(recovery_index>=0)
        {
         const SCommonRecoverySnapshot recovery=
            m_recovery_records[recovery_index].recovery;
         measurement.recovery_audit_sequence=recovery.recovery_audit_sequence;
         measurement.recovery_sequence=recovery.recovery_sequence;
         measurement.recovery_active=recovery.recovery_active;
         measurement.recovery_completed=recovery.recovery_completed;
         measurement.recovery_failed=recovery.recovery_failed;
         measurement.recovery_escalated=recovery.recovery_escalated;
         measurement.recovery_entry_resume_allowed=recovery.entry_resume_allowed;
         measurement.recovery_entry_snapshot_available=
            recovery.entry_snapshot_available;
         measurement.recovery_entry_sequence=recovery.entry_evaluation_sequence;
         measurement.recovery_execution_gate_allowed=
            recovery.execution_gate_allowed;
         measurement.recovery_data_leak_safe=recovery.data_leak_safe;
        }
      return(true);
     }

   //--- Adds or replaces one emitted Common Health evaluation. Health is
   //--- typed-only and never consumes DataBus capacity.
   bool              SetHealthSnapshot(const string symbol,
                                       const ENUM_TIMEFRAMES timeframe,
                                       const SCommonHealthSnapshot &snapshot)
     {
      if(StringLen(symbol)==0 || PeriodSeconds(timeframe)<=0 ||
         snapshot.symbol!=symbol ||
         snapshot.timeframe!=EnumToString(timeframe) ||
         StringLen(snapshot.snapshot_version)==0 || snapshot.updated_at<=0 ||
         snapshot.health_evaluation_sequence<=0)
         return(false);
      int index=FindHealthIndex(symbol,timeframe);
      if(index<0)
        {
         const int count=ArraySize(m_health_records);
         if(ArrayResize(m_health_records,count+1)!=(count+1))
            return(false);
         index=count;
        }
      m_health_records[index].symbol=symbol;
      m_health_records[index].timeframe=timeframe;
      m_health_records[index].snapshot_type="Health";
      m_health_records[index].snapshot_version=snapshot.snapshot_version;
      m_health_records[index].updated_at=snapshot.updated_at;
      m_health_records[index].is_valid=snapshot.is_valid;
      m_health_records[index].health=snapshot;
      return(StoreHealthHistory(snapshot));
     }

   bool              GetHealthSnapshot(const string symbol,
                                       const ENUM_TIMEFRAMES timeframe,
                                       SCommonHealthSnapshot &snapshot)
     {
      const int index=FindHealthIndex(symbol,timeframe);
      if(index<0)
         return(false);
      snapshot=m_health_records[index].health;
      return(true);
     }

   bool              HasHealthSnapshot(const string symbol,
                                       const ENUM_TIMEFRAMES timeframe)
     {
      return(FindHealthIndex(symbol,timeframe)>=0);
     }

   int               HealthSnapshotCount(void)
     {
      return(ArraySize(m_health_records));
     }

   int               HealthHistoryCount(void)
     {
      return(ArraySize(m_health_history));
     }

   bool              GetHealthHistorySnapshot(const int index,
                                              SCommonHealthSnapshot &snapshot)
     {
      if(index<0 || index>=ArraySize(m_health_history))
         return(false);
      snapshot=m_health_history[index];
      return(true);
     }

   void              Clear(void)
     {
      ArrayFree(m_environment_records);
      ArrayFree(m_volatility_records);
      ArrayFree(m_range_records);
      ArrayFree(m_trend_records);
      ArrayFree(m_market_state_records);
      ArrayFree(m_standby_records);
      ArrayFree(m_risk_records);
      ArrayFree(m_entry_records);
      ArrayFree(m_entry_history);
      ArrayFree(m_exit_records);
      ArrayFree(m_exit_history);
      ArrayFree(m_execution_records);
      ArrayFree(m_execution_history);
      ArrayFree(m_recovery_records);
      ArrayFree(m_recovery_history);
      ArrayFree(m_confidence_records);
      ArrayFree(m_decision_score_records);
      ArrayFree(m_health_records);
      ArrayFree(m_health_history);
     }
  };

#endif // FENX_COMMON_SNAPSHOT_STORE_MQH
