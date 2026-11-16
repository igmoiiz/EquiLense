import 'package:equilense/features/comparison/domain/comparison_engine.dart';
import 'package:equilense/features/financial_analysis/domain/calc_result.dart';
import 'package:equilense/features/financial_analysis/domain/company_financials.dart';
import 'package:equilense/features/financial_analysis/domain/financial_analysis_engine.dart';
import 'package:equilense/features/financial_analysis/domain/integrity_checker.dart';
import 'package:equilense/features/forecasting/domain/forecasting_engine.dart';
import 'package:equilense/features/scoring/domain/scoring_engine.dart';
import 'package:equilense/features/scoring/domain/verdict.dart';
import 'package:equilense/shared/models/metric_code.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/sample_financials.dart';

void main() {
  group('FinancialAnalysisEngine', () {
    final a = FinancialAnalysisEngine.analyze(sampleStrong());

    test('revenue CAGR uses 2 periods', () {
      // 1000 → 1440 over 2 years = 20%
      expect(a.cagr[MetricCode.totalRevenue]!.value, closeTo(20, 1e-9));
    });
    test('YoY starts at second year', () {
      expect(a.yoy[MetricCode.totalRevenue]!.keys, [2022, 2023]);
      expect(a.yoy[MetricCode.totalRevenue]![2022]!.value, closeTo(20, 1e-9));
    });
    test('vertical analysis', () {
      expect(a.vertical[2021]![MetricCode.costOfSales]!.value, closeTo(60, 1e-9));
      expect(a.vertical[2021]![MetricCode.netProfit]!.value, closeTo(20, 1e-9));
    });
    test('ROE uses average equity after first year', () {
      expect(a.ratio(2021, RatioCode.returnOnEquity).note, 'Closing equity');
      expect(a.ratio(2022, RatioCode.returnOnEquity).value, closeTo(260 / 1530 * 100, 1e-9));
    });
    test('expense signs are normalized', () {
      final f = CompanyFinancials(companyId: 'x', companyName: 'X', currency: 'PKR', values: {
        2023: {MetricCode.totalRevenue: 100, MetricCode.costOfSales: -60, MetricCode.adminExpenses: -10},
      });
      final r = FinancialAnalysisEngine.analyze(f);
      expect(r.vertical[2023]![MetricCode.costOfSales]!.value, 60);
      expect(r.financials.value(2023, MetricCode.grossProfit), 40); // derived
      expect(r.financials.derivations, isNotEmpty);
    });
    test('missing values stay missing', () {
      final f = CompanyFinancials(companyId: 'x', companyName: 'X', currency: 'PKR', values: {
        2023: {MetricCode.totalRevenue: 100},
      });
      final r = FinancialAnalysisEngine.analyze(f);
      expect(r.ratio(2023, RatioCode.currentRatio).status, CalcStatus.missingInput);
      expect(r.cagr[MetricCode.totalRevenue]!.status, CalcStatus.notMeaningful);
    });
    test('non-consecutive years flagged for YoY', () {
      final f = CompanyFinancials(companyId: 'x', companyName: 'X', currency: 'PKR', values: {
        2020: {MetricCode.totalRevenue: 100},
        2023: {MetricCode.totalRevenue: 150},
      });
      final r = FinancialAnalysisEngine.analyze(f);
      expect(r.yoy[MetricCode.totalRevenue]![2023]!.status, CalcStatus.notMeaningful);
      expect(r.cagr[MetricCode.totalRevenue]!.value, isNotNull); // 3 elapsed periods
    });
  });

  group('ForecastingEngine', () {
    test('least squares on exact line', () {
      final fit = ForecastingEngine.fitLine([1, 2, 3], [10, 20, 30])!;
      expect(fit.slope, closeTo(10, 1e-9));
      expect(fit.predict(4), closeTo(40, 1e-9));
    });
    test('least squares on noisy data', () {
      final fit = ForecastingEngine.fitLine([1, 2, 3], [10, 25, 30])!;
      // slope = 10, intercept = 21.667 - 20 = 1.667 → predict(4) = 41.667
      expect(fit.slope, closeTo(10, 1e-9));
      expect(fit.predict(4), closeTo(41.6667, 1e-3));
    });
    test('regression needs two points', () => expect(ForecastingEngine.fitLine([1], [5]), isNull));

    test('weighted growth with 2 rates re-normalizes 0.5/0.3', () {
      final r = ForecastingEngine.weightedGrowth(sampleStrong(), MetricCode.totalRevenue, GrowthWeights.standard);
      // both growth rates 20% → weighted 20% → 1440 × 1.2
      expect(r.result.value, closeTo(1728, 1e-6));
      expect((r.assumptions['weights_applied'] as List).cast<double>()[0], closeTo(0.625, 1e-9));
    });
    test('weighted growth rejects negative base', () {
      final r = ForecastingEngine.weightedGrowth(sampleWeak(), MetricCode.netProfit, GrowthWeights.standard);
      expect(r.result.isOk, isFalse);
    });
    test('growth weights must sum to 1', () {
      expect(() => GrowthWeights([0.5, 0.4]), throwsArgumentError);
    });
    test('forecast set covers revenue, profit and margin projections', () {
      final fs = ForecastingEngine.forecast(sampleStrong());
      expect(fs.where((f) => f.method == ForecastMethod.marginStability).length, 5);
      expect(fs.every((f) => f.year == 2024), isTrue);
      final adm = fs.firstWhere(
          (f) => f.metric == MetricCode.adminExpenses && f.method == ForecastMethod.marginStability);
      final avgShare = (40 / 1000 + 45 / 1200 + 50 / 1440) / 3;
      expect(adm.result.value, closeTo(1728 * avgShare, 1e-6));
    });
    test('insufficient history', () {
      final f = CompanyFinancials(companyId: 'x', companyName: 'X', currency: 'PKR', values: {
        2023: {MetricCode.totalRevenue: 100},
      });
      final fs = ForecastingEngine.forecast(f);
      expect(fs.where((r) => r.metric == MetricCode.totalRevenue).every((r) => !r.result.isOk), isTrue);
    });
  });

  group('ScoringEngine', () {
    test('weights must sum to 100', () {
      expect(() => ScoringWeights({Criterion.revenueGrowth: 50}), throwsArgumentError);
      expect(ScoringWeights.standard().total, 100);
    });
    test('strong sample scores high and complete', () {
      final s = ScoringEngine.score(FinancialAnalysisEngine.analyze(sampleStrong()), ScoringWeights.standard());
      expect(s.isComplete, isTrue);
      final rg = s.criteria.firstWhere((c) => c.criterion == Criterion.revenueGrowth);
      expect(rg.points, 25); // CAGR 20% = full band
      expect(s.total, greaterThan(70));
      expect(s.total, lessThanOrEqualTo(100));
    });
    test('negative profits give zero cash-flow points, not missing', () {
      final s = ScoringEngine.score(FinancialAnalysisEngine.analyze(sampleWeak()), ScoringWeights.standard());
      final cf = s.criteria.firstWhere((c) => c.criterion == Criterion.cashFlowQuality);
      expect(cf.points, 0);
    });
    test('missing data marks score incomplete instead of zero', () {
      final f = CompanyFinancials(companyId: 'x', companyName: 'X', currency: 'PKR', values: {
        2022: {MetricCode.totalRevenue: 100},
        2023: {MetricCode.totalRevenue: 120},
      });
      final s = ScoringEngine.score(FinancialAnalysisEngine.analyze(f), ScoringWeights.standard());
      expect(s.isComplete, isFalse);
      expect(s.missing, contains(Criterion.returnOnEquity));
      expect(s.criteria.firstWhere((c) => c.criterion == Criterion.returnOnEquity).points, isNull);
    });
    test('points never exceed allocation', () {
      for (final f in [sampleStrong(), sampleWeak()]) {
        final s = ScoringEngine.score(FinancialAnalysisEngine.analyze(f), ScoringWeights.standard());
        for (final c in s.criteria) {
          expect(c.points!, inInclusiveRange(0, c.maxPoints));
        }
      }
    });
  });

  group('VerdictEngine', () {
    test('gap > 10 recommends leader', () {
      expect(VerdictEngine.classify(70, 59.9), VerdictType.recommendA);
      expect(VerdictEngine.classify(50, 61), VerdictType.recommendB);
    });
    test('gap ≤ 5 is a tie', () {
      expect(VerdictEngine.classify(60, 55), VerdictType.tieHoldBoth);
      expect(VerdictEngine.classify(55, 60), VerdictType.tieHoldBoth);
      expect(VerdictEngine.classify(60, 60), VerdictType.tieHoldBoth);
    });
    test('5 < gap ≤ 10 is inconclusive', () {
      expect(VerdictEngine.classify(60, 54.99), VerdictType.inconclusive);
      expect(VerdictEngine.classify(70, 60), VerdictType.inconclusive);
    });
    test('full comparison recommends the stronger sample', () {
      final o = ComparisonEngine.run(
        companyA: sampleStrong(),
        companyB: sampleWeak(),
        weights: ScoringWeights.standard(),
      );
      expect(o.verdict.type, VerdictType.recommendA);
      expect(o.verdict.explanation, contains(disclaimer));
      expect(o.verdict.explanation, contains('weaknesses'));
    });
    test('unsupported industry', () {
      final o = ComparisonEngine.run(
        companyA: sampleStrong(),
        companyB: sampleWeak(),
        weights: ScoringWeights.standard(),
        industrySupported: false,
      );
      expect(o.verdict.type, VerdictType.unsupportedIndustry);
      expect(o.scoreA.criteria, isEmpty); // industrial criteria not applied
      expect((o.toPayload()['scores'] as List), isEmpty);
    });
    test('insufficient data', () {
      final thin = CompanyFinancials(companyId: 'c', companyName: 'Thin', currency: 'PKR', values: {
        2021: {MetricCode.totalRevenue: 1},
        2022: {MetricCode.totalRevenue: 2},
      });
      final o = ComparisonEngine.run(companyA: sampleStrong(), companyB: thin, weights: ScoringWeights.standard());
      expect(o.verdict.type, VerdictType.insufficientData);
      expect(o.verdict.scoreA, isNull);
    });
  });

  group('IntegrityChecker', () {
    test('currency mismatch is an error', () {
      final b = sampleWeak();
      final usd = CompanyFinancials(companyId: b.companyId, companyName: b.companyName, currency: 'USD', values: b.values);
      final issues = IntegrityChecker.check(sampleStrong(), usd);
      expect(issues.any((i) => i.severity == IssueSeverity.error && i.message.contains('Currency')), isTrue);
    });
    test('clean samples have no errors', () {
      final issues = IntegrityChecker.check(sampleStrong(), sampleWeak());
      expect(issues.where((i) => i.severity == IssueSeverity.error), isEmpty);
    });
    test('invalid values are errors', () {
      final f = CompanyFinancials(companyId: 'x', companyName: 'X', currency: 'PKR', values: {
        2022: {MetricCode.totalRevenue: -5, MetricCode.currentAssets: 500, MetricCode.totalAssets: 100},
        2023: {MetricCode.totalRevenue: 10},
      });
      final errors = IntegrityChecker.check(f, sampleStrong()).where((i) => i.severity == IssueSeverity.error);
      expect(errors.length, greaterThanOrEqualTo(2));
    });
  });

  test('payload is JSON-safe and complete', () {
    final o = ComparisonEngine.run(companyA: sampleStrong(), companyB: sampleWeak(), weights: ScoringWeights.standard());
    final p = o.toPayload();
    expect((p['ratios'] as List).length, 2 * 3 * RatioCode.values.length);
    expect((p['scores'] as List).length, 10);
    expect((p['result'] as Map)['verdict'], 'recommend_a');
  });
}
