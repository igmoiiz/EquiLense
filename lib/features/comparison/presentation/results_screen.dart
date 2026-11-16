import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../shared/models/metric_code.dart';
import '../../../shared/models/models.dart';
import '../../analysis/data/analysis_repository.dart';
import '../../financial_analysis/domain/calc_result.dart';
import '../../financial_analysis/domain/financial_analysis_engine.dart';
import '../../financial_analysis/domain/integrity_checker.dart';
import '../../forecasting/domain/forecasting_engine.dart';
import '../../reports/data/report_exporter.dart';
import '../../scoring/domain/verdict.dart';
import '../data/comparison_provider.dart';
import '../domain/comparison_engine.dart';
import 'charts.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key, required this.analysisId});

  final String analysisId;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool _saving = false;
  bool _autoSaved = false;

  static const _tabs = ['Overview', 'Growth', 'Ratios', 'Cash flow', 'Forecast', 'Scoring', 'Verdict'];

  Future<void> _save(ComparisonState s, {bool silent = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(analysisRepositoryProvider).saveResults(s.analysis.id, s.outcome.toPayload());
      ref
        ..invalidate(analysisProvider(s.analysis.id))
        ..invalidate(analysesProvider)
        ..invalidate(dashboardStatsProvider);
      if (mounted && !silent) showSnack(context, 'Results saved.');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save results: ${describeError(e)}', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _export(ComparisonState s, {required bool pdf}) async {
    try {
      final name = ReportExporter.fileBase(s.analysis);
      final bytes = pdf ? await ReportExporter.pdf(s.analysis, s.outcome) : ReportExporter.excel(s.analysis, s.outcome);
      await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        fileExtension: pdf ? 'pdf' : 'xlsx',
        mimeType: pdf ? MimeType.pdf : MimeType.microsoftExcel,
      );
      if (mounted) showSnack(context, '${pdf ? 'PDF' : 'Excel'} report saved as $name.${pdf ? 'pdf' : 'xlsx'}');
    } catch (e) {
      if (mounted) showSnack(context, 'Export failed: ${describeError(e)}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(comparisonProvider(widget.analysisId));

    // Persist automatically the first time results are computed from a validated dataset.
    ref.listen(comparisonProvider(widget.analysisId), (_, next) {
      final s = next.value;
      if (s != null && s.validated && !_autoSaved && s.analysis.status != AnalysisStatus.completed) {
        _autoSaved = true;
        _save(s, silent: true);
      }
    });

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(state.value?.analysis.name ?? 'Results'),
          actions: [
            if (state.value case final s?) ...[
              IconButton(
                tooltip: 'Recalculate and save',
                onPressed: _saving || !s.validated ? null : () => _save(s),
                icon: _saving
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
              ),
              PopupMenuButton<bool>(
                tooltip: 'Export report',
                icon: const Icon(Icons.ios_share),
                onSelected: (pdf) => _export(s, pdf: pdf),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: true, child: Text('Export PDF report')),
                  PopupMenuItem(value: false, child: Text('Export Excel workbook')),
                ],
              ),
            ],
          ],
          bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final t in _tabs) Tab(text: t)]),
        ),
        body: AsyncView(
          value: state,
          onRetry: () => ref.invalidate(comparisonProvider(widget.analysisId)),
          data: (s) {
            if (!s.validated) return _NotValidated(analysisId: widget.analysisId);
            final o = s.outcome;
            return TabBarView(children: [
              _Overview(s: s),
              _Growth(o: o),
              _Ratios(o: o),
              _CashFlow(o: o),
              _Forecast(o: o),
              _Scoring(o: o, industry: s.industry),
              _VerdictTab(s: s),
            ]);
          },
        ),
      ),
    );
  }
}

class _NotValidated extends StatelessWidget {
  const _NotValidated({required this.analysisId});
  final String analysisId;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.fact_check_outlined,
        title: 'Dataset not confirmed',
        message: 'Results are only calculated from validated figures. Review the extracted values and confirm the '
            'dataset first. Any edit after confirmation requires re-confirmation.',
        action: FilledButton(onPressed: () => context.go('/analyses/$analysisId/validate'), child: const Text('Review data')),
      );
}

// ---------------------------------------------------------------------------

class _CompanyHeader extends StatelessWidget {
  const _CompanyHeader({required this.o});
  final ComparisonOutcome o;

  @override
  Widget build(BuildContext context) => Legend(items: [
        (o.a.financials.companyName, Theme.of(context).colorScheme.companyA, false),
        (o.b.financials.companyName, Theme.of(context).colorScheme.companyB, false),
      ]);
}

/// Two-column comparison table: metric | A | B, one row per year when needed.
class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.o, required this.rows});

  final ComparisonOutcome o;
  final List<(String label, String a, String b)> rows;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = t.colorScheme;
    final head = t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);
    Widget cell(String v, {TextStyle? style, TextAlign align = TextAlign.right}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Text(v, textAlign: align, style: style ?? t.textTheme.bodySmall),
        );
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.6), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
      border: TableBorder(horizontalInside: BorderSide(color: s.outlineVariant.withValues(alpha: 0.6))),
      children: [
        TableRow(children: [
          cell('Metric', style: head, align: TextAlign.left),
          cell(o.a.financials.companyName, style: head?.copyWith(color: s.companyA)),
          cell(o.b.financials.companyName, style: head?.copyWith(color: s.companyB)),
        ]),
        for (final (label, a, b) in rows)
          TableRow(children: [cell(label, align: TextAlign.left), cell(a), cell(b)]),
      ],
    );
  }
}

String _fmtCalc(CalcResult r, String unit) => r.isOk ? (unit == '%' ? Fmt.pct(r.value) : Fmt.times(r.value)) : 'n/a';

List<double?> _series(CompanyAnalysis a, List<int> years, MetricCode m) => [for (final y in years) a.financials.value(y, m)];

List<int> _years(ComparisonOutcome o) => {...o.a.years, ...o.b.years}.toList()..sort();

class _Overview extends StatelessWidget {
  const _Overview({required this.s});
  final ComparisonState s;

  @override
  Widget build(BuildContext context) {
    final o = s.outcome;
    final a = s.analysis;
    final scheme = Theme.of(context).colorScheme;
    final title = o.verdict.type.label(a.companyA.name, a.companyB.name);
    final warnings = o.issues.where((i) => i.severity == IssueSeverity.warning).length;
    final errors = o.issues.where((i) => i.severity == IssueSeverity.error).length;
    return PageBody(children: [
      Card(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Financial performance verdict', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(o.verdict.reasons.first),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      ResponsiveGrid(minItemWidth: 220, children: [
        for (final (score, color) in [(o.scoreA, scheme.companyA), (o.scoreB, scheme.companyB)])
          StatTile(
            label: '${score.companyName} score',
            value: !o.isScored ? 'Not scored' : (score.isComplete ? score.total.toStringAsFixed(1) : 'Incomplete'),
            caption: !o.isScored
                ? 'specialized industry'
                : (score.isComplete ? 'out of 100' : 'partial ${score.total.toStringAsFixed(1)}'),
            color: color,
          ),
        StatTile(label: 'Financial years', value: _years(o).map((y) => 'FY$y').join(' · '), caption: a.currency),
        StatTile(
          label: 'Data checks',
          value: errors > 0 ? '$errors error(s)' : (warnings > 0 ? '$warnings warning(s)' : 'All passed'),
          color: errors > 0 ? scheme.negative : null,
        ),
      ]),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Revenue',
        subtitle: 'Reported revenue by financial year',
        trailing: _CompanyHeader(o: o),
        child: GroupedBarChart(
          years: _years(o),
          a: _series(o.a, _years(o), MetricCode.totalRevenue),
          b: _series(o.b, _years(o), MetricCode.totalRevenue),
        ),
      ),
      if (o.issues.isNotEmpty) ...[
        const SizedBox(height: 12),
        SectionCard(
          title: 'Data integrity notes',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final i in o.issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${i.severity == IssueSeverity.error ? '✕' : '•'} $i',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ]),
        ),
      ],
    ]);
  }
}

class _Growth extends StatelessWidget {
  const _Growth({required this.o});
  final ComparisonOutcome o;

  @override
  Widget build(BuildContext context) {
    final years = _years(o);
    return PageBody(children: [
      for (final m in [MetricCode.grossProfit, MetricCode.netProfit])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SectionCard(
            title: m.label,
            trailing: _CompanyHeader(o: o),
            child: GroupedBarChart(years: years, a: _series(o.a, years, m), b: _series(o.b, years, m)),
          ),
        ),
      SectionCard(
        title: 'Horizontal analysis',
        subtitle: 'Year-over-year growth and CAGR over elapsed years',
        child: _CompareTable(o: o, rows: [
          for (final m in FinancialAnalysisEngine.horizontalMetrics) ...[
            ('${m.label} CAGR', _fmtCalc(o.a.cagr[m]!, '%'), _fmtCalc(o.b.cagr[m]!, '%')),
            for (final y in years.skip(1))
              (
                '  YoY FY$y',
                _fmtCalc(o.a.yoy[m]?[y] ?? const CalcResult.fail(CalcStatus.missingInput), '%'),
                _fmtCalc(o.b.yoy[m]?[y] ?? const CalcResult.fail(CalcStatus.missingInput), '%'),
              ),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Vertical analysis',
        subtitle: 'Line items as % of revenue (latest year shown first)',
        child: _CompareTable(o: o, rows: [
          for (final y in years.reversed)
            for (final m in FinancialAnalysisEngine.verticalMetrics)
              (
                '${m.label} FY$y',
                _fmtCalc(o.a.vertical[y]?[m] ?? const CalcResult.fail(CalcStatus.missingInput), '%'),
                _fmtCalc(o.b.vertical[y]?[m] ?? const CalcResult.fail(CalcStatus.missingInput), '%'),
              ),
        ]),
      ),
    ]);
  }
}

class _Ratios extends StatelessWidget {
  const _Ratios({required this.o});
  final ComparisonOutcome o;

  @override
  Widget build(BuildContext context) {
    final years = _years(o);
    Widget group(String title, List<RatioCode> codes) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SectionCard(
            title: title,
            child: _CompareTable(o: o, rows: [
              for (final r in codes)
                for (final y in years.reversed) ('${r.label} FY$y', _fmtCalc(o.a.ratio(y, r), r.unit), _fmtCalc(o.b.ratio(y, r), r.unit)),
            ]),
          ),
        );
    return PageBody(children: [
      SectionCard(
        title: 'Margins',
        trailing: _CompanyHeader(o: o),
        child: Column(children: [
          for (final r in RatioCode.profitability.take(2)) ...[
            Align(alignment: Alignment.centerLeft, child: Text(r.label, style: Theme.of(context).textTheme.labelMedium)),
            GroupedBarChart(
              years: years,
              percent: true,
              height: 180,
              a: [for (final y in years) o.a.ratio(y, r).value],
              b: [for (final y in years) o.b.ratio(y, r).value],
            ),
            const SizedBox(height: 8),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      group('Profitability', RatioCode.profitability),
      group('Liquidity', RatioCode.liquidity),
      group('Solvency', RatioCode.solvency),
      group('Efficiency', const [RatioCode.assetTurnover, RatioCode.adminExpensePct]),
      Text('n/a = not calculable (missing input, zero or negative denominator). Missing values are never treated as zero.',
          style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _CashFlow extends StatelessWidget {
  const _CashFlow({required this.o});
  final ComparisonOutcome o;

  @override
  Widget build(BuildContext context) {
    final years = _years(o);
    return PageBody(children: [
      SectionCard(
        title: 'Operating cash flow',
        trailing: _CompanyHeader(o: o),
        child: GroupedBarChart(
          years: years,
          a: _series(o.a, years, MetricCode.operatingCashFlow),
          b: _series(o.b, years, MetricCode.operatingCashFlow),
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Cash conversion',
        subtitle: 'Operating cash flow ÷ net profit. Above 1.0x means profits are backed by cash.',
        child: _CompareTable(o: o, rows: [
          for (final y in years.reversed) ...[
            ('Operating cash flow FY$y', Fmt.full(o.a.financials.value(y, MetricCode.operatingCashFlow)),
                Fmt.full(o.b.financials.value(y, MetricCode.operatingCashFlow))),
            ('Net profit FY$y', Fmt.full(o.a.financials.value(y, MetricCode.netProfit)),
                Fmt.full(o.b.financials.value(y, MetricCode.netProfit))),
            ('Cash conversion FY$y', _fmtCalc(o.a.ratio(y, RatioCode.cashConversion), 'x'),
                _fmtCalc(o.b.ratio(y, RatioCode.cashConversion), 'x')),
          ],
        ]),
      ),
    ]);
  }
}

class _Forecast extends StatelessWidget {
  const _Forecast({required this.o});
  final ComparisonOutcome o;

  ForecastResult? _f(List<ForecastResult> fs, MetricCode m, ForecastMethod method) =>
      fs.where((f) => f.metric == m && f.method == method).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final years = _years(o);
    final allYears = [...years, if (years.isNotEmpty) years.last + 1];
    final t = Theme.of(context);
    String v(ForecastResult? f) => f == null ? '—' : (f.result.isOk ? Fmt.full(f.result.value) : 'n/a – ${f.result.reason}');
    return PageBody(children: [
      Card(
        color: t.colorScheme.secondaryContainer,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Projected values are estimates derived from three historical years. They are not guaranteed '
              'outcomes. Dashed lines show the weighted-growth projection.'),
        ),
      ),
      const SizedBox(height: 12),
      for (final m in [MetricCode.totalRevenue, MetricCode.netProfit])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SectionCard(
            title: '${m.label}: historical vs projected',
            trailing: _CompanyHeader(o: o),
            child: ForecastLineChart(
              years: allYears,
              historyA: _series(o.a, years, m),
              historyB: _series(o.b, years, m),
              forecastA: _f(o.forecastsA, m, ForecastMethod.weightedGrowth)?.result.value,
              forecastB: _f(o.forecastsB, m, ForecastMethod.weightedGrowth)?.result.value,
            ),
          ),
        ),
      SectionCard(
        title: 'Forecast results (FY${allYears.isEmpty ? '' : allYears.last})',
        child: _CompareTable(o: o, rows: [
          for (final m in [MetricCode.totalRevenue, MetricCode.netProfit])
            for (final method in ForecastMethod.values)
              if (_f(o.forecastsA, m, method) != null || _f(o.forecastsB, m, method) != null)
                ('${m.label} – ${method.label}', v(_f(o.forecastsA, m, method)), v(_f(o.forecastsB, m, method))),
          for (final m in ForecastingEngine.projectedExpenses)
            ('${m.label} – ${ForecastMethod.marginStability.label}', v(_f(o.forecastsA, m, ForecastMethod.marginStability)),
                v(_f(o.forecastsB, m, ForecastMethod.marginStability))),
        ]),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Methodology and assumptions',
        child: Text(
          '• Linear trend: ordinary least-squares line through the historical values, extended one year.\n'
          '• Weighted moving growth: Y4 = Y3 × (1 + Σ wᵢ·gᵢ) with weights ${o.growthWeights.mostRecentFirst.join(' / ')} '
          '(most recent first), re-normalized to the available growth observations. Not computed when a base year is '
          'zero or negative.\n'
          '• Margin stability: expense = forecast revenue (weighted growth, else linear) × average historical share '
          'of revenue.\n'
          '• Limitations: three observations give a very short trend; one-off items, inflation and structural changes '
          'are not modelled.',
          style: t.textTheme.bodySmall,
        ),
      ),
    ]);
  }
}

class _Scoring extends StatelessWidget {
  const _Scoring({required this.o, required this.industry});
  final ComparisonOutcome o;
  final Industry? industry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final rows = [
      for (final c in o.scoreA.criteria)
        (
          '${c.criterion.label} (${c.weight.toStringAsFixed(0)}%)',
          c.points,
          o.scoreB.criteria.where((x) => x.criterion == c.criterion).firstOrNull?.points,
          c.maxPoints,
        ),
    ];
    if (!o.isScored) {
      return EmptyState(
        icon: Icons.account_balance_outlined,
        title: '${industry?.label ?? 'This industry'} is not scored',
        message: '${industry?.notes ?? ''} Industrial-company criteria (current ratio, D/E, overhead) would be '
            'misleading here, so no score or verdict is produced. Historical analysis and forecasts remain available.',
      );
    }
    return PageBody(children: [
      SectionCard(
        title: 'Criterion scores',
        subtitle: 'Industry: ${industry?.label ?? 'Other'} · weights applied: '
            '${o.weights.toJson().entries.map((e) => '${e.key.replaceAll('_', ' ')} ${e.value.toStringAsFixed(0)}%').join(', ')}',
        trailing: _CompanyHeader(o: o),
        child: ScoreBars(rows: [
          ...rows,
          ('Total', o.scoreA.total, o.scoreB.total, 100),
        ]),
      ),
      const SizedBox(height: 12),
      for (final s in [o.scoreA, o.scoreB])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SectionCard(
            title: '${s.companyName} – why this score',
            subtitle: s.isComplete ? 'Complete' : 'Incomplete: ${s.missing.map((c) => c.label).join(', ')}',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final c in s.criteria)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${c.criterion.label}: ${c.explanation}', style: t.textTheme.bodySmall),
                ),
            ]),
          ),
        ),
    ]);
  }
}

class _VerdictTab extends StatelessWidget {
  const _VerdictTab({required this.s});
  final ComparisonState s;

  @override
  Widget build(BuildContext context) {
    final o = s.outcome;
    final t = Theme.of(context);
    return PageBody(maxWidth: 820, children: [
      SectionCard(
        title: o.verdict.type.label(s.analysis.companyA.name, s.analysis.companyB.name),
        subtitle: 'Decision rules: gap > ${VerdictEngine.recommendGap.toStringAsFixed(0)} pts → higher scorer; '
            'gap ≤ ${VerdictEngine.tieGap.toStringAsFixed(0)} pts → tie; otherwise review required.',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final r in o.verdict.reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  '),
                Expanded(
                  child: Text(r,
                      style: r == disclaimer
                          ? t.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)
                          : t.textTheme.bodyMedium),
                ),
              ]),
            ),
        ]),
      ),
    ]);
  }
}
