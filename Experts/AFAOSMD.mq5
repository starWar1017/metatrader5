//+------------------------------------------------------------------+
//|                                                      AFAOSMD.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.5"
#property description "A strategy using Average Force, Andean Oscillator, and MACD"
#property description "NZDCAD-30M  2019.01.01 - 2023.10.22"

#include <EAUtils.mqh>

#define PATH_AF "Indicators\\AverageForce.ex5"
#define I_AF "::" + PATH_AF
#resource "\\" + PATH_AF

#define PATH_AOS "Indicators\\AndeanOscillator.ex5"
#define I_AOS "::" + PATH_AOS
#resource "\\" + PATH_AOS
enum ENUM_AOS_BI {
    AOS_BI_BULL,
    AOS_BI_BEAR,
    AOS_BI_SIGNAL
};

input group "Indicator Parameters"
input int AfPeriod = 20; // Average Force Period
input int AfSmooth = 9; // Average Force Smooth
input int AosPeriod = 50; // Andean Oscillator Period
input int AosSignalPeriod = 9; // Andean Oscillator Signal Period
input int MdFast = 100; // MACD Fast
input int MdSlow = 200; // MACD Slow

input group "General"
input double TPCoef = 1.0; // TP Coefficient
input ENUM_SL SLType = SL_SWING; // SL Type
input int SLLookback = 7; // SL Look Back
input int SLDev = 60; // SL Deviation (Points)
input bool Reverse = true; // Reverse Signal

input group "Risk Management"
input double Risk = 1.0; // Risk
input ENUM_RISK RiskMode = RISK_DEFAULT; // Risk Mode
input bool IgnoreSL = false; // Ignore SL
input bool IgnoreTP = true; // Ignore TP
input bool Trail = true; // Trailing Stop
input double TrailingStopLevel = 50; // Trailing Stop Level (%) (0: Disable)
input double EquityDrawdownLimit = 0; // Equity Drawdown Limit (%) (0: Disable)

input group "Strategy: Grid"
input bool Grid = true; // Grid Enable
input double GridVolMult = 1.1; // Grid Volume Multiplier
input double GridTrailingStopLevel = 0; // Grid Trailing Stop Level (%) (0: Disable)
input int GridMaxLvl = 20; // Grid Max Levels

input group "News"
input bool News = false; // News Enable
input ENUM_NEWS_IMPORTANCE NewsImportance = NEWS_IMPORTANCE_MEDIUM; // News Importance
input int NewsMinsBefore = 60; // News Minutes Before
input int NewsMinsAfter = 60; // News Minutes After
input int NewsStartYear = 0; // News Start Year to Fetch for Backtesting (0: Disable)

input group "Open Position Limit"
input bool OpenNewPos = true; // Allow Opening New Position
input bool MultipleOpenPos = true; // Allow Having Multiple Open Positions
input double MarginLimit = 300; // Margin Limit (%) (0: Disable)
input int SpreadLimit = -1; // Spread Limit (Points) (-1: Disable)

input group "Auxiliary"
input int Slippage = 30; // Slippage (Points)
input int TimerInterval = 30; // Timer Interval (Seconds)
input ulong MagicNumber = 1001; // Magic Number
input ENUM_FILLING Filling = FILLING_DEFAULT; // Order Filling

GerEA ea;
datetime lastCandle;
datetime tc;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double AF(int i = -1) {
    int handle = iCustom(NULL, 0, I_AF, AfPeriod, AfSmooth);
    if (i == -1) return -1;
    return Ind(handle, i);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double AOS(ENUM_AOS_BI bi = 0, int i = -1) {
    int handle = iCustom(NULL, 0, I_AOS, AosPeriod, AosSignalPeriod);
    if (i == -1) return -1;
    return Ind(handle, i, bi);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double MD(int i = -1) {
    int handle = iMACD(NULL, 0, MdFast, MdSlow, 1, PRICE_CLOSE);
    if (i == -1) return -1;
    return Ind(handle, i);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal() {
    if (!(AOS(AOS_BI_BULL, 1) > AOS(AOS_BI_BEAR, 1))) return false;
    if (!(AF(2) < 0 && AF(1) > 0)) return false;
    if (!(MD(2) > 0 && MD(1) > 0)) return false;
    if (!(MD(2) < MD(1))) return false;

    double in = Ask();
    double sl = BuySL(SLType, SLLookback, in, SLDev, 1);
    double tp = in + TPCoef * MathAbs(in - sl);
    ea.BuyOpen(in, sl, tp, IgnoreSL, IgnoreTP);
    return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal() {
    if (!(AOS(AOS_BI_BULL, 1) < AOS(AOS_BI_BEAR, 1))) return false;
    if (!(AF(2) > 0 && AF(1) < 0)) return false;
    if (!(MD(2) < 0 && MD(1) < 0)) return false;
    if (!(MD(2) > MD(1))) return false;

    double in = Bid();
    double sl = SellSL(SLType, SLLookback, in, SLDev, 1);
    double tp = in - TPCoef * MathAbs(in - sl);
    ea.SellOpen(in, sl, tp, IgnoreSL, IgnoreTP);
    return true;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    ea.Init();
    ea.SetMagic(MagicNumber);
    ea.risk = Risk * 0.01;
    ea.reverse = Reverse;
    ea.trailingStopLevel = TrailingStopLevel * 0.01;
    ea.grid = Grid;
    ea.gridVolMult = GridVolMult;
    ea.gridTrailingStopLevel = GridTrailingStopLevel * 0.01;
    ea.gridMaxLvl = GridMaxLvl;
    ea.equityDrawdownLimit = EquityDrawdownLimit * 0.01;
    ea.slippage = Slippage;
    ea.news = News;
    ea.newsImportance = NewsImportance;
    ea.newsMinsBefore = NewsMinsBefore;
    ea.newsMinsAfter = NewsMinsAfter;
    ea.filling = Filling;
    ea.riskMode = RiskMode;

    if (RiskMode == RISK_FIXED_VOL || RiskMode == RISK_MIN_AMOUNT) ea.risk = Risk;
    if (News) fetchCalendarFromYear(NewsStartYear);

    AOS();
    AF();
    MD();

    EventSetTimer(TimerInterval);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
    datetime oldTc = tc;
    tc = TimeCurrent();
    if (tc == oldTc) return;

    if (Trail) ea.CheckForTrail();
    if (EquityDrawdownLimit) ea.CheckForEquity();
    if (Grid) ea.CheckForGrid();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if (lastCandle != Time(0)) {
        lastCandle = Time(0);

        if (!OpenNewPos) return;
        if (SpreadLimit != -1 && Spread() > SpreadLimit) return;
        if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) return;
        if ((Grid || !MultipleOpenPos) && ea.OPTotal() > 0) return;

        if (BuySignal()) return;
        SellSignal();
    }
}
//+------------------------------------------------------------------+
