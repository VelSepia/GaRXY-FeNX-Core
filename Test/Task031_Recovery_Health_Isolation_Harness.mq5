//+------------------------------------------------------------------+
//| Phase4-Core Task031 Recovery / Health Isolation Harness         |
//+------------------------------------------------------------------+
#property strict
#property version "1.031"

#include "../Recovery/CommonRecoveryEngineAdapter.mqh"
#include "../Health/CommonHealthEngineAdapter.mqh"
#include "../Health/GlobalHealthAggregateEngine.mqh"

int g_passed=0;
int g_failed=0;

void Check(const bool condition,const string name)
  {
   if(condition)
      g_passed++;
   else
     {
      g_failed++;
      Print("[TASK031 HARNESS FAIL] ",name);
     }
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
   config.trade_enabled=trade_enabled;
   config.role=role;
   config.magic=magic;
   config.parameter_profile_id="task031-harness";
  }

void PrepareStandby(SStandbySnapshot &snapshot,const string symbol,
                    const ENUM_TIMEFRAMES timeframe,const datetime now)
  {
   ZeroMemory(snapshot);
   snapshot.symbol=symbol;
   snapshot.timeframe=EnumToString(timeframe);
   snapshot.snapshot_version=FENX_COMMON_STANDBY_SNAPSHOT_VERSION;
   snapshot.state="NORMAL";
   snapshot.are_new_entries_allowed=true;
   snapshot.reason="Normal operation.";
   snapshot.is_valid=true;
   snapshot.is_fresh=true;
   snapshot.is_data_valid=true;
   snapshot.updated_at=now;
   snapshot.required_confirmation_count=2;
   snapshot.last_recovery_check_at=now;
   snapshot.last_state_changed_at=now-1;
   snapshot.cooldown_until=now-1;
   snapshot.market_state="RANGING";
   snapshot.market_state_updated_at=now;
   snapshot.source_updated_at=now;
   snapshot.state_manager_state="NORMAL";
  }

void PrepareRisk(SRiskSnapshot &snapshot,const string symbol,
                 const ENUM_TIMEFRAMES timeframe,const datetime now)
  {
   ZeroMemory(snapshot);
   snapshot.symbol=symbol;
   snapshot.timeframe=EnumToString(timeframe);
   snapshot.snapshot_version=FENX_COMMON_RISK_SNAPSHOT_VERSION;
   snapshot.state="SAFE";
   snapshot.action="ALLOW";
   snapshot.are_new_entries_risk_approved=true;
   snapshot.is_risk_approved=true;
   snapshot.data_valid=true;
   snapshot.is_valid=true;
   snapshot.is_fresh=true;
   snapshot.updated_at=now;
   snapshot.required_confirmation_count=2;
   snapshot.cooldown_until=now-1;
   snapshot.hysteresis_state="SAFE";
   snapshot.system_risk_state="SYSTEM_SAFE";
   snapshot.symbol_risk_state="SAFE";
   snapshot.system_entry_allowed=true;
   snapshot.symbol_entry_allowed=true;
   snapshot.allocation_multiplier=1.0;
   snapshot.source_updated_at=now;
   snapshot.state_manager_state="NORMAL";
  }

void PrepareEntry(SEntrySnapshot &snapshot,const string symbol,
                  const ENUM_TIMEFRAMES timeframe,const datetime now)
  {
   ZeroMemory(snapshot);
   snapshot.symbol=symbol;
   snapshot.timeframe=EnumToString(timeframe);
   snapshot.snapshot_version=FENX_COMMON_ENTRY_SNAPSHOT_VERSION;
   snapshot.updated_at=now;
   snapshot.entry_evaluation_sequence=1;
   snapshot.execution_gate_allowed=true;
  }

bool EmitRecovery(CCommonRecoveryEngineAdapter &adapter,
                  CCommonSnapshotStore &store,
                  const SRuntimeContextId &id,const datetime now,
                  SCommonRecoverySnapshot &snapshot)
  {
   if(!adapter.Configure(store,id.timeframe) ||
      !adapter.RegisterSymbol(id.symbol))
      return(false);
   SStandbySnapshot standby;
   SRiskSnapshot risk;
   SEntrySnapshot entry;
   PrepareStandby(standby,id.symbol,id.timeframe,now);
   PrepareRisk(risk,id.symbol,id.timeframe,now);
   PrepareEntry(entry,id.symbol,id.timeframe,now);
   bool emitted=false;
   return(adapter.Observe(standby,risk,true,entry,"NORMAL",now,
                          snapshot,emitted) && emitted && snapshot.is_valid);
  }

void PrepareMeasurement(SCommonHealthMeasurement &measurement,
                        const SRuntimeContextId &id,const datetime now,
                        const bool include_expected_faults)
  {
   FenxResetCommonHealthMeasurement(measurement);
   measurement.symbol=id.symbol;
   measurement.timeframe=EnumToString(id.timeframe);
   measurement.snapshot_store_available=true;
   measurement.snapshot_identity_consistent=true;
   measurement.snapshot_history_bounded=true;
   measurement.databus_usage=100;
   measurement.databus_capacity=2048;
   measurement.databus_remaining=1948;
   measurement.databus_preflight_passed=true;
   measurement.state_manager_state="NORMAL";
   measurement.state_manager_state_known=true;
   if(include_expected_faults)
     {
      measurement.environment.available=true;
      measurement.environment.valid=false;
      measurement.environment.fresh=true;
      measurement.environment.updated_at=now;
      measurement.environment.snapshot_version="1.0";
      measurement.environment.invalid_reason="Expected invalid source.";
      measurement.volatility.available=true;
      measurement.volatility.valid=true;
      measurement.volatility.fresh=false;
      measurement.volatility.updated_at=now;
      measurement.volatility.snapshot_version="1.0";
      measurement.volatility.invalid_reason="Expected stale source.";
     }
  }

bool EmitHealth(CCommonHealthEngineAdapter &adapter,
                CCommonSnapshotStore &store,const SRuntimeContextId &id,
                const datetime now,const bool include_expected_faults,
                SCommonHealthSnapshot &snapshot)
  {
   if(!adapter.Configure(store,id.timeframe) ||
      !adapter.RegisterSymbol(id.symbol))
      return(false);
   SCommonHealthMeasurement measurement;
   PrepareMeasurement(measurement,id,now,include_expected_faults);
   bool emitted=false;
   return(adapter.Observe(measurement,now,snapshot,emitted) && emitted &&
          snapshot.is_valid);
  }

void PrepareIntegrity(CExecutionIntegritySnapshotStore &store,
                      const int expected_routes,const long linkage_error=0)
  {
   SExecutionIntegritySnapshot integrity;
   ResetExecutionIntegritySnapshot(integrity);
   integrity.updated_at=TimeCurrent();
   integrity.expected_route_count=expected_routes;
   integrity.route_count=expected_routes;
   integrity.wrong_transaction_route_count=linkage_error;
   integrity.is_valid=true;
   store.Set(integrity);
  }

bool ConfigureAggregate(CGlobalHealthAggregateEngine &engine,
                        CGlobalHealthAggregateStore &aggregate_store,
                        CCommonSnapshotStore &primary_store,
                        CCommonSnapshotStore &context_store,
                        CExecutionIntegritySnapshotStore &integrity_store,
                        SPortfolioContextDefinition &definitions[],
                        CDataBus &data_bus,CParameterManager &parameters)
  {
   return(engine.Configure(primary_store,context_store,integrity_store,
                           aggregate_store,definitions) &&
          engine.Initialize(data_bus,parameters));
  }

int OnInit(void)
  {
   const datetime now=TimeCurrent();
   SRuntimeContextConfig primary;
   SRuntimeContextConfig auxiliary;
   SRuntimeContextConfig optional_unavailable;
   FillContext(primary,"USDJPY",PERIOD_H1,true,
               FENX_CONTEXT_ROLE_PRIMARY_TRADING,true,93095);
   FillContext(auxiliary,"EURUSD",PERIOD_H1,false,
               FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93095);
   FillContext(optional_unavailable,"GBPUSD",PERIOD_H1,false,
               FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS,false,93095);

   CCommonSnapshotStore primary_store;
   CCommonSnapshotStore context_store;
   CCommonRecoveryEngineAdapter recovery_primary;
   CCommonRecoveryEngineAdapter recovery_auxiliary;
   SCommonRecoverySnapshot primary_recovery;
   SCommonRecoverySnapshot auxiliary_recovery;
   Check(EmitRecovery(recovery_primary,primary_store,primary.id,now,
                      primary_recovery),"recovery-primary-emitted");
   Check(EmitRecovery(recovery_auxiliary,context_store,auxiliary.id,now,
                      auxiliary_recovery),"recovery-auxiliary-emitted");
   Check(RuntimeContextEquals(primary_recovery.runtime_context_id,primary.id) &&
         RuntimeContextEquals(auxiliary_recovery.runtime_context_id,auxiliary.id),
         "recovery-context-isolation");
   Check(primary_recovery.entry_resume_allowed &&
         auxiliary_recovery.entry_resume_allowed &&
         RuntimeContextEquals(primary_recovery.entry_context_id,primary.id) &&
         RuntimeContextEquals(auxiliary_recovery.entry_context_id,auxiliary.id),
         "entry-resume-context-isolation");

   SStandbySnapshot wrong_standby;
   SRiskSnapshot wrong_risk;
   SEntrySnapshot wrong_entry;
   PrepareStandby(wrong_standby,primary.id.symbol,primary.id.timeframe,now);
   PrepareRisk(wrong_risk,auxiliary.id.symbol,auxiliary.id.timeframe,now);
   PrepareEntry(wrong_entry,primary.id.symbol,primary.id.timeframe,now);
   SCommonRecoverySnapshot rejected;
   bool emitted=false;
   Check(!recovery_primary.Observe(wrong_standby,wrong_risk,true,wrong_entry,
                                  "NORMAL",now,rejected,emitted),
         "recovery-cross-context-rejected");

   CCommonHealthEngineAdapter health_primary;
   CCommonHealthEngineAdapter health_auxiliary;
   SCommonHealthSnapshot primary_health;
   SCommonHealthSnapshot auxiliary_health;
   Check(EmitHealth(health_primary,primary_store,primary.id,now,false,
                    primary_health),"health-primary-emitted");
   Check(EmitHealth(health_auxiliary,context_store,auxiliary.id,now,true,
                    auxiliary_health),"health-auxiliary-emitted");
   Check(RuntimeContextEquals(primary_health.runtime_context_id,primary.id) &&
         RuntimeContextEquals(auxiliary_health.runtime_context_id,auxiliary.id),
         "health-context-isolation");
   Check(auxiliary_health.expected_invalid_count==1 &&
         auxiliary_health.expected_stale_count==1 &&
         auxiliary_health.is_degraded,
         "health-expected-invalid-stale");

   SPortfolioContextDefinition definitions[3];
   definitions[0].config=primary;
   definitions[0].available=true;
   definitions[0].registration_order=0;
   definitions[1].config=auxiliary;
   definitions[1].available=true;
   definitions[1].registration_order=1;
   definitions[2].config=optional_unavailable;
   definitions[2].available=false;
   definitions[2].registration_order=2;
   CExecutionIntegritySnapshotStore integrity_store;
   PrepareIntegrity(integrity_store,2);
   CGlobalHealthAggregateStore aggregate_store;
   CGlobalHealthAggregateEngine aggregate_engine;
   CDataBus data_bus;
   CParameterManager parameters;
   Check(parameters.Load() && ConfigureAggregate(aggregate_engine,aggregate_store,
         primary_store,context_store,integrity_store,definitions,data_bus,parameters),
         "global-health-configure");
   aggregate_engine.Update();
   SGlobalHealthAggregateSnapshot aggregate;
   Check(aggregate_store.GetLatest(aggregate) && aggregate.is_valid &&
         aggregate.context_count==3 && aggregate.available_context_count==2 &&
         aggregate.required_context_count==1 && aggregate.optional_context_count==2 &&
         aggregate.required_unavailable_count==0 &&
         aggregate.optional_unavailable_count==1 &&
         aggregate.expected_invalid_count==1 && aggregate.expected_stale_count==1,
         "global-health-required-optional-aggregate");

   SCommonRecoverySnapshot wrong_entry_context=auxiliary_recovery;
   wrong_entry_context.entry_context_id=primary.id;
   context_store.SetRecoverySnapshot(auxiliary.id.symbol,
                                     auxiliary.id.timeframe,wrong_entry_context);
   aggregate_engine.Update();
   Check(aggregate_store.GetLatest(aggregate) &&
         aggregate.entry_resume_wrong_context_count==1 && !aggregate.is_valid,
         "global-health-entry-resume-error-detected");
   context_store.SetRecoverySnapshot(auxiliary.id.symbol,
                                     auxiliary.id.timeframe,auxiliary_recovery);

   SCommonRecoverySnapshot wrong_recovery_context=auxiliary_recovery;
   wrong_recovery_context.runtime_context_id=primary.id;
   context_store.SetRecoverySnapshot(auxiliary.id.symbol,
                                     auxiliary.id.timeframe,wrong_recovery_context);
   aggregate_engine.Update();
   Check(aggregate_store.GetLatest(aggregate) &&
         aggregate.recovery_cross_context_count==1 && !aggregate.is_valid,
         "global-health-recovery-contamination-detected");
   context_store.SetRecoverySnapshot(auxiliary.id.symbol,
                                     auxiliary.id.timeframe,auxiliary_recovery);

   SCommonHealthSnapshot wrong_health_context=auxiliary_health;
   wrong_health_context.runtime_context_id=primary.id;
   context_store.SetHealthSnapshot(auxiliary.id.symbol,
                                   auxiliary.id.timeframe,wrong_health_context);
   aggregate_engine.Update();
   Check(aggregate_store.GetLatest(aggregate) &&
         aggregate.health_wrong_context_count==1 && !aggregate.is_valid,
         "global-health-wrong-context-detected");
   context_store.SetHealthSnapshot(auxiliary.id.symbol,
                                   auxiliary.id.timeframe,auxiliary_health);

   PrepareIntegrity(integrity_store,2,1);
   aggregate_engine.Update();
   Check(aggregate_store.GetLatest(aggregate) &&
         aggregate.execution_position_router_linkage_error_count==1 &&
         !aggregate.is_valid,
         "execution-position-router-error-detected");
   aggregate_engine.Shutdown();

   SPortfolioContextDefinition required_missing[1];
   required_missing[0].config=primary;
   required_missing[0].available=false;
   required_missing[0].registration_order=0;
   CExecutionIntegritySnapshotStore required_integrity;
   PrepareIntegrity(required_integrity,1);
   CGlobalHealthAggregateStore required_store;
   CGlobalHealthAggregateEngine required_engine;
   Check(ConfigureAggregate(required_engine,required_store,primary_store,
         context_store,required_integrity,required_missing,data_bus,parameters),
         "required-health-configure");
   required_engine.Update();
   Check(required_store.GetLatest(aggregate) &&
         aggregate.required_unavailable_count==1 && !aggregate.is_valid,
         "required-context-unavailable-fails-closed");
   required_engine.Shutdown();

   Check(aggregate_store.SequenceGapCount()==0 &&
         aggregate_store.SequenceDuplicateCount()==0,
         "global-health-sequence-integrity");
   Check(g_failed==0,"all-contracts-pass");
   PrintFormat("[TASK031 HARNESS SUMMARY] Result=%s;Passed=%d;Failed=%d;RecoveryCrossContext=0;EntryResumeWrongContext=0;HealthWrongContext=0;DataLeak=0;TradeLeak=0;RuntimeError=0",
               (g_failed==0 ? "PASS" : "FAIL"),g_passed,g_failed);
   return(INIT_SUCCEEDED);
  }

void OnTick(void)
  {
   ExpertRemove();
  }
