import '../../../shared/models/metric_code.dart';
import '../../comparison/domain/comparison_engine.dart';
import '../../financial_analysis/domain/calc_result.dart';
import '../../financial_analysis/domain/financial_analysis_engine.dart';
import '../../forecasting/domain/forecasting_engine.dart';
import '../../scoring/domain/scoring_engine.dart';

/// Cell content: a [num] (exported as a number), a [String], or null (missing).
typedef Cell = Object?;

class ReportTable {
  const ReportTable(this.title, this.headers, this.rows);
  final String title;
  final List<String> headers;
  final List<List<Cell>> rows;
}

Cell _calc(CalcResult r) => r.isOk ? _round(r.value!) : 'n/a (${r.reason})';
num _round(double v) => (v * 100).roundToDouble() / 100;

/// Tables shared by the PDF and Excel exports so both match the dashboard.
abstract final class ReportTables {
  static const assumptions = [
    'Figures are taken from the user-validated dataset; rejected values are excluded.',
    'Expenses are stored as positive amounts regardless of the sign used in the source statement.',
    'CAGR uses the number of elapsed years between the first and last observation (3 years = 2 periods).',
    'ROE and asset turnover use average balances when the prior-year balance is available, otherwise closing balances.',
    'Linear forecasts use ordinary least squares on the available years; weighted-growth forecasts weight the most '
        'recent YoY growth most heavily (default 50/30/20, re-normalized to available observations).',
    'Margin-stability projections apply the average historical share of revenue to the forecast revenue.',
    'Forecasts are estimates, not guaranteed outcomes. Scores compare reported fundamentals only; this is not '
        'personalized investment advice or a stock valuation.',
    'Banking and insurance companies require specialized methodology and are not scored.',
  ];

  static ReportTable historical(CompanyAnalysis a) => ReportTable(
        '${a.financials.companyName} – Historical financial statements (${a.financials.currency})',
        ['Line item', for (final y in a.years) 'FY$y'],
        [
          for (final m in MetricCode.values)
            if (a.years.any((y) => a.financials.value(y, m) != null))
              [m.label, for (final y in a.years) a.financials.value(y, m)],
        ],
      );

  static ReportTable horizontal(CompanyAnalysis a) => ReportTable(
        '${a.financials.companyName} – Horizontal analysis (YoY growth %, CAGR %)',
        ['Metric', for (final y in a.years.skip(1)) 'YoY FY$y', 'CAGR'],
        [
          for (final m in FinancialAnalysisEngine.horizontalMetrics)
            [m.label, for (final y in a.years.skip(1)) _calc(a.yoy[m]![y]!), _calc(a.cagr[m]!)],
        ],
      );

  static ReportTable vertical(CompanyAnalysis a) => ReportTable(
        '${a.financials.companyName} – Vertical analysis (% of revenue)',
        ['Line item', for (final y in a.years) 'FY$y'],
        [
          ['Revenue', for (final y in a.years) a.financials.value(y, MetricCode.totalRevenue) == null ? 'n/a' : 100],
          for (final m in FinancialAnalysisEngine.verticalMetrics) [m.label, for (final y in a.years) _calc(a.vertical[y]![m]!)],
        ],
      );

  static ReportTable ratios(CompanyAnalysis a) => ReportTable(
        '${a.financials.companyName} – Financial ratios',
        ['Ratio', 'Unit', for (final y in a.years) 'FY$y'],
        [
          for (final r in RatioCode.values) [r.label, r.unit, for (final y in a.years) _calc(a.ratio(y, r))],
        ],
      );

  static ReportTable forecasts(String name, List<ForecastResult> fs) => ReportTable(
        '$name – Year-4 forecasts (estimates)',
        ['Metric', 'Method', 'Year', 'Forecast', 'Notes'],
        [
          for (final f in fs)
            [
              f.metric.label,
              f.method.label,
              'FY${f.year}',
              f.result.isOk ? _round(f.result.value!) : null,
              f.result.isOk ? _assumptionText(f) : f.result.reason,
            ],
        ],
      );

  static String _assumptionText(ForecastResult f) => switch (f.method) {
        ForecastMethod.linearRegression =>
          'slope ${(f.assumptions['slope_per_year'] as double).toStringAsFixed(0)}/yr over ${f.assumptions['observations']} obs.',
        ForecastMethod.weightedGrowth =>
          'weighted growth ${((f.assumptions['weighted_growth_rate'] as double) * 100).toStringAsFixed(2)}%',
        ForecastMethod.marginStability =>
          'avg ${((f.assumptions['average_share_of_revenue'] as double) * 100).toStringAsFixed(2)}% of revenue',
      };

  static ReportTable scores(CompanyScore s) => ReportTable(
        '${s.companyName} – Scoring breakdown',
        ['Criterion', 'Weight', 'Raw value', 'Points', 'Explanation'],
        [
          for (final c in s.criteria)
            [c.criterion.label, c.weight, c.rawValue == null ? null : _round(c.rawValue!), c.points, c.explanation],
          ['Total', 100, null, s.total, s.isComplete ? 'Complete' : 'Incomplete – partial total'],
        ],
      );

  static ReportTable comparison(ComparisonOutcome o) {
    final a = o.a, b = o.b;
    Cell latest(CompanyAnalysis x, RatioCode r) => x.years.isEmpty ? null : _calc(x.ratio(x.latestYear, r));
    Cell value(CompanyAnalysis x, MetricCode m) => x.years.isEmpty ? null : x.financials.value(x.latestYear, m);
    return ReportTable(
      'Side-by-side comparison (latest year)',
      ['Metric', a.financials.companyName, b.financials.companyName],
      [
        ['Latest financial year', a.years.isEmpty ? null : 'FY${a.latestYear}', b.years.isEmpty ? null : 'FY${b.latestYear}'],
        ['Revenue', value(a, MetricCode.totalRevenue), value(b, MetricCode.totalRevenue)],
        ['Net profit', value(a, MetricCode.netProfit), value(b, MetricCode.netProfit)],
        ['Operating cash flow', value(a, MetricCode.operatingCashFlow), value(b, MetricCode.operatingCashFlow)],
        ['Revenue CAGR %', _calc(a.cagr[MetricCode.totalRevenue]!), _calc(b.cagr[MetricCode.totalRevenue]!)],
        for (final r in RatioCode.values) ['${r.label} (${r.unit})', latest(a, r), latest(b, r)],
        ['Total score', o.scoreA.total, o.scoreB.total],
      ],
    );
  }

  static List<ReportTable> forCompany(ComparisonOutcome o, {required bool first}) {
    final a = first ? o.a : o.b;
    return [
      historical(a),
      horizontal(a),
      vertical(a),
      ratios(a),
      forecasts(a.financials.companyName, first ? o.forecastsA : o.forecastsB),
      scores(first ? o.scoreA : o.scoreB),
    ];
  }
}
