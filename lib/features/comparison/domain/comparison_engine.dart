import '../../financial_analysis/domain/company_financials.dart';
import '../../financial_analysis/domain/financial_analysis_engine.dart';
import '../../financial_analysis/domain/integrity_checker.dart';
import '../../forecasting/domain/forecasting_engine.dart';
import '../../scoring/domain/scoring_engine.dart';
import '../../scoring/domain/verdict.dart';

/// Everything computed for one two-company comparison. The dashboard, the
/// exports and the database payload are all produced from this object, so
/// displayed and exported figures are identical.
class ComparisonOutcome {
  const ComparisonOutcome({
    required this.a,
    required this.b,
    required this.forecastsA,
    required this.forecastsB,
    required this.scoreA,
    required this.scoreB,
    required this.verdict,
    required this.weights,
    required this.issues,
    required this.growthWeights,
  });

  final CompanyAnalysis a;
  final CompanyAnalysis b;
  final List<ForecastResult> forecastsA;
  final List<ForecastResult> forecastsB;
  final CompanyScore scoreA;
  final CompanyScore scoreB;
  final Verdict verdict;
  final ScoringWeights weights;
  final GrowthWeights growthWeights;
  final List<IntegrityIssue> issues;

  bool get hasErrors => issues.any((i) => i.severity == IssueSeverity.error);

  bool get isScored => verdict.type != VerdictType.unsupportedIndustry;

  /// JSON payload for the `save_analysis_results` RPC.
  Map<String, Object?> toPayload() {
    num? n(double? v) => v == null || v.isNaN || v.isInfinite ? null : v;
    List<Map<String, Object?>> ratios(CompanyAnalysis x) => [
          for (final y in x.ratios.entries)
            for (final r in y.value.entries)
              {
                'company_id': x.financials.companyId,
                'financial_year': y.key,
                'ratio_code': r.key.code,
                'ratio_value': n(r.value.value),
                'calculation_status': r.value.status.dbValue,
                'note': r.value.isOk ? r.value.note : r.value.reason,
              },
        ];
    List<Map<String, Object?>> forecasts(String companyId, List<ForecastResult> fs) => [
          for (final f in fs)
            {
              'company_id': companyId,
              'forecast_year': f.year,
              'metric_code': f.metric.code,
              'forecast_value': n(f.result.value),
              'forecasting_method': f.method.dbValue,
              'forecast_status': f.result.isOk
                  ? 'ok'
                  : (f.result.status.dbValue == 'missing_input' ? 'insufficient_data' : 'not_meaningful'),
              'assumptions': {...f.assumptions, if (!f.result.isOk) 'reason': f.result.reason},
            },
        ];
    List<Map<String, Object?>> scores(CompanyScore s) => [
          for (final c in s.criteria)
            {
              'company_id': s.companyId,
              'criterion': c.criterion.code,
              'weight': c.weight,
              'raw_metric_value': n(c.rawValue),
              'awarded_points': c.points,
              'maximum_points': c.maxPoints,
              'score_status': c.isScored ? 'scored' : 'incomplete',
              'explanation': c.explanation,
            },
        ];

    return {
      'weights': weights.toJson(),
      'ratios': [...ratios(a), ...ratios(b)],
      'forecasts': [
        ...forecasts(a.financials.companyId, forecastsA),
        ...forecasts(b.financials.companyId, forecastsB),
      ],
      'scores': [...scores(scoreA), ...scores(scoreB)],
      'result': {
        'company_a_score': verdict.scoreA,
        'company_b_score': verdict.scoreB,
        'verdict': verdict.type.dbValue,
        'explanation': verdict.explanation,
        'details': {
          'partial_score_a': scoreA.total,
          'partial_score_b': scoreB.total,
          'growth_weights': growthWeights.mostRecentFirst,
          'issues': [for (final i in issues) i.toString()],
        },
      },
    };
  }
}

abstract final class ComparisonEngine {
  static ComparisonOutcome run({
    required CompanyFinancials companyA,
    required CompanyFinancials companyB,
    required ScoringWeights weights,
    bool industrySupported = true,
    GrowthWeights? growthWeights,
    ScoringThresholds thresholds = const ScoringThresholds(),
  }) {
    final gw = growthWeights ?? GrowthWeights.standard;
    final a = FinancialAnalysisEngine.analyze(companyA);
    final b = FinancialAnalysisEngine.analyze(companyB);
    // Industrial scoring criteria are not applied to unsupported industries
    // (banking, insurance): no criterion scores are produced or persisted.
    CompanyScore score(CompanyAnalysis x) => industrySupported
        ? ScoringEngine.score(x, weights, t: thresholds)
        : CompanyScore(companyId: x.financials.companyId, companyName: x.financials.companyName, criteria: const []);
    final sa = score(a);
    final sb = score(b);
    return ComparisonOutcome(
      a: a,
      b: b,
      forecastsA: ForecastingEngine.forecast(companyA, weights: gw),
      forecastsB: ForecastingEngine.forecast(companyB, weights: gw),
      scoreA: sa,
      scoreB: sb,
      verdict: VerdictEngine.decide(a: a, b: b, scoreA: sa, scoreB: sb, industrySupported: industrySupported),
      weights: weights,
      growthWeights: gw,
      issues: IntegrityChecker.check(companyA, companyB),
    );
  }
}
