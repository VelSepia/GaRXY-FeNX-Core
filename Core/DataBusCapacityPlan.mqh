//+------------------------------------------------------------------+
//|                                  Core/DataBusCapacityPlan.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_CORE_DATA_BUS_CAPACITY_PLAN_MQH
#define FENX_CORE_DATA_BUS_CAPACITY_PLAN_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "DataBus.mqh"

//--- Calculates and validates the complete startup key reservation before
//--- any engine initialization or DataBus publication is allowed to begin.
class CDataBusCapacityPlan
  {
private:
   int m_configured_symbol_count;
   int m_baseline_required_entries;
   int m_environment_required_entries;
   int m_additional_global_entries;
   int m_additional_per_symbol_entries;
   int m_additional_required_entries;
   int m_total_required_entries;

public:
                     CDataBusCapacityPlan(void)
     {
      m_configured_symbol_count=0;
      m_baseline_required_entries=0;
      m_environment_required_entries=0;
      m_additional_global_entries=0;
      m_additional_per_symbol_entries=0;
      m_additional_required_entries=0;
      m_total_required_entries=0;
     }

   bool              Build(const int configured_symbol_count,
                           const int environment_required_entries,
                           const int additional_global_entries=0,
                           const int additional_per_symbol_entries=0)
     {
      if(configured_symbol_count<1 ||
         configured_symbol_count>FENX_MARKET_SELECTION_MAX_SYMBOLS ||
         environment_required_entries<0 || additional_global_entries<0 ||
         additional_per_symbol_entries<0)
        {
         CLogger::Error("DataBus startup capacity plan received invalid inputs.");
         return(false);
        }

      m_configured_symbol_count=configured_symbol_count;
      m_baseline_required_entries=
         FENX_DATABUS_BASELINE_FIXED_ENTRIES+
         FENX_DATABUS_BASELINE_PER_SYMBOL_ENTRIES*configured_symbol_count;
      m_environment_required_entries=environment_required_entries;
      m_additional_global_entries=additional_global_entries;
      m_additional_per_symbol_entries=additional_per_symbol_entries;
      m_additional_required_entries=additional_global_entries+
                                    additional_per_symbol_entries*configured_symbol_count;
      m_total_required_entries=m_baseline_required_entries+
                               m_environment_required_entries+
                               m_additional_required_entries;
      return(true);
     }

   bool              Validate(CDataBus *data_bus)
     {
      if(data_bus==NULL)
        {
         CLogger::Error("DataBus capacity preflight received an invalid DataBus.");
         return(false);
        }

      // A non-empty bus proves the check was called too late and could permit
      // a partially published multi-field snapshot, so fail closed.
      if(data_bus.CurrentSize()!=0)
        {
         CLogger::Error(StringFormat(
            "DataBus capacity preflight must run before writes; current size is %d.",
            data_bus.CurrentSize()));
         return(false);
        }

      const int capacity=data_bus.Capacity();
      const int remaining=capacity-m_total_required_entries;
      const double remaining_percentage=
         (capacity>0 ? 100.0*(double)remaining/(double)capacity : 0.0);
      const bool accepted=data_bus.HasCapacityFor(m_total_required_entries);

      CLogger::Info(StringFormat(
         "[DATABUS CAPACITY] Configured Symbols: %d; Baseline Required Keys: %d; Environment Required Keys: %d; Additional Global Keys: %d; Additional Per-Symbol Keys: %d; Additional Required Keys: %d; Total Required Keys: %d; Capacity: %d; Remaining: %d; Remaining Ratio: %.1f%%; Capacity Check: %s",
         m_configured_symbol_count,m_baseline_required_entries,
         m_environment_required_entries,m_additional_global_entries,
         m_additional_per_symbol_entries,m_additional_required_entries,
         m_total_required_entries,capacity,remaining,remaining_percentage,
         (accepted ? "PASS" : "FAIL")));

      if(!accepted)
        {
         CLogger::Error(
            "DataBus startup capacity is insufficient; engine initialization and trading are blocked.");
         return(false);
        }
      return(true);
     }

   int               ConfiguredSymbolCount(void)
     {
      return(m_configured_symbol_count);
     }

   int               BaselineRequiredEntries(void)
     {
      return(m_baseline_required_entries);
     }

   int               EnvironmentRequiredEntries(void)
     {
      return(m_environment_required_entries);
     }

   int               AdditionalGlobalEntries(void)
     {
      return(m_additional_global_entries);
     }

   int               AdditionalPerSymbolEntries(void)
     {
      return(m_additional_per_symbol_entries);
     }

   int               AdditionalRequiredEntries(void)
     {
      return(m_additional_required_entries);
     }

   int               TotalRequiredEntries(void)
     {
      return(m_total_required_entries);
     }
  };

#endif // FENX_CORE_DATA_BUS_CAPACITY_PLAN_MQH
