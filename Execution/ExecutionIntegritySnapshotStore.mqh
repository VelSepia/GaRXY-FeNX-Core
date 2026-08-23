//+------------------------------------------------------------------+
//|             Execution/ExecutionIntegritySnapshotStore.mqh      |
//+------------------------------------------------------------------+
#ifndef FENX_EXECUTION_INTEGRITY_SNAPSHOT_STORE_MQH
#define FENX_EXECUTION_INTEGRITY_SNAPSHOT_STORE_MQH

//--- Passive facts emitted by the transaction router and position ownership
//--- infrastructure. The contract is diagnostic only and exposes no order,
//--- close, retry, permission, or StateManager command.
struct SExecutionIntegritySnapshot
  {
   datetime updated_at;
   int      expected_route_count;
   int      route_count;
   long     received_count;
   long     dispatched_count;
   long     external_count;
   long     wrong_dispatch_count;
   int      lifecycle_count;
   int      finalized_lifecycle_count;
   long     wrong_owner_count;
   long     duplicate_lifecycle_count;
   long     ownership_conflict_count;
   long     cross_symbol_order_count;
   long     wrong_context_close_count;
   long     wrong_transaction_route_count;
   long     trade_leak_count;
   long     runtime_error_count;
   bool     is_valid;
  };

void ResetExecutionIntegritySnapshot(SExecutionIntegritySnapshot &snapshot)
  {
   snapshot.updated_at=0;
   snapshot.expected_route_count=0;
   snapshot.route_count=0;
   snapshot.received_count=0;
   snapshot.dispatched_count=0;
   snapshot.external_count=0;
   snapshot.wrong_dispatch_count=0;
   snapshot.lifecycle_count=0;
   snapshot.finalized_lifecycle_count=0;
   snapshot.wrong_owner_count=0;
   snapshot.duplicate_lifecycle_count=0;
   snapshot.ownership_conflict_count=0;
   snapshot.cross_symbol_order_count=0;
   snapshot.wrong_context_close_count=0;
   snapshot.wrong_transaction_route_count=0;
   snapshot.trade_leak_count=0;
   snapshot.runtime_error_count=0;
   snapshot.is_valid=false;
  }

//--- Single-current typed store. Harnesses may inject a structurally valid
//--- non-zero error fact to prove Global Health detects it; production writes
//--- only measurements read from the adopted Task030 infrastructure.
class CExecutionIntegritySnapshotStore
  {
private:
   SExecutionIntegritySnapshot m_latest;

public:
                     CExecutionIntegritySnapshotStore(void)
     {
      Clear();
     }

   bool              Set(const SExecutionIntegritySnapshot &snapshot)
     {
      if(snapshot.updated_at<=0 || snapshot.expected_route_count<1 ||
         snapshot.route_count<0 || snapshot.received_count<0 ||
         snapshot.dispatched_count<0 || snapshot.external_count<0 ||
         snapshot.wrong_dispatch_count<0 || snapshot.lifecycle_count<0 ||
         snapshot.finalized_lifecycle_count<0 ||
         snapshot.finalized_lifecycle_count>snapshot.lifecycle_count ||
         snapshot.wrong_owner_count<0 ||
         snapshot.duplicate_lifecycle_count<0 ||
         snapshot.ownership_conflict_count<0 ||
         snapshot.cross_symbol_order_count<0 ||
         snapshot.wrong_context_close_count<0 ||
         snapshot.wrong_transaction_route_count<0 ||
         snapshot.trade_leak_count<0 || snapshot.runtime_error_count<0)
         return(false);
      m_latest=snapshot;
      return(true);
     }

   bool              GetLatest(SExecutionIntegritySnapshot &snapshot)
     {
      if(m_latest.updated_at<=0)
         return(false);
      snapshot=m_latest;
      return(true);
     }

   void              Clear(void)
     {
      ResetExecutionIntegritySnapshot(m_latest);
     }
  };

#endif // FENX_EXECUTION_INTEGRITY_SNAPSHOT_STORE_MQH
