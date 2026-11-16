import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../shared/models/metric_code.dart';
import '../domain/statement_parser.dart';

/// Converts uploaded PDF / XLSX bytes into extracted line items.
/// Parsing runs in a background isolate on native platforms via [compute].
abstract final class ExtractionService {
  /// Minimum characters per page below which a PDF is treated as scanned.
  static const _minCharsPerPage = 40;

  static Future<ExtractionReport> extract({
    required Uint8List bytes,
    required String fileType,
    Map<String, MetricCode> userMappings = const {},
  }) {
    final mappings = {for (final e in userMappings.entries) e.key: e.value.code};
    return compute(_extractIsolate, (bytes: bytes, fileType: fileType, mappings: mappings));
  }

  static ExtractionReport _extractIsolate(({Uint8List bytes, String fileType, Map<String, String> mappings}) input) {
    final mappings = <String, MetricCode>{
      for (final e in input.mappings.entries)
        if (MetricCode.fromCode(e.value) != null) e.key: MetricCode.fromCode(e.value)!,
    };
    return switch (input.fileType) {
      'pdf' => _fromPdf(input.bytes, mappings),
      'xlsx' => _fromExcel(input.bytes, mappings),
      _ => const ExtractionReport(items: [], unitMultiplier: 1, warnings: ['Unsupported file type.']),
    };
  }

  static ExtractionReport _fromPdf(Uint8List bytes, Map<String, MetricCode> mappings) {
    final PdfDocument doc;
    try {
      doc = PdfDocument(inputBytes: bytes);
    } catch (e) {
      return ExtractionReport(items: const [], unitMultiplier: 1, warnings: ['Could not open PDF: $e']);
    }
    try {
      final pages = doc.pages.count;
      final lines = PdfTextExtractor(doc).extractTextLines();
      final text = lines.map((l) => l.text).join('\n');
      if (text.replaceAll(RegExp(r'\s'), '').length < _minCharsPerPage * pages) {
        return const ExtractionReport(items: [], unitMultiplier: 1, warnings: [
          'This PDF contains little or no machine-readable text (likely scanned). On-device OCR is not '
              'available, so enter the figures manually on the review screen.',
        ]);
      }
      return StatementParser.extractFromText(text, userMappings: mappings);
    } finally {
      doc.dispose();
    }
  }

  static ExtractionReport _fromExcel(Uint8List bytes, Map<String, MetricCode> mappings) {
    final Excel book;
    try {
      book = Excel.decodeBytes(bytes);
    } catch (e) {
      return ExtractionReport(items: const [], unitMultiplier: 1, warnings: ['Could not open workbook: $e']);
    }
    final rows = <StatementRow>[];
    final header = StringBuffer();
    for (final sheet in book.tables.values) {
      for (final r in sheet.rows) {
        String? label;
        final numbers = <String>[];
        for (final cell in r) {
          final v = cell?.value;
          switch (v) {
            case TextCellValue():
              final s = v.toString().trim();
              if (s.isEmpty) continue;
              final n = StatementParser.parseNumber(s);
              if (n != null && label != null) {
                numbers.add(s);
              } else {
                label ??= s;
              }
              if (header.length < 4000) header.writeln(s);
            case IntCellValue(:final value):
              if (label != null) numbers.add('$value');
            case DoubleCellValue(:final value):
              if (label != null) numbers.add('$value');
            case FormulaCellValue():
              break; // cached results are not exposed reliably; users can paste values
            default:
              break;
          }
        }
        if (label != null && numbers.isNotEmpty) rows.add(StatementRow(label, numbers));
      }
    }
    return StatementParser.extract(
      rows,
      unitMultiplier: StatementParser.detectUnitMultiplier(header.toString()),
      userMappings: mappings,
    );
  }
}
