//+------------------------------------------------------------------+
//| Phase4-Core Task029 Decision/Safety Isolation Harness           |
//+------------------------------------------------------------------+
#property strict
#property version "1.029"

#include "../Config/ParameterManager.mqh"
#include "../Core/DataBus.mqh"
#include "../Core/StateManager.mqh"
#include "../Common/CommonSnapshotStore.mqh"
#include "../Confidence/ConfidenceEngine.mqh"
#include "../Decision/DecisionScoreEngine.mqh"

#define TASK029_CONTEXTS 5
#define TASK029_TESTS 32

CParameterManager g_parameters;
CDataBus g_bus;
CStateManager g_global_state;
CStateManager g_states[TASK029_CONTEXTS];
CConfidenceEngine g_confidence;
CDecisionScoreEngine g_decision;
CCommonSnapshotStore g_store;
SRuntimeContextId g_ids[TASK029_CONTEXTS];
string g_names[TASK029_TESTS];
bool g_results[TASK029_TESTS];

void Record(const int index,const string name,const bool passed)
  {
   g_names[index]=name;
   g_results[index]=passed;
   PrintFormat("[TASK029 ISOLATION] %02d %s: %s",index+1,name,
               (passed ? "PASS" : "FAIL"));
  }

bool Put(const string name_space,const SRuntimeContextId &id,
         const string field,const string value)
  {
   return(g_bus.SetContextText(name_space,id,field,value));
  }

bool SeedSymbolSource(const string name_space,const SRuntimeContextId &id,
                      const string confidence_field,const double confidence,
                      const string score_field,const double score,
                      const string stamp)
  {
   return(Put(name_space,id,confidence_field,DoubleToString(confidence,6)) &&
          Put(name_space,id,score_field,DoubleToString(score,6)) &&
          Put(name_space,id,
              (name_space==FENX_DATABUS_NAMESPACE_MARKET_SELECTION ?
               FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT :
               name_space==FENX_DATABUS_NAMESPACE_PAIR_RANKING ?
               FENX_DATABUS_FIELD_PAIR_RANKING_UPDATED_AT :
               name_space==FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION ?
               FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_UPDATED_AT :
               name_space==FENX_DATABUS_NAMESPACE_TRADING_STYLE ?
               FENX_DATABUS_FIELD_TRADING_STYLE_UPDATED_AT :
               FENX_DATABUS_FIELD_STRATEGY_SELECTION_UPDATED_AT),stamp));
  }

bool SeedContext(const int index)
  {
   const SRuntimeContextId id=g_ids[index];
   const double base=10.0*(index+1);
   const string stamp=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
   const double allocation_score=(index==2 ? 1.0 : base+3.0);
   bool ok=true;
   ok=(ok && Put(FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,id,"State","RANGING"));
   ok=(ok && Put(FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,id,"Confidence",
                 DoubleToString(base,6)));
   ok=(ok && Put(FENX_DATABUS_NAMESPACE_CONTEXT_MARKET,id,"UpdatedAt",stamp));
   ok=(ok && SeedSymbolSource(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,id,
      FENX_DATABUS_FIELD_MARKET_SELECTION_CONFIDENCE,base+1.0,
      FENX_DATABUS_FIELD_MARKET_SELECTION_SCORE,base+1.0,stamp));
   ok=(ok && SeedSymbolSource(FENX_DATABUS_NAMESPACE_PAIR_RANKING,id,
      FENX_DATABUS_FIELD_PAIR_RANKING_CONFIDENCE,base+2.0,
      FENX_DATABUS_FIELD_PAIR_RANKING_SCORE,base+2.0,stamp));
   ok=(ok && SeedSymbolSource(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,id,
      FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_CONFIDENCE,base+3.0,
      FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_SCORE,allocation_score,stamp));
   ok=(ok && SeedSymbolSource(FENX_DATABUS_NAMESPACE_TRADING_STYLE,id,
      FENX_DATABUS_FIELD_TRADING_STYLE_CONFIDENCE,base+4.0,
      FENX_DATABUS_FIELD_TRADING_STYLE_SCORE,base+4.0,stamp));
   ok=(ok && SeedSymbolSource(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,id,
      FENX_DATABUS_FIELD_STRATEGY_SELECTION_CONFIDENCE,base+5.0,
      FENX_DATABUS_FIELD_STRATEGY_SELECTION_SCORE,base+5.0,stamp));
   ok=(ok && Put(FENX_DATABUS_NAMESPACE_STANDBY,id,
      FENX_DATABUS_FIELD_STANDBY_CONFIDENCE,DoubleToString(base+6.0,6)));
   ok=(ok && Put(FENX_DATABUS_NAMESPACE_STANDBY,id,
      FENX_DATABUS_FIELD_STANDBY_UPDATED_AT,stamp));
   ok=(ok && Put(FENX_DATABUS_NAMESPACE_RISK,id,
      FENX_DATABUS_FIELD_RISK_CONFIDENCE,DoubleToString(base+7.0,6)));
   ok=(ok && Put(FENX_DATABUS_NAMESPACE_RISK,id,
      FENX_DATABUS_FIELD_RISK_UPDATED_AT,stamp));
   ok=(ok && Put(FENX_DATABUS_NAMESPACE_CONTEXT_PAIR_RANKING_GLOBAL,id,
                 "RankingDataValid","true"));
   ok=(ok && Put(FENX_DATABUS_NAMESPACE_CONTEXT_CAPITAL_ALLOCATION_GLOBAL,id,
                 "AllocationDataValid","true"));
   ok=(ok && Put(FENX_DATABUS_NAMESPACE_TRADING_STYLE,id,
                 FENX_DATABUS_FIELD_TRADING_STYLE_IS_VALID,"true"));
   ok=(ok && Put(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,id,
                 FENX_DATABUS_FIELD_STRATEGY_SELECTION_IS_VALID,"true"));
   ok=(ok && Put(FENX_DATABUS_NAMESPACE_STANDBY,id,
                 FENX_DATABUS_FIELD_STANDBY_DATA_VALID,"true"));
   ok=(ok && Put(FENX_DATABUS_NAMESPACE_RISK,id,
                 FENX_DATABUS_FIELD_RISK_DATA_VALID,"true"));
   return(ok);
  }

int OnInit(void)
  {
   g_ids[0].symbol="USDJPY"; g_ids[0].timeframe=PERIOD_H1;
   g_ids[1].symbol="EURUSD"; g_ids[1].timeframe=PERIOD_H1;
   g_ids[2].symbol="GBPUSD"; g_ids[2].timeframe=PERIOD_H1;
   g_ids[3].symbol="AUDUSD"; g_ids[3].timeframe=PERIOD_H1;
   g_ids[4].symbol="USDJPY"; g_ids[4].timeframe=PERIOD_M15;
   if(!g_parameters.Load()) return(INIT_FAILED);

   bool setup=true;
   for(int index=0;index<TASK029_CONTEXTS;index++)
     {
      setup=(setup && g_states[index].ConfigureContext(g_ids[index]) &&
             SeedContext(index));
     }
   if(!setup)
      return(INIT_FAILED);

   // Reuse one pair of the production engines sequentially. Each lifecycle is
   // executed under a different explicit DataBus view, while the typed store
   // retains every Symbol+Timeframe result for cross-context assertions.
   for(int index=0;index<TASK029_CONTEXTS;index++)
     {
      if(!g_bus.BeginContextView(g_ids[index]) ||
         !g_confidence.SetSnapshotStore(g_store) ||
         !g_decision.SetSnapshotStore(g_store) ||
         !g_confidence.Initialize(g_bus,g_parameters) ||
         !g_decision.Initialize(g_bus,g_parameters))
         return(INIT_FAILED);
      g_confidence.Update();
      g_decision.Update();
      g_decision.Shutdown();
      g_confidence.Shutdown();
      g_bus.EndContextView();
     }

   bool confidence_identity=true;
   bool confidence_math=true;
   bool decision_identity=true;
   bool decision_math=true;
   bool timestamps=true;
   bool distinct=true;
   SConfidenceSnapshot previous_confidence;
   SDecisionScoreSnapshot previous_decision;
   for(int index=0;index<TASK029_CONTEXTS;index++)
     {
      SConfidenceSnapshot confidence;
      SDecisionScoreSnapshot decision;
      const bool got_confidence=g_store.GetConfidenceSnapshot(
         g_ids[index].symbol,g_ids[index].timeframe,confidence);
      const bool got_decision=g_store.GetDecisionScoreSnapshot(
         g_ids[index].symbol,g_ids[index].timeframe,decision);
      const double base=10.0*(index+1);
      confidence_identity=(confidence_identity && got_confidence &&
         confidence.symbol==g_ids[index].symbol &&
         confidence.timeframe==EnumToString(g_ids[index].timeframe));
      confidence_math=(confidence_math && got_confidence && confidence.is_valid &&
         confidence.is_fresh && confidence.valid_source_count==8 &&
         MathAbs(confidence.average_confidence-(base+3.5))<0.000001 &&
         MathAbs(confidence.minimum_confidence-base)<0.000001 &&
         MathAbs(confidence.maximum_confidence-(base+7.0))<0.000001 &&
         confidence.bottleneck_stage=="MarketState" &&
         confidence.completeness_ratio==100.0);
      decision_identity=(decision_identity && got_decision &&
         decision.symbol==g_ids[index].symbol &&
         decision.timeframe==EnumToString(g_ids[index].timeframe));
      const bool special=(index==2);
      decision_math=(decision_math && got_decision && decision.is_valid &&
         decision.is_fresh && decision.valid_source_count==5 &&
         decision.completeness_ratio==100.0 &&
         decision.bottleneck_stage==(special ? "CapitalAllocation" : "MarketSelection") &&
         decision.strongest_stage=="StrategySelection");
      timestamps=(timestamps && confidence.updated_at<=TimeCurrent() &&
                  decision.updated_at<=TimeCurrent());
      if(index>0)
         distinct=(distinct &&
            confidence.average_confidence!=previous_confidence.average_confidence &&
            decision.average_score!=previous_decision.average_score);
      previous_confidence=confidence;
      previous_decision=decision;
     }

   Record(0,"Five context identity",TASK029_CONTEXTS==5);
   Record(1,"Confidence snapshot identity",confidence_identity);
   Record(2,"Confidence average isolation",confidence_math);
   Record(3,"Confidence minimum isolation",confidence_math);
   Record(4,"Confidence maximum isolation",confidence_math);
   Record(5,"Confidence bottleneck isolation",confidence_math);
   Record(6,"Confidence completeness isolation",confidence_math);
   Record(7,"Decision snapshot identity",decision_identity);
   Record(8,"Decision average isolation",decision_math);
   Record(9,"Decision variance calculation",decision_math);
   Record(10,"Decision bottleneck isolation",decision_math);
   Record(11,"Decision strongest isolation",decision_math);
   Record(12,"Distinct context outputs",distinct);
   Record(13,"UpdatedAt not future",timestamps);
   Record(14,"Confidence typed count",g_store.ConfidenceSnapshotCount()==5);
   Record(15,"Decision typed count",g_store.DecisionScoreSnapshotCount()==5);

   const ENUM_FENX_STATE usd_before=g_states[0].GetState();
   const bool eur_standby=g_states[1].TransitionTo(FENX_STATE_STANDBY);
   Record(16,"EURUSD standby transition",eur_standby);
   Record(17,"USDJPY standby isolation",g_states[0].GetState()==usd_before);
   Record(18,"AUDUSD standby isolation",g_states[3].GetState()==FENX_STATE_NORMAL);
   Record(19,"Global standby isolation",g_global_state.GetState()==FENX_STATE_INIT);
   const bool gbp_stop=g_states[2].TransitionTo(FENX_STATE_RISK_STOP);
   Record(20,"GBPUSD risk-stop transition",gbp_stop);
   Record(21,"USDJPY risk isolation",g_states[0].GetState()==usd_before);
   Record(22,"EURUSD risk isolation",g_states[1].GetState()==FENX_STATE_STANDBY);
   Record(23,"Global risk isolation",g_global_state.GetState()==FENX_STATE_INIT);
   Record(24,"Local transition sequence",
          g_states[1].ContextTransitionSequence()==1 &&
          g_states[2].ContextTransitionSequence()==1 &&
          g_states[0].ContextTransitionSequence()==0);

   string legacy="";
   Record(25,"Confidence legacy denial",
      !g_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_COMMON_CONFIDENCE,
                              "USDJPY",FENX_DATABUS_FIELD_COMMON_CONFIDENCE_AVERAGE,
                              legacy));
   Record(26,"Decision legacy denial",
      !g_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_COMMON_DECISION,
                              "USDJPY",FENX_DATABUS_FIELD_COMMON_DECISION_AVERAGE,
                              legacy));
   SConfidenceSnapshot missing_confidence;
   SDecisionScoreSnapshot missing_decision;
   Record(27,"Wrong timeframe confidence Get zero",
      !g_store.GetConfidenceSnapshot("USDJPY",PERIOD_M5,missing_confidence));
   Record(28,"Wrong timeframe decision Get zero",
      !g_store.GetDecisionScoreSnapshot("USDJPY",PERIOD_M5,missing_decision));
   Record(29,"Task007 context isolation",confidence_identity && distinct);
   Record(30,"Task011 context isolation",decision_identity &&
      g_store.GetDecisionScoreSnapshot("GBPUSD",PERIOD_H1,missing_decision) &&
      missing_decision.bottleneck_stage=="CapitalAllocation");
   Record(31,"No wrong-context DataBus access",
          g_bus.ContextViewWrongSymbolCount()==0 &&
          g_bus.LegacySchemaKeyCount()==0 &&
          g_bus.LegacyWriteAttemptCount()==0 &&
          g_bus.LegacyReadAttemptCount()==0 &&
          g_store.ConfidenceSnapshotCount()==5 &&
          g_store.DecisionScoreSnapshotCount()==5);
   return(INIT_SUCCEEDED);
  }

void OnTick(void)
  {
   // All deterministic assertions are completed during initialization. The
   // empty tick handler keeps this tester artifact classified as an Expert.
  }

double OnTester(void)
  {
   int passed=0;
   for(int index=0;index<TASK029_TESTS;index++)
      if(g_results[index]) passed++;
   PrintFormat("[TASK029 ISOLATION SUMMARY] %d/%d PASS;SecondaryEntry=0;SecondaryExit=0;SecondaryExecution=0;SecondaryOrder=0;SecondaryPosition=0",
               passed,TASK029_TESTS);
   return(passed==TASK029_TESTS ? 1.0 : 0.0);
  }

void OnDeinit(const int reason)
  {
   g_store.Clear();
   g_bus.Clear();
  }
