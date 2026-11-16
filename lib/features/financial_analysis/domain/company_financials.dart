import '../../../shared/models/metric_code.dart';

/// Validated, standardized figures for one company across its financial years.
/// Only values that exist are stored; absence means "missing", never zero.
class CompanyFinancials {
  CompanyFinancials({
    required this.companyId,
    required this.companyName,
    required this.currency,
    required Map<int, Map<MetricCode, double>> values,
    this.derivations = const [],
  }) : values = Map.unmodifiable({
          for (final e in values.entries) e.key: Map<MetricCode, double>.unmodifiable(e.value),
        });

  final String companyId;
  final String companyName;
  final String currency;
  final Map<int, Map<MetricCode, double>> values;

  /// Human-readable notes for values derived from other values.
  final List<String> derivations;

  List<int> get years => values.keys.toList()..sort();

  double? value(int year, MetricCode metric) => values[year]?[metric];

  /// Returns a copy with expense signs normalized to positive magnitudes and
  /// Gross Profit derived from Revenue − Cost of Sales where it is missing.
  CompanyFinancials normalized() {
    final notes = <String>[...derivations];
    final out = <int, Map<MetricCode, double>>{};
    for (final year in years) {
      final row = <MetricCode, double>{};
      values[year]!.forEach((m, v) => row[m] = m.isExpense ? v.abs() : v);
      final rev = row[MetricCode.totalRevenue];
      final cogs = row[MetricCode.costOfSales];
      if (!row.containsKey(MetricCode.grossProfit) && rev != null && cogs != null) {
        row[MetricCode.grossProfit] = rev - cogs;
        notes.add('$year: Gross Profit derived as Revenue − Cost of Sales');
      }
      out[year] = row;
    }
    return CompanyFinancials(
      companyId: companyId,
      companyName: companyName,
      currency: currency,
      values: out,
      derivations: notes,
    );
  }
}
