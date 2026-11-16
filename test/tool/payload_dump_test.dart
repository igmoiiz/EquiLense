@Tags(['tool'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:equilense/features/comparison/domain/comparison_engine.dart';
import 'package:equilense/features/financial_analysis/domain/company_financials.dart';
import 'package:equilense/features/scoring/domain/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/sample_financials.dart';

/// Writes an RPC payload to PAYLOAD_OUT for database contract testing.
/// Run: flutter test test/tool --dart-define=... (skipped unless PAYLOAD_OUT is set)
void main() {
  final out = Platform.environment['PAYLOAD_OUT'];
  test('dump payload', () {
    CompanyFinancials withId(CompanyFinancials f, String id) =>
        CompanyFinancials(companyId: id, companyName: f.companyName, currency: f.currency, values: f.values);
    final o = ComparisonEngine.run(
      companyA: withId(sampleStrong(), 'aaaaaaaa-0000-0000-0000-000000000001'),
      companyB: withId(sampleWeak(), 'aaaaaaaa-0000-0000-0000-000000000002'),
      weights: ScoringWeights.standard(),
    );
    File(out!).writeAsStringSync(jsonEncode(o.toPayload()));
  }, skip: out == null ? 'PAYLOAD_OUT not set' : false);
}
