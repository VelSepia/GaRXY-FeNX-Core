//+------------------------------------------------------------------+
//|                     Execution/PositionLifecycleRegistry.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_EXECUTION_POSITION_LIFECYCLE_REGISTRY_MQH
#define FENX_EXECUTION_POSITION_LIFECYCLE_REGISTRY_MQH

#include "../Common/Types.mqh"

//--- Complete cross-component identity for one FeNX position lifecycle.
//--- Local Entry/Exit/Execution sequences remain scoped to context_id.
struct SPositionLifecycleIdentity
  {
   SRuntimeContextId context_id;
   long              magic;
   ulong             position_ticket;
   ulong             position_lifecycle_id;
   long              entry_evaluation_sequence;
   long              entry_execution_sequence;
   long              exit_evaluation_sequence;
   long              exit_execution_sequence;
   ulong             open_order_ticket;
   ulong             open_deal_ticket;
   ulong             close_order_ticket;
   ulong             close_deal_ticket;
   string            open_reason;
   string            close_reason;
   bool              finalized;
  };

void ResetPositionLifecycleIdentity(SPositionLifecycleIdentity &identity)
  {
   identity.context_id.symbol="";
   identity.context_id.timeframe=PERIOD_CURRENT;
   identity.magic=0;
   identity.position_ticket=0;
   identity.position_lifecycle_id=0;
   identity.entry_evaluation_sequence=0;
   identity.entry_execution_sequence=0;
   identity.exit_evaluation_sequence=0;
   identity.exit_execution_sequence=0;
   identity.open_order_ticket=0;
   identity.open_deal_ticket=0;
   identity.close_order_ticket=0;
   identity.close_deal_ticket=0;
   identity.open_reason="";
   identity.close_reason="";
   identity.finalized=false;
  }

//--- Bounded only by actual position lifecycles. It is not a trading input;
//--- it supplies deterministic ownership and linkage for transaction routing,
//--- diagnostics, and future Health integration.
class CPositionLifecycleRegistry
  {
private:
   SPositionLifecycleIdentity m_records[];
   long                       m_wrong_owner_count;
   long                       m_duplicate_event_count;

   int               FindIndex(const ulong lifecycle_id,
                               const ulong position_ticket)
     {
      for(int index=ArraySize(m_records)-1;index>=0;index--)
        {
         if(lifecycle_id>0 &&
            m_records[index].position_lifecycle_id==lifecycle_id)
            return(index);
         if(lifecycle_id==0 && position_ticket>0 &&
            m_records[index].position_ticket==position_ticket)
            return(index);
        }
      return(-1);
     }

public:
                     CPositionLifecycleRegistry(void)
     {
      m_wrong_owner_count=0;
      m_duplicate_event_count=0;
     }

   bool              ObserveOpen(const SRuntimeContextId &context_id,
                                 const long magic,
                                 const ulong position_ticket,
                                 const ulong lifecycle_id,
                                 const ulong order_ticket,
                                 const ulong deal_ticket,
                                 const long entry_sequence,
                                 const long execution_sequence,
                                 const string reason)
     {
      if(!IsValidRuntimeContextId(context_id) || magic<=0 ||
         lifecycle_id==0 || deal_ticket==0)
         return(false);

      const int existing=FindIndex(lifecycle_id,position_ticket);
      if(existing>=0)
        {
         if(!RuntimeContextEquals(m_records[existing].context_id,context_id) ||
            m_records[existing].magic!=magic)
            m_wrong_owner_count++;
         else
            m_duplicate_event_count++;
         return(false);
        }

      const int count=ArraySize(m_records);
      if(ArrayResize(m_records,count+1)!=(count+1))
         return(false);
      ResetPositionLifecycleIdentity(m_records[count]);
      m_records[count].context_id=context_id;
      m_records[count].magic=magic;
      m_records[count].position_ticket=position_ticket;
      m_records[count].position_lifecycle_id=lifecycle_id;
      m_records[count].entry_evaluation_sequence=entry_sequence;
      m_records[count].entry_execution_sequence=execution_sequence;
      m_records[count].open_order_ticket=order_ticket;
      m_records[count].open_deal_ticket=deal_ticket;
      m_records[count].open_reason=reason;
      return(true);
     }

   bool              ObserveClose(const SRuntimeContextId &context_id,
                                  const long magic,
                                  const ulong position_ticket,
                                  const ulong lifecycle_id,
                                  const ulong order_ticket,
                                  const ulong deal_ticket,
                                  const long exit_sequence,
                                  const long execution_sequence,
                                  const string reason)
     {
      const int index=FindIndex(lifecycle_id,position_ticket);
      if(index<0)
         return(false);
      if(!RuntimeContextEquals(m_records[index].context_id,context_id) ||
         m_records[index].magic!=magic)
        {
         m_wrong_owner_count++;
         return(false);
        }
      if(m_records[index].finalized)
        {
         m_duplicate_event_count++;
         return(false);
        }
      m_records[index].position_ticket=(position_ticket>0 ? position_ticket :
                                        m_records[index].position_ticket);
      m_records[index].exit_evaluation_sequence=exit_sequence;
      m_records[index].exit_execution_sequence=execution_sequence;
      m_records[index].close_order_ticket=order_ticket;
      m_records[index].close_deal_ticket=deal_ticket;
      m_records[index].close_reason=reason;
      m_records[index].finalized=true;
      return(true);
     }

   bool              FindOwner(const ulong lifecycle_id,
                               const ulong position_ticket,
                               SRuntimeContextId &context_id,long &magic)
     {
      const int index=FindIndex(lifecycle_id,position_ticket);
      if(index<0)
         return(false);
      context_id=m_records[index].context_id;
      magic=m_records[index].magic;
      return(true);
     }

   bool              FindOwnerByLink(const ulong order_ticket,
                                     const ulong deal_ticket,
                                     SRuntimeContextId &context_id,long &magic)
     {
      for(int index=ArraySize(m_records)-1;index>=0;index--)
        {
         const bool order_match=(order_ticket>0 &&
            (m_records[index].open_order_ticket==order_ticket ||
             m_records[index].close_order_ticket==order_ticket));
         const bool deal_match=(deal_ticket>0 &&
            (m_records[index].open_deal_ticket==deal_ticket ||
             m_records[index].close_deal_ticket==deal_ticket));
         if(!order_match && !deal_match)
            continue;
         context_id=m_records[index].context_id;
         magic=m_records[index].magic;
         return(true);
        }
      return(false);
     }

   bool              Get(const int index,SPositionLifecycleIdentity &identity)
     {
      if(index<0 || index>=ArraySize(m_records))
         return(false);
      identity=m_records[index];
      return(true);
     }

   int               Count(void) { return(ArraySize(m_records)); }

   int               FinalizedCount(void)
     {
      int count=0;
      for(int index=0;index<ArraySize(m_records);index++)
         if(m_records[index].finalized) count++;
      return(count);
     }

   long              WrongOwnerCount(void) { return(m_wrong_owner_count); }
   long              DuplicateEventCount(void) { return(m_duplicate_event_count); }

   void              Clear(void)
     {
      ArrayResize(m_records,0);
      m_wrong_owner_count=0;
      m_duplicate_event_count=0;
     }
  };

#endif // FENX_EXECUTION_POSITION_LIFECYCLE_REGISTRY_MQH
