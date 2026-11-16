import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/env.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_providers.dart';
import '../../../shared/models/models.dart';
import '../../scoring/domain/scoring_engine.dart';

class AnalysisRepository {
  AnalysisRepository(this._db);
  final SupabaseClient _db;

  Future<List<Analysis>> list({int? limit}) => guard(() async {
        var q = _db.from('analyses').select(Analysis.select).order('created_at', ascending: false);
        final rows = limit == null ? await q : await q.limit(limit);
        return rows.map(Analysis.fromJson).toList();
      });

  Future<Analysis> get(String id) => guard(() async {
        final row = await _db.from('analyses').select(Analysis.select).eq('id', id).single();
        return Analysis.fromJson(row);
      });

  /// Creates the analysis and its six financial periods (2 companies × 3 years).
  Future<Analysis> create({
    required String name,
    required String companyAId,
    required String companyBId,
    required String industry,
    required int firstYear,
    required String currency,
    required ScoringWeights weights,
  }) =>
      guard(() async {
        final row = await _db
            .from('analyses')
            .insert({
              'analysis_name': name.trim(),
              'company_a_id': companyAId,
              'company_b_id': companyBId,
              'industry': industry,
              'first_financial_year': firstYear,
              'currency': currency,
              'scoring_weights': weights.toJson(),
            })
            .select('id')
            .single();
        final id = row['id'] as String;
        try {
          await _db.from('financial_periods').insert([
            for (final c in [companyAId, companyBId])
              for (var i = 0; i < Analysis.yearsPerCompany; i++)
                {'analysis_id': id, 'company_id': c, 'financial_year': firstYear + i, 'currency': currency},
          ]);
        } catch (_) {
          await _db.from('analyses').delete().eq('id', id); // roll back partial creation
          rethrow;
        }
        return get(id);
      });

  Future<void> updateWeights(String id, ScoringWeights weights) =>
      guard(() => _db.from('analyses').update({'scoring_weights': weights.toJson()}).eq('id', id));

  Future<void> setStatus(String id, AnalysisStatus status) =>
      guard(() => _db.from('analyses').update({'status': status.db}).eq('id', id));

  /// Deletes stored files first, then the analysis (rows cascade).
  Future<void> delete(String id) => guard(() async {
        final docs = await _db.from('documents').select('storage_path').eq('analysis_id', id);
        final paths = [for (final d in docs) d['storage_path'] as String];
        if (paths.isNotEmpty) await _db.storage.from(Env.documentsBucket).remove(paths);
        await _db.from('analyses').delete().eq('id', id);
      });

  Future<void> saveResults(String id, Map<String, Object?> payload) =>
      guard(() => _db.rpc('save_analysis_results', params: {'p_analysis_id': id, 'p_payload': payload}));

  Future<({int analyses, int companies, int completed})> stats() => guard(() async {
        final results = await Future.wait([
          _db.from('analyses').count(CountOption.exact),
          _db.from('companies').count(CountOption.exact),
          _db.from('analyses').count(CountOption.exact).eq('status', 'completed'),
        ]);
        return (analyses: results[0], companies: results[1], completed: results[2]);
      });
}

class ReferenceRepository {
  ReferenceRepository(this._db);
  final SupabaseClient _db;

  Future<List<Industry>> industries() => guard(() async {
        final rows = await _db.from('industries').select().order('label');
        return rows.map(Industry.fromJson).toList();
      });

  /// Default weights for an industry; null when the industry is unsupported.
  Future<ScoringWeights?> weights(String industry) => guard(() async {
        final rows = await _db.from('industry_weights').select('criterion, weight').eq('industry', industry);
        if (rows.isEmpty) return null;
        return ScoringWeights({
          for (final r in rows)
            if (Criterion.fromCode(r['criterion'] as String) != null)
              Criterion.fromCode(r['criterion'] as String)!: (r['weight'] as num).toDouble(),
        });
      });
}

final analysisRepositoryProvider = Provider((ref) => AnalysisRepository(ref.watch(supabaseProvider)));
final referenceRepositoryProvider = Provider((ref) => ReferenceRepository(ref.watch(supabaseProvider)));

final analysesProvider = FutureProvider<List<Analysis>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(analysisRepositoryProvider).list();
});

final analysisProvider =
    FutureProvider.family<Analysis, String>((ref, id) => ref.watch(analysisRepositoryProvider).get(id));

final dashboardStatsProvider = FutureProvider((ref) {
  ref.watch(authStateProvider);
  return ref.watch(analysisRepositoryProvider).stats();
});

final industriesProvider = FutureProvider<List<Industry>>((ref) => ref.watch(referenceRepositoryProvider).industries());

final industryWeightsProvider = FutureProvider.family<ScoringWeights?, String>(
    (ref, industry) => ref.watch(referenceRepositoryProvider).weights(industry));
