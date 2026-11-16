import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../analysis/data/analysis_repository.dart';
import '../../scoring/domain/scoring_engine.dart';
import '../../validation/data/financial_data_repository.dart';
import '../domain/comparison_engine.dart';

class ComparisonState {
  const ComparisonState({required this.analysis, required this.outcome, required this.validated, required this.industry});

  final Analysis analysis;
  final ComparisonOutcome outcome;
  final bool validated;
  final Industry? industry;
}

/// Recomputes the full comparison from validated database values. All engine
/// work is deterministic, so the dashboard and exports always agree.
final comparisonProvider = FutureProvider.family<ComparisonState, String>((ref, id) async {
  final analysis = await ref.watch(analysisProvider(id).future);
  final data = await ref.watch(analysisDataProvider(id).future);
  final industries = await ref.watch(industriesProvider.future);
  final industry = industries.where((i) => i.code == analysis.industry).firstOrNull;

  final weights = analysis.scoringWeights != null
      ? ScoringWeights.fromJson(analysis.scoringWeights!)
      : (await ref.watch(industryWeightsProvider(analysis.industry).future)) ?? ScoringWeights.standard();

  final outcome = ComparisonEngine.run(
    companyA: data.financialsFor(analysis.companyA, validatedOnly: true),
    companyB: data.financialsFor(analysis.companyB, validatedOnly: true),
    weights: weights,
    industrySupported: industry?.supported ?? true,
  );
  return ComparisonState(analysis: analysis, outcome: outcome, validated: data.allValidated, industry: industry);
});
