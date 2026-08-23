//+------------------------------------------------------------------+
//|                    Execution/PositionOwnershipArbiter.mqh       |
//+------------------------------------------------------------------+
#ifndef FENX_EXECUTION_POSITION_OWNERSHIP_ARBITER_MQH
#define FENX_EXECUTION_POSITION_OWNERSHIP_ARBITER_MQH

#include "../Common/Types.mqh"

//--- One deterministic ownership claim used by the isolation harness. Live
//--- trading decisions are always derived from terminal positions instead.
struct SPositionOwnershipClaim
  {
   SRuntimeContextId context_id;
   long              magic;
   ulong             claim_id;
  };

//--- Protects MT5 netting ownership at the symbol boundary. The arbiter does
//--- not add a market or strategy filter: it preserves the established rule
//--- that any existing position on a symbol prevents another FeNX owner from
//--- acquiring that symbol.
class CPositionOwnershipArbiter
  {
private:
   SPositionOwnershipClaim m_claims[];
   long                    m_conflict_count;

public:
                     CPositionOwnershipArbiter(void)
     {
      m_conflict_count=0;
     }

   //--- Production path. Terminal position state remains the source of truth,
   //--- so manual and other-EA positions retain the existing fail-closed rule.
   bool              CanAcquireLive(const SRuntimeContextId &context_id,
                                    const long magic,string &reason)
     {
      if(!IsValidRuntimeContextId(context_id) || magic<=0)
        {
         reason="Position ownership identity is invalid.";
         return(false);
        }

      for(int index=PositionsTotal()-1;index>=0;index--)
        {
         const ulong ticket=PositionGetTicket(index);
         if(ticket==0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL)!=context_id.symbol)
            continue;

         m_conflict_count++;
         reason="An existing position on "+context_id.symbol+
                " blocks a second context owner.";
         return(false);
        }
      reason="";
      return(true);
     }

   //--- Broker-independent claim path for deterministic same-symbol tests.
   //--- Different symbols may reuse one magic; one symbol may not have two
   //--- context owners, even when their timeframes and magic values differ.
   bool              TryClaim(const SRuntimeContextId &context_id,
                              const long magic,const ulong claim_id,
                              string &reason)
     {
      if(!IsValidRuntimeContextId(context_id) || magic<=0 || claim_id==0)
        {
         reason="Synthetic ownership identity is invalid.";
         return(false);
        }
      for(int index=0;index<ArraySize(m_claims);index++)
        {
         if(m_claims[index].context_id.symbol!=context_id.symbol)
            continue;
         m_conflict_count++;
         reason="The symbol is already owned by another runtime context.";
         return(false);
        }

      const int count=ArraySize(m_claims);
      if(ArrayResize(m_claims,count+1)!=(count+1))
        {
         reason="Unable to allocate a position ownership claim.";
         return(false);
        }
      m_claims[count].context_id=context_id;
      m_claims[count].magic=magic;
      m_claims[count].claim_id=claim_id;
      reason="";
      return(true);
     }

   bool              OwnsClaim(const SRuntimeContextId &context_id,
                               const long magic,const ulong claim_id)
     {
      for(int index=0;index<ArraySize(m_claims);index++)
        {
         if(RuntimeContextEquals(m_claims[index].context_id,context_id) &&
            m_claims[index].magic==magic &&
            m_claims[index].claim_id==claim_id)
            return(true);
        }
      return(false);
     }

   bool              ReleaseClaim(const SRuntimeContextId &context_id,
                                  const long magic,const ulong claim_id)
     {
      for(int index=0;index<ArraySize(m_claims);index++)
        {
         if(!RuntimeContextEquals(m_claims[index].context_id,context_id) ||
            m_claims[index].magic!=magic ||
            m_claims[index].claim_id!=claim_id)
            continue;
         for(int move=index;move<ArraySize(m_claims)-1;move++)
            m_claims[move]=m_claims[move+1];
         ArrayResize(m_claims,ArraySize(m_claims)-1);
         return(true);
        }
      return(false);
     }

   int               ClaimCount(void) { return(ArraySize(m_claims)); }
   long              ConflictCount(void) { return(m_conflict_count); }

   void              Clear(void)
     {
      ArrayResize(m_claims,0);
      m_conflict_count=0;
     }
  };

#endif // FENX_EXECUTION_POSITION_OWNERSHIP_ARBITER_MQH
