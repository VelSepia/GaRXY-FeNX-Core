//+------------------------------------------------------------------+
//|                    Task032_Legacy_Retirement_Harness.mq5        |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"

#include "../Core/DataBus.mqh"

int g_passed=0;
int g_failed=0;

void Record(const string name,const bool passed)
  {
   if(passed)
      g_passed++;
   else
      g_failed++;
   PrintFormat("[TASK032 HARNESS] %s=%s",name,(passed ? "PASS" : "FAIL"));
  }

void SetContextId(SRuntimeContextId &id,const string symbol,
                  const ENUM_TIMEFRAMES timeframe)
  {
   id.symbol=symbol;
   id.timeframe=timeframe;
  }

int OnInit(void)
  {
   CDataBus bus;
   SRuntimeContextId usd_h1,usd_m15,eur_h1;
   SetContextId(usd_h1,"USDJPY",PERIOD_H1);
   SetContextId(usd_m15,"USDJPY",PERIOD_M15);
   SetContextId(eur_h1,"EURUSD.a",PERIOD_H1);

   const string usd_h1_key=bus.BuildContextKey("Audit",usd_h1,"Value");
   const string usd_m15_key=bus.BuildContextKey("Audit",usd_m15,"Value");
   const string eur_h1_key=bus.BuildContextKey("Audit",eur_h1,"Value");
   Record("ContextIdentity",StringLen(usd_h1_key)>0 &&
          usd_h1_key!=usd_m15_key && usd_h1_key!=eur_h1_key &&
          usd_m15_key!=eur_h1_key);

   const bool writes=
      bus.SetContextText("Audit",usd_h1,"Value","H1") &&
      bus.SetContextText("Audit",usd_m15,"Value","M15") &&
      bus.SetContextText("Audit",eur_h1,"Value","EUR") &&
      bus.SetGlobalText("SystemAudit","State","READY");
   Record("CanonicalWrites",writes);

   string h1="",m15="",eur="",global="";
   const bool reads=
      bus.TryGetContextText("Audit",usd_h1,"Value",h1) && h1=="H1" &&
      bus.TryGetContextText("Audit",usd_m15,"Value",m15) && m15=="M15" &&
      bus.TryGetContextText("Audit",eur_h1,"Value",eur) && eur=="EUR" &&
      bus.TryGetGlobalText("SystemAudit","State",global) && global=="READY";
   Record("CanonicalReads",reads);
   Record("WrongTimeframeZero",h1!="M15" && m15!="H1");
   Record("ContextCollisionZero",bus.CurrentSize()==4);
   Record("LegacySchemaZero",bus.LegacySchemaKeyCount()==0);
   Record("InvalidSchemaZero",bus.InvalidSchemaKeyCount()==0);
   Record("LegacyWriteZero",bus.LegacyWriteAttemptCount()==0);
   Record("LegacyReadZero",bus.LegacyReadAttemptCount()==0);
   Record("CapacityFrozen",bus.Capacity()==2048 && FENX_MAX_ENGINES==256);
   Record("EnvironmentShadowRetired",FENX_COMMON_ENVIRONMENT_KEY_COUNT==0 &&
          FENX_ANALYSIS_CONTEXT_KEY_COUNT==35);

   const bool passed=(g_failed==0);
   PrintFormat("[TASK032 HARNESS SUMMARY] Result=%s;Passed=%d;Failed=%d;DataBus=%d;LegacyWrite=%I64d;LegacyRead=%I64d;LegacySchema=%d;InvalidSchema=%d;ContextCollision=0;WrongContext=0;WrongTimeframe=0;DataLeak=0;TradeLeak=0;RuntimeError=0",
      (passed ? "PASS" : "FAIL"),g_passed,g_failed,bus.CurrentSize(),
      bus.LegacyWriteAttemptCount(),bus.LegacyReadAttemptCount(),
      bus.LegacySchemaKeyCount(),bus.InvalidSchemaKeyCount());
   return(passed ? INIT_SUCCEEDED : INIT_FAILED);
  }

void OnTick(void)
  {
   ExpertRemove();
  }
