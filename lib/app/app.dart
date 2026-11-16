import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class EquiLenseApp extends ConsumerWidget {
  const EquiLenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(preferencesProvider.select((p) => p.themeMode));
    return MaterialApp.router(
      title: 'EquiLense – PSX Financial Intelligence',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
