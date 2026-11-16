import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../app/env.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_providers.dart';
import '../../../shared/models/models.dart';

const supportedExtensions = ['pdf', 'xlsx'];

const _mime = {
  'pdf': 'application/pdf',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

/// Validates a picked file before upload. Returns an error message or null.
String? validateUpload({required String fileName, required int sizeBytes}) {
  final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  if (ext == 'xls') {
    return 'Legacy .xls files are not supported. Re-save the workbook as .xlsx and upload again.';
  }
  if (!supportedExtensions.contains(ext)) return 'Unsupported file type. Upload a PDF or XLSX file.';
  if (sizeBytes <= 0) return 'The file is empty.';
  if (sizeBytes > Env.maxUploadBytes) {
    return 'File is ${(sizeBytes / 1048576).toStringAsFixed(1)} MB; the limit is ${Env.maxUploadBytes ~/ 1048576} MB.';
  }
  return null;
}

class DocumentRepository {
  DocumentRepository(this._db);
  final SupabaseClient _db;

  StorageFileApi get _bucket => _db.storage.from(Env.documentsBucket);

  Future<List<FinancialDocument>> list(String analysisId) => guard(() async {
        final rows =
            await _db.from('documents').select().eq('analysis_id', analysisId).order('created_at', ascending: false);
        return rows.map(FinancialDocument.fromJson).toList();
      });

  /// Uploads to `{uid}/{analysis}/{company}/{year}_{uuid}.{ext}` and records
  /// metadata. If [replacing] is given, the old file and row are removed after
  /// the new upload succeeds.
  Future<FinancialDocument> upload({
    required String analysisId,
    required String companyId,
    required int year,
    required String fileName,
    required Uint8List bytes,
    String documentType = 'annual_report',
    FinancialDocument? replacing,
  }) =>
      guard(() async {
        final error = validateUpload(fileName: fileName, sizeBytes: bytes.length);
        if (error != null) throw AppException(error);
        final ext = fileName.split('.').last.toLowerCase();
        final path = '${requireUserId(_db)}/$analysisId/$companyId/${year}_${const Uuid().v4()}.$ext';
        await _bucket.uploadBinary(path, bytes, fileOptions: FileOptions(contentType: _mime[ext], upsert: false));
        final Map<String, dynamic> row;
        try {
          row = await _db
              .from('documents')
              .insert({
                'analysis_id': analysisId,
                'company_id': companyId,
                'file_name': fileName,
                'storage_path': path,
                'file_type': ext,
                'file_size_bytes': bytes.length,
                'financial_year': year,
                'document_type': documentType,
              })
              .select()
              .single();
        } catch (_) {
          await _bucket.remove([path]); // don't leave orphaned objects on partial failure
          rethrow;
        }
        // The new document is fully stored; a failure removing the old one is
        // reported but does not undo the successful upload.
        if (replacing != null) {
          try {
            await delete(replacing);
          } catch (e) {
            throw AppException('Uploaded the new file, but could not remove ${replacing.fileName}: ${describeError(e)}');
          }
        }
        return FinancialDocument.fromJson(row);
      });

  Future<Uint8List> download(FinancialDocument doc) => guard(() => _bucket.download(doc.storagePath));

  Future<String> signedUrl(FinancialDocument doc) => guard(() => _bucket.createSignedUrl(doc.storagePath, 300));

  Future<void> delete(FinancialDocument doc) => guard(() async {
        await _db.from('documents').delete().eq('id', doc.id);
        await _bucket.remove([doc.storagePath]);
      });

  Future<void> setExtractionStatus(String id, {required bool success, required String message}) => guard(() => _db
      .from('documents')
      .update({'upload_status': success ? 'extracted' : 'extraction_failed', 'extraction_message': message}).eq('id', id));
}

final documentRepositoryProvider = Provider((ref) => DocumentRepository(ref.watch(supabaseProvider)));

final documentsProvider = FutureProvider.family<List<FinancialDocument>, String>(
    (ref, analysisId) => ref.watch(documentRepositoryProvider).list(analysisId));
