import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/common.dart';
import '../../../shared/models/models.dart';
import '../../analysis/data/analysis_repository.dart';
import '../data/company_repository.dart';

class CompaniesScreen extends ConsumerStatefulWidget {
  const CompaniesScreen({super.key});

  @override
  ConsumerState<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends ConsumerState<CompaniesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companiesProvider);
    final industries = ref.watch(industriesProvider).value ?? const [];
    String industryLabel(String code) => industries.where((i) => i.code == code).firstOrNull?.label ?? code;

    return Scaffold(
      appBar: AppBar(title: const Text('Companies')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCompanyEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add company'),
      ),
      body: AsyncView(
        value: companies,
        onRetry: () => ref.invalidate(companiesProvider),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.business_outlined,
              title: 'No companies yet',
              message: 'Add the PSX-listed companies you want to compare. They can be reused across analyses.',
            );
          }
          final q = _query.toLowerCase();
          final filtered = list
              .where((c) =>
                  q.isEmpty ||
                  c.name.toLowerCase().contains(q) ||
                  (c.ticker?.toLowerCase().contains(q) ?? false) ||
                  (c.sector?.toLowerCase().contains(q) ?? false))
              .toList();
          return PageBody(maxWidth: 900, children: [
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, ticker or sector'),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(children: [
                for (final (i, c) in filtered.indexed) ...[
                  if (i > 0) const Divider(),
                  ListTile(
                    title: Text(c.name),
                    subtitle: Text([
                      if (c.ticker != null) c.ticker!,
                      industryLabel(c.industry),
                      if (c.sector != null) c.sector!,
                      c.exchange,
                    ].join(' · ')),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Company actions',
                      onSelected: (v) async {
                        if (v == 'edit') {
                          await showCompanyEditor(context, existing: c);
                          return;
                        }
                        final ok = await confirmDialog(context,
                            title: 'Delete ${c.name}?',
                            message: 'This removes the company. Companies used in analyses cannot be deleted.',
                            confirm: 'Delete',
                            destructive: true);
                        if (!ok) return;
                        try {
                          await ref.read(companyRepositoryProvider).delete(c.id);
                          ref.invalidate(companiesProvider);
                        } catch (e) {
                          if (context.mounted) showSnack(context, describeError(e), error: true);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () => showCompanyEditor(context, existing: c),
                  ),
                ],
                if (filtered.isEmpty)
                  const Padding(padding: EdgeInsets.all(24), child: Text('No companies match your search.')),
              ]),
            ),
            const SizedBox(height: 72),
          ]);
        },
      ),
    );
  }
}

/// Add/edit dialog. Returns the saved company.
Future<Company?> showCompanyEditor(BuildContext context, {Company? existing}) =>
    showDialog<Company>(context: context, builder: (_) => _CompanyEditor(existing: existing));

class _CompanyEditor extends ConsumerStatefulWidget {
  const _CompanyEditor({this.existing});
  final Company? existing;

  @override
  ConsumerState<_CompanyEditor> createState() => _CompanyEditorState();
}

class _CompanyEditorState extends ConsumerState<_CompanyEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _ticker = TextEditingController(text: widget.existing?.ticker);
  late final _sector = TextEditingController(text: widget.existing?.sector);
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _exchange = TextEditingController(text: widget.existing?.exchange ?? 'PSX');
  late String _industry = widget.existing?.industry ?? 'other';
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _ticker, _sector, _description, _exchange]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final c = Company(
      id: widget.existing?.id ?? '',
      name: _name.text,
      ticker: _ticker.text,
      sector: _sector.text,
      industry: _industry,
      description: _description.text,
      exchange: _exchange.text,
    );
    try {
      final repo = ref.read(companyRepositoryProvider);
      final saved = widget.existing == null ? await repo.create(c) : await repo.update(c);
      ref.invalidate(companiesProvider);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final industries = ref.watch(industriesProvider).value ?? const <Industry>[];
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add company' : 'Edit company'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Company name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ticker,
                decoration: const InputDecoration(labelText: 'PSX ticker', hintText: 'e.g. LUCK'),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => (v == null || v.trim().isEmpty || RegExp(r'^[A-Za-z0-9.]{1,12}$').hasMatch(v.trim()))
                    ? null
                    : 'Letters, digits and dots only (max 12)',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: industries.any((i) => i.code == _industry) ? _industry : null,
                decoration: const InputDecoration(labelText: 'Industry'),
                items: [for (final i in industries) DropdownMenuItem(value: i.code, child: Text(i.label))],
                onChanged: (v) => setState(() => _industry = v ?? 'other'),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _sector, decoration: const InputDecoration(labelText: 'Sector')),
              const SizedBox(height: 12),
              TextFormField(controller: _exchange, decoration: const InputDecoration(labelText: 'Exchange')),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
