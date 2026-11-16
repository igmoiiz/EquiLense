import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../shared/models/models.dart';
import '../../comparison/domain/comparison_engine.dart';
import '../../scoring/domain/verdict.dart';
import '../domain/report_tables.dart';

final _num = NumberFormat('#,##0.##');

String _text(Cell c) => switch (c) {
      null => '—',
      num v => _num.format(v),
      _ => c.toString(),
    };

/// Builds PDF and XLSX reports from the same [ReportTables] the UI uses.
abstract final class ReportExporter {
  static String fileBase(Analysis a) =>
      'EquiLense_${a.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}';

  static Future<Uint8List> pdf(Analysis analysis, ComparisonOutcome o) async {
    final doc = pw.Document(title: analysis.name, author: 'EquiLense');
    final verdictTitle = o.verdict.type.label(analysis.companyA.name, analysis.companyB.name);
    final header = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);
    const cellStyle = pw.TextStyle(fontSize: 7.5);

    pw.Widget table(ReportTable t) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(height: 10),
          pw.Text(t.title, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: t.headers,
            data: [for (final r in t.rows) [for (final c in r) _text(c)]],
            headerStyle: header,
            cellStyle: cellStyle,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {for (var i = 1; i < t.headers.length; i++) i: pw.Alignment.centerRight},
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          ),
        ]);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('EquiLense · page ${c.pageNumber} of ${c.pagesCount}', style: const pw.TextStyle(fontSize: 7)),
      ),
      build: (c) => [
        pw.Text('Financial Performance Comparison', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(analysis.name, style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Generated ${DateFormat('d MMM yyyy HH:mm').format(DateTime.now())} · '
            'Financial years ${analysis.years.first}–${analysis.years.last} · Industry: ${analysis.industry}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        pw.Text('Companies', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        for (final (tag, co) in [('A', analysis.companyA), ('B', analysis.companyB)])
          pw.Text('Company $tag: ${co.name}${co.ticker != null ? ' (${co.ticker})' : ''} · ${co.exchange}'
              '${co.sector != null ? ' · ${co.sector}' : ''}', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueGrey700, width: 0.8)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Verdict: $verdictTitle', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            for (final r in o.verdict.reasons) pw.Bullet(text: r, style: const pw.TextStyle(fontSize: 8.5)),
          ]),
        ),
        table(ReportTables.comparison(o)),
        for (final t in ReportTables.forCompany(o, first: true)) table(t),
        for (final t in ReportTables.forCompany(o, first: false)) table(t),
        pw.SizedBox(height: 12),
        pw.Text('Applied scoring weights', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
        pw.Text(o.weights.toJson().entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(0)}%').join(' · '),
            style: const pw.TextStyle(fontSize: 8.5)),
        if (o.issues.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Data integrity notes', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
          for (final i in o.issues) pw.Bullet(text: i.toString(), style: const pw.TextStyle(fontSize: 8)),
        ],
        pw.SizedBox(height: 12),
        pw.Text('Assumptions and limitations', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
        for (final a in ReportTables.assumptions) pw.Bullet(text: a, style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 6),
        pw.Text(disclaimer, style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
      ],
    ));
    return doc.save();
  }

  static Uint8List excel(Analysis analysis, ComparisonOutcome o) {
    final book = Excel.createExcel();
    final defaultSheet = book.getDefaultSheet();

    void write(String sheetName, List<ReportTable> tables, {List<String> preface = const []}) {
      final s = book[sheetName];
      var row = 0;
      void put(int col, Cell value, {bool bold = false}) {
        final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = switch (value) {
          null => null,
          num v => DoubleCellValue(v.toDouble()),
          _ => TextCellValue(value.toString()),
        };
        if (bold) cell.cellStyle = CellStyle(bold: true);
      }

      for (final line in preface) {
        put(0, line);
        row++;
      }
      if (preface.isNotEmpty) row++;
      for (final t in tables) {
        put(0, t.title, bold: true);
        row++;
        for (final (i, h) in t.headers.indexed) {
          put(i, h, bold: true);
        }
        row++;
        for (final r in t.rows) {
          for (final (i, c) in r.indexed) {
            put(i, c);
          }
          row++;
        }
        row++;
      }
      s.setColumnWidth(0, 36);
    }

    final tablesA = ReportTables.forCompany(o, first: true);
    final tablesB = ReportTables.forCompany(o, first: false);
    write('Company A', [tablesA[0]], preface: ['Company A: ${analysis.companyA.display}']);
    write('Company B', [tablesB[0]], preface: ['Company B: ${analysis.companyB.display}']);
    write('Historical Analysis', [tablesA[1], tablesA[2], tablesB[1], tablesB[2]]);
    write('Financial Ratios', [tablesA[3], tablesB[3]]);
    write('Forecasting', [tablesA[4], tablesB[4]], preface: ['Forecasts are estimates, not guaranteed outcomes.']);
    write('Scoring', [tablesA[5], tablesB[5]], preface: [
      'Weights: ${o.weights.toJson().entries.map((e) => '${e.key} ${e.value.toStringAsFixed(0)}%').join(', ')}',
    ]);
    write('Final Comparison', [ReportTables.comparison(o)], preface: [
      'Verdict: ${o.verdict.type.label(analysis.companyA.name, analysis.companyB.name)}',
      ...o.verdict.reasons,
      '',
      'Assumptions and limitations:',
      ...ReportTables.assumptions,
    ]);
    if (defaultSheet != null && defaultSheet != 'Company A') book.delete(defaultSheet);
    return Uint8List.fromList(book.encode()!);
  }
}
