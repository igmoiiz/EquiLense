import 'package:equilense/app/theme/app_theme.dart';
import 'package:equilense/features/analysis/data/analysis_repository.dart';
import 'package:equilense/features/analysis/presentation/analysis_hub_screen.dart';
import 'package:equilense/features/analysis/presentation/new_analysis_screen.dart';
import 'package:equilense/features/authentication/data/auth_repository.dart';
import 'package:equilense/features/authentication/presentation/auth_screens.dart';
import 'package:equilense/features/companies/data/company_repository.dart';
import 'package:equilense/features/comparison/data/comparison_provider.dart';
import 'package:equilense/features/comparison/domain/comparison_engine.dart';
import 'package:equilense/features/comparison/presentation/results_screen.dart';
import 'package:equilense/features/dashboard/presentation/dashboard_screen.dart';
import 'package:equilense/features/documents/data/document_repository.dart';
import 'package:equilense/features/scoring/domain/scoring_engine.dart';
import 'package:equilense/features/validation/data/financial_data_repository.dart';
import 'package:equilense/features/validation/presentation/validation_screen.dart';
import 'package:equilense/shared/models/metric_code.dart';
import 'package:equilense/shared/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/sample_financials.dart';

const _longA = 'Sample Alpha Cement & Construction Materials Company Limited';
const _longB = 'Sample Beta Industrial Holdings (Private) Limited';

final _analysis = Analysis(
  id: 'an1',
  name: 'Sample comparison',
  companyA: const Company(id: 'a', name: _longA, ticker: 'ALP'),
  companyB: const Company(id: 'b', name: _longB, ticker: 'BET'),
  industry: 'other',
  firstYear: 2021,
  currency: 'PKR',
  status: AnalysisStatus.completed,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

const _industries = [
  Industry(code: 'other', label: 'Other', supported: true),
  Industry(code: 'banking', label: 'Banking', supported: false, notes: 'Specialized.'),
];

AnalysisData _data() {
  final periods = <FinancialPeriod>[];
  final metrics = <MetricRecord>[];
  for (final (cid, f) in [('a', sampleStrong()), ('b', sampleWeak())]) {
    for (final y in f.years) {
      final pid = '$cid-$y';
      periods.add(FinancialPeriod(id: pid, companyId: cid, year: y, currency: 'PKR', isValidated: true));
      f.values[y]!.forEach((m, v) => metrics.add(MetricRecord(
            id: '$pid-${m.code}',
            analysisId: 'an1',
            periodId: pid,
            companyId: cid,
            metricCode: m.code,
            value: v,
            entrySource: 'pdf',
            status: ValidationStatus.validated,
            originalLabel: m.label,
            confidence: 0.95,
          )));
    }
  }
  return AnalysisData(periods: periods, metrics: metrics);
}

ComparisonState _state({bool supported = true}) {
  final d = _data();
  return ComparisonState(
    analysis: _analysis,
    outcome: ComparisonEngine.run(
      companyA: d.financialsFor(_analysis.companyA, validatedOnly: true),
      companyB: d.financialsFor(_analysis.companyB, validatedOnly: true),
      weights: ScoringWeights.standard(),
      industrySupported: supported,
    ),
    validated: true,
    industry: supported ? _industries.first : _industries.last,
  );
}

final _overrides = [
  analysisProvider.overrideWith((ref, id) async => _analysis),
  analysisDataProvider.overrideWith((ref, id) async => _data()),
  documentsProvider.overrideWith((ref, id) async => <FinancialDocument>[]),
  companiesProvider.overrideWith((ref) async => [_analysis.companyA, _analysis.companyB]),
  industriesProvider.overrideWith((ref) async => _industries),
  industryWeightsProvider.overrideWith((ref, code) async => ScoringWeights.standard()),
  analysesProvider.overrideWith((ref) async => [_analysis]),
  dashboardStatsProvider.overrideWith((ref) async => (analyses: 1, companies: 2, completed: 1)),
  profileProvider.overrideWith(
      (ref) async => const Profile(id: 'u', email: 'u@example.com', fullName: 'Test User', defaultCurrency: 'PKR')),
];

Future<void> _pump(WidgetTester tester, Widget screen, Size size, {List<dynamic> extra = const []}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [..._overrides, ...extra.cast()],
    child: MaterialApp(theme: AppTheme.light(), home: screen),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, String tab) async {
  final f = find.widgetWithText(Tab, tab);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [Size(375, 812), Size(1280, 800)]) {
    final label = '${size.width.toInt()}px';

    testWidgets('login renders and validates ($label)', (tester) async {
      await _pump(tester, const LoginScreen(), size);
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pump();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });

    testWidgets('register renders ($label)', (tester) async {
      await _pump(tester, const RegisterScreen(), size);
      expect(find.text('Create account'), findsWidgets);
    });

    testWidgets('dashboard renders real counts ($label)', (tester) async {
      await _pump(tester, const DashboardScreen(), size);
      expect(find.text('Welcome, Test'), findsOneWidget);
      expect(find.text('Sample comparison'), findsOneWidget);
    });

    testWidgets('new analysis renders company selection ($label)', (tester) async {
      await _pump(tester, const NewAnalysisScreen(), size);
      expect(find.text('Company A *'), findsOneWidget);
      expect(find.text('Revenue Growth'), findsOneWidget);
      expect(find.text('Total 100.0%'), findsOneWidget);
    });

    testWidgets('analysis hub renders steps ($label)', (tester) async {
      await _pump(tester, const AnalysisHubScreen(analysisId: 'an1'), size);
      expect(find.text('Upload financial statements'), findsOneWidget);
      expect(find.textContaining('Dataset confirmed'), findsOneWidget);
    });

    testWidgets('validation grid renders values ($label)', (tester) async {
      await _pump(tester, const ValidationScreen(analysisId: 'an1'), size);
      expect(find.text('Income statement'), findsOneWidget);
      expect(find.text('1,000'), findsWidgets); // Sample Alpha FY2021 revenue
      expect(find.text('View results'), findsOneWidget);
      // Open the edit dialog for a value.
      await tester.tap(find.text('1,440').first);
      await tester.pumpAndSettle();
      expect(find.text('Save & confirm'), findsOneWidget);
    });

    testWidgets('results: every tab renders ($label)', (tester) async {
      await _pump(tester, const ResultsScreen(analysisId: 'an1'), size,
          extra: [comparisonProvider.overrideWith((ref, id) async => _state())]);
      for (final tab in ['Overview', 'Growth', 'Ratios', 'Cash flow', 'Forecast', 'Scoring', 'Verdict']) {
        await _openTab(tester, tab);
        expect(tester.takeException(), isNull, reason: tab);
      }
      expect(find.textContaining('scored higher'), findsWidgets);
    });

    testWidgets('results: unsupported industry is not scored ($label)', (tester) async {
      await _pump(tester, const ResultsScreen(analysisId: 'an1'), size,
          extra: [comparisonProvider.overrideWith((ref, id) async => _state(supported: false))]);
      expect(find.text('Not scored'), findsNWidgets(2));
      await _openTab(tester, 'Scoring');
      expect(find.text('Banking is not scored'), findsOneWidget);
    });
  }

  test('fixture covers every required metric', () {
    final codes = _data().metrics.map((m) => m.metricCode).toSet();
    for (final m in MetricCode.required) {
      expect(codes, contains(m.code));
    }
  });
}
