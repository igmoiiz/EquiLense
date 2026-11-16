import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common.dart';
import '../../analysis/data/analysis_repository.dart';
import '../../analysis/presentation/analysis_widgets.dart';
import '../../authentication/data/auth_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final analyses = ref.watch(analysesProvider);
    final name = ref.watch(profileProvider).value?.fullName;
    final t = Theme.of(context);

    Future<void> refresh() async {
      ref
        ..invalidate(dashboardStatsProvider)
        ..invalidate(analysesProvider);
      await ref.read(analysesProvider.future);
    }

    return Scaffold(
      appBar: AppBar(title: Text(name == null ? 'Dashboard' : 'Welcome, ${name.split(' ').first}')),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: PageBody(children: [
          AsyncView(
            value: stats,
            onRetry: () => ref.invalidate(dashboardStatsProvider),
            data: (s) => ResponsiveGrid(minItemWidth: 200, children: [
              StatTile(label: 'Total analyses', value: '${s.analyses}'),
              StatTile(label: 'Completed', value: '${s.completed}'),
              StatTile(label: 'Saved companies', value: '${s.companies}'),
            ]),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.compare_arrows, color: t.colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Compare two PSX-listed companies using three years of financial statements.'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => context.go('/analyses/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New analysis'),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Recent comparisons',
            trailing: TextButton(onPressed: () => context.go('/analyses'), child: const Text('View all')),
            child: AsyncView(
              value: analyses,
              onRetry: () => ref.invalidate(analysesProvider),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No analyses yet. Start one to see results here.'),
                    )
                  : Column(children: [
                      for (final (i, a) in list.take(5).indexed) ...[
                        if (i > 0) const Divider(),
                        AnalysisTile(analysis: a),
                      ],
                    ]),
            ),
          ),
        ]),
      ),
    );
  }
}
