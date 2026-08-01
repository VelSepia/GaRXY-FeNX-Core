//+------------------------------------------------------------------+
//|                                              Core/DataBus.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_CORE_DATA_BUS_MQH
#define FENX_CORE_DATA_BUS_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Common/Types.mqh"

//--- Shared, in-memory message store for registered framework engines.
class CDataBus
  {
private:
   SDataBusItem m_items[];

   int FindIndex(const string key)
     {
      for(int index=0;index<ArraySize(m_items);index++)
        {
         if(m_items[index].key==key)
            return(index);
        }

      return(-1);
     }

   string BuildSymbolKey(const string name_space,const string symbol,const string field)
     {
      if(StringLen(name_space)==0 || StringLen(symbol)==0 || StringLen(field)==0)
         return("");

      return(name_space+"."+symbol+"."+field);
     }

public:
   bool SetText(const string key,const string value)
     {
      if(StringLen(key)==0)
        {
         CLogger::Warning("DataBus rejected an empty key.");
         return(false);
        }

      int index=FindIndex(key);
      if(index<0)
        {
         const int item_count=ArraySize(m_items);
         if(item_count>=Capacity())
           {
            CLogger::Error("DataBus capacity has been reached.");
            return(false);
           }

         if(ArrayResize(m_items,item_count+1)!=(item_count+1))
           {
            CLogger::Error("DataBus could not allocate a new entry.");
            return(false);
           }

         index=item_count;
         m_items[index].key=key;
        }

      m_items[index].value=value;
      m_items[index].updated_at=TimeCurrent();
      return(true);
     }

   bool TryGetText(const string key,string &value)
     {
      const int index=FindIndex(key);
      if(index<0)
         return(false);

      value=m_items[index].value;
      return(true);
     }

   bool SetSymbolText(const string name_space,const string symbol,const string field,
                      const string value)
     {
      const string key=BuildSymbolKey(name_space,symbol,field);
      if(StringLen(key)==0)
        {
         CLogger::Warning("DataBus rejected an incomplete per-symbol key.");
         return(false);
        }

      return(SetText(key,value));
     }

   bool TryGetSymbolText(const string name_space,const string symbol,const string field,
                         string &value)
     {
      const string key=BuildSymbolKey(name_space,symbol,field);
      if(StringLen(key)==0)
         return(false);

      return(TryGetText(key,value));
     }

   bool Contains(const string key)
     {
      return(FindIndex(key)>=0);
     }

   //--- Returns the logical safety guard. The dynamic array is not pre-sized.
   int Capacity(void)
     {
      return(FENX_DATABUS_CAPACITY);
     }

   //--- Returns only entries currently stored in the dynamic array.
   int CurrentSize(void)
     {
      return(ArraySize(m_items));
     }

   //--- Returns the number of additional unique keys that can be accepted.
   int RemainingCapacity(void)
     {
      const int remaining=Capacity()-CurrentSize();
      return(remaining>0 ? remaining : 0);
     }

   //--- Tests an additional unique-key reservation without allocating memory.
   bool CanReserve(const int required_entries)
     {
      return(required_entries>=0 && required_entries<=RemainingCapacity());
     }

   //--- Compatibility-friendly alias for capacity planning callers.
   bool HasCapacityFor(const int required_entries)
     {
      return(CanReserve(required_entries));
     }

   int Count(void)
     {
      return(CurrentSize());
     }

   void Clear(void)
     {
      ArrayFree(m_items);
     }
  };

#endif // FENX_CORE_DATA_BUS_MQH

