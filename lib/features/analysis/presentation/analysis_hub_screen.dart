import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../shared/models/models.dart';
import '../../documents/data/document_repository.dart';
import '../../scoring/domain/scoring_engine.dart';
import '../../scoring/presentation/weights_editor.dart';
import '../../validation/data/financial_data_repository.dart';
import '../data/analysis_repository.dart';
import 'analysis_widgets.dart';

/// Analysis details: workflow steps, settings and saved result.
class AnalysisHubScreen extends ConsumerWidget {
  const AnalysisHubScreen({super.key, required this.analysisId});

  final String analysisId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(analysisProvider(analysisId));
    return Scaffold(
      appBar: AppBar(
        title: Text(analysis.value?.name ?? 'Analysis'),
        actions: [
          if (analysis.value != null)
            PopupMenuButton<String>(
              tooltip: 'Analysis actions',
              onSelected: (v) => v == 'weights'
                  ? _editWeights(context, ref, analysis.value!)
                  : _delete(context, ref, analysis.value!),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'weights', child: Text('Edit scoring weights')),
                PopupMenuItem(value: 'delete', child: Text('Delete analysis')),
              ],
            ),
        ],
      ),
      body: AsyncView(
        value: analysis,
        onRetry: () => ref.invalidate(analysisProvider(analysisId)),
        data: (a) => _HubBody(analysis: a),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Analysis a) async {
    final ok = await confirmDialog(context,
        title: 'Delete "${a.name}"?',
        message: 'All uploaded documents, extracted figures and results for this analysis will be permanently '
            'deleted. This cannot be undone.',
        confirm: 'Delete permanently',
        destructive: true);
    if (!ok) return;
    try {
      await ref.read(analysisRepositoryProvider).delete(a.id);
      ref
        ..invalidate(analysesProvider)
        ..invalidate(dashboardStatsProvider);
      if (context.mounted) context.go('/analyses');
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e), error: true);
    }
  }

  Future<void> _editWeights(BuildContext context, WidgetRef ref, Analysis a) async {
    final initial = a.scoringWeights == null
        ? (await ref.read(industryWeightsProvider(a.industry).future) ?? ScoringWeights.standard())
        : ScoringWeights.fromJson(a.scoringWeights!);
    if (!context.mounted) return;
    ScoringWeights? edited = initial;
    final save = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Scoring weights'),
        content: SizedBox(width: 380, child: WeightsEditor(initial: initial, onChanged: (w) => edited = w)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      ),
    );
    if (save != true || !context.mounted) return;
    if (edited == null) {
      showSnack(context, 'Weights must total 100%. Nothing saved.', error: true);
      return;
    }
    try {
      await ref.read(analysisRepositoryProvider).updateWeights(a.id, edited!);
      ref.invalidate(analysisProvider(a.id));
      if (context.mounted) showSnack(context, 'Weights saved. Recalculate results to apply them.');
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e), error: true);
    }
  }
}

class _HubBody extends ConsumerWidget {
  const _HubBody({required this.analysis});
  final Analysis analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = analysis;
    final docs = ref.watch(documentsProvider(a.id)).value;
    final data = ref.watch(analysisDataProvider(a.id)).value;
    final scheme = Theme.of(context).colorScheme;
    final docCount = docs?.length ?? 0;
    final coveredSlots = {for (final d in docs ?? const <FinancialDocument>[]) '${d.companyId}-${d.year}'}.length;
    final valueCount = data?.metrics.length ?? 0;
    final validated = data?.allValidated ?? false;

    return PageBody(maxWidth: 900, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${a.companyA.display}  vs  ${a.companyB.display}',
                  style: Theme.of(context).textTheme.titleMedium)),
              StatusChip(a.status.label, color: statusColor(context, a)),
            ]),
            const SizedBox(height: 8),
            Text('Financial years ${a.years.join(', ')} · ${a.currency} · Industry: ${a.industry} · '
                'Created ${Fmt.date(a.createdAt)}'),
            if (a.result != null && a.status == AnalysisStatus.completed) ...[
              const SizedBox(height: 8),
              Text('Result: ${verdictLabel(a)}', style: TextStyle(color: scheme.primary)),
            ] else if (a.result != null) ...[
              const SizedBox(height: 8),
              Text('Data changed since the last result. Re-confirm the dataset to recalculate.',
                  style: TextStyle(color: scheme.tertiary)),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 16),
      _Step(
        number: 1,
        title: 'Upload financial statements',
        detail: '$docCount document(s), $coveredSlots of 6 company-years covered.',
        done: coveredSlots >= 6,
        action: 'Manage documents',
        onTap: () => context.go('/analyses/${a.id}/documents'),
      ),
      _Step(
        number: 2,
        title: 'Review and validate figures',
        detail: validated
            ? 'Dataset confirmed ($valueCount values).'
            : '$valueCount value(s) captured. Extracted or manual values must be confirmed before analysis.',
        done: validated,
        action: 'Review data',
        onTap: () => context.go('/analyses/${a.id}/validate'),
      ),
      _Step(
        number: 3,
        title: 'Analysis, forecast and verdict',
        detail: a.status == AnalysisStatus.completed
            ? 'Results saved. Open to view the dashboard or export the report.'
            : 'Available once the dataset is validated.',
        done: a.status == AnalysisStatus.completed,
        action: 'View results',
        onTap: validated || a.result != null ? () => context.go('/analyses/${a.id}/results') : null,
      ),
      const SizedBox(height: 8),
      Text(
        'Tip: you can enter all figures manually on the review screen if documents are scanned or unavailable.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    ]);
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.detail,
    required this.done,
    required this.action,
    required this.onTap,
  });

  final int number;
  final String title;
  final String detail;
  final bool done;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: done ? scheme.positive : scheme.surfaceContainerHighest,
            foregroundColor: done ? Colors.white : scheme.onSurface,
            child: done ? const Icon(Icons.check, size: 18) : Text('$number'),
          ),
          title: Text(title),
          subtitle: Text(detail),
          trailing: FilledButton.tonal(onPressed: onTap, child: Text(action)),
        ),
      ),
    );
  }
}
