//+------------------------------------------------------------------+
//|                                                      Akshay_TheOne_EA.mq5 |
//|                        © Options_Series                          |
//|                                                                  |
//| This Expert Advisor is subject to the terms of the Mozilla       |
//| Public License 2.0 at https://mozilla.org/MPL/2.0/               |
//+------------------------------------------------------------------+
#property copyright "© Options_Series"
#property link      "https://mozilla.org/MPL/2.0/"
#property license   "Mozilla Public License 2.0"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+

// Supertrend Parameters
input int    ST_AtrPeriod = 10;                     // ATR Length
input double ST_Factor = 3.0;                       // Factor

// HalfTrend Parameters
input int    HT_Amplitude = 2;                      // Amplitude
input int    HT_ChannelDeviation = 2;               // Channel Deviation

// Ichimoku Cloud Parameters
input int    IC_ConversionPeriods = 5;              // Conversion Periods
input int    IC_BasePeriods = 24;                   // Base Periods
input int    IC_LaggingSpan2Periods = 48;           // Lagging Span 2 Periods
input int    IC_Displacement = 24;                  // Displacement

// Price Oscillator Parameters
input int    shortlen_PPO = 12;                     // Price Osc - Short Length
input int    longlen_PPO = 26;                      // Price Osc - Long Length

// Chaikin Oscillator Parameters
input int    short_Chaikin_Osc = 3;                 // Chaikin Osc - Fast Length
input int    long_Chaikin_Osc = 10;                 // Chaikin Osc - Slow Length

// Ultimate Oscillator Parameters
input int    length1_UO = 7;                        // Ultimate Osc - Fast Length
input int    length2_UO = 14;                       // Ultimate Osc - Middle Length
input int    length3_UO = 28;                       // Ultimate Osc - Slow Length

// SMI Ergodic Oscillator Parameters
input int    longlen_SMIO = 20;                     // SMI Ergodic Osc - Long Length
input int    shortlen_SMIO = 5;                     // SMI Ergodic Osc - Short Length
input int    siglen_SMIO = 5;                       // SMI Ergodic Osc - Signal Line Length

// Chande Momentum Oscillator Parameters
input int    length_ChandeMO = 9;                   // Chande Momentum Osc - ChandeMO Length

// Detrended Price Oscillator Parameters
input int    period_DPO = 21;                       // Detrended Price Osc Length

// Money Flow Index Parameters
input int    length_MFI = 14;                       // Money Flow Index Length

// Trading Parameters
input double LotSize = 0.01;                        // Lot Size
input int    StopLoss = 100;                        // Stop Loss in points
input int    TakeProfit = 200;                      // Take Profit in points
input int    MagicNumber = 12345;                   // Magic Number for trades

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
int handle_supertrend;
int handle_half_trend;
int handle_ichimoku;
int handle_ppo;
int handle_chaikin;
int handle_ultimate;
int handle_smi;
int handle_chande;
int handle_dpo;
int handle_mfi;

double supertrend_buffer[];
double half_trend_buffer[];
double ichimoku_tenkan[];
double ichimoku_kijun[];
double ichimoku_senkou_a[];
double ichimoku_senkou_b[];
double ppo_buffer[];
double chaikin_buffer[];
double ultimate_buffer[];
double smi_buffer[];
double chande_buffer[];
double dpo_buffer[];
double mfi_buffer[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize indicator handles
   handle_supertrend = iCustom(_Symbol, PERIOD_CURRENT, "Supertrend", ST_AtrPeriod, ST_Factor);
   handle_half_trend = iCustom(_Symbol, PERIOD_CURRENT, "HalfTrend", HT_Amplitude, HT_ChannelDeviation);
   handle_ichimoku = iIchimoku(_Symbol, PERIOD_CURRENT, IC_ConversionPeriods, IC_BasePeriods, IC_LaggingSpan2Periods, IC_Displacement);
   handle_ppo = iPPO(_Symbol, PERIOD_CURRENT, shortlen_PPO, longlen_PPO, PRICE_CLOSE);
   handle_chaikin = iChaikin(_Symbol, PERIOD_CURRENT, short_Chaikin_Osc, long_Chaikin_Osc);
   handle_ultimate = iUltimate(_Symbol, PERIOD_CURRENT, length1_UO, length2_UO, length3_UO);
   handle_smi = iCustom(_Symbol, PERIOD_CURRENT, "SMI Ergodic Oscillator", longlen_SMIO, shortlen_SMIO, siglen_SMIO);
   handle_chande = iCustom(_Symbol, PERIOD_CURRENT, "Chande Momentum Oscillator", length_ChandeMO);
   handle_dpo = iCustom(_Symbol, PERIOD_CURRENT, "Detrended Price Oscillator", period_DPO);
   handle_mfi = iMFI(_Symbol, PERIOD_CURRENT, length_MFI);
   
   // Check if handles are valid
   if(handle_supertrend == INVALID_HANDLE || handle_half_trend == INVALID_HANDLE || 
      handle_ichimoku == INVALID_HANDLE || handle_ppo == INVALID_HANDLE ||
      handle_chaikin == INVALID_HANDLE || handle_ultimate == INVALID_HANDLE ||
      handle_smi == INVALID_HANDLE || handle_chande == INVALID_HANDLE ||
      handle_dpo == INVALID_HANDLE || handle_mfi == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return(INIT_FAILED);
   }
   
   // Set arrays as series
   ArraySetAsSeries(supertrend_buffer, true);
   ArraySetAsSeries(half_trend_buffer, true);
   ArraySetAsSeries(ichimoku_tenkan, true);
   ArraySetAsSeries(ichimoku_kijun, true);
   ArraySetAsSeries(ichimoku_senkou_a, true);
   ArraySetAsSeries(ichimoku_senkou_b, true);
   ArraySetAsSeries(ppo_buffer, true);
   ArraySetAsSeries(chaikin_buffer, true);
   ArraySetAsSeries(ultimate_buffer, true);
   ArraySetAsSeries(smi_buffer, true);
   ArraySetAsSeries(chande_buffer, true);
   ArraySetAsSeries(dpo_buffer, true);
   ArraySetAsSeries(mfi_buffer, true);
   
   Print("Expert Advisor initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(handle_supertrend != INVALID_HANDLE) IndicatorRelease(handle_supertrend);
   if(handle_half_trend != INVALID_HANDLE) IndicatorRelease(handle_half_trend);
   if(handle_ichimoku != INVALID_HANDLE) IndicatorRelease(handle_ichimoku);
   if(handle_ppo != INVALID_HANDLE) IndicatorRelease(handle_ppo);
   if(handle_chaikin != INVALID_HANDLE) IndicatorRelease(handle_chaikin);
   if(handle_ultimate != INVALID_HANDLE) IndicatorRelease(handle_ultimate);
   if(handle_smi != INVALID_HANDLE) IndicatorRelease(handle_smi);
   if(handle_chande != INVALID_HANDLE) IndicatorRelease(handle_chande);
   if(handle_dpo != INVALID_HANDLE) IndicatorRelease(handle_dpo);
   if(handle_mfi != INVALID_HANDLE) IndicatorRelease(handle_mfi);
   
   Print("Expert Advisor deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update indicator data
   if(!UpdateIndicators())
      return;
   
   // Check for trading signals
   CheckForSignals();
}

//+------------------------------------------------------------------+
//| Update all indicator data                                        |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   // Copy Supertrend data
   if(CopyBuffer(handle_supertrend, 0, 0, 3, supertrend_buffer) < 3)
      return false;
   
   // Copy HalfTrend data
   if(CopyBuffer(handle_half_trend, 0, 0, 3, half_trend_buffer) < 3)
      return false;
   
   // Copy Ichimoku data
   if(CopyBuffer(handle_ichimoku, 0, 0, 3, ichimoku_tenkan) < 3 ||
      CopyBuffer(handle_ichimoku, 1, 0, 3, ichimoku_kijun) < 3 ||
      CopyBuffer(handle_ichimoku, 2, 0, 3, ichimoku_senkou_a) < 3 ||
      CopyBuffer(handle_ichimoku, 3, 0, 3, ichimoku_senkou_b) < 3)
      return false;
   
   // Copy PPO data
   if(CopyBuffer(handle_ppo, 0, 0, 3, ppo_buffer) < 3)
      return false;
   
   // Copy Chaikin data
   if(CopyBuffer(handle_chaikin, 0, 0, 3, chaikin_buffer) < 3)
      return false;
   
   // Copy Ultimate Oscillator data
   if(CopyBuffer(handle_ultimate, 0, 0, 3, ultimate_buffer) < 3)
      return false;
   
   // Copy SMI data
   if(CopyBuffer(handle_smi, 0, 0, 3, smi_buffer) < 3)
      return false;
   
   // Copy Chande data
   if(CopyBuffer(handle_chande, 0, 0, 3, chande_buffer) < 3)
      return false;
   
   // Copy DPO data
   if(CopyBuffer(handle_dpo, 0, 0, 3, dpo_buffer) < 3)
      return false;
   
   // Copy MFI data
   if(CopyBuffer(handle_mfi, 0, 0, 3, mfi_buffer) < 3)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check for trading signals                                        |
//+------------------------------------------------------------------+
void CheckForSignals()
{
   // Check if we already have open positions
   if(PositionsTotal() > 0)
      return;
   
   // Get current price
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Simple signal logic (you can modify this based on your strategy)
   bool buy_signal = false;
   bool sell_signal = false;
   
   // Example signal logic using Supertrend and Ichimoku
   if(supertrend_buffer[0] < current_price && // Price above Supertrend
      ichimoku_tenkan[0] > ichimoku_kijun[0] && // Tenkan above Kijun
      mfi_buffer[0] < 80) // MFI not overbought
   {
      buy_signal = true;
   }
   
   if(supertrend_buffer[0] > current_price && // Price below Supertrend
      ichimoku_tenkan[0] < ichimoku_kijun[0] && // Tenkan below Kijun
      mfi_buffer[0] > 20) // MFI not oversold
   {
      sell_signal = true;
   }
   
   // Execute trades
   if(buy_signal)
      OpenBuyOrder();
   else if(sell_signal)
      OpenSellOrder();
}

//+------------------------------------------------------------------+
//| Open a buy order                                                 |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = ask - StopLoss * _Point;
   double tp = ask + TakeProfit * _Point;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 5;
   request.magic = MagicNumber;
   request.comment = "Akshay_TheOne_EA Buy";
   request.type_filling = ORDER_FILLING_FOK;
   
   if(!OrderSend(request, result))
      Print("Error opening buy order: ", GetLastError());
   else
      Print("Buy order opened successfully");
}

//+------------------------------------------------------------------+
//| Open a sell order                                                |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = bid + StopLoss * _Point;
   double tp = bid - TakeProfit * _Point;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = bid;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 5;
   request.magic = MagicNumber;
   request.comment = "Akshay_TheOne_EA Sell";
   request.type_filling = ORDER_FILLING_FOK;
   
   if(!OrderSend(request, result))
      Print("Error opening sell order: ", GetLastError());
   else
      Print("Sell order opened successfully");
}