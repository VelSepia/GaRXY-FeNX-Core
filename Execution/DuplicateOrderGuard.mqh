//+------------------------------------------------------------------+
//|                            Execution/DuplicateOrderGuard.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_EXECUTION_DUPLICATE_ORDER_GUARD_MQH
#define FENX_EXECUTION_DUPLICATE_ORDER_GUARD_MQH

#include "OrderRequest.mqh"

//--- Prevents multiple attempts from the same completed-bar signal.
class CDuplicateOrderGuard
  {
private:
   string   m_last_symbol;
   long     m_last_magic_number;
   int      m_last_direction;
   datetime m_last_bar_time;
   double   m_last_price;
   string   m_last_request_identifier;
   datetime m_last_attempt_at;
   int      m_cooldown_seconds;
   bool     m_one_order_per_bar;

public:
                     CDuplicateOrderGuard(void)
     {
      m_last_symbol="";
      m_last_magic_number=0;
      m_last_direction=-1;
      m_last_bar_time=0;
      m_last_price=0.0;
      m_last_request_identifier="";
      m_last_attempt_at=0;
      m_cooldown_seconds=0;
      m_one_order_per_bar=true;
     }

   void              Configure(const int cooldown_seconds,const bool one_order_per_bar)
     {
      m_cooldown_seconds=MathMax(0,cooldown_seconds);
      m_one_order_per_bar=one_order_per_bar;
     }

   bool              IsBlocked(const SOrderRequest &request,const double price_tolerance,
                               string &reason)
     {
      if(m_last_attempt_at>0 && m_cooldown_seconds>0 &&
         (long)(TimeCurrent()-m_last_attempt_at)<m_cooldown_seconds)
        {
         reason="Execution cooldown is active.";
         return(true);
        }
      if(m_one_order_per_bar && request.symbol==m_last_symbol &&
         request.magic_number==m_last_magic_number &&
         (int)request.direction==m_last_direction &&
         request.signal_bar_time==m_last_bar_time)
        {
         reason="A request for this direction was already attempted on the completed bar.";
         return(true);
        }
      if(request.symbol==m_last_symbol && request.magic_number==m_last_magic_number &&
         (int)request.direction==m_last_direction &&
         request.request_identifier==m_last_request_identifier &&
         MathAbs(request.entry_price-m_last_price)<=price_tolerance)
        {
         reason="A nearly identical request already exists.";
         return(true);
        }
      reason="";
      return(false);
     }

   void              MarkAttempt(const SOrderRequest &request)
     {
      m_last_symbol=request.symbol;
      m_last_magic_number=request.magic_number;
      m_last_direction=(int)request.direction;
      m_last_bar_time=request.signal_bar_time;
      m_last_price=request.entry_price;
      m_last_request_identifier=request.request_identifier;
      m_last_attempt_at=TimeCurrent();
     }

   void              Reset(void)
     {
      m_last_symbol="";
      m_last_magic_number=0;
      m_last_direction=-1;
      m_last_bar_time=0;
      m_last_price=0.0;
      m_last_request_identifier="";
      m_last_attempt_at=0;
     }
  };

#endif // FENX_EXECUTION_DUPLICATE_ORDER_GUARD_MQH
