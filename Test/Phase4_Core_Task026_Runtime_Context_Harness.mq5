//+------------------------------------------------------------------+
//| Phase4-Core Task026 Runtime Context Foundation Harness          |
//+------------------------------------------------------------------+
#property strict
#property version "1.026"

#include "../Core/RuntimeContextRegistry.mqh"
#include "../Core/EngineManager.mqh"
#include "../Core/DataBus.mqh"
#include "../Common/CommonSnapshotStore.mqh"
#include "../Engine/BaseEngine.mqh"

#define TASK026_TEST_COUNT 19

class CTask026HarnessEngine : public CBaseEngine
  {
private:
   int m_update_count;

public:
                     CTask026HarnessEngine(void)
     {
      m_update_count=0;
     }

   virtual void       Update(void)
     {
      m_update_count++;
     }

   int               UpdateCount(void)
     {
      return(m_update_count);
     }

   CStateManager    *AssignedStateManager(void)
     {
      return(m_state_manager);
     }
  };

bool                     g_results[TASK026_TEST_COUNT];
string                   g_names[TASK026_TEST_COUNT];
CEngineManager           g_bar_manager;
CTask026HarnessEngine    g_h1_bar_engine;
CTask026HarnessEngine    g_m15_bar_engine;
CParameterManager        g_bar_parameters;
CDataBus                 g_bar_data_bus;
CStateManager            g_bar_global_state;
CStateManager            g_h1_local_state;
CStateManager            g_m15_local_state;
CTask026HarnessEngine    g_capacity_engines[FENX_MAX_ENGINES+1];
bool                     g_bar_manager_ready=false;

void RecordResult(const int index,const string name,const bool passed)
  {
   g_names[index]=name;
   g_results[index]=passed;
   PrintFormat("[TASK026 HARNESS] %02d %s: %s",index+1,name,
               (passed ? "PASS" : "FAIL"));
  }

void FillContext(SRuntimeContextConfig &config,const string symbol,
                 const ENUM_TIMEFRAMES timeframe,const bool enabled,
                 const bool required,const bool trade_enabled,
                 const ENUM_FENX_CONTEXT_ROLE role,const long magic,
                 const string profile)
  {
   ResetRuntimeContextConfig(config);
   config.id.symbol=symbol;
   config.id.timeframe=timeframe;
   config.enabled=enabled;
   config.required=required;
   config.trade_enabled=trade_enabled;
   config.role=role;
   config.magic=magic;
   config.parameter_profile_id=profile;
  }

void BuildFiveContexts(SRuntimeContextConfig &configs[])
  {
   ArrayResize(configs,5);
   FillContext(configs[0],"USDJPY",PERIOD_H1,true,true,true,
               FENX_CONTEXT_ROLE_PRIMARY_TRADING,93095,"primary");
   FillContext(configs[1],"EURUSD",PERIOD_H1,true,false,false,
               FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,93095,"aux-b");
   FillContext(configs[2],"GBPUSD",PERIOD_H1,true,false,false,
               FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,93095,"aux-c");
   FillContext(configs[3],"AUDUSD",PERIOD_H1,true,false,false,
               FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,93095,"aux-d");
   FillContext(configs[4],"USDJPY",PERIOD_M15,true,false,false,
               FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,93096,"aux-e");
  }

bool ConfigureFive(CParameterManager &parameters,SRuntimeContextConfig &configs[],
                   bool &availability[])
  {
   BuildFiveContexts(configs);
   ArrayResize(availability,5);
   for(int index=0;index<5;index++)
      availability[index]=true;
   return(parameters.SetRuntimeContextConfigs(configs));
  }

int OnInit(void)
  {
   SRuntimeContextConfig configs[];
   bool availability[];
   CParameterManager parameters;
   const bool config_set=ConfigureFive(parameters,configs,availability);

   SRuntimeContextConfig config_out;
   const bool config_ok=(config_set && parameters.RuntimeContextCount()==5 &&
                         parameters.GetRuntimeContextConfig(4,config_out) &&
                         config_out.id.symbol=="USDJPY" &&
                         config_out.id.timeframe==PERIOD_M15 &&
                         config_out.magic==93096);
   RecordResult(0,"Context Config",config_ok);

   CRuntimeContextRegistry registry;
   const bool registry_ok=(config_set &&
      registry.InitializeWithAvailability(parameters,availability) &&
      registry.Count()==5);
   RecordResult(1,"Context Registry",registry_ok);

   CParameterManager fallback_parameters;
   SRuntimeContextConfig fallback;
   const bool fallback_ok=(fallback_parameters.RuntimeContextCount()==1 &&
      !fallback_parameters.HasExplicitRuntimeContexts() &&
      fallback_parameters.GetPrimaryRuntimeContext(fallback) &&
      fallback.id.symbol==_Symbol && fallback.id.timeframe==(ENUM_TIMEFRAMES)_Period &&
      fallback.enabled && fallback.required && fallback.trade_enabled &&
      fallback.role==FENX_CONTEXT_ROLE_PRIMARY_TRADING && fallback.magic==93095);
   RecordResult(2,"Single Fallback",fallback_ok);

   CRuntimeContext *primary=registry.Primary();
   const bool primary_ok=(registry.PrimaryIndex()==0 && primary!=NULL &&
      primary.Config().id.symbol=="USDJPY" &&
      primary.Config().role==FENX_CONTEXT_ROLE_PRIMARY_TRADING);
   RecordResult(3,"Primary Lookup",primary_ok);

   SRuntimeContextConfig duplicate_configs[];
   BuildFiveContexts(duplicate_configs);
   duplicate_configs[4].id=duplicate_configs[0].id;
   CParameterManager duplicate_parameters;
   duplicate_parameters.SetRuntimeContextConfigs(duplicate_configs);
   SRuntimeContextPreflight duplicate_preflight;
   CRuntimeContextRegistry preflight_registry;
   const bool duplicate_rejected=
      (!preflight_registry.EvaluatePreflight(duplicate_parameters,availability,
                                             512,143,duplicate_preflight) &&
       duplicate_preflight.failure_reason=="DUPLICATE_IDENTITY");
   RecordResult(4,"Duplicate Identity",duplicate_rejected);

   string valid_reason="";
   const bool multi_tf_ok=(parameters.ValidateRuntimeContextConfiguration(valid_reason) &&
      parameters.FindRuntimeContext(configs[0].id)==0 &&
      parameters.FindRuntimeContext(configs[4].id)==4 &&
      configs[0].magic!=configs[4].magic);
   RecordResult(5,"Same Symbol Multi-TF",multi_tf_ok);

   SRuntimeContextConfig magic_configs[];
   BuildFiveContexts(magic_configs);
   magic_configs[4].magic=93095;
   CParameterManager magic_parameters;
   magic_parameters.SetRuntimeContextConfigs(magic_configs);
   SRuntimeContextPreflight magic_preflight;
   const bool magic_rejected=
      (!preflight_registry.EvaluatePreflight(magic_parameters,availability,
                                             512,143,magic_preflight) &&
       magic_preflight.failure_reason=="MAGIC_OWNERSHIP_COLLISION");
   RecordResult(6,"Magic Ownership",magic_rejected);

   SRuntimeContextConfig disabled_configs[];
   ArrayResize(disabled_configs,2);
   disabled_configs[0]=configs[0];
   disabled_configs[1]=configs[1];
   disabled_configs[1].enabled=false;
   disabled_configs[1].required=false;
   disabled_configs[1].trade_enabled=false;
   bool disabled_availability[];
   ArrayResize(disabled_availability,2);
   disabled_availability[0]=true;
   disabled_availability[1]=false;
   CParameterManager disabled_parameters;
   CRuntimeContextRegistry disabled_registry;
   const bool disabled_ok=(disabled_parameters.SetRuntimeContextConfigs(disabled_configs) &&
      disabled_registry.InitializeWithAvailability(disabled_parameters,disabled_availability) &&
      disabled_registry.Count()==2 && disabled_registry.ContextAt(1)!=NULL &&
      !disabled_registry.ContextAt(1).IsAvailable() &&
      !disabled_registry.ContextAt(1).IsInitialized());
   RecordResult(7,"Enabled Disabled",disabled_ok);

   bool optional_availability[];
   ArrayResize(optional_availability,5);
   for(int index=0;index<5;index++) optional_availability[index]=true;
   optional_availability[1]=false;
   CRuntimeContextRegistry optional_registry;
   const bool optional_accepted=
      optional_registry.InitializeWithAvailability(parameters,optional_availability);
   SRuntimeContextConfig required_configs[];
   BuildFiveContexts(required_configs);
   required_configs[1].required=true;
   CParameterManager required_parameters;
   required_parameters.SetRuntimeContextConfigs(required_configs);
   SRuntimeContextPreflight required_preflight;
   const bool required_rejected=
      !preflight_registry.EvaluatePreflight(required_parameters,optional_availability,
                                            512,143,required_preflight);
   RecordResult(8,"Required Optional",optional_accepted && required_rejected &&
                required_preflight.failure_reason=="REQUIRED_CONTEXT_UNAVAILABLE");

   SRuntimeContextConfig trade_configs[];
   BuildFiveContexts(trade_configs);
   trade_configs[1].trade_enabled=true;
   CParameterManager trade_parameters;
   trade_parameters.SetRuntimeContextConfigs(trade_configs);
   string trade_reason="";
   const bool trade_flags_ok=(configs[0].trade_enabled && !configs[1].trade_enabled &&
      !trade_parameters.ValidateRuntimeContextConfiguration(trade_reason) &&
      trade_reason=="AUXILIARY_TRADING");
   RecordResult(9,"Trade Enabled",trade_flags_ok);

   SRuntimeContextConfig role_configs[];
   BuildFiveContexts(role_configs);
   role_configs[1].role=(ENUM_FENX_CONTEXT_ROLE)99;
   CParameterManager role_parameters;
   const bool role_ok=(!role_parameters.SetRuntimeContextConfigs(role_configs) &&
      configs[0].role==FENX_CONTEXT_ROLE_PRIMARY_TRADING &&
      configs[1].role==FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS);
   RecordResult(10,"Context Role",role_ok);

   const bool lookup_ok=(registry.Find(configs[1].id)==1 &&
      registry.Find(configs[4].id)==4 && registry.Has(configs[4].id));
   RecordResult(11,"Context Lookup",lookup_ok);

   CTask026HarnessEngine legacy_engine;
   CEngineManager metadata_manager;
   CDataBus metadata_bus;
   CStateManager metadata_global_state;
   CStateManager *primary_state=(primary==NULL ? NULL : primary.StateManager());
   bool context_registered=false;
   if(primary_state!=NULL)
      context_registered=metadata_manager.Register(g_h1_bar_engine,configs[0].id,
                                                   primary_state,RUNMODE_NEWBAR);
   const bool legacy_registered=metadata_manager.Register(legacy_engine);
   const bool metadata_initialized=(context_registered && legacy_registered &&
      metadata_manager.Initialize(metadata_bus,parameters,metadata_global_state));
   SRuntimeContextId metadata_id;
   const bool metadata_ok=(metadata_initialized && metadata_manager.HasContext(0) &&
      metadata_manager.GetContextId(0,metadata_id) &&
      RuntimeContextEquals(metadata_id,configs[0].id) &&
      metadata_manager.GetRegistrationStateManager(0)==primary_state &&
      metadata_manager.GetRunMode(0)==RUNMODE_NEWBAR);
   RecordResult(12,"Engine Context Metadata",metadata_ok);

   const bool legacy_ok=(metadata_initialized && !metadata_manager.HasContext(1) &&
      metadata_manager.GetRegistrationStateManager(1)==NULL &&
      legacy_engine.AssignedStateManager()==GetPointer(metadata_global_state) &&
      metadata_manager.GetRunMode(1)==RUNMODE_TICK);
   RecordResult(13,"Legacy Register",legacy_ok);
   metadata_manager.Shutdown();

   g_h1_bar_engine.SetName("Task026H1BarEngine");
   g_m15_bar_engine.SetName("Task026M15BarEngine");
   SRuntimeContextId h1_id;
   h1_id.symbol=_Symbol;
   h1_id.timeframe=PERIOD_H1;
   SRuntimeContextId m15_id;
   m15_id.symbol=_Symbol;
   m15_id.timeframe=PERIOD_M15;
   g_bar_manager_ready=(g_bar_manager.Register(g_h1_bar_engine,h1_id,
                                               g_h1_local_state,RUNMODE_NEWBAR) &&
                        g_bar_manager.Register(g_m15_bar_engine,m15_id,
                                               g_m15_local_state,RUNMODE_NEWBAR) &&
                        g_bar_manager.Initialize(g_bar_data_bus,g_bar_parameters,
                                                 g_bar_global_state));
   SRuntimeContextId bar_h1_out;
   SRuntimeContextId bar_m15_out;
   const bool bar_identity_ok=(g_bar_manager_ready &&
      g_bar_manager.GetContextId(0,bar_h1_out) &&
      g_bar_manager.GetContextId(1,bar_m15_out) &&
      RuntimeContextEquals(bar_h1_out,h1_id) && RuntimeContextEquals(bar_m15_out,m15_id) &&
      g_bar_manager.GetLastBarTime(0)==iTime(_Symbol,PERIOD_H1,0) &&
      g_bar_manager.GetLastBarTime(1)==iTime(_Symbol,PERIOD_M15,0));
   RecordResult(14,"Context NewBar Identity",bar_identity_ok);

   CEngineManager capacity_manager;
   bool capacity_ok=(FENX_MAX_ENGINES==256);
   for(int index=0;index<FENX_MAX_ENGINES;index++)
     {
      g_capacity_engines[index].SetName(StringFormat("CapacityEngine%03d",index));
      if(!capacity_manager.Register(g_capacity_engines[index]))
         capacity_ok=false;
     }
   capacity_ok=(capacity_ok && capacity_manager.Count()==256 &&
                !capacity_manager.Register(g_capacity_engines[FENX_MAX_ENGINES]));
   RecordResult(15,"Engine Capacity 256",capacity_ok);

   CDataBus context_bus;
   long h1_value=0;
   long m15_value=0;
   const bool databus_ok=(context_bus.SetContextInt("Task026",h1_id,"Value",101) &&
      context_bus.SetContextInt("Task026",m15_id,"Value",115) &&
      context_bus.TryGetContextInt("Task026",h1_id,"Value",h1_value) &&
      context_bus.TryGetContextInt("Task026",m15_id,"Value",m15_value) &&
      h1_value==101 && m15_value==115 && context_bus.CurrentSize()==2);
   RecordResult(16,"DataBus Context Link",databus_ok);

   CCommonSnapshotStore snapshot_store;
   SVolatilitySnapshot h1_snapshot;
   SVolatilitySnapshot m15_snapshot;
   h1_snapshot.symbol=_Symbol;
   h1_snapshot.timeframe=EnumToString(PERIOD_H1);
   h1_snapshot.snapshot_version=FENX_COMMON_VOLATILITY_SNAPSHOT_VERSION;
   h1_snapshot.updated_at=TimeCurrent();
   h1_snapshot.volatility_score=61.0;
   m15_snapshot=h1_snapshot;
   m15_snapshot.timeframe=EnumToString(PERIOD_M15);
   m15_snapshot.volatility_score=15.0;
   SVolatilitySnapshot h1_read;
   SVolatilitySnapshot m15_read;
   const bool snapshot_ok=(snapshot_store.SetVolatilitySnapshot(h1_id.symbol,h1_id.timeframe,h1_snapshot) &&
      snapshot_store.SetVolatilitySnapshot(m15_id.symbol,m15_id.timeframe,m15_snapshot) &&
      snapshot_store.GetVolatilitySnapshot(h1_id.symbol,h1_id.timeframe,h1_read) &&
      snapshot_store.GetVolatilitySnapshot(m15_id.symbol,m15_id.timeframe,m15_read) &&
      h1_read.volatility_score==61.0 && m15_read.volatility_score==15.0 &&
      snapshot_store.VolatilitySnapshotCount()==2);
   RecordResult(17,"Snapshot Context Link",snapshot_ok);

   SRuntimeContextPreflight valid_preflight;
   const bool valid_preflight_ok=preflight_registry.EvaluatePreflight(
      parameters,availability,512,143,valid_preflight);
   SRuntimeContextPreflight databus_failure;
   SRuntimeContextPreflight engine_failure;
   SRuntimeContextConfig zero_primary_configs[];
   BuildFiveContexts(zero_primary_configs);
   zero_primary_configs[0].role=FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS;
   zero_primary_configs[0].trade_enabled=false;
   CParameterManager zero_primary_parameters;
   zero_primary_parameters.SetRuntimeContextConfigs(zero_primary_configs);
   SRuntimeContextPreflight zero_primary_failure;
   const bool zero_primary_rejected=
      (!preflight_registry.EvaluatePreflight(zero_primary_parameters,availability,
                                             512,143,zero_primary_failure) &&
       zero_primary_failure.failure_reason=="PRIMARY_COUNT");
   SRuntimeContextConfig multiple_primary_configs[];
   BuildFiveContexts(multiple_primary_configs);
   multiple_primary_configs[1].role=FENX_CONTEXT_ROLE_PRIMARY_TRADING;
   multiple_primary_configs[1].trade_enabled=true;
   CParameterManager multiple_primary_parameters;
   multiple_primary_parameters.SetRuntimeContextConfigs(multiple_primary_configs);
   SRuntimeContextPreflight multiple_primary_failure;
   const bool multiple_primary_rejected=
      (!preflight_registry.EvaluatePreflight(multiple_primary_parameters,availability,
                                             512,143,multiple_primary_failure) &&
       multiple_primary_failure.failure_reason=="PRIMARY_COUNT");
   const bool fail_closed_ok=(valid_preflight_ok && valid_preflight.accepted &&
      valid_preflight.context_count==5 && valid_preflight.primary_context_index==0 &&
      !preflight_registry.EvaluatePreflight(parameters,availability,2049,143,databus_failure) &&
      databus_failure.failure_reason=="DATABUS_CAPACITY" &&
      !preflight_registry.EvaluatePreflight(parameters,availability,512,257,engine_failure) &&
      engine_failure.failure_reason=="ENGINE_CAPACITY" &&
      duplicate_rejected && magic_rejected && required_rejected &&
      zero_primary_rejected && multiple_primary_rejected);
   RecordResult(18,"Fail-Closed Preflight",fail_closed_ok);

   return(INIT_SUCCEEDED);
  }

void OnTick(void)
  {
   if(g_bar_manager_ready)
      g_bar_manager.Update();
  }

double OnTester(void)
  {
   // A full tester interval proves the two registrations advance independently.
   g_results[14]=(g_results[14] && g_h1_bar_engine.UpdateCount()>0 &&
                  g_m15_bar_engine.UpdateCount()>g_h1_bar_engine.UpdateCount());
   int passed=0;
   for(int index=0;index<TASK026_TEST_COUNT;index++)
     {
      if(g_results[index]) passed++;
      PrintFormat("[TASK026 FINAL] %02d %s: %s",index+1,g_names[index],
                  (g_results[index] ? "PASS" : "FAIL"));
     }
   PrintFormat("[TASK026 SUMMARY] %d/%d PASS H1Bars=%d M15Bars=%d",
               passed,TASK026_TEST_COUNT,g_h1_bar_engine.UpdateCount(),
               g_m15_bar_engine.UpdateCount());
   return((passed==TASK026_TEST_COUNT) ? 1.0 : 0.0);
  }

void OnDeinit(const int reason)
  {
   if(g_bar_manager_ready)
      g_bar_manager.Shutdown();
  }
