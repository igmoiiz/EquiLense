import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/common.dart';
import '../../../shared/models/models.dart';
import '../../companies/data/company_repository.dart';
import '../../companies/presentation/companies_screen.dart';
import '../../scoring/domain/scoring_engine.dart';
import '../../scoring/presentation/weights_editor.dart';
import '../data/analysis_repository.dart';

class NewAnalysisScreen extends ConsumerStatefulWidget {
  const NewAnalysisScreen({super.key});

  @override
  ConsumerState<NewAnalysisScreen> createState() => _NewAnalysisScreenState();
}

class _NewAnalysisScreenState extends ConsumerState<NewAnalysisScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _currency = TextEditingController(text: 'PKR');
  String? _companyA;
  String? _companyB;
  String _industry = 'other';
  int _firstYear = DateTime.now().year - 3;
  ScoringWeights? _weights;
  ScoringWeights? _defaults;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadWeights('other');
  }

  @override
  void dispose() {
    _name.dispose();
    _currency.dispose();
    super.dispose();
  }

  Future<void> _loadWeights(String industry) async {
    final w = await ref.read(industryWeightsProvider(industry).future).catchError((_) => null);
    if (!mounted) return;
    setState(() {
      _defaults = w ?? ScoringWeights.standard();
      _weights = _defaults;
    });
  }

  Future<void> _pickNewCompany(bool forA) async {
    final c = await showCompanyEditor(context);
    if (c == null) return;
    // Wait until the refreshed list contains the new company before selecting it.
    await ref.read(companiesProvider.future);
    if (mounted) setState(() => forA ? _companyA = c.id : _companyB = c.id);
  }

  Future<void> _submit(List<Company> companies) async {
    if (!_form.currentState!.validate()) return;
    if (_weights == null) {
      showSnack(context, 'Scoring weights must total 100%.', error: true);
      return;
    }
    setState(() => _busy = true); // also prevents duplicate submissions
    try {
      final a = await ref.read(analysisRepositoryProvider).create(
            name: _name.text,
            companyAId: _companyA!,
            companyBId: _companyB!,
            industry: _industry,
            firstYear: _firstYear,
            currency: _currency.text.trim().toUpperCase(),
            weights: _weights!,
          );
      ref
        ..invalidate(analysesProvider)
        ..invalidate(dashboardStatsProvider);
      if (mounted) context.go('/analyses/${a.id}/documents');
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companiesProvider);
    final industries = ref.watch(industriesProvider).value ?? const <Industry>[];
    final industry = industries.where((i) => i.code == _industry).firstOrNull;
    final years = [for (var y = DateTime.now().year - 3; y >= 2000; y--) y];

    return Scaffold(
      appBar: AppBar(title: const Text('New analysis')),
      body: AsyncView(
        value: companies,
        onRetry: () => ref.invalidate(companiesProvider),
        data: (list) => Form(
          key: _form,
          child: PageBody(maxWidth: 720, children: [
            SectionCard(
              title: 'Comparison',
              child: Column(children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Analysis name *', hintText: 'e.g. Cement leaders FY21–23'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                for (final forA in [true, false]) ...[
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        // initialValue is read once; re-key so programmatic selection shows.
                        key: ValueKey('${forA ? 'a' : 'b'}-${forA ? _companyA : _companyB}-${list.length}'),
                        isExpanded: true,
                        initialValue: list.any((c) => c.id == (forA ? _companyA : _companyB))
                            ? (forA ? _companyA : _companyB)
                            : null,
                        decoration: InputDecoration(labelText: forA ? 'Company A *' : 'Company B *'),
                        items: [for (final c in list) DropdownMenuItem(value: c.id, child: Text(c.display))],
                        onChanged: (v) => setState(() => forA ? _companyA = v : _companyB = v),
                        validator: (v) {
                          if (v == null) return 'Select a company';
                          if (_companyA != null && _companyA == _companyB) return 'Choose two different companies';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Add a new company',
                      onPressed: () => _pickNewCompany(forA),
                      icon: const Icon(Icons.add),
                    ),
                  ]),
                  const SizedBox(height: 12),
                ],
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _firstYear,
                      decoration: const InputDecoration(labelText: 'First financial year'),
                      items: [for (final y in years) DropdownMenuItem(value: y, child: Text('FY$y – FY${y + 2}'))],
                      onChanged: (v) => setState(() => _firstYear = v ?? _firstYear),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: _currency,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) =>
                          RegExp(r'^[A-Za-z]{3}$').hasMatch(v?.trim() ?? '') ? null : '3-letter code',
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Industry and scoring weights',
              subtitle: 'Defaults come from the selected industry. Adjust if needed; the total must be 100%.',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                DropdownButtonFormField<String>(
                  initialValue: _industry,
                  decoration: const InputDecoration(labelText: 'Industry'),
                  items: [for (final i in industries) DropdownMenuItem(value: i.code, child: Text(i.label))],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _industry = v);
                    _loadWeights(v);
                  },
                ),
                if (industry != null && !industry.supported) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('${industry.label}: ${industry.notes ?? ''} Historical analysis and forecasts will '
                          'run, but no score or verdict is produced.'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_defaults != null) WeightsEditor(initial: _defaults!, onChanged: (w) => _weights = w),
              ]),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy || list.length < 2 ? null : () => _submit(list),
              child: _busy
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create and upload documents'),
            ),
            if (list.length < 2)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Add at least two companies (use the + buttons above).', textAlign: TextAlign.center),
              ),
          ]),
        ),
      ),
    );
  }
}
