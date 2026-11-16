/// Outcome status of a single calculation. Names match the database
/// `calculation_status` check constraint.
enum CalcStatus {
  ok('ok'),
  missingInput('missing_input'),
  zeroDenominator('zero_denominator'),
  negativeDenominator('negative_denominator'),
  notMeaningful('not_meaningful');

  const CalcStatus(this.dbValue);
  final String dbValue;
}

/// A calculated value that is either present (status ok) or absent with a
/// reason. Missing data is never silently turned into zero.
class CalcResult {
  const CalcResult.ok(double this.value, {this.note}) : status = CalcStatus.ok;
  const CalcResult.fail(this.status, [this.note])
      : assert(status != CalcStatus.ok),
        value = null;

  final double? value;
  final CalcStatus status;
  final String? note;

  bool get isOk => status == CalcStatus.ok;

  String get reason => switch (status) {
        CalcStatus.ok => note ?? '',
        CalcStatus.missingInput => note ?? 'Missing input',
        CalcStatus.zeroDenominator => note ?? 'Denominator is zero',
        CalcStatus.negativeDenominator => note ?? 'Denominator is negative',
        CalcStatus.notMeaningful => note ?? 'Not meaningful',
      };

  @override
  String toString() => isOk ? 'CalcResult($value)' : 'CalcResult(${status.name}: $reason)';
}
