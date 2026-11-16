import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/common.dart';
import '../../../shared/models/models.dart';
import '../../analysis/data/analysis_repository.dart';
import '../../extraction/data/extraction_service.dart';
import '../../validation/data/financial_data_repository.dart';
import '../data/document_repository.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key, required this.analysisId});

  final String analysisId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(analysisProvider(analysisId));
    final docs = ref.watch(documentsProvider(analysisId));
    return Scaffold(
      appBar: AppBar(title: const Text('Financial documents')),
      body: AsyncView(
        value: analysis,
        onRetry: () => ref.invalidate(analysisProvider(analysisId)),
        data: (a) => AsyncView(
          value: docs,
          onRetry: () => ref.invalidate(documentsProvider(analysisId)),
          data: (list) => PageBody(children: [
            Text(
              'Upload one annual report (or statement workbook) per company and year. PDF or XLSX, up to 25 MB. '
              'Figures are extracted automatically and sent to the review screen.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ResponsiveGrid(minItemWidth: 420, children: [
              for (final c in a.companies)
                SectionCard(
                  title: c.display,
                  subtitle: c.id == a.companyA.id ? 'Company A' : 'Company B',
                  child: Column(children: [
                    for (final y in a.years)
                      _YearSlot(
                        analysis: a,
                        company: c,
                        year: y,
                        documents: list.where((d) => d.companyId == c.id && d.year == y).toList(),
                      ),
                  ]),
                ),
            ]),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => context.go('/analyses/$analysisId/validate'),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Continue to review'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _YearSlot extends ConsumerStatefulWidget {
  const _YearSlot({required this.analysis, required this.company, required this.year, required this.documents});

  final Analysis analysis;
  final Company company;
  final int year;
  final List<FinancialDocument> documents;

  @override
  ConsumerState<_YearSlot> createState() => _YearSlotState();
}

class _YearSlotState extends ConsumerState<_YearSlot> {
  String? _busy; // progress message

  void _refresh() {
    ref
      ..invalidate(documentsProvider(widget.analysis.id))
      ..invalidate(analysisDataProvider(widget.analysis.id));
  }

  Future<void> _pickAndUpload({FinancialDocument? replacing}) async {
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'xlsx', 'xls']);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open the file picker: $e', error: true);
      return;
    }
    if (files.isEmpty) return;
    final file = files.first;
    // length() may be unknown on some platforms (web); validate type first,
    // then validate the real size after reading.
    final knownSize = await file.length();
    final preCheck = validateUpload(fileName: file.name, sizeBytes: knownSize ?? 1);
    if (preCheck != null) {
      if (mounted) showSnack(context, preCheck, error: true);
      return;
    }
    setState(() => _busy = 'Reading ${file.name}…');
    try {
      final bytes = await file.readAsBytes();
      final invalid = validateUpload(fileName: file.name, sizeBytes: bytes.length);
      if (invalid != null) throw AppException(invalid);
      setState(() => _busy = 'Uploading ${(bytes.length / 1048576).toStringAsFixed(1)} MB…');
      final doc = await ref.read(documentRepositoryProvider).upload(
            analysisId: widget.analysis.id,
            companyId: widget.company.id,
            year: widget.year,
            fileName: file.name,
            bytes: bytes,
            replacing: replacing,
          );
      _refresh();
      await _extract(doc, bytes: bytes);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _extract(FinancialDocument doc, {Uint8List? bytes}) async {
    final docs = ref.read(documentRepositoryProvider);
    final dataRepo = ref.read(financialDataRepositoryProvider);
    try {
      setState(() => _busy = 'Extracting figures from ${doc.fileName}…');
      final content = bytes ?? await docs.download(doc);
      final mappings = await dataRepo.userMappings();
      final report = await ExtractionService.extract(bytes: content, fileType: doc.fileType, userMappings: mappings);
      final current = await dataRepo.load(widget.analysis.id);
      final period = current.period(widget.company.id, widget.year);
      if (period == null) throw const AppException('Financial period missing for this year.');
      final written = await dataRepo.applyExtraction(
        analysisId: widget.analysis.id,
        period: period,
        documentId: doc.id,
        sourceType: doc.fileType,
        items: report.items,
        current: current,
      );
      final message = [
        '${report.items.length} line item(s) recognised, $written written for review'
            '${report.unitMultiplier != 1 ? ' (units ×${report.unitMultiplier.toStringAsFixed(0)})' : ''}.',
        ...report.warnings,
      ].join(' ');
      await docs.setExtractionStatus(doc.id, success: report.items.isNotEmpty, message: message);
      _refresh();
      if (mounted) showSnack(context, message, error: report.items.isEmpty);
    } catch (e) {
      await docs.setExtractionStatus(doc.id, success: false, message: describeError(e)).catchError((_) {});
      _refresh();
      if (mounted) showSnack(context, 'Extraction failed: ${describeError(e)}', error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _preview(FinancialDocument doc) async {
    try {
      final url = await ref.read(documentRepositoryProvider).signedUrl(doc);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    }
  }

  Future<void> _delete(FinancialDocument doc) async {
    final ok = await confirmDialog(context,
        title: 'Delete ${doc.fileName}?',
        message: 'The file is removed from storage. Figures extracted from it stay on the review screen '
            'but lose their source link.',
        confirm: 'Delete',
        destructive: true);
    if (!ok) return;
    try {
      await ref.read(documentRepositoryProvider).delete(doc);
      _refresh();
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('FY${widget.year}', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (_busy == null)
            TextButton.icon(
              onPressed: _pickAndUpload,
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(widget.documents.isEmpty ? 'Upload' : 'Add file'),
            ),
        ]),
        if (_busy != null) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          const SizedBox(height: 6),
          Text(_busy!, style: t.textTheme.bodySmall),
        ],
        if (widget.documents.isEmpty && _busy == null)
          Text('No document uploaded', style: t.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        for (final d in widget.documents)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(d.fileType == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.table_chart_outlined),
            title: Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${(d.sizeBytes / 1048576).toStringAsFixed(2)} MB · '
              '${switch (d.uploadStatus) { 'extracted' => 'Extracted', 'extraction_failed' => 'Extraction failed', _ => 'Uploaded' }}'
              '${d.extractionMessage != null ? '\n${d.extractionMessage}' : ''}',
            ),
            isThreeLine: d.extractionMessage != null,
            trailing: PopupMenuButton<String>(
              enabled: _busy == null,
              tooltip: 'Document actions',
              onSelected: (v) => switch (v) {
                'preview' => _preview(d),
                'extract' => _extract(d),
                'replace' => _pickAndUpload(replacing: d),
                _ => _delete(d),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'preview', child: Text('Open / preview')),
                PopupMenuItem(value: 'extract', child: Text('Re-run extraction')),
                PopupMenuItem(value: 'replace', child: Text('Replace file')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
      ]),
    );
  }
}
