import '../../../shared/models/metric_code.dart';
import 'calc_result.dart';
import 'company_financials.dart';
import 'formulas.dart';

enum RatioCode {
  currentRatio('current_ratio', 'Current Ratio', 'x'),
  quickRatio('quick_ratio', 'Quick Ratio', 'x'),
  grossMargin('gross_margin', 'Gross Margin', '%'),
  netMargin('net_margin', 'Net Margin', '%'),
  returnOnEquity('return_on_equity', 'Return on Equity', '%'),
  debtToEquity('debt_to_equity', 'Debt-to-Equity', 'x'),
  interestCoverage('interest_coverage', 'Interest Coverage', 'x'),
  cashConversion('cash_conversion', 'Cash Conversion (OCF / NP)', 'x'),
  assetTurnover('asset_turnover', 'Asset Turnover', 'x'),
  adminExpensePct('admin_expense_pct', 'Admin Expenses % of Revenue', '%');

  const RatioCode(this.code, this.label, this.unit);
  final String code;
  final String label;
  final String unit;

  static const liquidity = [currentRatio, quickRatio];
  static const profitability = [grossMargin, netMargin, returnOnEquity];
  static const solvency = [debtToEquity, interestCoverage];
}

/// Complete historical analysis for one company.
class CompanyAnalysis {
  const CompanyAnalysis({
    required this.financials,
    required this.yoy,
    required this.cagr,
    required this.vertical,
    required this.ratios,
  });

  final CompanyFinancials financials;

  /// metric → year → YoY growth % (from the second year onwards).
  final Map<MetricCode, Map<int, CalcResult>> yoy;

  /// metric → CAGR % across first→last available year.
  final Map<MetricCode, CalcResult> cagr;

  /// year → metric → % of revenue.
  final Map<int, Map<MetricCode, CalcResult>> vertical;

  /// year → ratio → value.
  final Map<int, Map<RatioCode, CalcResult>> ratios;

  List<int> get years => financials.years;
  int get latestYear => years.last;

  CalcResult ratio(int year, RatioCode code) =>
      ratios[year]?[code] ?? const CalcResult.fail(CalcStatus.missingInput);
}

/// Horizontal, vertical and ratio analysis. Pure Dart, no Flutter imports.
abstract final class FinancialAnalysisEngine {
  static const horizontalMetrics = [
    MetricCode.totalRevenue,
    MetricCode.grossProfit,
    MetricCode.operatingProfit,
    MetricCode.netProfit,
    MetricCode.totalAssets,
    MetricCode.shareholdersEquity,
  ];

  static const verticalMetrics = [
    MetricCode.costOfSales,
    MetricCode.grossProfit,
    MetricCode.adminExpenses,
    MetricCode.sellingExpenses,
    MetricCode.operatingExpenses,
    MetricCode.operatingProfit,
    MetricCode.financeCost,
    MetricCode.netProfit,
  ];

  static CompanyAnalysis analyze(CompanyFinancials raw) {
    final f = raw.normalized();
    final years = f.years;
    if (years.isEmpty) {
      return CompanyAnalysis(financials: f, yoy: const {}, cagr: const {}, vertical: const {}, ratios: const {});
    }

    final yoy = <MetricCode, Map<int, CalcResult>>{};
    final cagr = <MetricCode, CalcResult>{};
    for (final m in horizontalMetrics) {
      yoy[m] = {
        for (var i = 1; i < years.length; i++)
          years[i]: years[i] - years[i - 1] == 1
              ? Formulas.yoyGrowth(f.value(years[i], m), f.value(years[i - 1], m))
              : const CalcResult.fail(CalcStatus.notMeaningful, 'Financial years are not consecutive'),
      };
      cagr[m] = Formulas.cagr(f.value(years.first, m), f.value(years.last, m), years.last - years.first);
    }

    final vertical = <int, Map<MetricCode, CalcResult>>{
      for (final y in years)
        y: {
          for (final m in verticalMetrics) m: Formulas.verticalPercent(f.value(y, m), f.value(y, MetricCode.totalRevenue)),
        },
    };

    final ratios = <int, Map<RatioCode, CalcResult>>{};
    for (final y in years) {
      double? v(MetricCode m) => f.value(y, m);
      final prev = years.contains(y - 1) ? y - 1 : null;
      ratios[y] = {
        RatioCode.currentRatio: Formulas.currentRatio(v(MetricCode.currentAssets), v(MetricCode.currentLiabilities)),
        RatioCode.quickRatio: Formulas.quickRatio(
            v(MetricCode.currentAssets), v(MetricCode.inventory), v(MetricCode.currentLiabilities)),
        RatioCode.grossMargin: Formulas.grossMargin(v(MetricCode.grossProfit), v(MetricCode.totalRevenue)),
        RatioCode.netMargin: Formulas.netMargin(v(MetricCode.netProfit), v(MetricCode.totalRevenue)),
        RatioCode.returnOnEquity: Formulas.returnOnEquity(
          v(MetricCode.netProfit),
          v(MetricCode.shareholdersEquity),
          openingEquity: prev == null ? null : f.value(prev, MetricCode.shareholdersEquity),
        ),
        RatioCode.debtToEquity: Formulas.debtToEquity(v(MetricCode.totalDebt), v(MetricCode.shareholdersEquity)),
        RatioCode.interestCoverage:
            Formulas.interestCoverage(v(MetricCode.operatingProfit), v(MetricCode.financeCost)),
        RatioCode.cashConversion:
            Formulas.cashConversion(v(MetricCode.operatingCashFlow), v(MetricCode.netProfit)),
        RatioCode.assetTurnover: Formulas.assetTurnover(
          v(MetricCode.totalRevenue),
          v(MetricCode.totalAssets),
          openingAssets: prev == null ? null : f.value(prev, MetricCode.totalAssets),
        ),
        RatioCode.adminExpensePct: Formulas.verticalPercent(v(MetricCode.adminExpenses), v(MetricCode.totalRevenue)),
      };
    }

    return CompanyAnalysis(financials: f, yoy: yoy, cagr: cagr, vertical: vertical, ratios: ratios);
  }
}
