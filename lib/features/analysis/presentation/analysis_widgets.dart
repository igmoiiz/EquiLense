import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../shared/models/models.dart';
import '../../scoring/domain/verdict.dart';

/// Verdict for completed analyses; otherwise the workflow status (a stored
/// result from superseded data is not shown as current).
String verdictLabel(Analysis a) {
  final r = a.result;
  if (r == null || a.status != AnalysisStatus.completed) return a.status.label;
  return VerdictType.fromDb(r.verdict).label(a.companyA.name, a.companyB.name);
}

Color statusColor(BuildContext context, Analysis a) {
  final s = Theme.of(context).colorScheme;
  return switch (a.status) {
    AnalysisStatus.completed => s.positive,
    AnalysisStatus.dataValidated => s.primary,
    AnalysisStatus.archived => s.outline,
    AnalysisStatus.draft => s.tertiary,
  };
}

class AnalysisTile extends StatelessWidget {
  const AnalysisTile({super.key, required this.analysis});

  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    final t = Theme.of(context);
    final r = a.status == AnalysisStatus.completed ? a.result : null;
    return ListTile(
      onTap: () => context.go('/analyses/${a.id}'),
      title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${a.companyA.display}  vs  ${a.companyB.display}\n'
          'FY ${a.years.first}–${a.years.last} · ${Fmt.date(a.updatedAt)}'),
      isThreeLine: true,
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        StatusChip(r == null ? a.status.label : verdictLabel(a), color: statusColor(context, a)),
        if (r?.scoreA != null && r?.scoreB != null) ...[
          const SizedBox(height: 4),
          Text('${r!.scoreA!.toStringAsFixed(1)} vs ${r.scoreB!.toStringAsFixed(1)}', style: t.textTheme.labelSmall),
        ],
      ]),
    );
  }
}
