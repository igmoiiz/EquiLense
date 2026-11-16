import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_providers.dart';
import '../../../shared/models/metric_code.dart';
import '../../../shared/models/models.dart';
import '../../extraction/domain/statement_parser.dart';
import '../../extraction/domain/taxonomy.dart';
import '../../financial_analysis/domain/company_financials.dart';

/// All persisted financial inputs for one analysis.
class AnalysisData {
  const AnalysisData({required this.periods, required this.metrics});

  final List<FinancialPeriod> periods;
  final List<MetricRecord> metrics;

  FinancialPeriod? period(String companyId, int year) =>
      periods.where((p) => p.companyId == companyId && p.year == year).firstOrNull;

  MetricRecord? metric(String periodId, MetricCode code) =>
      metrics.where((m) => m.periodId == periodId && m.metricCode == code.code).firstOrNull;

  bool get allValidated => periods.isNotEmpty && periods.every((p) => p.isValidated);

  int get pendingCount => metrics.where((m) => m.status == ValidationStatus.pending).length;

  /// Builds engine input from validated (non-rejected) values only.
  CompanyFinancials financialsFor(Company company, {required bool validatedOnly}) {
    final values = <int, Map<MetricCode, double>>{};
    String currency = 'PKR';
    for (final p in periods.where((p) => p.companyId == company.id)) {
      currency = p.currency;
      final row = <MetricCode, double>{};
      for (final m in metrics.where((m) => m.periodId == p.id)) {
        final code = MetricCode.fromCode(m.metricCode);
        if (code == null || m.value == null || m.status == ValidationStatus.rejected) continue;
        if (validatedOnly && m.status != ValidationStatus.validated) continue;
        row[code] = m.value!;
      }
      if (row.isNotEmpty) values[p.year] = row;
    }
    return CompanyFinancials(companyId: company.id, companyName: company.name, currency: currency, values: values);
  }
}

class FinancialDataRepository {
  FinancialDataRepository(this._db);
  final SupabaseClient _db;

  Future<AnalysisData> load(String analysisId) => guard(() async {
        final results = await Future.wait([
          _db.from('financial_periods').select().eq('analysis_id', analysisId).order('financial_year'),
          _db.from('financial_metrics').select().eq('analysis_id', analysisId),
        ]);
        return AnalysisData(
          periods: results[0].map(FinancialPeriod.fromJson).toList(),
          metrics: results[1].map(MetricRecord.fromJson).toList(),
        );
      });

  /// Inserts or updates a value. Editing a value resets its period's validation.
  Future<void> upsertMetric({
    required String analysisId,
    required FinancialPeriod period,
    required MetricCode code,
    required double? value,
    String? originalLabel,
    String? originalValue,
    String? sourceDocumentId,
    double? confidence,
    String entrySource = 'manual',
    ValidationStatus status = ValidationStatus.pending,
  }) =>
      guard(() async {
        await _db.from('financial_metrics').upsert({
          'analysis_id': analysisId,
          'company_id': period.companyId,
          'financial_period_id': period.id,
          'metric_code': code.code,
          'standardized_value': value,
          'original_label': originalLabel,
          'original_value': originalValue,
          'source_document_id': sourceDocumentId,
          'extraction_confidence': confidence,
          'entry_source': entrySource,
          'validation_status': status.db,
        }, onConflict: 'financial_period_id,metric_code');
        await _invalidatePeriod(period.id, analysisId);
      });

  Future<void> setMetricStatus(MetricRecord m, ValidationStatus status) => guard(() async {
        await _db.from('financial_metrics').update({'validation_status': status.db}).eq('id', m.id);
        await _invalidatePeriod(m.periodId, m.analysisId);
      });

  Future<void> deleteMetric(MetricRecord m) => guard(() async {
        await _db.from('financial_metrics').delete().eq('id', m.id);
        await _invalidatePeriod(m.periodId, m.analysisId);
      });

  /// Moves a value to another standardized field and remembers the mapping.
  Future<void> remapMetric(MetricRecord m, MetricCode target) => guard(() async {
        await _db
            .from('financial_metrics')
            .update({'metric_code': target.code, 'validation_status': 'pending'}).eq('id', m.id);
        if (m.originalLabel != null && m.originalLabel!.trim().isNotEmpty) {
          await _db.from('metric_mappings').upsert(
            {'original_label': m.originalLabel!.trim(), 'standardized_metric_code': target.code, 'user_id': requireUserId(_db)},
            onConflict: 'user_id,normalized_label',
          );
        }
        await _invalidatePeriod(m.periodId, m.analysisId);
      });

  /// Writes extracted items into a period. Values the user already validated
  /// are never overwritten. Returns the number of values written.
  Future<int> applyExtraction({
    required String analysisId,
    required FinancialPeriod period,
    required String documentId,
    required String sourceType,
    required List<ExtractedItem> items,
    required AnalysisData current,
  }) =>
      guard(() async {
        final rows = <Map<String, Object?>>[];
        for (final item in items) {
          final existing = current.metric(period.id, item.metric);
          if (existing != null && existing.status == ValidationStatus.validated) continue;
          rows.add({
            'analysis_id': analysisId,
            'company_id': period.companyId,
            'financial_period_id': period.id,
            'metric_code': item.metric.code,
            'standardized_value': item.value,
            'original_label': item.originalLabel,
            'original_value': item.originalValue,
            'source_document_id': documentId,
            'extraction_confidence': item.confidence,
            'entry_source': sourceType == 'pdf' ? 'pdf' : 'excel',
            'validation_status': 'pending',
          });
        }
        if (rows.isNotEmpty) {
          await _db.from('financial_metrics').upsert(rows, onConflict: 'financial_period_id,metric_code');
          await _invalidatePeriod(period.id, analysisId);
        }
        return rows.length;
      });

  /// Marks every non-rejected value of the analysis as validated, flags all
  /// periods validated, and sets the analysis status.
  Future<void> confirmDataset(String analysisId) => guard(() async {
        await _db
            .from('financial_metrics')
            .update({'validation_status': 'validated'})
            .eq('analysis_id', analysisId)
            .eq('validation_status', 'pending');
        await _db
            .from('financial_periods')
            .update({'is_validated': true, 'validated_at': DateTime.now().toUtc().toIso8601String()}).eq(
                'analysis_id', analysisId);
        await _db.from('analyses').update({'status': 'data_validated'}).eq('id', analysisId);
      });

  Future<void> setCurrency(String analysisId, String companyId, String currency) => guard(() async {
        await _db
            .from('financial_periods')
            .update({'currency': currency, 'is_validated': false})
            .eq('analysis_id', analysisId)
            .eq('company_id', companyId);
      });

  Future<Map<String, MetricCode>> userMappings() => guard(() async {
        final rows = await _db.from('metric_mappings').select('normalized_label, standardized_metric_code');
        return {
          for (final r in rows)
            if (MetricCode.fromCode(r['standardized_metric_code'] as String) != null)
              normalizeLabel(r['normalized_label'] as String): MetricCode.fromCode(r['standardized_metric_code'] as String)!,
        };
      });

  /// Any change un-validates the period and demotes the analysis to draft so
  /// that lists never show a verdict computed from superseded data.
  Future<void> _invalidatePeriod(String periodId, String analysisId) async {
    await _db.from('financial_periods').update({'is_validated': false, 'validated_at': null}).eq('id', periodId);
    await _db
        .from('analyses')
        .update({'status': 'draft'})
        .eq('id', analysisId)
        .inFilter('status', ['data_validated', 'completed']);
  }
}

final financialDataRepositoryProvider = Provider((ref) => FinancialDataRepository(ref.watch(supabaseProvider)));

final analysisDataProvider = FutureProvider.family<AnalysisData, String>(
    (ref, analysisId) => ref.watch(financialDataRepositoryProvider).load(analysisId));
