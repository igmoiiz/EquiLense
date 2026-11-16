import 'package:flutter/material.dart';

/// Restrained financial palette: one ink-blue brand colour, two comparison
/// colours (A/B) that stay distinguishable in light and dark mode, and
/// semantic positive/negative colours used only for signed values.
abstract final class AppTheme {
  static const _seed = Color(0xFF1F3A5F);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: b);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: b);
    return base.copyWith(
      scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF6F7F9) : scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.6), space: 1),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        dataRowMinHeight: 40,
        headingRowHeight: 40,
      ),
    );
  }
}

/// Comparison colours, consistent across all charts and tables.
extension CompanyColors on ColorScheme {
  Color get companyA => brightness == Brightness.light ? const Color(0xFF2563A6) : const Color(0xFF7FB2F0);
  Color get companyB => brightness == Brightness.light ? const Color(0xFFC0711B) : const Color(0xFFF2B266);
  Color get positive => brightness == Brightness.light ? const Color(0xFF1E7B4F) : const Color(0xFF6FCF97);
  Color get negative => brightness == Brightness.light ? const Color(0xFFB3261E) : const Color(0xFFF2B8B5);
}
