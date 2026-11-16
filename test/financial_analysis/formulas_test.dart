import 'package:equilense/features/financial_analysis/domain/calc_result.dart';
import 'package:equilense/features/financial_analysis/domain/formulas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YoY growth', () {
    test('positive growth', () => expect(Formulas.yoyGrowth(120, 100).value, closeTo(20, 1e-9)));
    test('decline', () => expect(Formulas.yoyGrowth(80, 100).value, closeTo(-20, 1e-9)));
    test('zero base', () => expect(Formulas.yoyGrowth(10, 0).status, CalcStatus.zeroDenominator));
    test('negative base', () => expect(Formulas.yoyGrowth(10, -5).status, CalcStatus.negativeDenominator));
    test('missing', () {
      expect(Formulas.yoyGrowth(null, 100).status, CalcStatus.missingInput);
      expect(Formulas.yoyGrowth(100, null).value, isNull);
    });
  });

  group('CAGR', () {
    test('uses elapsed periods (3 observations = 2 periods)', () {
      // 100 → 121 over 2 years = 10%
      expect(Formulas.cagr(100, 121, 2).value, closeTo(10, 1e-9));
    });
    test('zero start', () => expect(Formulas.cagr(0, 100, 2).status, CalcStatus.zeroDenominator));
    test('negative start', () => expect(Formulas.cagr(-10, 100, 2).status, CalcStatus.negativeDenominator));
    test('negative end', () => expect(Formulas.cagr(100, -10, 2).status, CalcStatus.notMeaningful));
    test('insufficient periods', () => expect(Formulas.cagr(100, 120, 0).status, CalcStatus.notMeaningful));
    test('zero end gives -100%', () => expect(Formulas.cagr(100, 0, 2).value, closeTo(-100, 1e-9)));
    test('missing', () => expect(Formulas.cagr(null, 100, 2).status, CalcStatus.missingInput));
  });

  group('Vertical analysis', () {
    test('percent of revenue', () => expect(Formulas.verticalPercent(25, 200).value, closeTo(12.5, 1e-9)));
    test('revenue itself is 100%', () => expect(Formulas.verticalPercent(200, 200).value, 100));
    test('zero revenue', () => expect(Formulas.verticalPercent(25, 0).status, CalcStatus.zeroDenominator));
    test('negative revenue', () => expect(Formulas.verticalPercent(25, -1).status, CalcStatus.negativeDenominator));
  });

  group('Liquidity', () {
    test('current ratio', () => expect(Formulas.currentRatio(300, 150).value, 2));
    test('current ratio zero liabilities',
        () => expect(Formulas.currentRatio(300, 0).status, CalcStatus.zeroDenominator));
    test('quick ratio', () => expect(Formulas.quickRatio(300, 100, 100).value, 2));
    test('quick ratio requires inventory (never assumes zero)',
        () => expect(Formulas.quickRatio(300, null, 100).status, CalcStatus.missingInput));
  });

  group('Profitability', () {
    test('gross margin', () => expect(Formulas.grossMargin(40, 200).value, 20));
    test('net margin negative profit', () => expect(Formulas.netMargin(-20, 200).value, -10));
    test('ROE closing equity', () {
      final r = Formulas.returnOnEquity(50, 250);
      expect(r.value, 20);
      expect(r.note, 'Closing equity');
    });
    test('ROE average equity', () {
      final r = Formulas.returnOnEquity(50, 300, openingEquity: 200);
      expect(r.value, 20);
      expect(r.note, 'Average equity');
    });
    test('ROE negative equity',
        () => expect(Formulas.returnOnEquity(50, -100).status, CalcStatus.negativeDenominator));
  });

  group('Solvency', () {
    test('debt to equity', () => expect(Formulas.debtToEquity(50, 100).value, 0.5));
    test('D/E zero debt is 0 (debt known to be zero)', () => expect(Formulas.debtToEquity(0, 100).value, 0));
    test('D/E negative equity', () => expect(Formulas.debtToEquity(50, -1).status, CalcStatus.negativeDenominator));
    test('interest coverage', () => expect(Formulas.interestCoverage(100, 25).value, 4));
    test('interest coverage accepts bracketed (negative) finance cost',
        () => expect(Formulas.interestCoverage(100, -25).value, 4));
    test('interest coverage no finance cost',
        () => expect(Formulas.interestCoverage(100, 0).status, CalcStatus.zeroDenominator));
  });

  group('Normalization', () {
    test('ascending band', () {
      expect(Formulas.normalize(0, worst: 0, best: 20), 0);
      expect(Formulas.normalize(10, worst: 0, best: 20), 0.5);
      expect(Formulas.normalize(40, worst: 0, best: 20), 1);
      expect(Formulas.normalize(-5, worst: 0, best: 20), 0);
    });
    test('descending band (lower is better)', () {
      expect(Formulas.normalize(3, worst: 15, best: 3), 1);
      expect(Formulas.normalize(9, worst: 15, best: 3), 0.5);
      expect(Formulas.normalize(20, worst: 15, best: 3), 0);
    });
  });
}
