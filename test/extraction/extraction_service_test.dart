import 'dart:typed_data';

import 'package:equilense/features/extraction/data/extraction_service.dart';
import 'package:equilense/shared/models/metric_code.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

/// Synthetic statements generated in-test (not real company data).
Future<Uint8List> _statementPdf() async {
  final doc = pw.Document();
  const lines = [
    'SAMPLE INDUSTRIES LIMITED',
    'STATEMENT OF PROFIT OR LOSS FOR THE YEAR ENDED 30 JUNE 2023',
    "(Rupees in '000)",
    'Note 2023 2022',
    'Revenue from contracts with customers 24 1,500,000 1,200,000',
    'Cost of sales 25 (900,000) (750,000)',
    'Gross profit 600,000 450,000',
    'Administrative expenses 26 (80,000) (70,000)',
    'Other income 27 12,000 9,000',
    'Finance cost 28 (30,000) (25,000)',
    'Profit before taxation 400,000 300,000',
    'Taxation 29 (120,000) (90,000)',
    'Profit for the year 280,000 210,000',
  ];
  doc.addPage(pw.Page(build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [for (final l in lines) pw.Text(l)],
      )));
  return doc.save();
}

Uint8List _statementXlsx() {
  final book = Excel.createExcel();
  final s = book[book.getDefaultSheet()!];
  final rows = <List<CellValue?>>[
    [TextCellValue('Balance sheet'), TextCellValue('Rupees in million')],
    [TextCellValue('Line item'), IntCellValue(2023), IntCellValue(2022)],
    [TextCellValue('Total current assets'), DoubleCellValue(45.5), DoubleCellValue(40)],
    [TextCellValue('Stock-in-trade'), IntCellValue(12), IntCellValue(10)],
    [TextCellValue('Total assets'), IntCellValue(150), IntCellValue(140)],
    [TextCellValue('Total current liabilities'), TextCellValue('(30)'), IntCellValue(28)],
    [TextCellValue('Total equity'), IntCellValue(90), IntCellValue(85)],
  ];
  for (final r in rows) {
    s.appendRow(r);
  }
  return Uint8List.fromList(book.encode()!);
}

void main() {
  test('PDF text extraction end to end', () async {
    final r = await ExtractionService.extract(bytes: await _statementPdf(), fileType: 'pdf');
    final by = {for (final i in r.items) i.metric: i};
    expect(r.unitMultiplier, 1000);
    expect(by[MetricCode.totalRevenue]?.value, 1500000000);
    expect(by[MetricCode.costOfSales]?.value, 900000000);
    expect(by[MetricCode.netProfit]?.value, 280000000);
    expect(by[MetricCode.taxExpense]?.value, 120000000);
    expect(by.containsKey(MetricCode.totalAssets), isFalse);
  });

  test('blank PDF is reported as scanned / not machine-readable', () async {
    final doc = pw.Document()..addPage(pw.Page(build: (_) => pw.SizedBox()));
    final r = await ExtractionService.extract(bytes: await doc.save(), fileType: 'pdf');
    expect(r.items, isEmpty);
    expect(r.warnings.single, contains('manually'));
  });

  test('XLSX extraction with small values and units in millions', () async {
    final r = await ExtractionService.extract(bytes: _statementXlsx(), fileType: 'xlsx');
    final by = {for (final i in r.items) i.metric: i};
    expect(r.unitMultiplier, 1e6);
    expect(by[MetricCode.currentAssets]?.value, 45.5e6);
    expect(by[MetricCode.inventory]?.value, 12e6); // small current value kept, not treated as a note
    expect(by[MetricCode.totalAssets]?.value, 150e6);
    expect(by[MetricCode.currentLiabilities]?.value, -30e6);
    expect(by[MetricCode.shareholdersEquity]?.value, 90e6);
  });

  test('corrupt file is reported, not thrown', () async {
    final r = await ExtractionService.extract(bytes: Uint8List.fromList([1, 2, 3]), fileType: 'pdf');
    expect(r.items, isEmpty);
    expect(r.warnings, isNotEmpty);
  });
}
