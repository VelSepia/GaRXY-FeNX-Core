//+------------------------------------------------------------------+
//|                                Execution/PositionManager.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_EXECUTION_POSITION_MANAGER_MQH
#define FENX_EXECUTION_POSITION_MANAGER_MQH

#include "../Common/Types.mqh"
#include "PositionOwnershipArbiter.mqh"

//--- Identifies and reports FeNX positions without sending trade requests.
class CPositionManager
  {
private:
   string m_symbol;
   SRuntimeContextId m_context_id;
   long   m_magic_number;
   CPositionOwnershipArbiter *m_ownership_arbiter;

public:
                     CPositionManager(void)
     {
      m_symbol="";
      m_context_id.symbol="";
      m_context_id.timeframe=PERIOD_CURRENT;
      m_magic_number=0;
      m_ownership_arbiter=NULL;
     }

   void              Configure(const string symbol,const long magic_number)
     {
      m_symbol=symbol;
      m_context_id.symbol=symbol;
      m_context_id.timeframe=(ENUM_TIMEFRAMES)_Period;
      m_magic_number=magic_number;
      m_ownership_arbiter=NULL;
     }

   //--- Formal context identity used by Task030. Arbiter ownership remains
   //--- external and shared across contexts; PositionManager never deletes it.
   bool              Configure(const SRuntimeContextId &context_id,
                               const long magic_number,
                               CPositionOwnershipArbiter &ownership_arbiter)
     {
      if(!IsValidRuntimeContextId(context_id) || magic_number<=0)
         return(false);
      m_context_id=context_id;
      m_symbol=context_id.symbol;
      m_magic_number=magic_number;
      m_ownership_arbiter=GetPointer(ownership_arbiter);
      return(m_ownership_arbiter!=NULL);
     }

   bool              OwnsPositionFacts(const string symbol,const long magic_number)
     {
      return(symbol==m_symbol && magic_number==m_magic_number);
     }

   //--- Returns the single managed position expected by the execution contract.
   bool              TryGetFeNXPosition(ulong &ticket,ENUM_POSITION_TYPE &position_type,
                                        datetime &opened_at)
     {
      ticket=0;
      position_type=POSITION_TYPE_BUY;
      opened_at=0;
      for(int index=PositionsTotal()-1;index>=0;index--)
        {
         const ulong candidate=PositionGetTicket(index);
         if(candidate==0 || !PositionSelectByTicket(candidate))
            continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_symbol ||
            PositionGetInteger(POSITION_MAGIC)!=m_magic_number)
            continue;

         ticket=candidate;
         position_type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         opened_at=(datetime)PositionGetInteger(POSITION_TIME);
         return(true);
        }
      return(false);
     }

   int               CountFeNXPositions(void)
     {
      int count=0;
      for(int index=PositionsTotal()-1;index>=0;index--)
        {
         const ulong ticket=PositionGetTicket(index);
         if(ticket==0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL)==m_symbol &&
            PositionGetInteger(POSITION_MAGIC)==m_magic_number)
            count++;
        }
      return(count);
     }

   bool              HasAnyPositionOnSymbol(void)
     {
      for(int index=PositionsTotal()-1;index>=0;index--)
        {
         const ulong ticket=PositionGetTicket(index);
         if(ticket==0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL)==m_symbol)
            return(true);
        }
      return(false);
     }

   bool              CanOpenNewPosition(const int maximum_fenx_positions,string &reason)
     {
      if(CountFeNXPositions()>=maximum_fenx_positions)
        {
         reason="An existing FeNX position already uses the execution symbol.";
         return(false);
        }
      // Conservative behavior is required for both hedging and netting
      // accounts: never merge a context order into another owner position.
      if(m_ownership_arbiter!=NULL)
        {
         if(!m_ownership_arbiter.CanAcquireLive(m_context_id,m_magic_number,reason))
            return(false);
        }
      else if(HasAnyPositionOnSymbol())
        {
         reason="An existing position on "+m_symbol+
                " blocks a new FeNX order to avoid interference.";
         return(false);
        }
      reason="";
      return(true);
     }
  };

#endif // FENX_EXECUTION_POSITION_MANAGER_MQH
