//+------------------------------------------------------------------+
//|                                         Core/EngineManager.mqh  |
//+------------------------------------------------------------------+
#ifndef FENX_CORE_ENGINE_MANAGER_MQH
#define FENX_CORE_ENGINE_MANAGER_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Common/Types.mqh"
#include "../Config/ParameterManager.mqh"
#include "../Core/DataBus.mqh"
#include "../Engine/IEngine.mqh"

//--- Selects the event that allows EngineManager to update an engine.
//--- RUNMODE_TICK preserves the scheduling behavior used before run modes existed.
enum ENUM_ENGINE_RUN_MODE
  {
   RUNMODE_TICK = 0,
   RUNMODE_NEWBAR,
   RUNMODE_ONCHANGE
  };

//--- Coordinates the lifecycle of non-owning references to EA engines.
class CEngineManager
  {
private:
   IEngine              *m_engines[];
   ENUM_ENGINE_RUN_MODE m_run_modes[];
   bool                 m_change_pending[];
   bool                 m_has_context[];
   bool                 m_context_data_views[];
   SRuntimeContextId    m_context_ids[];
   CStateManager        *m_state_managers[];
   datetime             m_last_bar_times[];
   int                  m_initialized_engine_count;
   bool                 m_initialized;
   bool                 m_has_legacy_newbar_engine;
   datetime             m_last_bar_time;
   CDataBus             *m_data_bus;

   bool              IsValidRunMode(const ENUM_ENGINE_RUN_MODE run_mode)
     {
      return(run_mode==RUNMODE_TICK ||
             run_mode==RUNMODE_NEWBAR ||
             run_mode==RUNMODE_ONCHANGE);
     }

   //--- Detects one forward transition of the current chart's bar. This is the
   //--- unchanged compatibility path for engines registered without context.
   bool              IsNewBar(void)
     {
      const datetime current_bar_time=iTime(_Symbol,_Period,0);
      if(current_bar_time<=0)
         return(false);

      if(m_last_bar_time<=0)
        {
         m_last_bar_time=current_bar_time;
         return(false);
        }

      if(current_bar_time<=m_last_bar_time)
         return(false);

      m_last_bar_time=current_bar_time;
      return(true);
     }

   //--- Context registrations use their own Symbol+Timeframe clock and never
   //--- depend on the chart selected for the Expert Advisor.
   bool              IsContextNewBar(const int index)
     {
      if(index<0 || index>=ArraySize(m_engines) || !m_has_context[index])
         return(false);

      const datetime current_bar_time=
         iTime(m_context_ids[index].symbol,m_context_ids[index].timeframe,0);
      if(current_bar_time<=0)
         return(false);

      if(m_last_bar_times[index]<=0)
        {
         m_last_bar_times[index]=current_bar_time;
         return(false);
        }

      if(current_bar_time<=m_last_bar_times[index])
         return(false);

      m_last_bar_times[index]=current_bar_time;
      return(true);
     }

   bool              RegisterInternal(IEngine &engine,
                                      const ENUM_ENGINE_RUN_MODE run_mode,
                                      const bool has_context,
                                      const SRuntimeContextId &context_id,
                                      CStateManager *state_manager,
                                      const bool context_data_view)
     {
      if(m_initialized)
        {
         CLogger::Warning("Engine registration is only allowed before initialization.");
         return(false);
        }
      if(!IsValidRunMode(run_mode))
        {
         CLogger::Error("Engine registration received an invalid run mode.");
         return(false);
        }
      if(has_context &&
         (!IsValidRuntimeContextId(context_id) || state_manager==NULL))
        {
         CLogger::Error("Context engine registration received invalid metadata.");
         return(false);
        }

      IEngine *engine_pointer=GetPointer(engine);
      if(engine_pointer==NULL)
        {
         CLogger::Error("Engine registration received an invalid engine reference.");
         return(false);
        }

      const int engine_count=ArraySize(m_engines);
      if(engine_count>=FENX_MAX_ENGINES)
        {
         CLogger::Error("EngineManager capacity has been reached.");
         return(false);
        }
      for(int index=0;index<engine_count;index++)
        {
         if(m_engines[index]==engine_pointer)
           {
            CLogger::Warning("Engine registration ignored a duplicate engine.");
            return(false);
           }
        }

      if(ArrayResize(m_engines,engine_count+1)!=(engine_count+1) ||
         ArrayResize(m_run_modes,engine_count+1)!=(engine_count+1) ||
         ArrayResize(m_change_pending,engine_count+1)!=(engine_count+1) ||
         ArrayResize(m_has_context,engine_count+1)!=(engine_count+1) ||
         ArrayResize(m_context_data_views,engine_count+1)!=(engine_count+1) ||
         ArrayResize(m_context_ids,engine_count+1)!=(engine_count+1) ||
         ArrayResize(m_state_managers,engine_count+1)!=(engine_count+1) ||
         ArrayResize(m_last_bar_times,engine_count+1)!=(engine_count+1))
        {
         // Keep all parallel metadata arrays aligned after any allocation failure.
         ArrayResize(m_engines,engine_count);
         ArrayResize(m_run_modes,engine_count);
         ArrayResize(m_change_pending,engine_count);
         ArrayResize(m_has_context,engine_count);
         ArrayResize(m_context_data_views,engine_count);
         ArrayResize(m_context_ids,engine_count);
         ArrayResize(m_state_managers,engine_count);
         ArrayResize(m_last_bar_times,engine_count);
         CLogger::Error("EngineManager could not register a new engine.");
         return(false);
        }

      m_engines[engine_count]=engine_pointer;
      m_run_modes[engine_count]=run_mode;
      m_change_pending[engine_count]=false;
      m_has_context[engine_count]=has_context;
      m_context_data_views[engine_count]=(has_context && context_data_view);
      m_context_ids[engine_count]=context_id;
      m_state_managers[engine_count]=state_manager;
      m_last_bar_times[engine_count]=0;
      if(run_mode==RUNMODE_NEWBAR)
        {
         if(!has_context)
            m_has_legacy_newbar_engine=true;
        }

      CLogger::Info(StringFormat("Registered engine: %s",engine_pointer.GetName()));
      return(true);
     }

public:
                     CEngineManager(void)
     {
      m_initialized_engine_count=0;
      m_initialized=false;
      m_has_legacy_newbar_engine=false;
      m_last_bar_time=0;
      m_data_bus=NULL;
     }

   //--- Legacy overload: no context metadata and the global StateManager are
   //--- used exactly as before Task026.
   bool              Register(IEngine &engine,
                              const ENUM_ENGINE_RUN_MODE run_mode=RUNMODE_TICK)
     {
      SRuntimeContextId empty_context;
      empty_context.symbol="";
      empty_context.timeframe=PERIOD_CURRENT;
      return(RegisterInternal(engine,run_mode,false,empty_context,NULL,false));
     }

   //--- Context-aware overload. EngineManager stores non-owning metadata; the
   //--- registry remains the sole owner of the supplied local StateManager.
   bool              Register(IEngine &engine,
                              const SRuntimeContextId &context_id,
                              CStateManager &state_manager,
                              const ENUM_ENGINE_RUN_MODE run_mode=RUNMODE_TICK)
     {
      CStateManager *state_manager_pointer=GetPointer(state_manager);
      return(RegisterInternal(engine,run_mode,true,context_id,state_manager_pointer,false));
     }

   //--- Registers a context-scoped compatibility view for Task029 engines.
   //--- Analysis engines retain their explicit Task027 bindings and therefore
   //--- continue to use the older context overload above.
   bool              RegisterContextDataView(
                        IEngine &engine,
                        const SRuntimeContextId &context_id,
                        CStateManager &state_manager,
                        const ENUM_ENGINE_RUN_MODE run_mode=RUNMODE_TICK)
     {
      CStateManager *state_manager_pointer=GetPointer(state_manager);
      return(RegisterInternal(engine,run_mode,true,context_id,
                              state_manager_pointer,true));
     }

   bool              Initialize(CDataBus &data_bus,CParameterManager &parameters,
                                CStateManager &state_manager)
     {
      if(m_initialized)
         return(true);

      m_data_bus=GetPointer(data_bus);

      const int engine_count=ArraySize(m_engines);
      if(m_has_legacy_newbar_engine)
         m_last_bar_time=iTime(_Symbol,_Period,0);

      for(int index=0;index<engine_count;index++)
        {
         if(m_engines[index]==NULL)
           {
            CLogger::Error("EngineManager found an invalid engine pointer.");
            Shutdown();
            return(false);
           }

         if(!m_has_context[index])
            m_engines[index].SetStateManager(state_manager);
         else if(m_state_managers[index]==NULL)
           {
            CLogger::Error("EngineManager found invalid context state metadata.");
            Shutdown();
            return(false);
           }
         else
            m_engines[index].SetStateManager(m_state_managers[index]);

         if(m_run_modes[index]==RUNMODE_NEWBAR)
           {
            if(m_has_context[index])
               m_last_bar_times[index]=
                  iTime(m_context_ids[index].symbol,m_context_ids[index].timeframe,0);
            else
               m_last_bar_times[index]=m_last_bar_time;
           }

         bool context_view_started=false;
         if(m_context_data_views[index])
           {
            context_view_started=data_bus.BeginContextView(m_context_ids[index]);
            if(!context_view_started)
              {
               CLogger::Error("EngineManager could not activate a context DataBus view.");
               Shutdown();
               return(false);
              }
           }

         const bool initialized=m_engines[index].Initialize(data_bus,parameters);
         if(context_view_started)
            data_bus.EndContextView();
         if(!initialized)
           {
            CLogger::Error(StringFormat("Failed to initialize engine: %s",m_engines[index].GetName()));
            Shutdown();
            return(false);
           }
         m_initialized_engine_count++;
        }

      m_initialized=true;
      CLogger::Info(StringFormat("EngineManager initialized %d engine(s).",engine_count));
      return(true);
     }

   //--- Queues one update for a registered RUNMODE_ONCHANGE engine.
   //--- Repeated notifications before Update() are intentionally coalesced.
   bool              NotifyChange(IEngine &engine)
     {
      IEngine *engine_pointer=GetPointer(engine);
      if(engine_pointer==NULL)
         return(false);

      const int engine_count=ArraySize(m_engines);
      for(int index=0;index<engine_count;index++)
        {
         if(m_engines[index]!=engine_pointer)
            continue;
         if(m_run_modes[index]!=RUNMODE_ONCHANGE)
           {
            CLogger::Warning("Change notification ignored for a non-OnChange engine.");
            return(false);
           }
         m_change_pending[index]=true;
         return(true);
        }

      CLogger::Warning("Change notification ignored for an unregistered engine.");
      return(false);
     }

   //--- Dispatches legacy engines through the legacy chart clock and context
   //--- engines through independent Symbol+Timeframe clocks.
   void              Update(void)
     {
      if(!m_initialized)
         return;

      const bool legacy_is_new_bar=
         (m_has_legacy_newbar_engine && IsNewBar());
      for(int index=0;index<m_initialized_engine_count;index++)
        {
         if(m_engines[index]==NULL)
            continue;

         bool should_update=false;
         switch(m_run_modes[index])
           {
            case RUNMODE_TICK:
               should_update=true;
               break;
            case RUNMODE_NEWBAR:
               should_update=(m_has_context[index] ?
                              IsContextNewBar(index) : legacy_is_new_bar);
               if(!m_has_context[index] && legacy_is_new_bar)
                  m_last_bar_times[index]=m_last_bar_time;
               break;
            case RUNMODE_ONCHANGE:
               should_update=m_change_pending[index];
               if(should_update)
                  m_change_pending[index]=false;
               break;
           }

         if(should_update)
           {
            bool context_view_started=false;
            if(m_context_data_views[index])
              {
               context_view_started=m_data_bus.BeginContextView(m_context_ids[index]);
               if(!context_view_started)
                 {
                  CLogger::Error("EngineManager skipped an engine because its context DataBus view could not be activated.");
                  continue;
                 }
              }
            m_engines[index].Update();
            if(context_view_started)
               m_data_bus.EndContextView();
           }
        }
     }

   void              Shutdown(void)
     {
      for(int index=m_initialized_engine_count-1;index>=0;index--)
        {
         if(m_engines[index]!=NULL)
            m_engines[index].Shutdown();
        }
      for(int index=0;index<ArraySize(m_change_pending);index++)
        {
         m_change_pending[index]=false;
         m_last_bar_times[index]=0;
        }

      m_initialized_engine_count=0;
      m_initialized=false;
      m_last_bar_time=0;
      m_data_bus=NULL;
     }

   int               Count(void)
     {
      return(ArraySize(m_engines));
     }

   bool              HasContext(const int index)
     {
      return(index>=0 && index<ArraySize(m_has_context) && m_has_context[index]);
     }

   bool              GetContextId(const int index,SRuntimeContextId &context_id)
     {
      if(!HasContext(index))
         return(false);
      context_id=m_context_ids[index];
      return(true);
     }

   CStateManager    *GetRegistrationStateManager(const int index)
     {
      if(index<0 || index>=ArraySize(m_state_managers))
         return(NULL);
      return(m_state_managers[index]);
     }

   ENUM_ENGINE_RUN_MODE GetRunMode(const int index)
     {
      if(index<0 || index>=ArraySize(m_run_modes))
         return(RUNMODE_TICK);
      return(m_run_modes[index]);
     }

   datetime          GetLastBarTime(const int index)
     {
      if(index<0 || index>=ArraySize(m_last_bar_times))
         return(0);
      return(m_last_bar_times[index]);
     }

   string            GetEngineName(const int index)
     {
      if(index<0 || index>=ArraySize(m_engines) || m_engines[index]==NULL)
         return("");
      return(m_engines[index].GetName());
     }

   int               InitializedEngineCount(void)
     {
      return(m_initialized_engine_count);
     }

   bool              IsInitialized(void)
     {
      return(m_initialized);
     }
  };

#endif // FENX_CORE_ENGINE_MANAGER_MQH
