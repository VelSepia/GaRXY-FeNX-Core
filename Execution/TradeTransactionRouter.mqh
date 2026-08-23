//+------------------------------------------------------------------+
//|                        Execution/TradeTransactionRouter.mqh     |
//+------------------------------------------------------------------+
#ifndef FENX_EXECUTION_TRADE_TRANSACTION_ROUTER_MQH
#define FENX_EXECUTION_TRADE_TRANSACTION_ROUTER_MQH

#include "../Common/Types.mqh"
#include "ExecutionEngine.mqh"
#include "PositionLifecycleRegistry.mqh"

//--- MT5-derived routing facts. Production fills these only from the current
//--- transaction/request and selected history records; the harness can supply
//--- the same value contract without creating a broker order.
struct STradeTransactionRouteFacts
  {
   string          symbol;
   long            magic;
   ulong           position_ticket;
   ulong           position_lifecycle_id;
   ulong           order_ticket;
   ulong           deal_ticket;
   ENUM_DEAL_ENTRY deal_entry;
   ENUM_DEAL_REASON deal_reason;
   bool            deal_entry_available;
   long            entry_evaluation_sequence;
   long            exit_evaluation_sequence;
   long            execution_sequence;
  };

void ResetTradeTransactionRouteFacts(STradeTransactionRouteFacts &facts)
  {
   facts.symbol="";
   facts.magic=0;
   facts.position_ticket=0;
   facts.position_lifecycle_id=0;
   facts.order_ticket=0;
   facts.deal_ticket=0;
   facts.deal_entry=DEAL_ENTRY_IN;
   facts.deal_reason=DEAL_REASON_EXPERT;
   facts.deal_entry_available=false;
   facts.entry_evaluation_sequence=0;
   facts.exit_evaluation_sequence=0;
   facts.execution_sequence=0;
  }

struct STradeTransactionRouteResult
  {
   bool              matched;
   bool              external;
   int               context_index;
   int               dispatch_count;
   string            matching_priority;
   SRuntimeContextId context_id;
   long              magic;
  };

void ResetTradeTransactionRouteResult(STradeTransactionRouteResult &result)
  {
   result.matched=false;
   result.external=true;
   result.context_index=-1;
   result.dispatch_count=0;
   result.matching_priority="UNOWNED";
   result.context_id.symbol="";
   result.context_id.timeframe=PERIOD_CURRENT;
   result.magic=0;
  }

//--- Resolves exactly one context before dispatch. It never broadcasts an MT5
//--- event. Stable priority is lifecycle ownership, then Symbol+Magic, then a
//--- known order/deal linkage retained by the lifecycle registry.
class CTradeTransactionRouter
  {
private:
   SRuntimeContextConfig m_routes[];
   CExecutionEngine     *m_observers[];
   CPositionLifecycleRegistry m_lifecycles;
   long                  m_received_count;
   long                  m_dispatched_count;
   long                  m_external_count;
   long                  m_wrong_dispatch_count;

   int               FindRoute(const SRuntimeContextId &context_id,
                               const long magic)
     {
      for(int index=0;index<ArraySize(m_routes);index++)
         if(RuntimeContextEquals(m_routes[index].id,context_id) &&
            m_routes[index].magic==magic)
            return(index);
      return(-1);
     }

   int               FindBySymbolMagic(const string symbol,const long magic)
     {
      if(StringLen(symbol)==0 || magic<=0)
         return(-1);
      for(int index=0;index<ArraySize(m_routes);index++)
         if(m_routes[index].id.symbol==symbol && m_routes[index].magic==magic)
            return(index);
      return(-1);
     }

   string            DealReasonName(const ENUM_DEAL_REASON reason)
     {
      if(reason==DEAL_REASON_EXPERT) return("EXPERT");
      if(reason==DEAL_REASON_SL) return("SL");
      if(reason==DEAL_REASON_TP) return("TP");
      return("EXTERNAL");
     }

   void              PopulateSequences(const int route_index,
                                       STradeTransactionRouteFacts &facts)
     {
      if(route_index<0 || route_index>=ArraySize(m_observers) ||
         m_observers[route_index]==NULL)
         return;
      if(facts.entry_evaluation_sequence<=0)
         facts.entry_evaluation_sequence=
            m_observers[route_index].EntryEvaluationSequence();
      if(facts.exit_evaluation_sequence<=0)
         facts.exit_evaluation_sequence=
            m_observers[route_index].ExitEvaluationSequence();
      if(facts.execution_sequence<=0)
         facts.execution_sequence=m_observers[route_index].ExecutionSequence();
     }

   void              ObserveLifecycle(const int route_index,
                                      STradeTransactionRouteFacts &facts)
     {
      if(route_index<0 || route_index>=ArraySize(m_routes) ||
         !facts.deal_entry_available || facts.deal_ticket==0)
         return;
      PopulateSequences(route_index,facts);
      const SRuntimeContextConfig config=m_routes[route_index];
      if(facts.deal_entry==DEAL_ENTRY_IN)
         m_lifecycles.ObserveOpen(config.id,config.magic,
            facts.position_ticket,facts.position_lifecycle_id,
            facts.order_ticket,facts.deal_ticket,
            facts.entry_evaluation_sequence,facts.execution_sequence,
            DealReasonName(facts.deal_reason));
      else if(facts.deal_entry==DEAL_ENTRY_OUT ||
              facts.deal_entry==DEAL_ENTRY_OUT_BY)
         m_lifecycles.ObserveClose(config.id,config.magic,
            facts.position_ticket,facts.position_lifecycle_id,
            facts.order_ticket,facts.deal_ticket,
            facts.exit_evaluation_sequence,facts.execution_sequence,
            DealReasonName(facts.deal_reason));
     }

   bool              ExtractFacts(const MqlTradeTransaction &transaction,
                                  const MqlTradeRequest &request,
                                  STradeTransactionRouteFacts &facts)
     {
      ResetTradeTransactionRouteFacts(facts);
      facts.symbol=transaction.symbol;
      facts.position_ticket=transaction.position;
      facts.position_lifecycle_id=transaction.position;
      facts.order_ticket=transaction.order;
      facts.deal_ticket=transaction.deal;

      if(transaction.deal>0 && HistoryDealSelect(transaction.deal))
        {
         facts.symbol=HistoryDealGetString(transaction.deal,DEAL_SYMBOL);
         facts.magic=HistoryDealGetInteger(transaction.deal,DEAL_MAGIC);
         facts.position_lifecycle_id=(ulong)
            HistoryDealGetInteger(transaction.deal,DEAL_POSITION_ID);
         facts.order_ticket=(ulong)
            HistoryDealGetInteger(transaction.deal,DEAL_ORDER);
         facts.deal_entry=(ENUM_DEAL_ENTRY)
            HistoryDealGetInteger(transaction.deal,DEAL_ENTRY);
         facts.deal_reason=(ENUM_DEAL_REASON)
            HistoryDealGetInteger(transaction.deal,DEAL_REASON);
         facts.deal_entry_available=true;
        }
      else if(transaction.order>0 && HistoryOrderSelect(transaction.order))
        {
         facts.symbol=HistoryOrderGetString(transaction.order,ORDER_SYMBOL);
         facts.magic=HistoryOrderGetInteger(transaction.order,ORDER_MAGIC);
        }

      // TRADE_TRANSACTION_REQUEST is the only event where request fields are
      // guaranteed. They are used solely when history/transaction omitted the
      // same identity and never override selected MT5 history facts.
      if(StringLen(facts.symbol)==0)
         facts.symbol=request.symbol;
      if(facts.magic<=0)
         facts.magic=(long)request.magic;
      if(facts.position_ticket==0)
         facts.position_ticket=request.position;
      return(StringLen(facts.symbol)>0 || facts.position_lifecycle_id>0 ||
             facts.order_ticket>0 || facts.deal_ticket>0);
     }

public:
                     CTradeTransactionRouter(void)
     {
      m_received_count=0;
      m_dispatched_count=0;
      m_external_count=0;
      m_wrong_dispatch_count=0;
     }

   bool              RegisterRoute(const SRuntimeContextConfig &config,
                                   CExecutionEngine &observer)
     {
      if(!IsValidRuntimeContextId(config.id) || config.magic<=0)
         return(false);
      for(int index=0;index<ArraySize(m_routes);index++)
        {
         if(RuntimeContextEquals(m_routes[index].id,config.id) ||
            (m_routes[index].id.symbol==config.id.symbol &&
             m_routes[index].magic==config.magic))
            return(false);
        }
      const int count=ArraySize(m_routes);
      if(ArrayResize(m_routes,count+1)!=(count+1) ||
         ArrayResize(m_observers,count+1)!=(count+1))
        {
         ArrayResize(m_routes,count);
         ArrayResize(m_observers,count);
         return(false);
        }
      m_routes[count]=config;
      m_observers[count]=GetPointer(observer);
      return(m_observers[count]!=NULL);
     }

   bool              Resolve(const STradeTransactionRouteFacts &facts,
                             STradeTransactionRouteResult &result)
     {
      ResetTradeTransactionRouteResult(result);
      SRuntimeContextId owner;
      owner.symbol="";
      owner.timeframe=PERIOD_CURRENT;
      long owner_magic=0;
      int route_index=-1;
      if(m_lifecycles.FindOwner(facts.position_lifecycle_id,
                                facts.position_ticket,owner,owner_magic))
        {
         route_index=FindRoute(owner,owner_magic);
         result.matching_priority="POSITION_LIFECYCLE";
        }
      if(route_index<0)
        {
         route_index=FindBySymbolMagic(facts.symbol,facts.magic);
         if(route_index>=0)
            result.matching_priority="SYMBOL_MAGIC";
        }
      if(route_index<0 &&
         m_lifecycles.FindOwnerByLink(facts.order_ticket,facts.deal_ticket,
                                      owner,owner_magic))
        {
         route_index=FindRoute(owner,owner_magic);
         result.matching_priority="ORDER_DEAL_LINK";
        }
      if(route_index<0)
         return(false);

      result.matched=true;
      result.external=false;
      result.context_index=route_index;
      result.dispatch_count=1;
      result.context_id=m_routes[route_index].id;
      result.magic=m_routes[route_index].magic;
      return(true);
     }

   //--- Harness-only routing uses the exact resolver/lifecycle path but never
   //--- calls an observer and therefore cannot reach CTrade or a broker.
   bool              RouteSynthetic(STradeTransactionRouteFacts &facts,
                                    STradeTransactionRouteResult &result)
     {
      m_received_count++;
      if(!Resolve(facts,result))
        {
         m_external_count++;
         return(false);
        }
      m_dispatched_count++;
      ObserveLifecycle(result.context_index,facts);
      return(true);
     }

   bool              Route(const MqlTradeTransaction &transaction,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &trade_result)
     {
      m_received_count++;
      STradeTransactionRouteFacts facts;
      if(!ExtractFacts(transaction,request,facts))
        {
         m_external_count++;
         return(false);
        }
      STradeTransactionRouteResult route;
      if(!Resolve(facts,route))
        {
         m_external_count++;
         return(false);
        }
      if(route.dispatch_count!=1 || route.context_index<0 ||
         route.context_index>=ArraySize(m_observers) ||
         m_observers[route.context_index]==NULL)
        {
         m_wrong_dispatch_count++;
         return(false);
        }
      m_observers[route.context_index].ObserveTradeTransaction(transaction);
      m_dispatched_count++;
      ObserveLifecycle(route.context_index,facts);
      return(true);
     }

   int               RouteCount(void) { return(ArraySize(m_routes)); }
   long              ReceivedCount(void) { return(m_received_count); }
   long              DispatchedCount(void) { return(m_dispatched_count); }
   long              ExternalCount(void) { return(m_external_count); }
   long              WrongDispatchCount(void) { return(m_wrong_dispatch_count); }
   CPositionLifecycleRegistry *Lifecycles(void)
     {
      return(GetPointer(m_lifecycles));
     }

   void              Clear(void)
     {
      ArrayResize(m_routes,0);
      ArrayResize(m_observers,0);
      m_lifecycles.Clear();
      m_received_count=0;
      m_dispatched_count=0;
      m_external_count=0;
      m_wrong_dispatch_count=0;
     }
  };

#endif // FENX_EXECUTION_TRADE_TRANSACTION_ROUTER_MQH
