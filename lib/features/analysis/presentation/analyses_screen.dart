import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common.dart';
import '../data/analysis_repository.dart';
import 'analysis_widgets.dart';

/// Saved analyses.
class AnalysesScreen extends ConsumerWidget {
  const AnalysesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyses = ref.watch(analysesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved analyses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/analyses/new'),
        icon: const Icon(Icons.add),
        label: const Text('New analysis'),
      ),
      body: AsyncView(
        value: analyses,
        onRetry: () => ref.invalidate(analysesProvider),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.compare_arrows,
                title: 'No analyses yet',
                message: 'Create an analysis, choose two companies and upload their financial statements.',
                action: FilledButton(onPressed: () => context.go('/analyses/new'), child: const Text('New analysis')),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(analysesProvider.future),
                child: PageBody(maxWidth: 900, children: [
                  Card(
                    child: Column(children: [
                      for (final (i, a) in list.indexed) ...[
                        if (i > 0) const Divider(),
                        AnalysisTile(analysis: a),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 72),
                ]),
              ),
      ),
    );
  }
}
