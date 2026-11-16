import '../../../shared/models/metric_code.dart';
import '../../financial_analysis/domain/calc_result.dart';
import '../../financial_analysis/domain/company_financials.dart';
import '../../financial_analysis/domain/formulas.dart';

enum ForecastMethod {
  linearRegression('linear_regression', 'Linear trend (least squares)'),
  weightedGrowth('weighted_growth', 'Weighted moving growth'),
  marginStability('margin_stability', 'Margin stability projection');

  const ForecastMethod(this.dbValue, this.label);
  final String dbValue;
  final String label;
}

/// Weights applied to historical YoY growth rates, most recent first.
/// Must sum to 1. When fewer growth observations exist than weights, the
/// leading weights are used and re-normalized to sum to 1.
class GrowthWeights {
  GrowthWeights(this.mostRecentFirst) {
    final sum = mostRecentFirst.fold<double>(0, (a, b) => a + b);
    if (mostRecentFirst.isEmpty || (sum - 1).abs() > 1e-6 || mostRecentFirst.any((w) => w < 0)) {
      throw ArgumentError('Growth weights must be non-negative and sum to 1 (got $sum).');
    }
  }

  static final standard = GrowthWeights(const [0.5, 0.3, 0.2]);

  final List<double> mostRecentFirst;

  List<double> forCount(int n) {
    final used = mostRecentFirst.take(n).toList();
    final sum = used.fold<double>(0, (a, b) => a + b);
    if (sum == 0) return List.filled(used.length, 1 / used.length);
    return used.map((w) => w / sum).toList();
  }
}

class ForecastResult {
  const ForecastResult({
    required this.metric,
    required this.method,
    required this.year,
    required this.result,
    required this.assumptions,
  });

  final MetricCode metric;
  final ForecastMethod method;
  final int year;
  final CalcResult result;
  final Map<String, Object?> assumptions;
}

/// Linear-regression output with its fitted line.
class LinearFit {
  const LinearFit(this.intercept, this.slope);
  final double intercept;
  final double slope;
  double predict(double x) => intercept + slope * x;
}

abstract final class ForecastingEngine {
  static const projectedExpenses = [
    MetricCode.costOfSales,
    MetricCode.adminExpenses,
    MetricCode.sellingExpenses,
    MetricCode.financeCost,
  ];

  /// Ordinary least squares fit of y = a + b·x.
  /// b = Σ(x−x̄)(y−ȳ) / Σ(x−x̄)²,  a = ȳ − b·x̄.
  static LinearFit? fitLine(List<double> xs, List<double> ys) {
    if (xs.length != ys.length || xs.length < 2) return null;
    final n = xs.length;
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = ys.reduce((a, b) => a + b) / n;
    var sxy = 0.0, sxx = 0.0;
    for (var i = 0; i < n; i++) {
      sxy += (xs[i] - mx) * (ys[i] - my);
      sxx += (xs[i] - mx) * (xs[i] - mx);
    }
    if (sxx == 0) return null;
    final b = sxy / sxx;
    return LinearFit(my - b * mx, b);
  }

  static ForecastResult linearRegression(CompanyFinancials f, MetricCode metric) {
    final points = [
      for (final y in f.years)
        if (f.value(y, metric) != null) (y, f.value(y, metric)!),
    ];
    final target = f.years.isEmpty ? 0 : f.years.last + 1;
    final fit = fitLine([for (final p in points) p.$1.toDouble()], [for (final p in points) p.$2]);
    if (fit == null) {
      return ForecastResult(
        metric: metric,
        method: ForecastMethod.linearRegression,
        year: target,
        result: const CalcResult.fail(CalcStatus.missingInput, 'At least two historical values required'),
        assumptions: {'observations': points.length},
      );
    }
    return ForecastResult(
      metric: metric,
      method: ForecastMethod.linearRegression,
      year: target,
      result: CalcResult.ok(fit.predict(target.toDouble())),
      assumptions: {
        'observations': points.length,
        'years': [for (final p in points) p.$1],
        'slope_per_year': fit.slope,
        'intercept': fit.intercept,
      },
    );
  }

  /// Y4 = Y3 × (1 + Σ wᵢ·gᵢ) with gᵢ the YoY growth rates, most recent first.
  static ForecastResult weightedGrowth(CompanyFinancials f, MetricCode metric, GrowthWeights weights) {
    final years = f.years;
    final target = years.isEmpty ? 0 : years.last + 1;
    ForecastResult fail(CalcStatus s, String note, [Map<String, Object?> a = const {}]) => ForecastResult(
          metric: metric,
          method: ForecastMethod.weightedGrowth,
          year: target,
          result: CalcResult.fail(s, note),
          assumptions: a,
        );

    if (years.length < 2) return fail(CalcStatus.missingInput, 'At least two historical years required');
    final growth = <double>[];
    for (var i = years.length - 1; i >= 1; i--) {
      final g = Formulas.yoyGrowth(f.value(years[i], metric), f.value(years[i - 1], metric));
      if (!g.isOk) {
        return fail(g.status == CalcStatus.missingInput ? CalcStatus.missingInput : CalcStatus.notMeaningful,
            'Growth ${years[i - 1]}→${years[i]}: ${g.reason}');
      }
      growth.add(g.value! / 100);
    }
    final latest = f.value(years.last, metric)!;
    if (latest <= 0) return fail(CalcStatus.notMeaningful, 'Latest value is not positive');
    final w = weights.forCount(growth.length);
    var rate = 0.0;
    for (var i = 0; i < growth.length; i++) {
      rate += w[i] * growth[i];
    }
    return ForecastResult(
      metric: metric,
      method: ForecastMethod.weightedGrowth,
      year: target,
      result: CalcResult.ok(latest * (1 + rate)),
      assumptions: {
        'growth_rates_most_recent_first': growth,
        'weights_applied': w,
        'weighted_growth_rate': rate,
        'base_value': latest,
      },
    );
  }

  /// Projects an expense (or net profit) as forecast revenue × its average
  /// historical share of revenue.
  static ForecastResult marginStability(CompanyFinancials f, MetricCode metric, double? forecastRevenue, int year) {
    final shares = <double>[];
    for (final y in f.years) {
      final r = Formulas.verticalPercent(f.value(y, metric), f.value(y, MetricCode.totalRevenue));
      if (r.isOk) shares.add(r.value! / 100);
    }
    if (forecastRevenue == null || shares.isEmpty) {
      return ForecastResult(
        metric: metric,
        method: ForecastMethod.marginStability,
        year: year,
        result: CalcResult.fail(CalcStatus.missingInput,
            forecastRevenue == null ? 'No revenue forecast available' : 'No historical ${metric.label} share'),
        assumptions: const {},
      );
    }
    final avg = shares.reduce((a, b) => a + b) / shares.length;
    return ForecastResult(
      metric: metric,
      method: ForecastMethod.marginStability,
      year: year,
      result: CalcResult.ok(forecastRevenue * avg),
      assumptions: {'average_share_of_revenue': avg, 'observations': shares.length, 'forecast_revenue': forecastRevenue},
    );
  }

  /// Full forecast set for one company.
  static List<ForecastResult> forecast(CompanyFinancials raw, {GrowthWeights? weights}) {
    final f = raw.normalized();
    if (f.years.isEmpty) return const [];
    final w = weights ?? GrowthWeights.standard;
    final out = <ForecastResult>[];
    for (final m in [MetricCode.totalRevenue, MetricCode.netProfit]) {
      out
        ..add(linearRegression(f, m))
        ..add(weightedGrowth(f, m, w));
    }
    // Revenue base for margin projections: weighted growth, else regression.
    final revWg = out.firstWhere((r) => r.metric == MetricCode.totalRevenue && r.method == ForecastMethod.weightedGrowth);
    final revLr = out.firstWhere((r) => r.metric == MetricCode.totalRevenue && r.method == ForecastMethod.linearRegression);
    final base = revWg.result.value ?? revLr.result.value;
    final year = f.years.last + 1;
    for (final m in [...projectedExpenses, MetricCode.netProfit]) {
      out.add(marginStability(f, m, base, year));
    }
    return out;
  }
}
