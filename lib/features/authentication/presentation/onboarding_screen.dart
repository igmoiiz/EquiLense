import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/preferences.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  static const _steps = [
    (Icons.upload_file_outlined, 'Upload statements',
        'Add three years of annual reports (PDF or XLSX) for two PSX-listed companies.'),
    (Icons.fact_check_outlined, 'Review extracted figures',
        'Line items are mapped to a standard taxonomy. You confirm or correct every value before analysis.'),
    (Icons.query_stats_outlined, 'Analyse and compare',
        'Growth, margins, ratios, a fourth-year forecast and a transparent 100-point score, side by side.'),
    (Icons.picture_as_pdf_outlined, 'Export the report',
        'Download the full comparison as a PDF or Excel workbook.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    Future<void> next(String route) async {
      await ref.read(preferencesProvider.notifier).completeOnboarding();
      if (context.mounted) context.go(route);
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.analytics_outlined, size: 40, color: t.colorScheme.primary),
                const SizedBox(height: 16),
                Text('PSX Financial Intelligence',
                    style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Compare the financial performance of two listed companies from their own statements.',
                    style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 28),
                for (final (icon, title, body) in _steps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(icon, color: t.colorScheme.primary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(body, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                        ]),
                      ),
                    ]),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Results compare reported fundamentals. They are not investment advice or a stock valuation.',
                  style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => next('/register'), child: const Text('Create an account')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () => next('/login'), child: const Text('I already have an account')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
