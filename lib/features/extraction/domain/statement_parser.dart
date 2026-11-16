import '../../../shared/models/metric_code.dart';
import 'taxonomy.dart';

/// A candidate value found in a document, before user validation.
class ExtractedItem {
  const ExtractedItem({
    required this.metric,
    required this.originalLabel,
    required this.originalValue,
    required this.value,
    required this.confidence,
  });

  final MetricCode metric;
  final String originalLabel;
  final String originalValue;

  /// Value after sign handling and unit scaling (e.g. "Rupees in '000" × 1000).
  final double value;
  final double confidence;
}

class ExtractionReport {
  const ExtractionReport({required this.items, required this.unitMultiplier, required this.warnings});

  final List<ExtractedItem> items;
  final double unitMultiplier;
  final List<String> warnings;
}

/// One logical row: a label and the numeric cells that follow it.
class StatementRow {
  const StatementRow(this.label, this.numbers);
  final String label;
  final List<String> numbers;
}

abstract final class StatementParser {
  static final _number = RegExp(r'\(?-?\d{1,3}(?:,\d{3})+(?:\.\d+)?\)?|\(?-?\d+(?:\.\d+)?\)?');

  /// Detects reporting units such as "Rupees in thousand", "Rs. '000", "(Rupees in million)".
  static double detectUnitMultiplier(String text) {
    final t = text.toLowerCase();
    if (RegExp(r"(rupees|rs\.?|pkr)\s*(in\s*)?(millions?|mn|'?000,?000)").hasMatch(t) ||
        RegExp(r'in millions?').hasMatch(t)) {
      return 1e6;
    }
    if (RegExp(r"(rupees|rs\.?|pkr)\s*(in\s*)?(thousands?|'000|000s)").hasMatch(t) ||
        RegExp(r"\(\s*'?000\s*\)").hasMatch(t)) {
      return 1e3;
    }
    return 1;
  }

  /// Parses "1,234", "(1,234)", "-1234.5". Brackets denote negatives.
  static double? parseNumber(String raw) {
    var s = raw.trim();
    if (s.isEmpty || s == '-' || s == '—') return null;
    final negative = s.startsWith('(') && s.endsWith(')') || s.startsWith('-');
    s = s.replaceAll(RegExp(r'[(),\s-]'), '');
    final v = double.tryParse(s);
    if (v == null) return null;
    return negative ? -v : v;
  }

  /// Splits a text line into its label and trailing numeric tokens.
  static StatementRow? splitLine(String line) {
    final matches = _number.allMatches(line).toList();
    if (matches.isEmpty) return null;
    final first = matches.first;
    final label = line.substring(0, first.start).trim();
    if (label.length < 3) return null;
    return StatementRow(label, [for (final m in matches) m.group(0)!]);
  }

  /// Picks the current-year figure from a row's numbers. A leading note
  /// reference (small number such as "25" or "25.1") or year header is skipped
  /// only when what follows still looks like the value columns: three or more
  /// tokens, or a next token that is clearly an amount. "45 40" (small figures
  /// in millions) is therefore kept as current = 45.
  static String? pickCurrentValue(List<String> numbers) {
    final candidates = [...numbers];
    while (candidates.length > 1 &&
        _looksLikeNoteOrYear(candidates.first) &&
        (candidates.length >= 3 || !_looksLikeNoteOrYear(candidates[1]))) {
      candidates.removeAt(0);
    }
    if (candidates.isEmpty) return null;
    return candidates.first;
  }

  static bool _looksLikeNoteOrYear(String token) {
    if (token.contains(',') || token.contains('(')) return false;
    final v = double.tryParse(token);
    if (v == null) return false;
    if (v == v.roundToDouble() && v >= 1990 && v <= 2100) return true; // year header
    return v < 100 && RegExp(r'^\d{1,2}(\.\d{1,2})?$').hasMatch(token); // note ref
  }

  /// Turns rows into one candidate per metric (highest confidence wins, ties
  /// go to the first occurrence, which is normally the primary statement).
  static ExtractionReport extract(
    Iterable<StatementRow> rows, {
    required double unitMultiplier,
    Map<String, MetricCode> userMappings = const {},
  }) {
    final best = <MetricCode, ExtractedItem>{};
    for (final row in rows) {
      final match = matchLabel(row.label, userMappings: userMappings);
      if (match == null) continue;
      final raw = pickCurrentValue(row.numbers);
      if (raw == null) continue;
      final parsed = parseNumber(raw);
      if (parsed == null) continue;
      final value = (match.metric.isExpense ? parsed.abs() : parsed) * unitMultiplier;
      final existing = best[match.metric];
      if (existing == null || match.confidence > existing.confidence) {
        best[match.metric] = ExtractedItem(
          metric: match.metric,
          originalLabel: row.label,
          originalValue: raw,
          value: value,
          confidence: match.confidence,
        );
      }
    }
    final warnings = <String>[];
    if (best.isEmpty) {
      warnings.add('No recognizable financial line items were found. Enter values manually on the review screen.');
    }
    final missing = MetricCode.required.where((m) => !best.containsKey(m)).map((m) => m.label);
    if (best.isNotEmpty && missing.isNotEmpty) warnings.add('Not found: ${missing.join(', ')}.');
    final items = best.values.toList()..sort((a, b) => a.metric.index.compareTo(b.metric.index));
    return ExtractionReport(items: items, unitMultiplier: unitMultiplier, warnings: warnings);
  }

  /// Text (PDF) entry point.
  static ExtractionReport extractFromText(String text, {Map<String, MetricCode> userMappings = const {}}) {
    final rows = text.split(RegExp(r'\r?\n')).map(splitLine).whereType<StatementRow>();
    return extract(rows, unitMultiplier: detectUnitMultiplier(text), userMappings: userMappings);
  }
}
