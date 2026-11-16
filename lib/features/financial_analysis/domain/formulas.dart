import 'dart:math' as math;

import 'calc_result.dart';

/// Pure financial formulas. See FINANCIAL_FORMULAS.md for methodology.
/// Every function returns a [CalcResult]; none substitutes zero for missing data.
abstract final class Formulas {
  /// ((current - previous) / previous) × 100.
  /// A negative base makes the sign of growth misleading, so it is rejected.
  static CalcResult yoyGrowth(double? current, double? previous) {
    if (current == null || previous == null) return const CalcResult.fail(CalcStatus.missingInput);
    if (previous == 0) return const CalcResult.fail(CalcStatus.zeroDenominator, 'Prior-year value is zero');
    if (previous < 0) {
      return const CalcResult.fail(CalcStatus.negativeDenominator, 'Prior-year value is negative');
    }
    return CalcResult.ok((current - previous) / previous * 100);
  }

  /// ((end / begin) ^ (1 / periods) − 1) × 100, where [periods] is the number
  /// of elapsed years (3 annual observations ⇒ 2 periods).
  static CalcResult cagr(double? begin, double? end, int periods) {
    if (begin == null || end == null) return const CalcResult.fail(CalcStatus.missingInput);
    if (periods < 1) {
      return const CalcResult.fail(CalcStatus.notMeaningful, 'At least two annual observations are required');
    }
    if (begin == 0) return const CalcResult.fail(CalcStatus.zeroDenominator, 'Starting value is zero');
    if (begin < 0) return const CalcResult.fail(CalcStatus.negativeDenominator, 'Starting value is negative');
    if (end < 0) {
      return const CalcResult.fail(CalcStatus.notMeaningful, 'Ending value is negative; CAGR undefined');
    }
    return CalcResult.ok((math.pow(end / begin, 1 / periods) - 1) * 100);
  }

  /// numerator / denominator × [scale]. Denominator must be positive unless
  /// [allowNegativeDenominator] is set.
  static CalcResult divide(
    double? numerator,
    double? denominator, {
    double scale = 1,
    bool allowNegativeDenominator = false,
    String? zeroNote,
    String? negativeNote,
  }) {
    if (numerator == null || denominator == null) return const CalcResult.fail(CalcStatus.missingInput);
    if (denominator == 0) return CalcResult.fail(CalcStatus.zeroDenominator, zeroNote);
    if (denominator < 0 && !allowNegativeDenominator) {
      return CalcResult.fail(CalcStatus.negativeDenominator, negativeNote);
    }
    return CalcResult.ok(numerator / denominator * scale);
  }

  /// (item / revenue) × 100.
  static CalcResult verticalPercent(double? item, double? revenue) =>
      divide(item, revenue, scale: 100, zeroNote: 'Revenue is zero', negativeNote: 'Revenue is negative');

  static CalcResult currentRatio(double? currentAssets, double? currentLiabilities) =>
      divide(currentAssets, currentLiabilities, zeroNote: 'No current liabilities');

  static CalcResult quickRatio(double? currentAssets, double? inventory, double? currentLiabilities) {
    if (currentAssets == null || inventory == null) return const CalcResult.fail(CalcStatus.missingInput);
    return divide(currentAssets - inventory, currentLiabilities, zeroNote: 'No current liabilities');
  }

  static CalcResult grossMargin(double? grossProfit, double? revenue) => verticalPercent(grossProfit, revenue);

  static CalcResult netMargin(double? netProfit, double? revenue) => verticalPercent(netProfit, revenue);

  /// Net profit / average equity × 100. Uses the average of opening and
  /// closing equity when the opening balance is known, otherwise closing.
  static CalcResult returnOnEquity(double? netProfit, double? closingEquity, {double? openingEquity}) {
    if (netProfit == null || closingEquity == null) return const CalcResult.fail(CalcStatus.missingInput);
    final useAverage = openingEquity != null;
    final equity = useAverage ? (openingEquity + closingEquity) / 2 : closingEquity;
    final r = divide(netProfit, equity,
        scale: 100, zeroNote: 'Equity is zero', negativeNote: 'Negative shareholders\' equity');
    if (!r.isOk) return r;
    return CalcResult.ok(r.value!, note: useAverage ? 'Average equity' : 'Closing equity');
  }

  static CalcResult debtToEquity(double? totalDebt, double? equity) =>
      divide(totalDebt, equity, zeroNote: 'Equity is zero', negativeNote: 'Negative shareholders\' equity');

  static CalcResult interestCoverage(double? operatingProfit, double? financeCost) => divide(
        operatingProfit,
        financeCost?.abs(),
        zeroNote: 'No finance cost; coverage unbounded',
      );

  /// Operating cash flow / net profit. Only meaningful for positive profit.
  static CalcResult cashConversion(double? operatingCashFlow, double? netProfit) => divide(
        operatingCashFlow,
        netProfit,
        zeroNote: 'Net profit is zero',
        negativeNote: 'Net loss; cash conversion not meaningful',
      );

  /// Revenue / average total assets.
  static CalcResult assetTurnover(double? revenue, double? closingAssets, {double? openingAssets}) {
    if (revenue == null || closingAssets == null) return const CalcResult.fail(CalcStatus.missingInput);
    final assets = openingAssets != null ? (openingAssets + closingAssets) / 2 : closingAssets;
    return divide(revenue, assets, zeroNote: 'Total assets are zero');
  }

  /// Linear interpolation of [value] between [worst] and [best] into 0..1.
  /// Works for both directions (best may be lower than worst).
  static double normalize(double value, {required double worst, required double best}) {
    if (best == worst) return value >= best ? 1 : 0;
    final t = (value - worst) / (best - worst);
    return t.clamp(0.0, 1.0);
  }
}
