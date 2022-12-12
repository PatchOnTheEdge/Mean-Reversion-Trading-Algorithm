//+------------------------------------------------------------------+
//|                                                    MeanReversion |
//|                                                     MoneyMachine |
//|                                     https://moneymachine.monster |
//|                        ATTENTION!                                |
//| So far, this algorithm needs a big deposit to work!              |
//| Backtest with 100k initial deposit worked great on the DAX Index |                                              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Patrick Probst"
#property link      "http://moneymachine.monster"
#property version   "1.00"

#include <Trade\Trade.mqh>

input double MaximumRisk            = 0.001;     // Maximum Risk in percentage
input int    MovingPeriodLongOpen   = 90;       // Moving Average period long open
input int    MovingShiftLongOpen    = 0;        // Moving Average shift long open
input int    HourStart              = 0;        // start hour Nas: 0/1 - 18/19
input int    HourStop               = 24;       // stop hour Dax 8 - 22
input int    TradeDistanceStart     = 10;       // Distance between Trades
input int    TradeDistanceIncFactor = 2;        // Multiplier for Trade Distance

//---
int    ExtHandleLongOpen=0;
bool   ExtHedging=false;
CTrade ExtTrade;

#define MA_MAGIC 007
//+------------------------------------------------------------------+
//| Calculate optimal lot size                                       |
//+------------------------------------------------------------------+
double TradeSizeOptimized(ENUM_ORDER_TYPE order_type)
  {
//check if there are open Trades
// if so, the lot size is the size of the last trade multiplied with 2
// if not, the lot size is the Initial Lot size
   double price=0.0;
   double margin=0.0;
//--- select lot size
   if(!SymbolInfoDouble(_Symbol,SYMBOL_ASK,price))
      return(0.0);
   if(!OrderCalcMargin(order_type,_Symbol,10,price,margin))
      return(0.0);
   if(margin<=0.0)
      return(0.0);
   double step_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   int open_positions = CountOpenPositions(order_type);

   double margin_at_risk = AccountInfoDouble(ACCOUNT_MARGIN_FREE)*MaximumRisk;
   double lot=NormalizeDouble(margin_at_risk/margin,2);
   lot = step_vol * NormalizeDouble(lot/step_vol,0);

   double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lot < min_vol)
      lot = min_vol;

   if(open_positions > 0)
      lot = NormalizeDouble(lot * MathPow(2,open_positions),2);

   return(lot);
  }
//+------------------------------------------------------------------+
//| Check for open position conditions                               |
//+------------------------------------------------------------------+
void CheckForOpen(void)
  {
   MqlRates rt[1];
//--- go trading only for first ticks of new bar
   if(CopyRates(_Symbol,_Period,0,1,rt)!=1)
     {
      Print("CopyRates of ",_Symbol," failed, no history");
      return;
     }
   if(rt[0].tick_volume>1)
      return;

//--- get current Moving Average
   double   ma[1];
   if(CopyBuffer(ExtHandleLongOpen,0,0,1,ma)!=1)
     {
      Print("CopyBuffer from iMA failed, no data");
      return;
     }
//--- check signals
   ENUM_ORDER_TYPE signal=WRONG_VALUE;

   if(rt[0].close<=ma[0])
      signal=ORDER_TYPE_BUY;    // buy conditions
   if(rt[0].close>ma[0])
      signal=ORDER_TYPE_SELL;    // buy conditions
//check if distance to last trade is big enough
   if(!CheckDistanceToNextPosition(signal))
      signal = WRONG_VALUE;
//--- additional checking
   if(signal!=WRONG_VALUE)
     {
      if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && Bars(_Symbol,_Period)>100)
         ExtTrade.PositionOpen(_Symbol,signal,TradeSizeOptimized(signal),
                               SymbolInfoDouble(_Symbol,signal==ORDER_TYPE_SELL ? SYMBOL_BID:SYMBOL_ASK),
                               0,0);
     }
//---
  }
//+------------------------------------------------------------------+
//| Check for close position conditions                              |
//+------------------------------------------------------------------+
void CheckForClose(void)
  {
   MqlRates rt[1];
//--- go trading only for first ticks of new bar
   if(CopyRates(_Symbol,_Period,0,1,rt)!=1)
     {
      Print("CopyRates of ",_Symbol," failed, no history");
      return;
     }
   if(rt[0].tick_volume>1)
      return;
//--- get current Moving Average
   double   ma[1];
   if(CopyBuffer(ExtHandleLongOpen,0,0,1,ma)!=1)
     {
      Print("CopyBuffer from iMA failed, no data");
      return;
     }
//--- positions already selected before
   bool signal=false;
   ENUM_POSITION_TYPE type= WRONG_VALUE;

   if(rt[0].close>ma[0])
     {
      signal=true;
      type = POSITION_TYPE_BUY;
     }
   if(rt[0].close<ma[0])
     {
      signal=true;
      type = POSITION_TYPE_SELL;
     }
   if(type==(long)POSITION_TYPE_SELL && rt[0].open<ma[0] && rt[0].close>ma[0])
      signal=true;
//--- additional checking
   if(signal)
     {
      if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && Bars(_Symbol,_Period)>100)
         CloseAllProfitablePositions(type);
     }
//---
  }
//+------------------------------------------------------------------+
//| Position select depending on netting or hedging                  |
//+------------------------------------------------------------------+
bool SelectPosition()
  {
   bool res=false;
//--- check position in Hedging mode
   if(ExtHedging)
     {
      uint total=PositionsTotal();
      for(uint i=0; i<total; i++)
        {
         string position_symbol=PositionGetSymbol(i);
         if(_Symbol==position_symbol && MA_MAGIC==PositionGetInteger(POSITION_MAGIC))
           {
            res=true;
            break;
           }
        }
     }
//--- check position in Netting mode
   else
     {
      if(!PositionSelect(_Symbol))
         return(false);
      else
         return(PositionGetInteger(POSITION_MAGIC)==MA_MAGIC); //---check Magic number
     }
//--- result for Hedging mode
   return(res);
  }
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(void)
  {
//--- prepare trade class to control positions if hedging mode is active
   ExtHedging=((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   ExtTrade.SetExpertMagicNumber(MA_MAGIC);
   ExtTrade.SetMarginMode();
   ExtTrade.SetTypeFillingBySymbol(Symbol());
//--- Moving Average indicator
   ExtHandleLongOpen=iMA(_Symbol,_Period,MovingPeriodLongOpen,MovingPeriodLongOpen,MODE_EMA,PRICE_CLOSE);

//--- ok
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(void)
  {
//---
   if(SelectPosition())
      CheckForClose();

   CheckForOpen();
//---
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }
//+------------------------------------------------------------------+
//| Check if the time is between the given bounds                    |
//+------------------------------------------------------------------+
bool isTradingTime(void)
  {
   datetime current = TimeTradeServer();
   MqlDateTime stm;
   TimeToStruct(current,stm);
   if(stm.hour >= HourStart && stm.hour <= HourStop)
      return true;
   return false;
  }


//+------------------------------------------------------------------+
//| Closes all if average is profitable                              |
//+------------------------------------------------------------------+
void CloseAllProfitablePositions(int type)
  {
   int positions=PositionsTotal();
   double avg_profit = 0;

   for(int i=positions-1; i>=0; i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0)
        {
         Print("HistoryDealGetTicket failed, no trade history");
         break;
        }
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MA_MAGIC)
         continue;
      if(PositionGetInteger(POSITION_TYPE) != type)
         continue;
      avg_profit += PositionGetDouble(POSITION_PROFIT);

     }
   if(avg_profit > 0)
     {
      for(int i=positions-1; i>=0; i--)
        {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0)
           {
            Print("HistoryDealGetTicket failed, no trade history");
            break;
           }
         if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC)!=MA_MAGIC)
            continue;
         if(PositionGetInteger(POSITION_TYPE) != type)
            continue;
         ExtTrade.PositionClose(ticket);
        }
     }
  }

//+------------------------------------------------------------------+
//| Checks if the trade distance is within the rules                 |
//+------------------------------------------------------------------+
bool CheckDistanceToNextPosition(int type)
  {
   int positions=PositionsTotal();
   double smallest_distance = -1;
   int position_count=0;

   if(positions==0)
      return(true);

   for(int i=positions-1; i>=0; i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0)
        {
         Print("HistoryDealGetTicket failed, no trade history");
         break;
        }
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MA_MAGIC)
         continue;
      if(PositionGetInteger(POSITION_TYPE) != (ENUM_POSITION_TYPE)type)
         continue;
      position_count += 1;
      double distance = MathAbs(PositionGetDouble(POSITION_PRICE_OPEN) - PositionGetDouble(POSITION_PRICE_CURRENT));
      if(distance > smallest_distance)
         smallest_distance = distance;
     }
   if(smallest_distance >= TradeDistanceStart * MathPow(TradeDistanceIncFactor, position_count))
      return(true);

   return(false);
  }
//+------------------------------------------------------------------+
//| Count open Positions                                            |
//+------------------------------------------------------------------+
int CountOpenPositions(int order_type)
  {
   int positions=PositionsTotal();
   int open_positions = 0;

   for(int i=positions-1; i>=0; i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0)
        {
         Print("HistoryDealGetTicket failed, no trade history");
         break;
        }
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MA_MAGIC)
         continue;
      if(PositionGetInteger(POSITION_TYPE) == order_type)
         open_positions++;
     }
   return open_positions;
  }
//+------------------------------------------------------------------+
