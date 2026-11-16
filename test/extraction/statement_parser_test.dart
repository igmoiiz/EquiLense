import 'package:equilense/features/extraction/domain/statement_parser.dart';
import 'package:equilense/features/extraction/domain/taxonomy.dart';
import 'package:equilense/shared/models/metric_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('label matching', () {
    test('synonyms map to standardized codes', () {
      expect(matchLabel('Turnover')!.metric, MetricCode.totalRevenue);
      expect(matchLabel('Revenue from contracts with customers')!.metric, MetricCode.totalRevenue);
      expect(matchLabel('Net profit for the year')!.metric, MetricCode.netProfit);
      expect(matchLabel('Profit after taxation')!.metric, MetricCode.netProfit);
      expect(matchLabel('Stock-in-trade')!.metric, MetricCode.inventory);
      expect(matchLabel("Shareholders' equity")!.metric, MetricCode.shareholdersEquity);
    });
    test('does not blindly map look-alikes', () {
      expect(matchLabel('Other income'), isNull);
      expect(matchLabel('Deferred tax liabilities'), isNull);
      expect(matchLabel('Profit attributable to non-controlling interest'), isNull);
      expect(matchLabel('Total equity and liabilities'), isNull);
      expect(matchLabel('Earnings per share - basic'), isNull);
      expect(matchLabel('Gross profit')!.metric, MetricCode.grossProfit);
      expect(matchLabel('Profit before taxation')!.metric, MetricCode.profitBeforeTax);
    });
    test('exact match has higher confidence than prefix match', () {
      expect(matchLabel('Sales')!.confidence, greaterThan(matchLabel('Sales local and export')!.confidence));
    });
    test('user mappings take precedence', () {
      final m = matchLabel('Income from core business', userMappings: {'income from core business': MetricCode.totalRevenue});
      expect(m!.metric, MetricCode.totalRevenue);
      expect(m.confidence, 1.0);
    });
  });

  group('numbers', () {
    test('brackets are negative', () => expect(StatementParser.parseNumber('(1,234)'), -1234));
    test('commas', () => expect(StatementParser.parseNumber('12,345,678'), 12345678));
    test('dash means empty', () => expect(StatementParser.parseNumber('-'), isNull));
    test('skips note reference', () => expect(StatementParser.pickCurrentValue(['25', '1,200', '1,000']), '1,200'));
    test('skips year header', () => expect(StatementParser.pickCurrentValue(['2023', '5,000']), '5,000'));
    test('keeps small current values (figures in millions)', () {
      expect(StatementParser.pickCurrentValue(['45', '40']), '45');
      expect(StatementParser.pickCurrentValue(['12', '45', '40']), '45'); // note + two years
      expect(StatementParser.pickCurrentValue(['2050', '2040']), '2050');
      expect(StatementParser.pickCurrentValue(['7']), '7');
    });
    test('unit detection', () {
      expect(StatementParser.detectUnitMultiplier("(Rupees in '000)"), 1000);
      expect(StatementParser.detectUnitMultiplier('Rupees in thousand'), 1000);
      expect(StatementParser.detectUnitMultiplier('Rs in million'), 1e6);
      expect(StatementParser.detectUnitMultiplier('Rupees'), 1);
    });
  });

  test('extracts a statement (sample text)', () {
    const text = '''
SAMPLE COMPANY LIMITED
STATEMENT OF PROFIT OR LOSS
(Rupees in '000)
Note 2023 2022
Revenue from contracts with customers 24 1,500,000 1,200,000
Cost of sales 25 (900,000) (750,000)
Gross profit 600,000 450,000
Administrative expenses 26 (80,000) (70,000)
Other income 27 12,000 9,000
Finance cost 28 (30,000) (25,000)
Profit before taxation 400,000 300,000
Taxation 29 (120,000) (90,000)
Profit for the year 280,000 210,000
''';
    final r = StatementParser.extractFromText(text);
    final byCode = {for (final i in r.items) i.metric: i};
    expect(r.unitMultiplier, 1000);
    expect(byCode[MetricCode.totalRevenue]!.value, 1500000000);
    expect(byCode[MetricCode.costOfSales]!.value, 900000000); // expense → positive
    expect(byCode[MetricCode.costOfSales]!.originalValue, '(900,000)');
    expect(byCode[MetricCode.netProfit]!.value, 280000000);
    expect(byCode[MetricCode.taxExpense]!.value, 120000000);
    expect(byCode.containsKey(MetricCode.totalAssets), isFalse);
    expect(r.warnings.single, startsWith('Not found'));
  });

  test('empty text yields manual-entry warning', () {
    final r = StatementParser.extractFromText('   ');
    expect(r.items, isEmpty);
    expect(r.warnings.single, contains('manually'));
  });
}
