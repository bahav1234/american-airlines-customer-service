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

#include <Trade/Trade.mqh>

// Helper function for RGB colors
color RGB(int r, int g, int b)
{
   return (r | (g << 8) | (b << 16));
}

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
input double LotSize = 0.01;                        // Lot size
input int    StopLoss = 100;                        // SL in points
input int    TakeProfit = 200;                      // TP in points
input int    MagicNumber = 123456;                  // Magic number for orders
input bool   UseTrailingStop = true;                // Enable trailing stop
input int    TrailStart = 100;                      // Start trailing after this many points in profit
input int    TrailStop = 100;                       // Trailing stop distance in points

// ORB Settings (First 5-min bar after market open)
input int    MarketOpenHour = 9;
input int    MarketOpenMinute = 15;

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade trade;

datetime lastSignalTime = 0;
bool buySignal = false, sellSignal = false;
int tradeDirection = 0;  // 0=none, 1=buy, -1=sell

// Colors
color GC_Candle = RGB(8, 153, 129);
color RC_Candle = RGB(247, 82, 95);
color Green_Bright = clrLime;
color Red_Bright = clrRed;
color Neutral = clrWhite;

// Indicator buffers (current values)
double MA5_Close, MA24_Close, MA50_Close, MA200_Close, VWAP_Close, RSI_Close, PVT_Close, ATR_Close, PSAR_Plot;
double HA_O, HA_H, HA_L, HA_C;
double ST_Supertrend, ST_Direction;
double HT_Ht;
double IC_ConversionLine, IC_BaseLine;
double firstCandleHigh, firstCandleLow;
bool firstCandleRecorded = false;
double kvo_KVO, po_PPO, ao_AO, osc_Chaikin_Osc, out_UO, osc_SMIO, chandeMO, dpo_DPO, mf_MFI, vwap_PVT;
double DIPlus, DIMinus, ADX_SMA;
double erg_SMIO = 0.0;

// State variables for HalfTrend
int HT_Trend = 0;
int HT_NextTrend = 0;
double HT_MaxLowPrice = 0.0;
double HT_MinHighPrice = 0.0;
double HT_Up = 0.0;
double HT_Down = 0.0;

// Master Candle counters
int MC_bull = 0, MC_bear = 0;
bool Int_MC_bull = false, Int_MC_bear = false, Int_MC_Scalp_bull = false, Int_MC_Scalp_bear = false;

//+------------------------------------------------------------------+
//| Indicator value helpers (MQL5 handles -> single value)          |
//+------------------------------------------------------------------+
double GetMAValue(int period, int shift, ENUM_MA_METHOD method, ENUM_APPLIED_PRICE price)
{
   int handle = iMA(_Symbol, PERIOD_CURRENT, period, 0, method, price);
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) != 1)
   {
      IndicatorRelease(handle);
      return 0.0;
   }
   IndicatorRelease(handle);
   return buf[0];
}

double GetEMA(int period, int shift, ENUM_APPLIED_PRICE price)
{
   return GetMAValue(period, shift, MODE_EMA, price);
}

double GetSMA(int period, int shift, ENUM_APPLIED_PRICE price)
{
   return GetMAValue(period, shift, MODE_SMA, price);
}

double GetRSI(int period, int shift, ENUM_APPLIED_PRICE price)
{
   int handle = iRSI(_Symbol, PERIOD_CURRENT, period, price);
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) != 1)
   {
      IndicatorRelease(handle);
      return 0.0;
   }
   IndicatorRelease(handle);
   return buf[0];
}

double GetATR(int period, int shift)
{
   int handle = iATR(_Symbol, PERIOD_CURRENT, period);
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) != 1)
   {
      IndicatorRelease(handle);
      return 0.0;
   }
   IndicatorRelease(handle);
   return buf[0];
}

double GetSAR(double step, double maximum, int shift)
{
   int handle = iSAR(_Symbol, PERIOD_CURRENT, step, maximum);
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) != 1)
   {
      IndicatorRelease(handle);
      return 0.0;
   }
   IndicatorRelease(handle);
   return buf[0];
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize state variables
   HT_MaxLowPrice = iLow(_Symbol, PERIOD_CURRENT, 1);
   HT_MinHighPrice = iHigh(_Symbol, PERIOD_CURRENT, 1);

   Comment("Akshay - TheOne, TheMostWanted, TheUnbeatable, TheEnd\nMT5 EA Loaded");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if (!IsNewBar()) return; // Only run on new bar

   // Reset signals
   buySignal = false;
   sellSignal = false;

   // 1. Calculate all indicators
   CalculateIndicators();

   // 2. Determine trade conditions
   DetermineTradeConditions();

   // Get current bar time
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);

   // 3. Execute trades
   if (Int_MC_bull && CheckCrossover() && lastSignalTime != barTime)
   {
      CloseOrders(ORDER_TYPE_SELL);
      ExecuteOrder(ORDER_TYPE_BUY);
      lastSignalTime = barTime;
      buySignal = true;
   }
   else if (Int_MC_bear && CheckCrossunder() && lastSignalTime != barTime)
   {
      CloseOrders(ORDER_TYPE_BUY);
      ExecuteOrder(ORDER_TYPE_SELL);
      lastSignalTime = barTime;
      sellSignal = true;
   }

   // 4. Manage trailing stop
   if (UseTrailingStop)
   {
      ManageTrailingStop();
   }

   // 5. Update chart objects
   UpdateChartObjects();

   // 6. Generate alerts
   if (buySignal)
   {
      Alert("Buy Signal Triggered");
   }
   else if (sellSignal)
   {
      Alert("Sell Signal Triggered");
   }
}

//+------------------------------------------------------------------+
//| Calculate all indicators                                         |
//+------------------------------------------------------------------+
void CalculateIndicators()
{
   // Get current price data
   double close0 = iClose(_Symbol, PERIOD_CURRENT, 0);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double high0 = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low0 = iLow(_Symbol, PERIOD_CURRENT, 0);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double open0 = iOpen(_Symbol, PERIOD_CURRENT, 0);
   long   volume0 = (long)iVolume(_Symbol, PERIOD_CURRENT, 0);

   // 1. Moving Averages and VWAP
   MA5_Close = GetEMA(5, 0, PRICE_CLOSE);
   MA24_Close = GetEMA(24, 0, PRICE_CLOSE);
   MA50_Close = GetEMA(50, 0, PRICE_CLOSE);
   MA200_Close = GetSMA(200, 0, PRICE_CLOSE);

   // VWAP calculation (simple rolling 100-bar VWAP)
   double sumPriceVolume = 0.0;
   double sumVolume = 0.0;
   for(int i = 0; i < 100; i++)
   {
      double price = (iHigh(_Symbol, PERIOD_CURRENT, i) + iLow(_Symbol, PERIOD_CURRENT, i) + iClose(_Symbol, PERIOD_CURRENT, i)) / 3.0;
      double vol = (double)iVolume(_Symbol, PERIOD_CURRENT, i);
      sumPriceVolume += price * vol;
      sumVolume += vol;
   }
   VWAP_Close = (sumVolume > 0.0 ? sumPriceVolume / sumVolume : 0.0);

   // RSI
   RSI_Close = GetRSI(14, 0, PRICE_CLOSE);

   // PVT
   static double prevPVT = 0;
   double pvtChange = (close0 - close1);
   PVT_Close = prevPVT + (close1 != 0.0 ? (pvtChange / close1) * (double)volume0 : 0.0);
   prevPVT = PVT_Close;

   // ATR
   ATR_Close = GetATR(14, 0);

   // Parabolic SAR
   PSAR_Plot = GetSAR(0.02, 0.2, 0);

   // Heikin Ashi candles
   double haClose = (open0 + high0 + low0 + close0) / 4.0;
   double haOpen = (iOpen(_Symbol, PERIOD_CURRENT, 1) + iClose(_Symbol, PERIOD_CURRENT, 1)) / 2.0;
   double haHigh = MathMax(MathMax(high0, haOpen), haClose);
   double haLow = MathMin(MathMin(low0, haOpen), haClose);

   HA_O = haOpen;
   HA_H = haHigh;
   HA_L = haLow;
   HA_C = haClose;

   // Supertrend (basic version)
   double atr = GetATR(ST_AtrPeriod, 0);
   double mid = (high0 + low0) / 2.0;
   double upperBand = mid + (ST_Factor * atr);
   double lowerBand = mid - (ST_Factor * atr);

   static double prevST_Supertrend = 0.0;
   if (close0 > prevST_Supertrend)
   {
      ST_Direction = 1; // Up
      ST_Supertrend = (prevST_Supertrend == 0.0 ? lowerBand : MathMax(lowerBand, prevST_Supertrend));
   }
   else
   {
      ST_Direction = -1; // Down
      ST_Supertrend = (prevST_Supertrend == 0.0 ? upperBand : MathMin(upperBand, prevST_Supertrend));
   }
   prevST_Supertrend = ST_Supertrend;

   // HalfTrend
   CalculateHalfTrend();

   // Ichimoku Cloud (conversion/base only)
   double highest5 = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, IC_ConversionPeriods, 0));
   double lowest5  = iLow(_Symbol,  PERIOD_CURRENT, iLowest (_Symbol, PERIOD_CURRENT, MODE_LOW,  IC_ConversionPeriods, 0));
   double highest24 = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, IC_BasePeriods, 0));
   double lowest24  = iLow(_Symbol,  PERIOD_CURRENT, iLowest (_Symbol, PERIOD_CURRENT, MODE_LOW,  IC_BasePeriods, 0));

   IC_ConversionLine = (highest5 + lowest5) / 2.0;
   IC_BaseLine = (highest24 + lowest24) / 2.0;

   // ORB - First 5-minute candle
   datetime now = TimeCurrent();
   int curHour = TimeHour(now);
   int curMinute = TimeMinute(now);
   if (!firstCandleRecorded && curHour == MarketOpenHour && curMinute == MarketOpenMinute)
   {
      firstCandleHigh = high0;
      firstCandleLow = low0;
      firstCandleRecorded = true;
   }
   else if (curHour == 0 && curMinute == 0)
   {
      // New day
      firstCandleRecorded = false;
   }

   // VWMA calculations
   double vwma74 = CalculateVWMA(74);
   double vwma149 = CalculateVWMA(149);

   // King of Oscillators
   // Klinger Oscillator (simplified)
   double sv_KVO = (close0 >= close1 ? (double)volume0 : -(double)volume0);
   static double ema34_sv = 0, ema55_sv = 0;
   ema34_sv = (ema34_sv == 0 ? sv_KVO : ema34_sv * (33.0/35.0) + sv_KVO * (2.0/35.0));
   ema55_sv = (ema55_sv == 0 ? sv_KVO : ema55_sv * (54.0/56.0) + sv_KVO * (2.0/56.0));
   kvo_KVO = ema34_sv - ema55_sv;

   // Price Oscillator (PPO)
   double short_PPO = GetEMA(shortlen_PPO, 0, PRICE_CLOSE);
   double long_PPO  = GetEMA(longlen_PPO,  0, PRICE_CLOSE);
   po_PPO = (long_PPO != 0.0 ? (short_PPO - long_PPO) / long_PPO * 100.0 : 0.0);

   // Awesome Oscillator (AO)
   ao_AO = GetSMA(5, 0, PRICE_MEDIAN) - GetSMA(34, 0, PRICE_MEDIAN);

   // Chaikin Oscillator (simplified/placeholder)
   osc_Chaikin_Osc = GetEMA(short_Chaikin_Osc, 0, PRICE_CLOSE) - GetEMA(long_Chaikin_Osc, 0, PRICE_CLOSE);

   // Ultimate Oscillator (UO)
   double sum_bp7 = 0, sum_tr7 = 0, sum_bp14 = 0, sum_tr14 = 0, sum_bp28 = 0, sum_tr28 = 0;
   for(int i = 0; i < 28; i++)
   {
      double c_i   = iClose(_Symbol, PERIOD_CURRENT, i);
      double l_i   = iLow(_Symbol, PERIOD_CURRENT, i);
      double c_ip1 = iClose(_Symbol, PERIOD_CURRENT, i+1);
      double h_i   = iHigh(_Symbol, PERIOD_CURRENT, i);
      double bp = c_i - MathMin(l_i, c_ip1);
      double tr = MathMax(h_i, c_ip1) - MathMin(l_i, c_ip1);
      if (i < 7)  { sum_bp7  += bp; sum_tr7  += tr; }
      if (i < 14) { sum_bp14 += bp; sum_tr14 += tr; }
      sum_bp28 += bp; sum_tr28 += tr;
   }
   double avg7_UO  = (sum_tr7  > 0 ? sum_bp7  / sum_tr7  : 0.0);
   double avg14_UO = (sum_tr14 > 0 ? sum_bp14 / sum_tr14 : 0.0);
   double avg28_UO = (sum_tr28 > 0 ? sum_bp28 / sum_tr28 : 0.0);
   out_UO = 100.0 * (4.0 * avg7_UO + 2.0 * avg14_UO + avg28_UO) / 7.0;

   // SMI Ergodic Oscillator (very simplified proxy)
   double roc1 = close0 - close1;
   double roc2 = close1 - iClose(_Symbol, PERIOD_CURRENT, 2);
   double sum_erc = MathAbs(roc1) + MathAbs(roc2);
   double erc = (sum_erc > 0 ? MathAbs(roc1 - roc2) / sum_erc : 0.0);
   double smi = erc * 100.0;
   static double erg_SMIO_prev = 0.0;
   erg_SMIO = (erg_SMIO_prev == 0 ? smi : erg_SMIO_prev * (19.0/21.0) + smi * (2.0/21.0));
   erg_SMIO_prev = erg_SMIO;
   double ema_sig = GetEMA(siglen_SMIO, 0, PRICE_CLOSE);
   osc_SMIO = erg_SMIO - ema_sig;

   // Chande Momentum Oscillator
   double sum_up = 0.0, sum_abs = 0.0;
   for(int i = 0; i < length_ChandeMO; i++)
   {
      double change = iClose(_Symbol, PERIOD_CURRENT, i) - iClose(_Symbol, PERIOD_CURRENT, i+1);
      sum_up += MathMax(change, 0.0);
      sum_abs += MathAbs(change);
   }
   chandeMO = (sum_abs > 0 ? 100.0 * (sum_up - (sum_abs - sum_up)) / sum_abs : 0.0);

   // Detrended Price Oscillator
   double sma_dpo = GetSMA(period_DPO, 0, PRICE_CLOSE);
   int barsback_DPO = period_DPO / 2 + 1;
   dpo_DPO = close0 - (barsback_DPO < 1000 ? GetSMA(period_DPO, barsback_DPO, PRICE_CLOSE) : sma_dpo);

   // Money Flow Index (simplified)
   double posFlow = 0.0, negFlow = 0.0;
   for(int i = 0; i < length_MFI; i++)
   {
      double tp  = (iHigh(_Symbol, PERIOD_CURRENT, i) + iLow(_Symbol, PERIOD_CURRENT, i) + iClose(_Symbol, PERIOD_CURRENT, i)) / 3.0;
      double tp1 = (iHigh(_Symbol, PERIOD_CURRENT, i+1) + iLow(_Symbol, PERIOD_CURRENT, i+1) + iClose(_Symbol, PERIOD_CURRENT, i+1)) / 3.0;
      double vol = (double)iVolume(_Symbol, PERIOD_CURRENT, i);
      if (tp > tp1) posFlow += tp * vol; else negFlow += tp * vol;
   }
   mf_MFI = (negFlow > 0 ? 100.0 - 100.0 / (1.0 + posFlow / negFlow) : 100.0);

   // VWAP of PVT
   double sumPVTVolume = 0.0;
   double sumVolumePVT = 0.0;
   for(int i = 0; i < 100; i++)
   {
      double c_i   = iClose(_Symbol, PERIOD_CURRENT, i);
      double c_ip1 = iClose(_Symbol, PERIOD_CURRENT, i+1);
      double pvtVal = MathAbs(c_i - c_ip1);
      double vol = (double)iVolume(_Symbol, PERIOD_CURRENT, i);
      sumPVTVolume += pvtVal * vol;
      sumVolumePVT += vol;
   }
   vwap_PVT = (sumVolumePVT > 0.0 ? sumPVTVolume / sumVolumePVT : 0.0);

   // ADX Calculation (simplified Wilder smoothing)
   double trueRange = MathMax(MathMax(high0 - low0, MathAbs(high0 - close1)), MathAbs(low0 - close1));
   double dmp = ((high0 - high1) > (low1 - low0) ? MathMax(high0 - high1, 0.0) : 0.0);
   double dmm = ((low1 - low0) > (high0 - high1) ? MathMax(low1 - low0, 0.0) : 0.0);

   static double smoothedTrueRange = 0.0, sdmp = 0.0, sdmm = 0.0, adxVal = 0.0;
   smoothedTrueRange = (smoothedTrueRange == 0.0 ? trueRange : smoothedTrueRange - smoothedTrueRange/14.0 + trueRange);
   sdmp = (sdmp == 0.0 ? dmp : sdmp - sdmp/14.0 + dmp);
   sdmm = (sdmm == 0.0 ? dmm : sdmm - sdmm/14.0 + dmm);

   DIPlus  = (smoothedTrueRange > 0 ? sdmp / smoothedTrueRange * 100.0 : 0.0);
   DIMinus = (smoothedTrueRange > 0 ? sdmm / smoothedTrueRange * 100.0 : 0.0);

   double dx = ((DIPlus + DIMinus) > 0 ? MathAbs(DIPlus - DIMinus) / (DIPlus + DIMinus) * 100.0 : 0.0);
   adxVal = (adxVal == 0.0 ? dx : (adxVal * 13.0 + dx) / 14.0);
   ADX_SMA = adxVal;
}

//+------------------------------------------------------------------+
//| Calculate HalfTrend                                              |
//+------------------------------------------------------------------+
void CalculateHalfTrend()
{
   double close0 = iClose(_Symbol, PERIOD_CURRENT, 0);
   double low0 = iLow(_Symbol, PERIOD_CURRENT, 0);
   double high0 = iHigh(_Symbol, PERIOD_CURRENT, 0);

   // ATR for HalfTrend
   double atr_100 = GetATR(100, 0);
   double HT_Atr2 = atr_100 / 2.0;
   double HT_Dev = HT_ChannelDeviation * HT_Atr2;
   (void)HT_Dev; // currently unused in simplified logic

   // Find highest and lowest bars in the last HT_Amplitude bars
   int highestbars = 0, lowestbars = 0;
   double highestPrice = -DBL_MAX, lowestPrice = DBL_MAX;
   for(int i = 0; i < HT_Amplitude; i++)
   {
      double hi = iHigh(_Symbol, PERIOD_CURRENT, i);
      double lo = iLow(_Symbol, PERIOD_CURRENT, i);
      if (hi > highestPrice) { highestPrice = hi; highestbars = i; }
      if (lo < lowestPrice)  { lowestPrice  = lo; lowestbars  = i; }
   }

   double HT_HighPrice = iHigh(_Symbol, PERIOD_CURRENT, MathAbs(highestbars));
   double HT_LowPrice  = iLow(_Symbol,  PERIOD_CURRENT, MathAbs(lowestbars));

   // Moving averages (simple mean of highs/lows for the window)
   double HT_HighMa = 0.0, HT_LowMa = 0.0;
   for(int i = 0; i < HT_Amplitude; i++)
   {
      HT_HighMa += iHigh(_Symbol, PERIOD_CURRENT, i);
      HT_LowMa  += iLow(_Symbol,  PERIOD_CURRENT, i);
   }
   HT_HighMa /= (double)MathMax(HT_Amplitude, 1);
   HT_LowMa  /= (double)MathMax(HT_Amplitude, 1);

   // Trend switching logic (simplified and made stateful)
   if (HT_NextTrend == 1)
   {
      HT_MaxLowPrice = MathMax(HT_LowPrice, HT_MaxLowPrice);
      if (HT_HighMa < HT_MaxLowPrice && close0 < iLow(_Symbol, PERIOD_CURRENT, 1))
      {
         HT_Trend = 1;
         HT_NextTrend = 0;
         HT_MinHighPrice = HT_HighPrice;
      }
   }
   else
   {
      HT_MinHighPrice = (HT_MinHighPrice == 0.0 ? HT_HighPrice : MathMin(HT_HighPrice, HT_MinHighPrice));
      if (HT_LowMa > HT_MinHighPrice && close0 > iHigh(_Symbol, PERIOD_CURRENT, 1))
      {
         HT_Trend = 0;
         HT_NextTrend = 1;
         HT_MaxLowPrice = HT_LowPrice;
      }
   }

   static int prev_HT_Trend = -1;
   static double prev_HT_Up = 0.0, prev_HT_Down = 0.0;

   if (HT_Trend == 0)
   {
      if (prev_HT_Trend != 0)
         HT_Up = (prev_HT_Down == 0.0 ? HT_MaxLowPrice : prev_HT_Down);
      else
         HT_Up = (prev_HT_Up == 0.0 ? HT_MaxLowPrice : MathMax(HT_MaxLowPrice, prev_HT_Up));
   }
   else
   {
      if (prev_HT_Trend != 1)
         HT_Down = (prev_HT_Up == 0.0 ? HT_MinHighPrice : prev_HT_Up);
      else
         HT_Down = (prev_HT_Down == 0.0 ? HT_MinHighPrice : MathMin(HT_MinHighPrice, prev_HT_Down));
   }

   HT_Ht = (HT_Trend == 0 ? HT_Up : HT_Down);

   prev_HT_Trend = HT_Trend;
   prev_HT_Up = HT_Up;
   prev_HT_Down = HT_Down;
}

//+------------------------------------------------------------------+
//| Calculate VWMA                                                   |
//+------------------------------------------------------------------+
double CalculateVWMA(int period)
{
   double sumPriceVolume = 0.0;
   double sumVolume = 0.0;
   for(int i = 0; i < period; i++)
   {
      double price = iClose(_Symbol, PERIOD_CURRENT, i);
      double vol = (double)iVolume(_Symbol, PERIOD_CURRENT, i);
      sumPriceVolume += price * vol;
      sumVolume += vol;
   }
   return (sumVolume > 0.0 ? sumPriceVolume / sumVolume : 0.0);
}

//+------------------------------------------------------------------+
//| Check if new bar has started                                     |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastTime = 0;
   datetime curTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if (curTime != lastTime)
   {
      lastTime = curTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check EMA crossover condition                                    |
//+------------------------------------------------------------------+
bool CheckCrossover()
{
   double close0 = iClose(_Symbol, PERIOD_CURRENT, 0);
   double ema2 = GetEMA(2, 0, PRICE_CLOSE);
   double ema3 = GetEMA(3, 0, PRICE_CLOSE);
   double ema4 = GetEMA(4, 0, PRICE_CLOSE);
   double ema5 = GetEMA(5, 0, PRICE_CLOSE);
   double ema6 = GetEMA(6, 0, PRICE_CLOSE);

   int count = 0;
   if (close0 > ema2) count++;
   if (close0 > ema3) count++;
   if (close0 > ema4) count++;
   if (close0 > ema5) count++;
   if (close0 > ema6) count++;

   return (count >= 4);
}

//+------------------------------------------------------------------+
//| Check EMA crossunder condition                                   |
//+------------------------------------------------------------------+
bool CheckCrossunder()
{
   double close0 = iClose(_Symbol, PERIOD_CURRENT, 0);
   double ema2 = GetEMA(2, 0, PRICE_CLOSE);
   double ema3 = GetEMA(3, 0, PRICE_CLOSE);
   double ema4 = GetEMA(4, 0, PRICE_CLOSE);
   double ema5 = GetEMA(5, 0, PRICE_CLOSE);
   double ema6 = GetEMA(6, 0, PRICE_CLOSE);

   int count = 0;
   if (close0 < ema2) count++;
   if (close0 < ema3) count++;
   if (close0 < ema4) count++;
   if (close0 < ema5) count++;
   if (close0 < ema6) count++;

   return (count >= 4);
}

//+------------------------------------------------------------------+
//| Close all positions of a type                                    |
//+------------------------------------------------------------------+
void CloseOrders(ENUM_ORDER_TYPE type)
{
   // Close positions matching type for this symbol and magic
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByIndex(i)) continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      if (sym != _Symbol) continue;
      long magic = PositionGetInteger(POSITION_MAGIC);
      if ((int)magic != MagicNumber) continue;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if ((type == ORDER_TYPE_BUY && ptype == POSITION_TYPE_BUY) ||
          (type == ORDER_TYPE_SELL && ptype == POSITION_TYPE_SELL))
      {
         trade.PositionClose(_Symbol);
      }
   }
}

//+------------------------------------------------------------------+
//| Execute new order                                                |
//+------------------------------------------------------------------+
void ExecuteOrder(ENUM_ORDER_TYPE orderType)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price = (orderType == ORDER_TYPE_BUY ? ask : bid);
   double sl = 0.0, tp = 0.0;

   if(StopLoss > 0)
   {
      sl = (orderType == ORDER_TYPE_BUY ? price - StopLoss * _Point : price + StopLoss * _Point);
   }
   if(TakeProfit > 0)
   {
      tp = (orderType == ORDER_TYPE_BUY ? price + TakeProfit * _Point : price - TakeProfit * _Point);
   }

   MqlTradeRequest request;
   MqlTradeResult result;

   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = NormalizeDouble(price, _Digits);
   request.sl = (sl > 0.0 ? NormalizeDouble(sl, _Digits) : 0.0);
   request.tp = (tp > 0.0 ? NormalizeDouble(tp, _Digits) : 0.0);
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "Akshay EA";
   request.type_time = ORDER_TIME_GTC;
   request.type_filling = ORDER_FILLING_IOC;

   if(!OrderSend(request, result))
   {
      Print("OrderSend failed: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Manage trailing stop                                             |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByIndex(i)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL = PositionGetDouble(POSITION_SL);
      double posTP = PositionGetDouble(POSITION_TP);

      double newSL = 0.0;
      double profitPoints = 0.0;

      if (ptype == POSITION_TYPE_BUY)
      {
         profitPoints = (bid - openPrice) / _Point;
         if (profitPoints > TrailStart)
         {
            newSL = bid - TrailStop * _Point;
            if (newSL > posSL || posSL == 0.0)
            {
               trade.PositionModify(_Symbol, NormalizeDouble(newSL, _Digits), (posTP > 0.0 ? NormalizeDouble(posTP, _Digits) : 0.0));
            }
         }
      }
      else if (ptype == POSITION_TYPE_SELL)
      {
         profitPoints = (openPrice - ask) / _Point;
         if (profitPoints > TrailStart)
         {
            newSL = ask + TrailStop * _Point;
            if (newSL < posSL || posSL == 0.0)
            {
               trade.PositionModify(_Symbol, NormalizeDouble(newSL, _Digits), (posTP > 0.0 ? NormalizeDouble(posTP, _Digits) : 0.0));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Determine trade conditions                                       |
//+------------------------------------------------------------------+
void DetermineTradeConditions()
{
   double close0 = iClose(_Symbol, PERIOD_CURRENT, 0);

   // Individual conditions
   bool MA24_bull = close0 > MA24_Close;
   bool Supertrend_bull = close0 > ST_Supertrend;
   bool HalfTrend_bull = close0 > HT_Ht;
   bool Ichimoku_Cloud_bull = (close0 > IC_ConversionLine && close0 > IC_BaseLine) || (IC_ConversionLine > IC_BaseLine);
   bool Parabolic_SAR_bull = close0 > PSAR_Plot;
   bool ORB5min_bull = firstCandleRecorded && close0 > firstCandleLow && close0 > VWAP_Close && close0 > MA24_Close;

   // VWMA condition
   double vwma74 = CalculateVWMA(74);
   double vwma149 = CalculateVWMA(149);
   bool VWMA_bull = (((close0 > VWAP_Close) ? 1 : 0) + ((close0 > vwma74) ? 1 : 0) + ((close0 > vwma149) ? 1 : 0)) > 1;

   // PVT condition
   bool PVT_bull = PVT_Close > vwap_PVT;

   // Oscillator conditions
   bool Oscillator_Calc_bull = (((kvo_KVO > 0) ? 1 : 0) + ((po_PPO > 0) ? 1 : 0) + ((ao_AO > 0) ? 1 : 0) +
                                ((osc_Chaikin_Osc > 0) ? 1 : 0) + ((out_UO > 50) ? 1 : 0) + ((osc_SMIO > 0) ? 1 : 0) +
                                ((chandeMO > 0) ? 1 : 0) + ((dpo_DPO > 0) ? 1 : 0) + ((mf_MFI > 50) ? 1 : 0)) >
                               (((kvo_KVO < 0) ? 1 : 0) + ((po_PPO < 0) ? 1 : 0) + ((ao_AO < 0) ? 1 : 0) +
                                ((osc_Chaikin_Osc < 0) ? 1 : 0) + ((out_UO < 50) ? 1 : 0) + ((osc_SMIO < 0) ? 1 : 0) +
                                ((chandeMO < 0) ? 1 : 0) + ((dpo_DPO < 0) ? 1 : 0) + ((mf_MFI < 50) ? 1 : 0));

   bool RSI_bull = RSI_Close > 50.0;

   // ADX conditions (based on computed DI/ADX)
   bool ADX_Bull1 = (DIPlus > 20.0);
   bool ADX_Bull2 = (DIPlus > DIMinus);
   bool ADX_bull = (((ADX_SMA > 25.0) ? 1 : 0) + (ADX_Bull1 ? 1 : 0) + (ADX_Bull2 ? 1 : 0) >= 2);

   // Master Candle bullish
   MC_bull = (MA24_bull ? 1 : 0) + (Supertrend_bull ? 1 : 0) + (HalfTrend_bull ? 1 : 0) +
             (Ichimoku_Cloud_bull ? 1 : 0) + (Parabolic_SAR_bull ? 1 : 0) + (ORB5min_bull ? 1 : 0) +
             (VWMA_bull ? 1 : 0) + (PVT_bull ? 1 : 0) + (Oscillator_Calc_bull ? 1 : 0) +
             (RSI_bull ? 1 : 0) + (ADX_bull ? 1 : 0);

   // Bearish conditions
   bool MA24_bear = close0 < MA24_Close;
   bool Supertrend_bear = close0 < ST_Supertrend;
   bool HalfTrend_bear = close0 < HT_Ht;
   bool Ichimoku_Cloud_bear = (close0 < IC_ConversionLine && close0 < IC_BaseLine) || (IC_ConversionLine < IC_BaseLine);
   bool Parabolic_SAR_bear = close0 < PSAR_Plot;
   bool ORB5min_bear = firstCandleRecorded && close0 < firstCandleHigh && close0 < VWAP_Close && close0 < MA24_Close;
   bool VWMA_bear = (((close0 < VWAP_Close) ? 1 : 0) + ((close0 < vwma74) ? 1 : 0) + ((close0 < vwma149) ? 1 : 0)) > 1;
   bool PVT_bear = PVT_Close < vwap_PVT;
   bool Oscillator_Calc_bear = !Oscillator_Calc_bull;
   bool RSI_bear = RSI_Close < 50.0;

   bool ADX_Bear1 = (DIMinus > 20.0);
   bool ADX_Bear2 = (DIMinus > DIPlus);
   bool ADX_bear = (((ADX_SMA > 25.0) ? 1 : 0) + (ADX_Bear1 ? 1 : 0) + (ADX_Bear2 ? 1 : 0) >= 2);

   // Master Candle bearish
   MC_bear = (MA24_bear ? 1 : 0) + (Supertrend_bear ? 1 : 0) + (HalfTrend_bear ? 1 : 0) +
             (Ichimoku_Cloud_bear ? 1 : 0) + (Parabolic_SAR_bear ? 1 : 0) + (ORB5min_bear ? 1 : 0) +
             (VWMA_bear ? 1 : 0) + (PVT_bear ? 1 : 0) + (Oscillator_Calc_bear ? 1 : 0) +
             (RSI_bear ? 1 : 0) + (ADX_bear ? 1 : 0);

   // Determine master candle conditions
   Int_MC_bull = (MC_bull > MC_bear);
   Int_MC_bear = (MC_bull < MC_bear);

   // Scalp conditions (simplified)
   Int_MC_Scalp_bull = Int_MC_bull;
   Int_MC_Scalp_bear = Int_MC_bear;
}

//+------------------------------------------------------------------+
//| Update chart objects                                             |
//+------------------------------------------------------------------+
void UpdateChartObjects()
{
   // Clear previous objects
   ObjectDelete(0, "SignalLine_Buy");
   ObjectDelete(0, "SignalLine_Sell");

   datetime bt = iTime(_Symbol, PERIOD_CURRENT, 0);

   // Draw signal lines
   if(buySignal)
   {
      ObjectCreate(0, "SignalLine_Buy", OBJ_VLINE, 0, bt, 0);
      ObjectSetInteger(0, "SignalLine_Buy", OBJPROP_COLOR, GC_Candle);
      ObjectSetInteger(0, "SignalLine_Buy", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "SignalLine_Buy", OBJPROP_WIDTH, 1);
   }
   else if(sellSignal)
   {
      ObjectCreate(0, "SignalLine_Sell", OBJ_VLINE, 0, bt, 0);
      ObjectSetInteger(0, "SignalLine_Sell", OBJPROP_COLOR, RC_Candle);
      ObjectSetInteger(0, "SignalLine_Sell", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "SignalLine_Sell", OBJPROP_WIDTH, 1);
   }

   // Background color (requires an existing object named "background" if used)
   color bg = (Int_MC_bull ? RGB(8,153,129) : (Int_MC_bear ? RGB(247,82,95) : RGB(255,255,255)));
   ObjectSetInteger(0, "background", OBJPROP_COLOR, bg);

   // Current candle color (requires an existing object named "candle" if used)
   color cc = (Int_MC_bull ? clrLime : (Int_MC_bear ? clrRed : clrGray));
   ObjectSetInteger(0, "candle", OBJPROP_COLOR, cc);
}