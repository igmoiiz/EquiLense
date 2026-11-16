import '../../financial_analysis/domain/financial_analysis_engine.dart';
import '../../../shared/models/metric_code.dart';
import 'scoring_engine.dart';

enum VerdictType {
  recommendA('recommend_a'),
  recommendB('recommend_b'),
  tieHoldBoth('tie_hold_both'),
  inconclusive('inconclusive'),
  insufficientData('insufficient_data'),
  unsupportedIndustry('unsupported_industry');

  const VerdictType(this.dbValue);
  final String dbValue;

  static VerdictType fromDb(String v) => values.firstWhere((e) => e.dbValue == v);

  String label(String a, String b) => switch (this) {
        recommendA => '$a scored higher',
        recommendB => '$b scored higher',
        tieHoldBoth => 'Tie / Hold both',
        inconclusive => 'Inconclusive – review required',
        insufficientData => 'Insufficient data',
        unsupportedIndustry => 'Specialized analysis required',
      };
}

class Verdict {
  const Verdict({required this.type, required this.scoreA, required this.scoreB, required this.reasons});

  final VerdictType type;
  final double? scoreA;
  final double? scoreB;
  final List<String> reasons;

  String get explanation => reasons.join('\n');
}

const disclaimer =
    'This is a comparison of reported financial performance, not personalized investment advice or a valuation.';

abstract final class VerdictEngine {
  /// Recommend when the gap exceeds this many points.
  static const recommendGap = 10.0;

  /// Tie when the gap is at most this many points.
  static const tieGap = 5.0;

  /// Applies the specification's decision rules:
  /// gap > 10 → recommend leader; gap ≤ 5 → tie; 5 < gap ≤ 10 → inconclusive
  /// (the specification does not define this band).
  static VerdictType classify(double scoreA, double scoreB) {
    final gap = ((scoreA - scoreB) * 100).roundToDouble() / 100;
    if (gap > recommendGap) return VerdictType.recommendA;
    if (-gap > recommendGap) return VerdictType.recommendB;
    if (gap.abs() <= tieGap) return VerdictType.tieHoldBoth;
    return VerdictType.inconclusive;
  }

  static Verdict decide({
    required CompanyAnalysis a,
    required CompanyAnalysis b,
    required CompanyScore scoreA,
    required CompanyScore scoreB,
    bool industrySupported = true,
  }) {
    final nameA = scoreA.companyName, nameB = scoreB.companyName;
    if (!industrySupported) {
      return const Verdict(
        type: VerdictType.unsupportedIndustry,
        scoreA: null,
        scoreB: null,
        reasons: [
          'Banking and insurance companies require specialized metrics (capital adequacy, combined ratio, '
              'solvency margins). Industrial ratios would be misleading, so no score was produced.',
          disclaimer,
        ],
      );
    }

    final reasons = <String>[];
    if (!scoreA.isComplete || !scoreB.isComplete) {
      for (final s in [scoreA, scoreB]) {
        if (!s.isComplete) {
          reasons.add('${s.companyName}: could not score ${s.missing.map((c) => c.label).join(', ')}.');
        }
      }
      reasons
        ..add('Partial scores: $nameA ${scoreA.total.toStringAsFixed(2)}, $nameB ${scoreB.total.toStringAsFixed(2)} '
            '(not comparable until data is complete).')
        ..add(disclaimer);
      return Verdict(type: VerdictType.insufficientData, scoreA: null, scoreB: null, reasons: reasons);
    }

    final type = classify(scoreA.total, scoreB.total);
    final gap = (scoreA.total - scoreB.total).abs();
    reasons.add('$nameA scored ${scoreA.total.toStringAsFixed(2)} / 100 and $nameB scored '
        '${scoreB.total.toStringAsFixed(2)} / 100 (gap ${gap.toStringAsFixed(2)} points).');
    reasons.add(switch (type) {
      VerdictType.recommendA => 'The gap exceeds ${recommendGap.toStringAsFixed(0)} points, so $nameA shows the '
          'stronger financial performance.',
      VerdictType.recommendB => 'The gap exceeds ${recommendGap.toStringAsFixed(0)} points, so $nameB shows the '
          'stronger financial performance.',
      VerdictType.tieHoldBoth => 'The gap is within ${tieGap.toStringAsFixed(0)} points: the companies perform '
          'comparably (Tie / Hold both).',
      _ => 'The gap is between ${tieGap.toStringAsFixed(0)} and ${recommendGap.toStringAsFixed(0)} points. The '
          'specification defines no rule for this band, so the result needs manual review.',
    });

    // Per-dimension leaders.
    for (final c in {...scoreA.criteria.map((e) => e.criterion)}) {
      final pa = scoreA.criteria.firstWhere((e) => e.criterion == c).points!;
      final pb = scoreB.criteria.firstWhere((e) => e.criterion == c).points!;
      if ((pa - pb).abs() < 0.01) {
        reasons.add('${c.label}: level (${pa.toStringAsFixed(2)} each).');
      } else {
        final leader = pa > pb ? nameA : nameB;
        reasons.add('${c.label}: $leader stronger (${pa.toStringAsFixed(2)} vs ${pb.toStringAsFixed(2)}).');
      }
    }

    // Weaknesses.
    for (final (analysis, score) in [(a, scoreA), (b, scoreB)]) {
      final weak = weaknesses(analysis);
      if (weak.isNotEmpty) reasons.add('${score.companyName} weaknesses: ${weak.join('; ')}.');
    }
    reasons.add(disclaimer);
    return Verdict(type: type, scoreA: scoreA.total, scoreB: scoreB.total, reasons: reasons);
  }

  static List<String> weaknesses(CompanyAnalysis a) {
    if (a.years.isEmpty) return const [];
    final y = a.latestYear;
    final out = <String>[];
    final cr = a.ratio(y, RatioCode.currentRatio);
    if (cr.isOk && cr.value! < 1) out.add('current ratio below 1.0x (${cr.value!.toStringAsFixed(2)}x)');
    final de = a.ratio(y, RatioCode.debtToEquity);
    if (de.isOk && de.value! > 1) out.add('high leverage (D/E ${de.value!.toStringAsFixed(2)}x)');
    if (!de.isOk && de.reason.contains('Negative')) out.add('negative shareholders\' equity');
    final ic = a.ratio(y, RatioCode.interestCoverage);
    if (ic.isOk && ic.value! < 1.5) out.add('weak interest coverage (${ic.value!.toStringAsFixed(2)}x)');
    final np = a.financials.value(y, MetricCode.netProfit);
    if (np != null && np < 0) out.add('net loss in $y');
    final cc = a.ratio(y, RatioCode.cashConversion);
    if (cc.isOk && cc.value! < 0.8) out.add('operating cash flow lags profit (${cc.value!.toStringAsFixed(2)}x)');
    final g = a.cagr[MetricCode.totalRevenue];
    if (g != null && g.isOk && g.value! < 0) out.add('shrinking revenue (CAGR ${g.value!.toStringAsFixed(2)}%)');
    return out;
  }
}
