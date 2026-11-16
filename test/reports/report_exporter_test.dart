import 'package:equilense/features/comparison/domain/comparison_engine.dart';
import 'package:equilense/features/documents/data/document_repository.dart';
import 'package:equilense/features/reports/data/report_exporter.dart';
import 'package:equilense/features/reports/domain/report_tables.dart';
import 'package:equilense/features/scoring/domain/scoring_engine.dart';
import 'package:equilense/shared/models/models.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/sample_financials.dart';

void main() {
  final analysis = Analysis(
    id: 'x',
    name: 'Sample comparison',
    companyA: const Company(id: 'a', name: 'Sample Alpha', ticker: 'ALP'),
    companyB: const Company(id: 'b', name: 'Sample Beta', ticker: 'BET'),
    industry: 'other',
    firstYear: 2021,
    currency: 'PKR',
    status: AnalysisStatus.completed,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
  final outcome = ComparisonEngine.run(
    companyA: sampleStrong(),
    companyB: sampleWeak(),
    weights: ScoringWeights.standard(),
  );

  test('PDF report renders', () async {
    final bytes = await ReportExporter.pdf(analysis, outcome);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(5000));
  });

  test('Excel report has required worksheets and matching figures', () {
    final bytes = ReportExporter.excel(analysis, outcome);
    final book = Excel.decodeBytes(bytes);
    expect(book.tables.keys, containsAll(['Company A', 'Company B', 'Historical Analysis', 'Financial Ratios',
        'Forecasting', 'Scoring', 'Final Comparison']));
    // Total score row in the Scoring sheet equals the engine's total.
    final scoring = book.tables['Scoring']!;
    final totals = [
      for (final r in scoring.rows)
        if (r.isNotEmpty && r.first?.value.toString() == 'Total') (r[3]!.value as DoubleCellValue).value,
    ];
    expect(totals, [outcome.scoreA.total, outcome.scoreB.total]);
  });

  test('report tables never print missing values as zero', () {
    final t = ReportTables.historical(outcome.a);
    expect(t.rows.every((r) => r.skip(1).every((c) => c == null || c is num)), isTrue);
  });

  group('upload validation', () {
    test('rejects xls', () => expect(validateUpload(fileName: 'a.xls', sizeBytes: 10), contains('.xlsx')));
    test('rejects other types', () => expect(validateUpload(fileName: 'a.docx', sizeBytes: 10), isNotNull));
    test('rejects oversize', () => expect(validateUpload(fileName: 'a.pdf', sizeBytes: 26 * 1024 * 1024), isNotNull));
    test('rejects empty', () => expect(validateUpload(fileName: 'a.pdf', sizeBytes: 0), isNotNull));
    test('accepts pdf/xlsx', () {
      expect(validateUpload(fileName: 'Report.PDF', sizeBytes: 1000), isNull);
      expect(validateUpload(fileName: 'fs.xlsx', sizeBytes: 1000), isNull);
    });
  });
}
