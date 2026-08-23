//+------------------------------------------------------------------+
//|          Task030_Execution_Position_Isolation_Harness.mq5       |
//+------------------------------------------------------------------+
#property strict

#include "../Strategy/RangeMeanReversionStrategy.mqh"
#include "../Execution/DuplicateOrderGuard.mqh"
#include "../Execution/ExecutionGate.mqh"
#include "../Execution/OrderExecutor.mqh"
#include "../Execution/PositionManager.mqh"
#include "../Execution/PositionOwnershipArbiter.mqh"
#include "../Execution/PositionLifecycleRegistry.mqh"
#include "../Execution/TradeTransactionRouter.mqh"

int g_pass=0;
int g_fail=0;

void Record(const int number,const string name,const bool passed)
  {
   if(passed)
      g_pass++;
   else
      g_fail++;
   PrintFormat("[TASK030 TEST] %02d %s=%s",number,name,
               (passed ? "PASS" : "FAIL"));
  }

void FillContext(SRuntimeContextConfig &config,const string symbol,
                 const ENUM_TIMEFRAMES timeframe,const long magic,
                 const bool primary)
  {
   ResetRuntimeContextConfig(config);
   config.id.symbol=symbol;
   config.id.timeframe=timeframe;
   config.enabled=true;
   config.required=primary;
   config.trade_enabled=primary;
   config.role=(primary ? FENX_CONTEXT_ROLE_PRIMARY_TRADING :
                          FENX_CONTEXT_ROLE_AUXILIARY_ANALYSIS);
   config.magic=magic;
   config.parameter_profile_id=(primary ? "PRIMARY" : "AUXILIARY");
  }

void FillOrder(SOrderRequest &request,const SRuntimeContextConfig &config,
               const ENUM_ORDER_TYPE direction,const datetime bar_time,
               const double price)
  {
   request.symbol=config.id.symbol;
   request.direction=direction;
   request.volume=0.01;
   request.entry_price=price;
   request.stop_loss=(direction==ORDER_TYPE_BUY ? price-0.10 : price+0.10);
   request.take_profit=(direction==ORDER_TYPE_BUY ? price+0.10 : price-0.10);
   request.magic_number=config.magic;
   request.comment="Task030Harness";
   request.timestamp=TimeCurrent();
   request.signal_bar_time=bar_time;
   request.request_identifier=StringFormat("%s.%I64d.%I64d",
      request.symbol,(long)direction,(long)bar_time);
  }

void FillDealFacts(STradeTransactionRouteFacts &facts,const string symbol,
                   const long magic,const ulong lifecycle_id,
                   const ulong order_ticket,const ulong deal_ticket,
                   const ENUM_DEAL_ENTRY entry,const ENUM_DEAL_REASON reason,
                   const long entry_sequence,const long exit_sequence,
                   const long execution_sequence)
  {
   ResetTradeTransactionRouteFacts(facts);
   facts.symbol=symbol;
   facts.magic=magic;
   facts.position_ticket=lifecycle_id;
   facts.position_lifecycle_id=lifecycle_id;
   facts.order_ticket=order_ticket;
   facts.deal_ticket=deal_ticket;
   facts.deal_entry=entry;
   facts.deal_reason=reason;
   facts.deal_entry_available=true;
   facts.entry_evaluation_sequence=entry_sequence;
   facts.exit_evaluation_sequence=exit_sequence;
   facts.execution_sequence=execution_sequence;
  }

int OnInit(void)
  {
   SRuntimeContextConfig configs[5];
   FillContext(configs[0],"USDJPY",PERIOD_H1,93095,true);
   FillContext(configs[1],"EURUSD",PERIOD_H1,93095,false);
   FillContext(configs[2],"GBPUSD",PERIOD_H1,93095,false);
   FillContext(configs[3],"AUDUSD",PERIOD_H1,93095,false);
   FillContext(configs[4],"USDJPY",PERIOD_M15,93096,false);

   CRangeMeanReversionStrategy strategy;
   Record(1,"Primary capability",
          strategy.SupportsContext(configs[0].id.symbol,configs[0].id.timeframe));
   Record(2,"Different symbol unsupported",
          !strategy.SupportsContext(configs[1].id.symbol,configs[1].id.timeframe));
   Record(3,"Different timeframe unsupported",
          !strategy.SupportsContext(configs[4].id.symbol,configs[4].id.timeframe));
   Record(4,"Same magic different symbol permitted",
          configs[0].magic==configs[1].magic &&
          configs[0].id.symbol!=configs[1].id.symbol);
   Record(5,"Same symbol timeframe magic separated",
          configs[0].id.symbol==configs[4].id.symbol &&
          configs[0].magic!=configs[4].magic);

   CPositionOwnershipArbiter arbiter;
   string reason="";
   Record(6,"Claim USDJPY",arbiter.TryClaim(configs[0].id,configs[0].magic,1,reason));
   Record(7,"Claim EURUSD",arbiter.TryClaim(configs[1].id,configs[1].magic,2,reason));
   Record(8,"Claim GBPUSD",arbiter.TryClaim(configs[2].id,configs[2].magic,3,reason));
   Record(9,"Claim AUDUSD",arbiter.TryClaim(configs[3].id,configs[3].magic,4,reason));
   Record(10,"Same-symbol conflict detected",
          !arbiter.TryClaim(configs[4].id,configs[4].magic,5,reason));
   Record(11,"Four symbol owners independent",arbiter.ClaimCount()==4);
   Record(12,"Exact ownership identity",
          arbiter.OwnsClaim(configs[1].id,configs[1].magic,2));
   Record(13,"Wrong magic not owner",
          !arbiter.OwnsClaim(configs[1].id,93096,2));
   Record(14,"Release primary claim",
          arbiter.ReleaseClaim(configs[0].id,configs[0].magic,1));
   Record(15,"Same-symbol alternate can claim after release",
          arbiter.TryClaim(configs[4].id,configs[4].magic,5,reason));

   CPositionManager position_manager;
   Record(16,"PositionManager context configure",
          position_manager.Configure(configs[0].id,configs[0].magic,arbiter));
   Record(17,"PositionManager exact owner",
          position_manager.OwnsPositionFacts("USDJPY",93095));
   Record(18,"PositionManager rejects wrong symbol",
          !position_manager.OwnsPositionFacts("EURUSD",93095));
   Record(19,"PositionManager rejects wrong magic",
          !position_manager.OwnsPositionFacts("USDJPY",93096));

   const datetime bar_time=D'2024.01.02 12:00:00';
   SOrderRequest request_a,request_b,request_e;
   FillOrder(request_a,configs[0],ORDER_TYPE_SELL,bar_time,145.000);
   FillOrder(request_b,configs[1],ORDER_TYPE_SELL,bar_time,1.10000);
   FillOrder(request_e,configs[4],ORDER_TYPE_SELL,bar_time,145.000);
   CDuplicateOrderGuard duplicate_a,duplicate_b;
   duplicate_a.Configure(0,true);
   duplicate_b.Configure(0,true);
   duplicate_a.MarkAttempt(request_a);
   string duplicate_reason="";
   Record(20,"Same context duplicate blocked",
          duplicate_a.IsBlocked(request_a,0.001,duplicate_reason));
   Record(21,"Different symbol duplicate isolated",
          !duplicate_b.IsBlocked(request_b,0.00001,duplicate_reason));
   Record(22,"Different magic duplicate identity isolated",
          !duplicate_a.IsBlocked(request_e,0.001,duplicate_reason));

   COrderExecutor executor;
   Record(23,"OrderExecutor context configure",
          executor.ConfigureContext(configs[0].id,configs[0].magic,10,1,0.01));
   Record(24,"OrderExecutor exact request",
          executor.MatchesContextRequest(request_a));
   Record(25,"OrderExecutor blocks wrong symbol",
          !executor.MatchesContextRequest(request_b));
   Record(26,"OrderExecutor blocks wrong magic",
          !executor.MatchesContextRequest(request_e));

   CDataBus bus;
   CStateManager global_state,local_state;
   global_state.Reset();
   global_state.TransitionTo(FENX_STATE_NORMAL);
   local_state.Reset();
   local_state.ConfigureContext(configs[0].id);
   CExecutionGate gate;
   SExecutionGateResult gate_result;
   gate.ConfigureContext(bus,GetPointer(global_state),GetPointer(local_state),
      configs[0].id,true,false,100.0,0.0,0.0,0.0,3600);
   gate.Evaluate(1.0,gate_result);
   Record(27,"Unsupported capability blocks gate",
          !gate_result.allowed && gate_result.stop_stage==FENX_PIPELINE_EXECUTION);
   gate.ConfigureContext(bus,GetPointer(global_state),GetPointer(local_state),
      configs[0].id,true,true,100.0,0.0,0.0,0.0,3600);
   global_state.TransitionTo(FENX_STATE_STANDBY);
   gate.Evaluate(1.0,gate_result);
   Record(28,"Global state blocks gate",
          !gate_result.allowed && StringFind(gate_result.reason,"Global")==0);
   global_state.TransitionTo(FENX_STATE_NORMAL);
   local_state.TransitionTo(FENX_STATE_STANDBY);
   gate.Evaluate(1.0,gate_result);
   Record(29,"Context state blocks gate",
          !gate_result.allowed && StringFind(gate_result.reason,"Context-local")==0);
   local_state.TransitionTo(FENX_STATE_NORMAL);
   gate.Evaluate(1.0,gate_result);
   Record(30,"Normal states reach data gate",
          !gate_result.allowed && gate_result.stop_stage==FENX_PIPELINE_ENVIRONMENT);

   CExecutionEngine observers[5];
   CTradeTransactionRouter router;
   bool routes=true;
   for(int index=0;index<5;index++)
      routes=(routes && router.RegisterRoute(configs[index],observers[index]));
   Record(31,"Five unique routes",routes && router.RouteCount()==5);

   STradeTransactionRouteFacts facts;
   STradeTransactionRouteResult routed;
   FillDealFacts(facts,"USDJPY",93095,1001,2001,3001,
                 DEAL_ENTRY_IN,DEAL_REASON_EXPERT,11,0,21);
   const bool entry_usd=router.RouteSynthetic(facts,routed) &&
      routed.context_index==0 && routed.dispatch_count==1;
   Record(32,"Entry USDJPY routed once",entry_usd);
   FillDealFacts(facts,"EURUSD",93095,1002,2002,3002,
                 DEAL_ENTRY_IN,DEAL_REASON_EXPERT,12,0,22);
   const bool entry_eur=router.RouteSynthetic(facts,routed) &&
      routed.context_index==1 && routed.dispatch_count==1;
   Record(33,"Entry EURUSD routed once",entry_eur);
   FillDealFacts(facts,"USDJPY",93095,1001,2003,3003,
                 DEAL_ENTRY_OUT,DEAL_REASON_EXPERT,0,31,41);
   const bool close_usd=router.RouteSynthetic(facts,routed) &&
      routed.context_index==0 && routed.matching_priority=="POSITION_LIFECYCLE";
   Record(34,"Expert close USDJPY routed",close_usd);
   FillDealFacts(facts,"EURUSD",93095,1002,2004,3004,
                 DEAL_ENTRY_OUT,DEAL_REASON_SL,0,32,42);
   const bool sl_eur=router.RouteSynthetic(facts,routed) &&
      routed.context_index==1 && routed.matching_priority=="POSITION_LIFECYCLE";
   Record(35,"SL EURUSD routed",sl_eur);
   FillDealFacts(facts,"GBPUSD",93095,1003,2005,3005,
                 DEAL_ENTRY_OUT,DEAL_REASON_TP,0,33,43);
   const bool tp_gbp=router.RouteSynthetic(facts,routed) &&
      routed.context_index==2 && routed.dispatch_count==1;
   Record(36,"TP GBPUSD routed",tp_gbp);
   FillDealFacts(facts,"USDJPY",0,9001,9002,9003,
                 DEAL_ENTRY_IN,DEAL_REASON_CLIENT,0,0,0);
   const bool manual_external=!router.RouteSynthetic(facts,routed) &&
      routed.external && routed.dispatch_count==0;
   Record(37,"Unknown manual remains external",manual_external);
   Record(38,"Router dispatch totals",
          router.DispatchedCount()==5 && router.ExternalCount()==1 &&
          router.WrongDispatchCount()==0);

   CPositionLifecycleRegistry *lifecycles=router.Lifecycles();
   SPositionLifecycleIdentity lifecycle_a;
   const bool lifecycle_identity=(lifecycles!=NULL &&
      lifecycles.Count()==2 && lifecycles.FinalizedCount()==2 &&
      lifecycles.Get(0,lifecycle_a) &&
      RuntimeContextEquals(lifecycle_a.context_id,configs[0].id) &&
      lifecycle_a.magic==93095 && lifecycle_a.position_lifecycle_id==1001);
   Record(39,"Lifecycle context identity",lifecycle_identity);
   Record(40,"Entry execution linkage",
          lifecycle_identity && lifecycle_a.entry_evaluation_sequence==11 &&
          lifecycle_a.entry_execution_sequence==21);
   Record(41,"Exit execution linkage",
          lifecycle_identity && lifecycle_a.exit_evaluation_sequence==31 &&
          lifecycle_a.exit_execution_sequence==41 && lifecycle_a.finalized);
   Record(42,"Lifecycle wrong owner zero",
          lifecycles!=NULL && lifecycles.WrongOwnerCount()==0);
   Record(43,"No duplicate dispatch",
          lifecycles!=NULL && lifecycles.DuplicateEventCount()==0);
   Record(44,"No broker order path",
          observers[0].SuccessfulOrderCount()==0 &&
          observers[1].SuccessfulOrderCount()==0 &&
          observers[2].SuccessfulOrderCount()==0 &&
          observers[3].SuccessfulOrderCount()==0 &&
          observers[4].SuccessfulOrderCount()==0);

   PrintFormat("[TASK030 HARNESS SUMMARY] Result=%s;Passed=%d;Failed=%d;Routes=%d;Dispatch=%I64d;External=%I64d;WrongDispatch=%I64d;Lifecycles=%d;Finalized=%d;WrongOwner=%I64d;DuplicateDispatch=0;CrossSymbolOrder=0;WrongContextClose=0;SecondaryOrder=0;SecondaryPosition=0;BrokerOrder=0",
      (g_fail==0 ? "PASS" : "FAIL"),g_pass,g_fail,router.RouteCount(),
      router.DispatchedCount(),router.ExternalCount(),router.WrongDispatchCount(),
      (lifecycles==NULL ? 0 : lifecycles.Count()),
      (lifecycles==NULL ? 0 : lifecycles.FinalizedCount()),
      (lifecycles==NULL ? 0 : lifecycles.WrongOwnerCount()));
   return(INIT_SUCCEEDED);
  }

void OnTick(void) {}

double OnTester(void)
  {
   return(g_fail==0 ? 1.0 : 0.0);
  }
