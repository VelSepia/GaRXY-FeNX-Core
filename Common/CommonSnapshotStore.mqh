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
   SCommonMarketStateSnapshotRecord m_market_state_records[];
   SCommonStandbySnapshotRecord     m_standby_records[];
   SCommonRiskSnapshotRecord        m_risk_records[];
   SCommonEntrySnapshotRecord       m_entry_records[];
   SEntrySnapshot                   m_entry_history[];
   SCommonExitSnapshotRecord        m_exit_records[];
   SExitSnapshot                    m_exit_history[];
   SCommonExecutionSnapshotRecord   m_execution_records[];
   SCommonExecutionSnapshot         m_execution_history[];
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
      ArrayFree(m_market_state_records);
      ArrayFree(m_standby_records);
      ArrayFree(m_risk_records);
      ArrayFree(m_entry_records);
      ArrayFree(m_entry_history);
      ArrayFree(m_exit_records);
      ArrayFree(m_exit_history);
      ArrayFree(m_execution_records);
      ArrayFree(m_execution_history);
      ArrayFree(m_confidence_records);
      ArrayFree(m_decision_score_records);
     }
  };

#endif // FENX_COMMON_SNAPSHOT_STORE_MQH
