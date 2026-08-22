//+------------------------------------------------------------------+
//|                              Environment/VolatilityAnalyzer.mqh |
//+------------------------------------------------------------------+
#ifndef FENX_ENVIRONMENT_VOLATILITY_ANALYZER_MQH
#define FENX_ENVIRONMENT_VOLATILITY_ANALYZER_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Common/CommonSnapshotStore.mqh"
#include "../Core/AnalysisContextBinding.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Publishes ATR-based market-volatility facts without trading decisions.
class CVolatilityAnalyzer : public CBaseEngine
  {
private:
   int    m_atr_handle;
   int    m_atr_period;
   int    m_baseline_samples;
   double m_low_score;
   double m_high_score;
   int    m_freshness_limit_seconds;
   bool   m_consistency_verified;
   CCommonSnapshotStore *m_snapshot_store;
   CAnalysisContextBinding m_context;
   long   m_update_count;
   long   m_snapshot_count;

   bool ReadSnapshot(double &atr,double &score)
     {
      if(m_atr_handle==INVALID_HANDLE)
         return(false);

      const int required_values=m_baseline_samples+1;
      double atr_values[];
      ResetLastError();
      const int copied=CopyBuffer(m_atr_handle,0,0,required_values,atr_values);
      if(copied!=required_values)
         return(false);

      // CopyBuffer stores the oldest copied value at index zero.
      atr=atr_values[copied-1];
      if(atr<=0.0)
         return(false);

      double baseline_atr=0.0;
      for(int index=0;index<copied-1;index++)
         baseline_atr+=atr_values[index];

      baseline_atr/=m_baseline_samples;
      score=CalculateScore(atr,baseline_atr);
      return(true);
     }

   bool PublishSnapshot(const double atr,const double score,const string level)
     {
      if(m_data_bus==NULL)
         return(false);

      const int symbol_digits=(int)SymbolInfoInteger(m_context.Symbol(),SYMBOL_DIGITS);
      if(!m_context.PublishGlobalLegacy(m_data_bus,
             FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,"ATR",
             FENX_DATABUS_KEY_ENVIRONMENT_ATR,
             DoubleToString(atr,symbol_digits)))
         return(false);

      if(!m_context.PublishGlobalLegacy(m_data_bus,
             FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,"Score",
             FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,
             DoubleToString(score,2)))
         return(false);

      return(m_context.PublishGlobalLegacy(m_data_bus,
             FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,"Level",
             FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_LEVEL,level));
     }

   //--- Builds a typed mirror from the values already published to the legacy
   //--- DataBus. Numeric precision deliberately matches the existing strings,
   //--- so the two interfaces expose exactly the same source facts.
   bool BuildTypedSnapshot(const double atr,const double score,const string level,
                           SVolatilitySnapshot &snapshot)
     {
      const datetime observed_at=TimeCurrent();
      const int symbol_digits=(int)SymbolInfoInteger(m_context.Symbol(),SYMBOL_DIGITS);
      CVolatilitySnapshotContract contract;
      contract.Reset(snapshot,m_context.Symbol(),m_context.Timeframe(),observed_at,m_atr_period,0,
                     m_baseline_samples);
      snapshot.atr=StringToDouble(DoubleToString(atr,symbol_digits));
      snapshot.volatility_score=StringToDouble(DoubleToString(score,2));
      snapshot.volatility_level=level;
      snapshot.source_updated_at=observed_at;
      snapshot.source_bar_time=iTime(m_context.Symbol(),m_context.Timeframe(),0);
      return(contract.Finalize(snapshot,observed_at,m_freshness_limit_seconds));
     }

   bool SameTypedSnapshot(const SVolatilitySnapshot &left,
                          const SVolatilitySnapshot &right)
     {
      return(left.symbol==right.symbol && left.timeframe==right.timeframe &&
             left.snapshot_version==right.snapshot_version &&
             left.updated_at==right.updated_at &&
             left.is_valid==right.is_valid && left.is_fresh==right.is_fresh &&
             left.invalid_reason==right.invalid_reason && left.atr==right.atr &&
             left.volatility_score==right.volatility_score &&
             left.volatility_level==right.volatility_level &&
             left.source_updated_at==right.source_updated_at &&
             left.source_bar_time==right.source_bar_time &&
             left.atr_period==right.atr_period &&
             left.atr_shift==right.atr_shift &&
             left.baseline_samples==right.baseline_samples);
     }

   //--- Stores the typed mirror and, on its first success, verifies it against
   //--- both the stored payload and the three unchanged legacy DataBus values.
   bool StoreTypedSnapshot(const SVolatilitySnapshot &snapshot)
     {
      if(m_snapshot_store==NULL ||
         !m_snapshot_store.SetVolatilitySnapshot(m_context.Symbol(),m_context.Timeframe(),snapshot))
         return(false);
      if(m_consistency_verified)
         return(true);

      SVolatilitySnapshot stored;
      if(!m_snapshot_store.GetVolatilitySnapshot(m_context.Symbol(),m_context.Timeframe(),stored) ||
         !SameTypedSnapshot(snapshot,stored))
         return(false);

      string atr_text="";
      string score_text="";
      string level_text="";
      const int symbol_digits=(int)SymbolInfoInteger(m_context.Symbol(),SYMBOL_DIGITS);
      if(m_data_bus==NULL ||
         !m_context.ReadGlobalLegacy(m_data_bus,
            FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,"ATR",
            FENX_DATABUS_KEY_ENVIRONMENT_ATR,atr_text) ||
         !m_context.ReadGlobalLegacy(m_data_bus,
            FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,"Score",
            FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,score_text) ||
         !m_context.ReadGlobalLegacy(m_data_bus,
            FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,"Level",
            FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_LEVEL,level_text))
         return(false);
      return(atr_text==DoubleToString(snapshot.atr,symbol_digits) &&
             score_text==DoubleToString(snapshot.volatility_score,2) &&
             level_text==snapshot.volatility_level);
     }

public:
                     CVolatilityAnalyzer(void)
     {
      SetName("VolatilityAnalyzer");
      m_atr_handle=INVALID_HANDLE;
      m_atr_period=0;
      m_baseline_samples=0;
      m_low_score=0.0;
      m_high_score=0.0;
      m_freshness_limit_seconds=0;
      m_consistency_verified=false;
      m_snapshot_store=NULL;
      m_update_count=0;
      m_snapshot_count=0;
     }

   //--- Binds this instance to one explicit Symbol+Timeframe before handles
   //--- are created. Only the primary instance may publish legacy aliases.
   bool              SetRuntimeContext(const SRuntimeContextId &context_id,
                                       const bool publish_primary_legacy)
     {
      return(!m_initialized &&
             m_context.Configure(context_id,publish_primary_legacy));
     }

   //--- Injects the non-owning typed store before framework initialization.
   //--- Legacy DataBus publication remains mandatory and authoritative.
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
         CLogger::Error("VolatilityAnalyzer requires CommonSnapshotStore before initialization.");
         return(false);
        }
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_atr_period=parameters.VolatilityAtrPeriod();
      m_baseline_samples=parameters.VolatilityBaselineSamples();
      m_low_score=parameters.VolatilityLowScore();
      m_high_score=parameters.VolatilityHighScore();
      m_freshness_limit_seconds=parameters.RiskStaleDataLimitSeconds();

      if(m_atr_period<=0 || m_baseline_samples<=0 ||
         m_low_score<0.0 || m_high_score<=m_low_score ||
         m_freshness_limit_seconds<=0)
        {
         CLogger::Error("VolatilityAnalyzer received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      ResetLastError();
      m_atr_handle=iATR(m_context.Symbol(),m_context.Timeframe(),m_atr_period);
      if(m_atr_handle==INVALID_HANDLE)
        {
         CLogger::Error(StringFormat("VolatilityAnalyzer could not create an ATR handle. Error: %d",
                                     GetLastError()));
         CBaseEngine::Shutdown();
         return(false);
        }

      CLogger::Info(StringFormat("VolatilityAnalyzer configured with ATR(%d) and %d baseline samples.",
                                 m_atr_period,m_baseline_samples));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;
      m_update_count++;

      double atr=0.0;
      double score=0.0;
      if(!ReadSnapshot(atr,score))
        {
         CLogger::Warning("VolatilityAnalyzer is waiting for ATR data.");
         return;
        }

      const string level=Classify(score);
      if(!PublishSnapshot(atr,score,level))
        {
         CLogger::Error("VolatilityAnalyzer could not publish its snapshot to DataBus.");
         return;
        }

      SVolatilitySnapshot snapshot;
      if(!BuildTypedSnapshot(atr,score,level,snapshot) ||
         !StoreTypedSnapshot(snapshot))
        {
         CLogger::Error("VolatilityAnalyzer could not store or verify its typed snapshot.");
         return;
        }
      m_snapshot_count++;

      if(!m_consistency_verified)
        {
         CLogger::Info(StringFormat(
            "[COMMON_VOLATILITY] typed_databus_consistency=PASS;symbol=%s;timeframe=%s;store_count=%d;keys=0;atr_period=%d;atr_shift=%d;baseline_samples=%d",
            snapshot.symbol,snapshot.timeframe,
            m_snapshot_store.VolatilitySnapshotCount(),snapshot.atr_period,
            snapshot.atr_shift,snapshot.baseline_samples));
         m_consistency_verified=true;
        }
     }

   virtual void       Shutdown(void)
     {
      if(m_atr_handle!=INVALID_HANDLE)
        {
         IndicatorRelease(m_atr_handle);
         m_atr_handle=INVALID_HANDLE;
        }

      m_consistency_verified=false;
      CBaseEngine::Shutdown();
     }

   int               AtrHandle(void)
     {
      return(m_atr_handle);
     }

   long              UpdateCount(void)
     {
      return(m_update_count);
     }

   long              SnapshotCount(void)
     {
      return(m_snapshot_count);
     }

   SRuntimeContextId ContextId(void)
     {
      return(m_context.Id());
     }

   double            CalculateScore(const double current_atr,const double baseline_atr)
     {
      if(current_atr<=0.0 || baseline_atr<=0.0)
         return(0.0);

      // A current ATR equal to the recent baseline produces a neutral score of 50.
      return(MathMax(0.0,MathMin(100.0,50.0*current_atr/baseline_atr)));
     }

   string            Classify(const double score)
     {
      if(score>=m_high_score)
         return("HIGH");

      if(score<=m_low_score)
         return("LOW");

      return("NORMAL");
     }
  };

#endif // FENX_ENVIRONMENT_VOLATILITY_ANALYZER_MQH

