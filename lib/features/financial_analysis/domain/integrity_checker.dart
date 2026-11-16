import '../../../shared/models/metric_code.dart';
import 'company_financials.dart';

enum IssueSeverity { error, warning }

class IntegrityIssue {
  const IntegrityIssue(this.severity, this.message, {this.companyName, this.year});

  final IssueSeverity severity;
  final String message;
  final String? companyName;
  final int? year;

  @override
  String toString() =>
      '[${severity.name}] ${companyName ?? ''}${year != null ? ' $year' : ''}: $message';
}

/// Structural and consistency checks run before analysis.
/// Errors indicate data that would make results misleading; warnings indicate
/// gaps that will mark individual calculations as incomplete.
abstract final class IntegrityChecker {
  /// Relative tolerance for accounting identities (rounding in reports).
  static const identityTolerance = 0.02;

  static List<IntegrityIssue> check(CompanyFinancials a, CompanyFinancials b, {int expectedYears = 3}) {
    final issues = <IntegrityIssue>[];
    if (a.currency != b.currency) {
      issues.add(IntegrityIssue(IssueSeverity.error,
          'Currency mismatch: ${a.companyName} reports in ${a.currency}, ${b.companyName} in ${b.currency}.'));
    }
    final ya = a.years, yb = b.years;
    if (ya.isNotEmpty && yb.isNotEmpty && ya.join(',') != yb.join(',')) {
      issues.add(IntegrityIssue(IssueSeverity.warning,
          'Financial years differ (${ya.join(', ')} vs ${yb.join(', ')}). Comparison spans different periods.'));
    }
    issues
      ..addAll(_checkCompany(a, expectedYears))
      ..addAll(_checkCompany(b, expectedYears));
    return issues;
  }

  static List<IntegrityIssue> _checkCompany(CompanyFinancials f, int expectedYears) {
    final issues = <IntegrityIssue>[];
    final name = f.companyName;
    final years = f.years;
    if (years.length < 2) {
      issues.add(IntegrityIssue(IssueSeverity.error,
          'At least two financial years are required (found ${years.length}).', companyName: name));
    } else if (years.length < expectedYears) {
      issues.add(IntegrityIssue(IssueSeverity.warning,
          'Only ${years.length} of $expectedYears financial years provided.', companyName: name));
    }
    for (var i = 1; i < years.length; i++) {
      if (years[i] - years[i - 1] != 1) {
        issues.add(IntegrityIssue(IssueSeverity.warning,
            'Years ${years[i - 1]} and ${years[i]} are not consecutive.', companyName: name));
      }
    }

    for (final y in years) {
      double? v(MetricCode m) => f.value(y, m);
      final missing = MetricCode.required.where((m) => v(m) == null).map((m) => m.label).toList();
      if (missing.isNotEmpty) {
        issues.add(IntegrityIssue(IssueSeverity.warning, 'Missing: ${missing.join(', ')}.',
            companyName: name, year: y));
      }
      final rev = v(MetricCode.totalRevenue);
      if (rev != null && rev <= 0) {
        issues.add(IntegrityIssue(IssueSeverity.error, 'Revenue must be positive (found $rev).',
            companyName: name, year: y));
      }
      final ta = v(MetricCode.totalAssets);
      if (ta != null && ta <= 0) {
        issues.add(IntegrityIssue(IssueSeverity.error, 'Total assets must be positive.', companyName: name, year: y));
      }
      final ca = v(MetricCode.currentAssets);
      if (ca != null && ta != null && ca > ta * (1 + identityTolerance)) {
        issues.add(IntegrityIssue(IssueSeverity.error, 'Current assets exceed total assets.',
            companyName: name, year: y));
      }
      final cl = v(MetricCode.currentLiabilities), tl = v(MetricCode.totalLiabilities);
      if (cl != null && tl != null && cl > tl * (1 + identityTolerance)) {
        issues.add(IntegrityIssue(IssueSeverity.error, 'Current liabilities exceed total liabilities.',
            companyName: name, year: y));
      }
      final eq = v(MetricCode.shareholdersEquity);
      if (ta != null && tl != null && eq != null && !_close(ta, tl + eq)) {
        issues.add(IntegrityIssue(IssueSeverity.warning,
            'Balance sheet does not balance: Total Assets ≠ Total Liabilities + Equity.', companyName: name, year: y));
      }
      final cogs = v(MetricCode.costOfSales), gp = v(MetricCode.grossProfit);
      if (rev != null && cogs != null && gp != null && !_close(gp, rev - cogs.abs())) {
        issues.add(IntegrityIssue(IssueSeverity.warning, 'Gross Profit ≠ Revenue − Cost of Sales.',
            companyName: name, year: y));
      }
      final inv = v(MetricCode.inventory);
      if (inv != null && inv < 0) {
        issues.add(IntegrityIssue(IssueSeverity.error, 'Inventory cannot be negative.', companyName: name, year: y));
      }
    }
    return issues;
  }

  static bool _close(double a, double b) {
    final scale = [a.abs(), b.abs(), 1.0].reduce((x, y) => x > y ? x : y);
    return (a - b).abs() / scale <= identityTolerance;
  }
}
