import 'package:intl/intl.dart';

import '../../features/financial_analysis/domain/calc_result.dart';

abstract final class Fmt {
  static final _compact = NumberFormat.compact();
  static final _grouped = NumberFormat('#,##0');
  static final _date = DateFormat('d MMM yyyy');

  /// Large monetary amounts, e.g. 1.2B. Missing values show an em dash.
  static String money(double? v, {String currency = 'PKR'}) =>
      v == null ? '—' : '$currency ${_compact.format(v)}';

  static String full(double? v) => v == null ? '—' : _grouped.format(v);

  static String pct(double? v, {int digits = 1}) => v == null ? '—' : '${v.toStringAsFixed(digits)}%';

  static String times(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)}x';

  static String date(DateTime? d) => d == null ? '—' : _date.format(d.toLocal());

  static String calc(CalcResult r, {String unit = '%'}) {
    if (!r.isOk) return '—';
    return unit == '%' ? pct(r.value) : times(r.value);
  }
}
