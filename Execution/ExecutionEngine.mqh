//+------------------------------------------------------------------+
//|                               Execution/ExecutionEngine.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_EXECUTION_ENGINE_MQH
#define FENX_EXECUTION_ENGINE_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"
#include "../Strategy/RangeMeanReversionStrategy.mqh"
#include "DuplicateOrderGuard.mqh"
#include "ExecutionGate.mqh"
#include "OrderExecutor.mqh"
#include "PositionManager.mqh"
#include "TradeResultLogger.mqh"

//--- One update-cycle record published by the Minimal Execution System.
struct SExecutionSnapshot
  {
   bool     gate_allowed;
   bool     data_valid;
   string   gate_reason;
   string   entry_signal;
   double   entry_signal_score;
   double   entry_signal_confidence;
   string   requested_direction;
   double   requested_volume;
   double   requested_entry_price;
   double   requested_stop_loss;
   double   requested_take_profit;
   bool     duplicate_blocked;
   bool     existing_position_detected;
   datetime last_order_request_at;
   string   last_execution_result;
   long     last_execution_retcode;
   long     last_execution_deal_ticket;
   datetime updated_at;
  };

//--- Coordinates gate, strategy, duplicate protection, and the sole OrderExecutor.
class CExecutionEngine : public CBaseEngine
  {
private:
   CExecutionGate              m_gate;
   CRangeMeanReversionStrategy m_strategy;
   CDuplicateOrderGuard        m_duplicate_guard;
   CPositionManager            m_position_manager;
   COrderExecutor              m_order_executor;
   CTradeResultLogger          m_trade_logger;
   bool                        m_execution_enabled;
   bool                        m_ready;
   string                      m_symbol;
   long                        m_magic_number;
   double                      m_fixed_lot;
   string                      m_exit_mode;
   double                      m_fixed_take_profit_points;
   double                      m_fixed_stop_loss_points;
   double                      m_range_stop_buffer_points;
   int                         m_maximum_open_positions;
   string                      m_trade_comment;
   datetime                    m_last_processed_bar_time;
   datetime                    m_last_order_request_at;
   datetime                    m_last_global_execution_at;
   string                      m_last_execution_result;
   long                        m_last_execution_retcode;
   long                        m_last_execution_deal_ticket;
   int                         m_successful_order_count;
   int                         m_failed_order_count;
   int                         m_blocked_order_count;
   int                         m_successful_close_count;
   int                         m_failed_close_count;
   int                         m_entry_retry_count;
   int                         m_close_retry_count;
   int                         m_entry_signal_count;
   int                         m_entry_block_event_count;
   int                         m_no_signal_bar_count;
   int                         m_position_open_event_count;
   int                         m_position_close_event_count;
   int                         m_minimum_volume_adjustment_count;
   long                        m_update_count;
   long                        m_pipeline_block_ticks[FENX_PIPELINE_STAGE_COUNT];
   long                        m_pipeline_block_events[FENX_PIPELINE_STAGE_COUNT];
   ENUM_FENX_PIPELINE_STAGE    m_last_pipeline_stage;
   string                      m_last_pipeline_stage_reason;
   bool                        m_last_pipeline_blocked;
   int                         m_last_observed_fenx_position_count;
   datetime                    m_last_processed_exit_bar_time;
   string                      m_last_blocked_reason;

   void ResetSnapshot(SExecutionSnapshot &snapshot)
     {
      snapshot.gate_allowed=false;
      snapshot.data_valid=false;
      snapshot.gate_reason="Execution has not evaluated the current tick.";
      snapshot.entry_signal="NONE";
      snapshot.entry_signal_score=0.0;
      snapshot.entry_signal_confidence=0.0;
      snapshot.requested_direction="";
      snapshot.requested_volume=0.0;
      snapshot.requested_entry_price=0.0;
      snapshot.requested_stop_loss=0.0;
      snapshot.requested_take_profit=0.0;
      snapshot.duplicate_blocked=false;
      snapshot.existing_position_detected=false;
      snapshot.last_order_request_at=m_last_order_request_at;
      snapshot.last_execution_result=m_last_execution_result;
      snapshot.last_execution_retcode=m_last_execution_retcode;
      snapshot.last_execution_deal_ticket=m_last_execution_deal_ticket;
      snapshot.updated_at=TimeCurrent();
     }

   string DirectionName(const ENUM_ORDER_TYPE direction)
     {
      return(direction==ORDER_TYPE_BUY ? "BUY" : "SELL");
     }

   bool GetTickAndSpread(MqlTick &tick,double &spread_points,string &reason)
     {
      spread_points=-1.0;
      if(!SymbolInfoTick(m_symbol,tick))
        {
         reason="Current USDJPY tick data is unavailable.";
         return(false);
        }
      const double point=SymbolInfoDouble(m_symbol,SYMBOL_POINT);
      if(point<=0.0 || tick.bid<=0.0 || tick.ask<=0.0 || tick.ask<tick.bid)
        {
         reason="USDJPY tick or point data is invalid.";
         return(false);
        }
      spread_points=(tick.ask-tick.bid)/point;
      reason="";
      return(true);
     }

   void FillRequestFields(const SOrderRequest &request,SExecutionSnapshot &snapshot)
     {
      snapshot.requested_direction=DirectionName(request.direction);
      snapshot.requested_volume=request.volume;
      snapshot.requested_entry_price=request.entry_price;
      snapshot.requested_stop_loss=request.stop_loss;
      snapshot.requested_take_profit=request.take_profit;
     }

   bool BuildRequest(const SRangeEntryIntent &intent,const MqlTick &tick,
                     const double allocation_multiplier,SOrderRequest &request,string &reason)
     {
      request.symbol=m_symbol;
      request.direction=intent.direction;
      request.volume=m_fixed_lot*MathMin(1.0,allocation_multiplier);
      request.entry_price=(intent.direction==ORDER_TYPE_BUY ? tick.ask : tick.bid);
      request.magic_number=m_magic_number;
      request.comment=m_trade_comment;
      request.timestamp=TimeCurrent();
      request.signal_bar_time=intent.bar_time;
      request.request_identifier=StringFormat("%s.%s.%I64d",m_symbol,
                                               DirectionName(intent.direction),intent.bar_time);
      if(!m_strategy.BuildProtection(intent,request.entry_price,m_exit_mode,
                                     m_fixed_take_profit_points,m_fixed_stop_loss_points,
                                     m_range_stop_buffer_points,request.stop_loss,
                                     request.take_profit,reason))
         return(false);
      return(true);
     }

   void RecordBlocked(const string reason,SExecutionSnapshot &snapshot)
     {
      snapshot.gate_reason=reason;
      m_trade_logger.WarningOnce("Execution blocked: "+reason);
      if(reason!=m_last_blocked_reason)
        {
         m_blocked_order_count++;
         m_last_blocked_reason=reason;
        }
     }

   //--- Records a post-signal execution stop without changing the existing block decision.
   void RecordEntryBlocked(const string step,const string reason,
                           SExecutionSnapshot &snapshot)
     {
      m_entry_block_event_count++;
      m_pipeline_block_ticks[FENX_PIPELINE_EXECUTION]++;
      m_pipeline_block_events[FENX_PIPELINE_EXECUTION]++;
      CLogger::Info(StringFormat("[PIPELINE] stop=Execution;blocked=true;reason=%s;trace=Execution=%s=BLOCK",
                                 reason,step));
      RecordBlocked(reason,snapshot);
     }

   void ObservePositionCount(void)
     {
      const int current_count=m_position_manager.CountFeNXPositions();
      if(current_count==m_last_observed_fenx_position_count)
         return;
      if(current_count<m_last_observed_fenx_position_count)
        {
         m_position_close_event_count++;
         m_trade_logger.InfoOnce("[PIPELINE] Position=CLOSED;Close=BROKER_OR_EXTERNAL.");
        }
      else
        {
         m_position_open_event_count++;
         m_trade_logger.InfoOnce("[PIPELINE] Position=OPEN.");
        }
      m_last_observed_fenx_position_count=current_count;
     }

   //--- Counts blocked ticks and state/reason transitions without changing gate decisions.
   void RecordPipelineResult(const SExecutionGateResult &result)
     {
      const bool blocked=!result.allowed;
      const int stage_index=(int)result.stop_stage;
      if(blocked && stage_index>=0 && stage_index<FENX_PIPELINE_STAGE_COUNT)
         m_pipeline_block_ticks[stage_index]++;

      const bool changed=(blocked!=m_last_pipeline_blocked ||
                          result.stop_stage!=m_last_pipeline_stage ||
                          result.stage_reason!=m_last_pipeline_stage_reason);
      if(!changed)
         return;

      if(blocked && stage_index>=0 && stage_index<FENX_PIPELINE_STAGE_COUNT)
         m_pipeline_block_events[stage_index]++;
      CLogger::Info(StringFormat("[PIPELINE] stop=%s;blocked=%s;reason=%s;trace=%s",
                                 FenxPipelineStageName(result.stop_stage),
                                 (blocked ? "true" : "false"),result.stage_reason,
                                 result.pipeline_trace));
      m_last_pipeline_blocked=blocked;
      m_last_pipeline_stage=result.stop_stage;
      m_last_pipeline_stage_reason=result.stage_reason;
     }

   //--- Manages an existing FeNX position before evaluating any new-entry gate.
   void ManageOpenPosition(const ulong position_ticket,
                           const ENUM_POSITION_TYPE position_type,
                           const datetime opened_at,SExecutionSnapshot &snapshot)
     {
      SRangeExitIntent exit_intent;
      m_strategy.EvaluateExit(position_type,exit_intent);
      snapshot.data_valid=(exit_intent.bar_time>0);
      snapshot.gate_reason=exit_intent.reason;
      if(exit_intent.bar_time<=0)
         return;
      if(exit_intent.bar_time<=opened_at)
        {
         snapshot.gate_reason="Awaiting a completed bar after the position entry.";
         return;
        }
      if(!exit_intent.should_close)
         return;
      if(exit_intent.bar_time==m_last_processed_exit_bar_time)
        {
         snapshot.gate_reason="A close request was already attempted for this completed bar.";
         return;
        }

      m_last_processed_exit_bar_time=exit_intent.bar_time;
      m_last_order_request_at=TimeCurrent();
      m_last_global_execution_at=m_last_order_request_at;
      snapshot.last_order_request_at=m_last_order_request_at;
      m_trade_logger.InfoOnce(StringFormat("[PIPELINE] Close=REQUESTED;position=%I64u.",
                                           position_ticket));

      SOrderExecutionResult close_result;
      if(m_order_executor.ClosePosition(position_ticket,close_result))
        {
         m_successful_close_count++;
         m_last_execution_result="CLOSE_ACCEPTED: "+close_result.description;
         m_trade_logger.InfoOnce("[PIPELINE] Close=ACCEPTED;"+close_result.description);
        }
      else
        {
         m_failed_close_count++;
         m_last_execution_result="CLOSE_REJECTED: "+close_result.description;
         m_trade_logger.ErrorOnce("[PIPELINE] Close=REJECTED;"+close_result.description);
        }
      m_close_retry_count+=close_result.retry_count;
      m_last_execution_retcode=close_result.retcode;
      m_last_execution_deal_ticket=close_result.deal_ticket;
      snapshot.last_execution_result=m_last_execution_result;
      snapshot.last_execution_retcode=m_last_execution_retcode;
      snapshot.last_execution_deal_ticket=m_last_execution_deal_ticket;
      snapshot.gate_reason=exit_intent.reason;
     }

   bool PublishSnapshot(const SExecutionSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);
      bool success=true;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_EXECUTION_GATE_ALLOWED,
                                   (snapshot.gate_allowed ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_EXECUTION_GATE_REASON,snapshot.gate_reason)) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_ENTRY_SIGNAL,snapshot.entry_signal)) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_ENTRY_SIGNAL_SCORE,
                                   DoubleToString(snapshot.entry_signal_score,2))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_ENTRY_SIGNAL_CONFIDENCE,
                                   DoubleToString(snapshot.entry_signal_confidence,2))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_REQUESTED_DIRECTION,snapshot.requested_direction)) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_REQUESTED_VOLUME,
                                   DoubleToString(snapshot.requested_volume,2))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_REQUESTED_ENTRY_PRICE,
                                   DoubleToString(snapshot.requested_entry_price,(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS)))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_REQUESTED_STOP_LOSS,
                                   DoubleToString(snapshot.requested_stop_loss,(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS)))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_REQUESTED_TAKE_PROFIT,
                                   DoubleToString(snapshot.requested_take_profit,(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS)))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_DUPLICATE_ORDER_BLOCKED,
                                   (snapshot.duplicate_blocked ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_EXISTING_POSITION_DETECTED,
                                   (snapshot.existing_position_detected ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_LAST_ORDER_REQUEST_AT,
                                   TimeToString(snapshot.last_order_request_at,TIME_DATE|TIME_SECONDS))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_LAST_EXECUTION_RESULT,snapshot.last_execution_result)) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_LAST_EXECUTION_RETCODE,
                                   StringFormat("%I64d",snapshot.last_execution_retcode))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_LAST_EXECUTION_DEAL_TICKET,
                                   StringFormat("%I64d",snapshot.last_execution_deal_ticket))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_EXECUTION_DATA_VALID,
                                   (snapshot.data_valid ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_EXECUTION,m_symbol,
                                   FENX_DATABUS_FIELD_EXECUTION_UPDATED_AT,
                                   TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS))) success=false;
      return(success);
     }

   bool PublishGlobal(const SExecutionSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);
      const int open_fenx_positions=m_position_manager.CountFeNXPositions();
      bool success=true;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_EXECUTION_SYSTEM_ENABLED,
                             (m_execution_enabled ? "true" : "false"))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_EXECUTION_SYSTEM_READY,
                             (m_ready ? "true" : "false"))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_EXECUTION_SYSTEM_VALID,
                             (snapshot.data_valid ? "true" : "false"))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_EXECUTION_OPEN_POSITION_COUNT,
                             IntegerToString(open_fenx_positions))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_EXECUTION_SUCCESSFUL_ORDER_COUNT,
                             IntegerToString(m_successful_order_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_EXECUTION_FAILED_ORDER_COUNT,
                             IntegerToString(m_failed_order_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_EXECUTION_BLOCKED_ORDER_COUNT,
                             IntegerToString(m_blocked_order_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_EXECUTION_LAST_GLOBAL_AT,
                             TimeToString(m_last_global_execution_at,TIME_DATE|TIME_SECONDS))) success=false;
      return(success);
     }

public:
                     CExecutionEngine(void)
     {
      SetName("ExecutionEngine");
      m_execution_enabled=false;
      m_ready=false;
      m_symbol="USDJPY";
      m_magic_number=0;
      m_fixed_lot=0.0;
      m_exit_mode="";
      m_fixed_take_profit_points=0.0;
      m_fixed_stop_loss_points=0.0;
      m_range_stop_buffer_points=0.0;
      m_maximum_open_positions=0;
      m_trade_comment="";
      m_last_processed_bar_time=0;
      m_last_order_request_at=0;
      m_last_global_execution_at=0;
      m_last_execution_result="No execution request has been sent.";
      m_last_execution_retcode=0;
      m_last_execution_deal_ticket=0;
      m_successful_order_count=0;
      m_failed_order_count=0;
      m_blocked_order_count=0;
      m_successful_close_count=0;
      m_failed_close_count=0;
      m_entry_retry_count=0;
      m_close_retry_count=0;
      m_entry_signal_count=0;
      m_entry_block_event_count=0;
      m_no_signal_bar_count=0;
      m_position_open_event_count=0;
      m_position_close_event_count=0;
      m_minimum_volume_adjustment_count=0;
      m_update_count=0;
      for(int stage=0;stage<FENX_PIPELINE_STAGE_COUNT;stage++)
        {
         m_pipeline_block_ticks[stage]=0;
         m_pipeline_block_events[stage]=0;
        }
      m_last_pipeline_stage=FENX_PIPELINE_EXECUTION;
      m_last_pipeline_stage_reason="";
      m_last_pipeline_blocked=false;
      m_last_observed_fenx_position_count=0;
      m_last_processed_exit_bar_time=0;
      m_last_blocked_reason="";
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);
      if(m_state_manager==NULL)
        {
         CLogger::Error("ExecutionEngine requires StateManager injection.");
         CBaseEngine::Shutdown();
         return(false);
        }
      m_execution_enabled=parameters.ExecutionEnabled();
      m_symbol=parameters.ExecutionSymbol();
      m_magic_number=parameters.ExecutionMagicNumber();
      m_fixed_lot=parameters.ExecutionFixedLot();
      m_exit_mode=parameters.ExecutionExitMode();
      m_fixed_take_profit_points=parameters.ExecutionFixedTakeProfitPoints();
      m_fixed_stop_loss_points=parameters.ExecutionFixedStopLossPoints();
      m_range_stop_buffer_points=parameters.ExecutionRangeStopBufferPoints();
      m_maximum_open_positions=parameters.ExecutionMaximumOpenPositionsPerSymbol();
      m_trade_comment=parameters.ExecutionTradeComment();
      m_ready=(m_symbol=="USDJPY" && m_magic_number>0 && m_fixed_lot>0.0 &&
               (m_exit_mode=="RANGE_BASED" || m_exit_mode=="FIXED_POINTS") &&
               m_fixed_take_profit_points>0.0 && m_fixed_stop_loss_points>0.0 &&
               m_range_stop_buffer_points>=0.0 && m_maximum_open_positions==1 &&
               StringLen(m_trade_comment)>0);
      if(!m_ready)
        {
         CLogger::Error("ExecutionEngine received invalid minimal execution configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      m_gate.Configure(data_bus,m_state_manager,m_symbol,m_execution_enabled,
                       parameters.ExecutionMaximumSpreadPoints(),
                       parameters.ExecutionMinimumRangeScore(),
                       parameters.ExecutionMinimumStrategyConfidence(),
                       parameters.ExecutionMinimumRiskConfidence(),
                       parameters.RiskStaleDataLimitSeconds());
      m_strategy.Configure(data_bus,m_symbol,parameters.ExecutionEntryBoundaryDistancePoints(),
                           parameters.ExecutionEntryBoundaryDistanceAtrRatio(),
                           parameters.ExecutionMinimumRangeScore(),parameters.ExecutionAllowBuy(),
                           parameters.ExecutionAllowSell());
      m_duplicate_guard.Configure(parameters.ExecutionOrderCooldownSeconds(),
                                  parameters.ExecutionOneOrderPerBar());
      m_position_manager.Configure(m_symbol,m_magic_number);
      m_order_executor.Configure(m_magic_number,parameters.ExecutionMaximumSlippagePoints(),
                                  parameters.ExecutionTransientRetryLimit(),m_fixed_lot);
      CLogger::Info(StringFormat("ExecutionEngine initialized for %s; execution is %s.",m_symbol,
                                 (m_execution_enabled ? "ENABLED" : "DISABLED")));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;
      m_update_count++;

      SExecutionSnapshot snapshot;
      ResetSnapshot(snapshot);
      ObservePositionCount();
      snapshot.existing_position_detected=m_position_manager.HasAnyPositionOnSymbol();

      if(!m_execution_enabled)
        {
         snapshot.data_valid=true;
         snapshot.gate_reason="Execution is disabled by configuration.";
         PublishSnapshot(snapshot);
         PublishGlobal(snapshot);
         return;
        }

      ulong position_ticket=0;
      ENUM_POSITION_TYPE position_type=POSITION_TYPE_BUY;
      datetime position_opened_at=0;
      if(m_position_manager.TryGetFeNXPosition(position_ticket,position_type,position_opened_at))
        {
         ManageOpenPosition(position_ticket,position_type,position_opened_at,snapshot);
         PublishSnapshot(snapshot);
         PublishGlobal(snapshot);
         return;
        }

      MqlTick tick;
      double spread_points=-1.0;
      string tick_reason="";
      const bool tick_valid=GetTickAndSpread(tick,spread_points,tick_reason);
      SExecutionGateResult gate_result;
      m_gate.Evaluate((tick_valid ? spread_points : -1.0),gate_result);
      RecordPipelineResult(gate_result);
      snapshot.gate_allowed=gate_result.allowed;
      snapshot.data_valid=gate_result.data_valid;
      snapshot.gate_reason=gate_result.reason;
      if(!tick_valid)
        {
         RecordBlocked(tick_reason,snapshot);
         PublishSnapshot(snapshot);
         PublishGlobal(snapshot);
         return;
        }
      if(!gate_result.allowed)
        {
         m_trade_logger.WarningOnce("Execution Gate blocked: "+gate_result.reason);
         PublishSnapshot(snapshot);
         PublishGlobal(snapshot);
         return;
        }

      string position_reason="";
      if(!m_position_manager.CanOpenNewPosition(m_maximum_open_positions,position_reason))
        {
         snapshot.existing_position_detected=true;
         RecordBlocked(position_reason,snapshot);
         PublishSnapshot(snapshot);
         PublishGlobal(snapshot);
         return;
        }

      SRangeEntryIntent intent;
      m_strategy.Evaluate(intent);
      snapshot.entry_signal=(intent.has_signal ? DirectionName(intent.direction) : "NONE");
      snapshot.entry_signal_score=intent.score;
      snapshot.entry_signal_confidence=intent.confidence;
      if(intent.bar_time<=0)
        {
         RecordBlocked(intent.reason,snapshot);
         PublishSnapshot(snapshot);
         PublishGlobal(snapshot);
         return;
        }
      if(intent.bar_time==m_last_processed_bar_time)
        {
         snapshot.gate_reason="Awaiting a new completed bar before another entry evaluation.";
         PublishSnapshot(snapshot);
         PublishGlobal(snapshot);
         return;
        }
      m_last_processed_bar_time=intent.bar_time;
      if(!intent.has_signal)
        {
         m_no_signal_bar_count++;
         snapshot.gate_reason=intent.reason;
         m_trade_logger.InfoOnce("[PIPELINE] Execution=NO_SIGNAL;"+intent.reason);
         PublishSnapshot(snapshot);
         PublishGlobal(snapshot);
         return;
        }
      m_entry_signal_count++;

      SOrderRequest request;
      string request_reason="";
      if(!BuildRequest(intent,tick,gate_result.allocation_multiplier,request,request_reason))
        {
         FillRequestFields(request,snapshot);
         RecordEntryBlocked("BuildRequest",request_reason,snapshot);
         PublishSnapshot(snapshot);
         PublishGlobal(snapshot);
         return;
        }
      SOrderRequest normalized_request;
      if(!m_order_executor.Prepare(request,normalized_request,request_reason))
        {
         FillRequestFields(request,snapshot);
         RecordEntryBlocked("OrderPreparation",request_reason,snapshot);
         PublishSnapshot(snapshot);
         PublishGlobal(snapshot);
         return;
        }
      if(normalized_request.volume>request.volume+0.00000001)
        {
         m_minimum_volume_adjustment_count++;
         m_trade_logger.InfoOnce(StringFormat(
            "[PIPELINE] Volume=BROKER_MINIMUM_ADJUSTMENT;requested=%.8f;normalized=%.8f;configured_ceiling=%.8f",
            request.volume,normalized_request.volume,m_fixed_lot));
        }
      FillRequestFields(normalized_request,snapshot);
      const double price_tolerance=SymbolInfoDouble(m_symbol,SYMBOL_POINT);
      if(m_duplicate_guard.IsBlocked(normalized_request,price_tolerance,request_reason))
        {
         snapshot.duplicate_blocked=true;
         RecordEntryBlocked("DuplicateGuard",request_reason,snapshot);
         PublishSnapshot(snapshot);
         PublishGlobal(snapshot);
         return;
        }

      m_duplicate_guard.MarkAttempt(normalized_request);
      m_last_order_request_at=TimeCurrent();
      m_last_global_execution_at=m_last_order_request_at;
      snapshot.last_order_request_at=m_last_order_request_at;
      m_trade_logger.InfoOnce("[PIPELINE] Order=REQUESTED;"+
                              normalized_request.request_identifier);
      SOrderExecutionResult execution_result;
      if(m_order_executor.Send(normalized_request,execution_result))
        {
         m_successful_order_count++;
         m_last_execution_result="ACCEPTED: "+execution_result.description;
         m_trade_logger.InfoOnce("[PIPELINE] Order=ACCEPTED;Execution order accepted: "+
                                 execution_result.description);
        }
      else
        {
         m_failed_order_count++;
         m_last_execution_result="REJECTED: "+execution_result.description;
         m_trade_logger.ErrorOnce("[PIPELINE] Order=REJECTED;Execution order rejected: "+
                                  execution_result.description);
        }
      m_entry_retry_count+=execution_result.retry_count;
      m_last_execution_retcode=execution_result.retcode;
      m_last_execution_deal_ticket=execution_result.deal_ticket;
      snapshot.last_execution_result=m_last_execution_result;
      snapshot.last_execution_retcode=m_last_execution_retcode;
      snapshot.last_execution_deal_ticket=m_last_execution_deal_ticket;
      PublishSnapshot(snapshot);
      PublishGlobal(snapshot);
     }

   virtual void       Shutdown(void)
     {
      CLogger::Info(StringFormat("ExecutionEngine shutdown: entries %d successful, %d failed, %d blocked; closes %d successful, %d failed.",
                                 m_successful_order_count,m_failed_order_count,m_blocked_order_count,
                                 m_successful_close_count,m_failed_close_count));
      CLogger::Info(StringFormat("[BACKTEST_EXECUTION] updates=%I64d;entry_signals=%d;entry_blocks=%d;no_signal_bars=%d;orders_requested=%d;orders_accepted=%d;orders_rejected=%d;closes_requested=%d;closes_accepted=%d;closes_rejected=%d;entry_retries=%d;close_retries=%d;position_open_events=%d;position_close_events=%d;minimum_volume_adjustments=%d",
                                 m_update_count,m_entry_signal_count,m_entry_block_event_count,
                                 m_no_signal_bar_count,
                                 m_successful_order_count+m_failed_order_count,
                                 m_successful_order_count,m_failed_order_count,
                                 m_successful_close_count+m_failed_close_count,
                                 m_successful_close_count,m_failed_close_count,
                                 m_entry_retry_count,m_close_retry_count,m_position_open_event_count,
                                 m_position_close_event_count,m_minimum_volume_adjustment_count));
      for(int stage=0;stage<FENX_PIPELINE_STAGE_COUNT;stage++)
        {
         CLogger::Info(StringFormat("[BACKTEST_PIPELINE] stage=%s;blocked_ticks=%I64d;block_events=%I64d",
                                    FenxPipelineStageName((ENUM_FENX_PIPELINE_STAGE)stage),
                                    m_pipeline_block_ticks[stage],
                                    m_pipeline_block_events[stage]));
        }
      m_strategy.LogTask007Summary();
      m_duplicate_guard.Reset();
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_EXECUTION_ENGINE_MQH
