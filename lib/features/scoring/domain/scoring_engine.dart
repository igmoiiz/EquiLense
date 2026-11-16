import '../../../shared/models/metric_code.dart';
import '../../financial_analysis/domain/calc_result.dart';
import '../../financial_analysis/domain/financial_analysis_engine.dart';
import '../../financial_analysis/domain/formulas.dart';

enum Criterion {
  revenueGrowth('revenue_growth', 'Revenue Growth'),
  returnOnEquity('return_on_equity', 'Return on Equity'),
  overheadEfficiency('overhead_efficiency', 'Overhead Efficiency'),
  balanceSheetSafety('balance_sheet_safety', 'Balance Sheet Safety'),
  cashFlowQuality('cash_flow_quality', 'Operating Cash Flow Quality'),
  grossMargin('gross_margin', 'Gross Margin'),
  assetTurnover('asset_turnover', 'Asset Turnover');

  const Criterion(this.code, this.label);
  final String code;
  final String label;

  static Criterion? fromCode(String code) {
    for (final c in values) {
      if (c.code == code) return c;
    }
    return null;
  }
}

/// Industry weights (percent, summing to 100).
class ScoringWeights {
  ScoringWeights(Map<Criterion, double> weights) : weights = Map.unmodifiable(weights) {
    final sum = total;
    if ((sum - 100).abs() > 0.01) throw ArgumentError('Scoring weights must sum to 100% (got $sum).');
    if (weights.values.any((w) => w < 0)) throw ArgumentError('Scoring weights cannot be negative.');
  }

  /// Base specification weights.
  factory ScoringWeights.standard() => ScoringWeights(const {
        Criterion.revenueGrowth: 25,
        Criterion.returnOnEquity: 25,
        Criterion.overheadEfficiency: 20,
        Criterion.balanceSheetSafety: 15,
        Criterion.cashFlowQuality: 15,
      });

  factory ScoringWeights.fromJson(Map<String, dynamic> json) => ScoringWeights({
        for (final e in json.entries)
          if (Criterion.fromCode(e.key) != null) Criterion.fromCode(e.key)!: (e.value as num).toDouble(),
      });

  final Map<Criterion, double> weights;

  double get total => weights.values.fold(0, (a, b) => a + b);
  double of(Criterion c) => weights[c] ?? 0;
  Iterable<Criterion> get active => Criterion.values.where((c) => of(c) > 0);
  Map<String, double> toJson() => {for (final c in active) c.code: of(c)};
}

/// Normalization bands: value at [worst] earns 0%, at [best] earns 100%,
/// linear in between. Documented in FINANCIAL_FORMULAS.md.
class ScoringThresholds {
  const ScoringThresholds({
    this.revenueCagr = (worst: -5, best: 20),
    this.roe = (worst: 0, best: 25),
    this.adminPct = (worst: 15, best: 3),
    this.currentRatio = (worst: 0.8, best: 2.0),
    this.debtToEquity = (worst: 2.0, best: 0.5),
    this.cashConversion = (worst: 0, best: 1.2),
    this.grossMargin = (worst: 10, best: 60),
    this.assetTurnover = (worst: 0.2, best: 1.5),
  });

  final ({double worst, double best}) revenueCagr;
  final ({double worst, double best}) roe;
  final ({double worst, double best}) adminPct;
  final ({double worst, double best}) currentRatio;
  final ({double worst, double best}) debtToEquity;
  final ({double worst, double best}) cashConversion;
  final ({double worst, double best}) grossMargin;
  final ({double worst, double best}) assetTurnover;
}

class CriterionScore {
  const CriterionScore({
    required this.criterion,
    required this.weight,
    required this.rawValue,
    required this.points,
    required this.explanation,
  });

  final Criterion criterion;
  final double weight;
  final double? rawValue;

  /// Null when the criterion could not be scored (incomplete data).
  final double? points;
  final String explanation;

  double get maxPoints => weight;
  bool get isScored => points != null;
}

class CompanyScore {
  const CompanyScore({required this.companyId, required this.companyName, required this.criteria});

  final String companyId;
  final String companyName;
  final List<CriterionScore> criteria;

  bool get isComplete => criteria.every((c) => c.isScored);

  /// Sum of awarded points, rounded to 2 decimals. Partial when incomplete.
  double get total => _round2(criteria.fold(0, (a, c) => a + (c.points ?? 0)));

  List<Criterion> get missing => [for (final c in criteria) if (!c.isScored) c.criterion];
}

double _round2(double v) => (v * 100).roundToDouble() / 100;

abstract final class ScoringEngine {
  static CompanyScore score(CompanyAnalysis a, ScoringWeights weights,
      {ScoringThresholds t = const ScoringThresholds()}) {
    return CompanyScore(
      companyId: a.financials.companyId,
      companyName: a.financials.companyName,
      criteria: [for (final c in weights.active) _scoreCriterion(c, weights.of(c), a, t)],
    );
  }

  static CriterionScore _scoreCriterion(Criterion c, double weight, CompanyAnalysis a, ScoringThresholds t) {
    final y = a.years.isEmpty ? null : a.latestYear;
    CriterionScore incomplete(String why) =>
        CriterionScore(criterion: c, weight: weight, rawValue: null, points: null, explanation: 'Incomplete: $why');
    CriterionScore banded(double value, ({double worst, double best}) band, String describe) {
      final pts = _round2(Formulas.normalize(value, worst: band.worst, best: band.best) * weight);
      return CriterionScore(
        criterion: c,
        weight: weight,
        rawValue: value,
        points: pts,
        explanation: '$describe → ${pts.toStringAsFixed(2)} / ${weight.toStringAsFixed(0)} '
            '(0 pts at ${band.worst}, full at ${band.best}).',
      );
    }

    if (y == null) return incomplete('no financial years');

    switch (c) {
      case Criterion.revenueGrowth:
        final r = a.cagr[MetricCode.totalRevenue]!;
        if (!r.isOk) return incomplete('revenue CAGR – ${r.reason}');
        return banded(r.value!, t.revenueCagr, 'Revenue CAGR ${r.value!.toStringAsFixed(2)}%');

      case Criterion.returnOnEquity:
        final r = a.ratio(y, RatioCode.returnOnEquity);
        if (r.status == CalcStatus.negativeDenominator) {
          return CriterionScore(criterion: c, weight: weight, rawValue: null, points: 0,
              explanation: 'Negative shareholders\' equity in $y → 0 points.');
        }
        if (!r.isOk) return incomplete('ROE $y – ${r.reason}');
        return banded(r.value!, t.roe, 'ROE $y ${r.value!.toStringAsFixed(2)}% (${r.note})');

      case Criterion.overheadEfficiency:
        final vals = [
          for (final yr in a.years)
            if (a.ratio(yr, RatioCode.adminExpensePct).isOk) a.ratio(yr, RatioCode.adminExpensePct).value!,
        ];
        if (vals.isEmpty) return incomplete('administrative expenses or revenue missing');
        final avg = vals.reduce((p, q) => p + q) / vals.length;
        return banded(avg, t.adminPct,
            'Average admin expenses ${avg.toStringAsFixed(2)}% of revenue over ${vals.length} yr(s)');

      case Criterion.balanceSheetSafety:
        final cr = a.ratio(y, RatioCode.currentRatio);
        final de = a.ratio(y, RatioCode.debtToEquity);
        if (!cr.isOk) return incomplete('current ratio $y – ${cr.reason}');
        final crPart = Formulas.normalize(cr.value!, worst: t.currentRatio.worst, best: t.currentRatio.best);
        double dePart;
        String deText;
        if (de.status == CalcStatus.negativeDenominator) {
          dePart = 0;
          deText = 'negative equity (0%)';
        } else if (!de.isOk) {
          return incomplete('debt-to-equity $y – ${de.reason}');
        } else {
          dePart = Formulas.normalize(de.value!, worst: t.debtToEquity.worst, best: t.debtToEquity.best);
          deText = 'D/E ${de.value!.toStringAsFixed(2)}x';
        }
        final pts = _round2((crPart + dePart) / 2 * weight);
        return CriterionScore(
          criterion: c,
          weight: weight,
          rawValue: cr.value,
          points: pts,
          explanation: 'Current ratio ${cr.value!.toStringAsFixed(2)}x (target ≥ ${t.currentRatio.best}x) and '
              '$deText (target ≤ ${t.debtToEquity.best}x), equally weighted → ${pts.toStringAsFixed(2)} / '
              '${weight.toStringAsFixed(0)}.',
        );

      case Criterion.cashFlowQuality:
        double ocf = 0, np = 0;
        var n = 0;
        for (final yr in a.years) {
          final o = a.financials.value(yr, MetricCode.operatingCashFlow);
          final p = a.financials.value(yr, MetricCode.netProfit);
          if (o != null && p != null) {
            ocf += o;
            np += p;
            n++;
          }
        }
        if (n == 0) return incomplete('operating cash flow or net profit missing');
        if (np <= 0) {
          return CriterionScore(criterion: c, weight: weight, rawValue: null, points: 0,
              explanation: 'Cumulative net profit over $n yr(s) is not positive → 0 points.');
        }
        final ratio = ocf / np;
        return banded(ratio, t.cashConversion, 'Cumulative OCF / net profit ${ratio.toStringAsFixed(2)}x over $n yr(s)');

      case Criterion.grossMargin:
        final r = a.ratio(y, RatioCode.grossMargin);
        if (!r.isOk) return incomplete('gross margin $y – ${r.reason}');
        return banded(r.value!, t.grossMargin, 'Gross margin $y ${r.value!.toStringAsFixed(2)}%');

      case Criterion.assetTurnover:
        final r = a.ratio(y, RatioCode.assetTurnover);
        if (!r.isOk) return incomplete('asset turnover $y – ${r.reason}');
        return banded(r.value!, t.assetTurnover, 'Asset turnover $y ${r.value!.toStringAsFixed(2)}x');
    }
  }
}
