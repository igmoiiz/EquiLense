import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../shared/models/metric_code.dart';
import '../../../shared/models/models.dart';
import '../../analysis/data/analysis_repository.dart';
import '../../financial_analysis/domain/integrity_checker.dart';
import '../data/financial_data_repository.dart';

class ValidationScreen extends ConsumerWidget {
  const ValidationScreen({super.key, required this.analysisId});

  final String analysisId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(analysisProvider(analysisId));
    final data = ref.watch(analysisDataProvider(analysisId));
    return AsyncView(
      value: analysis,
      onRetry: () => ref.invalidate(analysisProvider(analysisId)),
      data: (a) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Review financial data'),
            bottom: TabBar(tabs: [for (final c in a.companies) Tab(text: c.name)]),
          ),
          body: AsyncView(
            value: data,
            onRetry: () => ref.invalidate(analysisDataProvider(analysisId)),
            data: (d) => Column(children: [
              _IssuesBanner(analysis: a, data: d),
              Expanded(
                child: TabBarView(children: [for (final c in a.companies) _CompanyTable(analysis: a, company: c, data: d)]),
              ),
              _ConfirmBar(analysis: a, data: d),
            ]),
          ),
        ),
      ),
    );
  }
}

class _IssuesBanner extends StatelessWidget {
  const _IssuesBanner({required this.analysis, required this.data});
  final Analysis analysis;
  final AnalysisData data;

  @override
  Widget build(BuildContext context) {
    final issues = IntegrityChecker.check(
      data.financialsFor(analysis.companyA, validatedOnly: false),
      data.financialsFor(analysis.companyB, validatedOnly: false),
    );
    if (issues.isEmpty) return const SizedBox.shrink();
    final errors = issues.where((i) => i.severity == IssueSeverity.error).length;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: errors > 0 ? scheme.errorContainer : scheme.secondaryContainer,
      child: ExpansionTile(
        dense: true,
        leading: Icon(errors > 0 ? Icons.error_outline : Icons.info_outline),
        title: Text('$errors error(s), ${issues.length - errors} warning(s) in the current data'),
        children: [
          SizedBox(
            height: 160,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), children: [
              for (final i in issues)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${i.severity == IssueSeverity.error ? '✕' : '•'} '
                      '${i.companyName ?? ''}${i.year != null ? ' FY${i.year}' : ''}: ${i.message}'),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CompanyTable extends ConsumerWidget {
  const _CompanyTable({required this.analysis, required this.company, required this.data});
  final Analysis analysis;
  final Company company;
  final AnalysisData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final periods = [for (final y in analysis.years) data.period(company.id, y)];
    final currency = periods.whereType<FinancialPeriod>().firstOrNull?.currency ?? analysis.currency;
    return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 24), children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Text('Tap a cell to add, edit, re-map, confirm or reject a value. Amounts in $currency (absolute).',
                    style: t.textTheme.bodySmall),
              ),
              TextButton.icon(
                onPressed: () => _editCurrency(context, ref, currency),
                icon: const Icon(Icons.currency_exchange, size: 18),
                label: Text(currency),
              ),
            ]),
            const SizedBox(height: 8),
            for (final statement in FinancialStatement.values) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: Text(switch (statement) {
                  FinancialStatement.incomeStatement => 'Income statement',
                  FinancialStatement.balanceSheet => 'Balance sheet',
                  FinancialStatement.cashFlow => 'Cash flow statement',
                }, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Card(
                child: Column(children: [
                  _HeaderRow(years: analysis.years),
                  for (final m in MetricCode.values.where((m) => m.statement == statement))
                    _MetricRow(analysis: analysis, metric: m, periods: periods, data: data),
                ]),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }

  Future<void> _editCurrency(BuildContext context, WidgetRef ref, String current) async {
    final ctrl = TextEditingController(text: current);
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Reporting currency – ${company.name}'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'ISO code', hintText: 'PKR'),
          textCapitalization: TextCapitalization.characters,
          maxLength: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim().toUpperCase()), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (v == null || !RegExp(r'^[A-Z]{3}$').hasMatch(v)) return;
    try {
      await ref.read(financialDataRepositoryProvider).setCurrency(analysis.id, company.id, v);
      ref.invalidate(analysisDataProvider(analysis.id));
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e), error: true);
    }
  }
}

const _labelWidth = 0.34;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.years});
  final List<int> years;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);
    return LayoutBuilder(
      builder: (_, c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          SizedBox(width: c.maxWidth * _labelWidth, child: Text('Field', style: style)),
          for (final y in years) Expanded(child: Text('FY$y', style: style, textAlign: TextAlign.right)),
        ]),
      ),
    );
  }
}

class _MetricRow extends ConsumerWidget {
  const _MetricRow({required this.analysis, required this.metric, required this.periods, required this.data});

  final Analysis analysis;
  final MetricCode metric;
  final List<FinancialPeriod?> periods;
  final AnalysisData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final required = MetricCode.required.contains(metric);
    return Column(children: [
      const Divider(),
      LayoutBuilder(
        builder: (_, c) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            SizedBox(
              width: c.maxWidth * _labelWidth,
              child: Text('${metric.label}${required ? ' *' : ''}', style: t.textTheme.bodySmall),
            ),
            for (final p in periods)
              Expanded(
                child: p == null
                    ? const SizedBox.shrink()
                    : _ValueCell(analysis: analysis, metric: metric, period: p, record: data.metric(p.id, metric)),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _ValueCell extends ConsumerWidget {
  const _ValueCell({required this.analysis, required this.metric, required this.period, required this.record});

  final Analysis analysis;
  final MetricCode metric;
  final FinancialPeriod period;
  final MetricRecord? record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final r = record;
    final (icon, color) = switch (r?.status) {
      null => (Icons.add, scheme.outline),
      ValidationStatus.validated => (Icons.check_circle, scheme.positive),
      ValidationStatus.rejected => (Icons.block, scheme.negative),
      ValidationStatus.pending => (Icons.radio_button_unchecked, scheme.tertiary),
    };
    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (_) => _EditValueDialog(analysis: analysis, metric: metric, period: period, record: r),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Flexible(
            child: Text(
              r?.value == null ? '' : Fmt.full(r!.value),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                decoration: r?.status == ValidationStatus.rejected ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: r == null
                ? 'Add value'
                : '${r.status.db} · ${r.entrySource}${r.confidence != null ? ' · confidence ${(r.confidence! * 100).round()}%' : ''}',
            child: Icon(icon, size: 14, color: color),
          ),
        ]),
      ),
    );
  }
}

class _EditValueDialog extends ConsumerStatefulWidget {
  const _EditValueDialog({required this.analysis, required this.metric, required this.period, required this.record});

  final Analysis analysis;
  final MetricCode metric;
  final FinancialPeriod period;
  final MetricRecord? record;

  @override
  ConsumerState<_EditValueDialog> createState() => _EditValueDialogState();
}

class _EditValueDialogState extends ConsumerState<_EditValueDialog> {
  late final _value = TextEditingController(
    text: widget.record?.value == null ? '' : widget.record!.value!.toStringAsFixed(widget.record!.value! % 1 == 0 ? 0 : 2),
  );
  late MetricCode _mapTo = widget.metric;
  bool _busy = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  FinancialDataRepository get _repo => ref.read(financialDataRepositoryProvider);

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(analysisDataProvider(widget.analysis.id));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  double? get _parsed => double.tryParse(_value.text.replaceAll(',', '').trim());

  Future<void> _save({required bool confirm}) async {
    final v = _parsed;
    if (v == null) {
      showSnack(context, 'Enter a numeric value.', error: true);
      return;
    }
    final r = widget.record;
    final changed = r?.value != v;
    await _run(() => _repo.upsertMetric(
          analysisId: widget.analysis.id,
          period: widget.period,
          code: widget.metric,
          value: v,
          originalLabel: r?.originalLabel,
          originalValue: r?.originalValue,
          sourceDocumentId: r?.sourceDocumentId,
          confidence: r?.confidence,
          entrySource: changed ? 'manual' : (r?.entrySource ?? 'manual'),
          status: confirm ? ValidationStatus.validated : ValidationStatus.pending,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final t = Theme.of(context);
    return AlertDialog(
      title: Text('${widget.metric.label} · FY${widget.period.year}'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (r != null) ...[
            _kv(context, 'Source', r.entrySource == 'manual' ? 'Manual entry' : r.entrySource.toUpperCase()),
            if (r.originalLabel != null) _kv(context, 'Original label', r.originalLabel!),
            if (r.originalValue != null) _kv(context, 'Original value', r.originalValue!),
            if (r.confidence != null) _kv(context, 'Match confidence', '${(r.confidence! * 100).round()}%'),
            _kv(context, 'Status', r.status.db),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _value,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Value (${widget.period.currency}, absolute amount)',
              helperText: widget.metric.isExpense ? 'Expenses are stored as positive amounts.' : 'Use - for negatives.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))],
          ),
          if (r != null) ...[
            const SizedBox(height: 16),
            Text('Correct the mapping', style: t.textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<MetricCode>(
                  isExpanded: true,
                  initialValue: _mapTo,
                  items: [for (final m in MetricCode.values) DropdownMenuItem(value: m, child: Text(m.label))],
                  onChanged: (m) => setState(() => _mapTo = m ?? _mapTo),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy || _mapTo == widget.metric ? null : () => _run(() => _repo.remapMetric(r, _mapTo)),
                child: const Text('Move'),
              ),
            ]),
            if (r.originalLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('The label "${r.originalLabel}" will map to the chosen field in future extractions.',
                    style: t.textTheme.bodySmall),
              ),
          ],
        ]),
      ),
      actions: [
        if (r != null) ...[
          TextButton(
            onPressed: _busy ? null : () => _run(() => _repo.deleteMetric(r)),
            child: const Text('Remove'),
          ),
          TextButton(
            onPressed: _busy || r.status == ValidationStatus.rejected
                ? null
                : () => _run(() => _repo.setMetricStatus(r, ValidationStatus.rejected)),
            child: const Text('Reject'),
          ),
        ],
        OutlinedButton(onPressed: _busy ? null : () => _save(confirm: false), child: const Text('Save')),
        FilledButton(onPressed: _busy ? null : () => _save(confirm: true), child: const Text('Save & confirm')),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(k, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(v, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}

class _ConfirmBar extends ConsumerStatefulWidget {
  const _ConfirmBar({required this.analysis, required this.data});
  final Analysis analysis;
  final AnalysisData data;

  @override
  ConsumerState<_ConfirmBar> createState() => _ConfirmBarState();
}

class _ConfirmBarState extends ConsumerState<_ConfirmBar> {
  bool _busy = false;

  Future<void> _confirm() async {
    final a = widget.analysis, d = widget.data;
    final issues = IntegrityChecker.check(
      d.financialsFor(a.companyA, validatedOnly: false),
      d.financialsFor(a.companyB, validatedOnly: false),
    );
    final errors = issues.where((i) => i.severity == IssueSeverity.error).toList();
    if (errors.isNotEmpty) {
      final proceed = await confirmDialog(
        context,
        title: 'Data has ${errors.length} structural error(s)',
        message: '${errors.take(6).map((e) => '• ${e.companyName ?? ''} ${e.year ?? ''}: ${e.message}').join('\n')}'
            '\n\nResults computed from this data may be misleading. Confirm anyway?',
        confirm: 'Confirm with errors',
        destructive: true,
      );
      if (!proceed) return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(financialDataRepositoryProvider).confirmDataset(a.id);
      ref
        ..invalidate(analysisDataProvider(a.id))
        ..invalidate(analysisProvider(a.id))
        ..invalidate(analysesProvider);
      if (mounted) context.go('/analyses/${a.id}/results');
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final active = d.metrics.where((m) => m.status != ValidationStatus.rejected).length;
    return Material(
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: Text(d.allValidated
                  ? 'Dataset confirmed. Editing any value will require re-confirmation.'
                  : '$active value(s), ${d.pendingCount} awaiting confirmation.'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _busy || active == 0 ? null : (d.allValidated ? () => context.go('/analyses/${widget.analysis.id}/results') : _confirm),
              child: Text(d.allValidated ? 'View results' : 'Confirm dataset'),
            ),
          ]),
        ),
      ),
    );
  }
}
