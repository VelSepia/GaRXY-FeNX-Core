//+------------------------------------------------------------------+
//| Phase4-Core Task027 Synthetic Context Analysis Harness          |
//+------------------------------------------------------------------+
#property strict
#property version "1.027"

#include "../Core/RuntimeContextRegistry.mqh"
#include "../Core/AnalysisContextBinding.mqh"

#define TASK027_SYNTHETIC_TEST_COUNT 16

class CTask027NewBarProbe : public CBaseEngine
  {
private:
   int m_updates;
public:
                     CTask027NewBarProbe(void) { m_updates=0; }
   virtual void       Update(void) { m_updates++; }
   int                UpdateCount(void) { return(m_updates); }
  };

bool g_results[TASK027_SYNTHETIC_TEST_COUNT];
string g_names[TASK027_SYNTHETIC_TEST_COUNT];
CEngineManager g_bar_manager;
CTask027NewBarProbe g_h1_probe;
CTask027NewBarProbe g_m15_probe;
CParameterManager g_bar_parameters;
CDataBus g_bar_bus;
CStateManager g_bar_global;
CStateManager g_h1_state;
CStateManager g_m15_state;
bool g_bar_ready=false;

void Record(const int index,const string name,const bool passed)
  {
   g_names[index]=name;
   g_results[index]=passed;
   PrintFormat("[TASK027 SYNTHETIC] %02d %s: %s",index+1,name,
               (passed ? "PASS" : "FAIL"));
  }

void FillContext(SRuntimeContextConfig &config,const string symbol,
                 const ENUM_TIMEFRAMES timeframe,const bool required,
                 const ENUM_FENX_CONTEXT_ROLE role,const bool trade_enabled,
                 const long magic)
  {
   ResetRuntimeContextConfig(config);
   config.id.symbol=symbol;
   config.id.timeframe=timeframe;
   config.enabled=true;
   config.required=required;
   config.role=role;
   config.trade_enabled=trade_enabled;
   config.magic=magic;
   config.parameter_profile_id="task027";
  }

void BuildContexts(SRuntimeContextConfig &configs[])
  {
   ArrayResize(configs,5);
   FillContext(configs[0],"USDJPY",PERIOD_H1,true,
               FENX_CONTEXT_ROLE_PRIMARY_TRADING,true,93095);
   FillContext(configs[1],"EURUSD",PERIOD_H1,false,
               FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93095);
   FillContext(configs[2],"GBPUSD",PERIOD_H1,false,
               FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93095);
   FillContext(configs[3],"AUDUSD",PERIOD_H1,false,
               FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93095);
   FillContext(configs[4],"USDJPY",PERIOD_M15,false,
               FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93096);
  }

int OnInit(void)
  {
   SRuntimeContextConfig configs[];
   BuildContexts(configs);
   bool availability[];
   ArrayResize(availability,5);
   for(int index=0;index<5;index++) availability[index]=true;

   CParameterManager parameters;
   CRuntimeContextRegistry registry;
   CCommonSnapshotStore snapshots;
   CEngineManager manager;
   const bool registry_ok=(parameters.SetRuntimeContextConfigs(configs) &&
      registry.InitializeWithAvailability(parameters,availability) &&
      registry.PrepareAnalysis(snapshots));
   Record(0,"Five Context Ownership",registry_ok && registry.Count()==5 &&
          registry.AvailableContextCount()==5 && registry.AnalysisEngineCount()==30);

   bool independent=true;
   for(int left=0;left<5;left++)
      for(int right=left+1;right<5;right++)
        {
         CRuntimeContext *a=registry.ContextAt(left);
         CRuntimeContext *b=registry.ContextAt(right);
         if(a==NULL || b==NULL || a.Volatility()==b.Volatility() ||
            a.Range()==b.Range() || a.Trend()==b.Trend() ||
            a.MarketState()==b.MarketState() ||
            a.Environment()==b.Environment() ||
            a.MarketSelection()==b.MarketSelection())
            independent=false;
        }
   Record(1,"Independent Engine Instances",independent);

   const bool registered=(registry_ok && registry.RegisterAnalysis(manager));
   Record(2,"Thirty Non-owning Registrations",registered && manager.Count()==30);

   const string sequence[6]={"VolatilityAnalyzer","RangeDetector","TrendDetector",
                             "MarketStateIntegrator","EnvironmentEngine",
                             "MarketSelectionEngine"};
   bool order_ok=registered;
   for(int context=0;context<5;context++)
      for(int stage=0;stage<6;stage++)
        {
         const int position=context*6+stage;
         SRuntimeContextId id;
         if(manager.GetEngineName(position)!=sequence[stage] ||
            !manager.GetContextId(position,id) ||
            !RuntimeContextEquals(id,configs[context].id))
            order_ok=false;
        }
   Record(3,"Pipeline and Phase Order",order_ok);

   bool state_ok=true;
   for(int context=0;context<5;context++)
     {
      CRuntimeContext *runtime=registry.ContextAt(context);
      for(int stage=0;stage<6;stage++)
        {
         const int position=context*6+stage;
         if(runtime==NULL || manager.GetRegistrationStateManager(position)!=
                             runtime.StateManager())
            state_ok=false;
        }
     }
   Record(4,"Context-local State Metadata",state_ok);

   bool auxiliary_safe=true;
   for(int context=1;context<5;context++)
      auxiliary_safe=(auxiliary_safe && !configs[context].trade_enabled &&
                      configs[context].role==FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS);
   Record(5,"Secondary Analysis-only Roles",auxiliary_safe);

   CDataBus bus;
   CAnalysisContextBinding primary_binding;
   CAnalysisContextBinding secondary_binding;
   const bool bindings=(primary_binding.Configure(configs[0].id,true) &&
                        secondary_binding.Configure(configs[1].id,false));
   const bool primary_write=(bindings && primary_binding.PublishGlobalLegacy(
      GetPointer(bus),FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,"ATR",
      FENX_DATABUS_KEY_ENVIRONMENT_ATR,"1.111"));
   const bool secondary_write=(secondary_binding.PublishGlobalLegacy(
      GetPointer(bus),FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,"ATR",
      FENX_DATABUS_KEY_ENVIRONMENT_ATR,"2.222"));
   string primary_context="",secondary_context="",legacy="";
   const bool isolation=(primary_write && secondary_write &&
      bus.TryGetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,
                            configs[0].id,"ATR",primary_context) &&
      bus.TryGetContextText(FENX_DATABUS_NAMESPACE_CONTEXT_VOLATILITY,
                            configs[1].id,"ATR",secondary_context) &&
      bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_ATR,legacy) &&
      primary_context=="1.111" && secondary_context=="2.222" &&
      legacy=="1.111");
   Record(6,"Context DataBus Isolation",isolation);
   Record(7,"Primary Legacy Alias",legacy==primary_context);
   Record(8,"Secondary Legacy Denial",legacy!="2.222" &&
          bus.LegacyFallbackReadCount()==0);

   const bool selection_primary=primary_binding.PublishSymbolLegacy(
      GetPointer(bus),FENX_DATABUS_NAMESPACE_MARKET_SELECTION,
      FENX_DATABUS_FIELD_MARKET_SELECTION_SCORE,"61.00");
   const bool selection_secondary=secondary_binding.PublishSymbolLegacy(
      GetPointer(bus),FENX_DATABUS_NAMESPACE_MARKET_SELECTION,
      FENX_DATABUS_FIELD_MARKET_SELECTION_SCORE,"72.00");
   string secondary_legacy="";
   Record(9,"Market Selection Per-context",selection_primary && selection_secondary &&
          !bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,
                                configs[1].id.symbol,
                                FENX_DATABUS_FIELD_MARKET_SELECTION_SCORE,
                                secondary_legacy));

   SVolatilitySnapshot h1;
   SVolatilitySnapshot m15;
   h1.symbol="USDJPY";
   h1.timeframe=EnumToString(PERIOD_H1);
   h1.snapshot_version=FENX_COMMON_VOLATILITY_SNAPSHOT_VERSION;
   h1.updated_at=TimeCurrent();
   h1.volatility_score=11.0;
   m15=h1;
   m15.timeframe=EnumToString(PERIOD_M15);
   m15.volatility_score=15.0;
   SVolatilitySnapshot h1_read;
   SVolatilitySnapshot m15_read;
   const bool snapshot_isolation=(snapshots.SetVolatilitySnapshot("USDJPY",PERIOD_H1,h1) &&
      snapshots.SetVolatilitySnapshot("USDJPY",PERIOD_M15,m15) &&
      snapshots.GetVolatilitySnapshot("USDJPY",PERIOD_H1,h1_read) &&
      snapshots.GetVolatilitySnapshot("USDJPY",PERIOD_M15,m15_read) &&
      h1_read.volatility_score==11.0 && m15_read.volatility_score==15.0);
   Record(10,"Typed Snapshot Isolation",snapshot_isolation);

   SVolatilitySnapshot wrong;
   Record(11,"Wrong-context Get Denied",
          !snapshots.GetVolatilitySnapshot("EURUSD",PERIOD_M15,wrong));
   Record(12,"Same-symbol Different-TF",configs[0].id.symbol==configs[4].id.symbol &&
          !RuntimeContextEquals(configs[0].id,configs[4].id));

   bool optional_availability[];
   ArrayResize(optional_availability,5);
   for(int index=0;index<5;index++) optional_availability[index]=true;
   optional_availability[1]=false;
   CRuntimeContextRegistry optional_registry;
   const bool optional_ok=optional_registry.InitializeWithAvailability(
      parameters,optional_availability);
   configs[1].required=true;
   CParameterManager required_parameters;
   required_parameters.SetRuntimeContextConfigs(configs);
   SRuntimeContextPreflight required_result;
   CRuntimeContextRegistry check_registry;
   const bool required_fail=!check_registry.EvaluatePreflight(
      required_parameters,optional_availability,709,30,required_result);
   Record(13,"Required Fail Optional Hold",optional_ok && required_fail &&
          required_result.failure_reason=="REQUIRED_CONTEXT_UNAVAILABLE");

   Record(14,"Capacity and Engine Bounds",FENX_DATABUS_CAPACITY==2048 &&
          FENX_MAX_ENGINES==256 && 709<=(int)MathFloor(2048.0*0.70));

   g_h1_probe.SetName("Task027H1NewBar");
   g_m15_probe.SetName("Task027M15NewBar");
   SRuntimeContextId h1_id;
   h1_id.symbol=_Symbol;
   h1_id.timeframe=PERIOD_H1;
   SRuntimeContextId m15_id;
   m15_id.symbol=_Symbol;
   m15_id.timeframe=PERIOD_M15;
   g_bar_ready=(g_bar_manager.Register(g_h1_probe,h1_id,g_h1_state,RUNMODE_NEWBAR) &&
      g_bar_manager.Register(g_m15_probe,m15_id,g_m15_state,RUNMODE_NEWBAR) &&
      g_bar_manager.Initialize(g_bar_bus,g_bar_parameters,g_bar_global));
   Record(15,"Independent NewBar Clocks",g_bar_ready &&
          g_bar_manager.GetLastBarTime(0)==iTime(_Symbol,PERIOD_H1,0) &&
          g_bar_manager.GetLastBarTime(1)==iTime(_Symbol,PERIOD_M15,0));
   return(INIT_SUCCEEDED);
  }

void OnTick(void)
  {
   if(g_bar_ready) g_bar_manager.Update();
  }

double OnTester(void)
  {
   g_results[15]=(g_results[15] && g_h1_probe.UpdateCount()>0 &&
                  g_m15_probe.UpdateCount()>g_h1_probe.UpdateCount());
   int passed=0;
   for(int index=0;index<TASK027_SYNTHETIC_TEST_COUNT;index++)
     {
      if(g_results[index]) passed++;
      PrintFormat("[TASK027 SYNTHETIC FINAL] %02d %s: %s",index+1,g_names[index],
                  (g_results[index] ? "PASS" : "FAIL"));
     }
   PrintFormat("[TASK027 SYNTHETIC SUMMARY] %d/%d PASS H1=%d M15=%d",
               passed,TASK027_SYNTHETIC_TEST_COUNT,g_h1_probe.UpdateCount(),
               g_m15_probe.UpdateCount());
   return(passed==TASK027_SYNTHETIC_TEST_COUNT ? 1.0 : 0.0);
  }

void OnDeinit(const int reason)
  {
   if(g_bar_ready) g_bar_manager.Shutdown();
  }
