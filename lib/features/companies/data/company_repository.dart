import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_providers.dart';
import '../../../shared/models/models.dart';

class CompanyRepository {
  CompanyRepository(this._db);
  final SupabaseClient _db;

  Future<List<Company>> list() => guard(() async {
        final rows = await _db.from('companies').select().order('company_name');
        return rows.map(Company.fromJson).toList();
      });

  Future<Company> create(Company c) => guard(() async {
        final row = await _db.from('companies').insert(c.toWrite()).select().single();
        return Company.fromJson(row);
      });

  Future<Company> update(Company c) => guard(() async {
        final row = await _db.from('companies').update(c.toWrite()).eq('id', c.id).select().single();
        return Company.fromJson(row);
      });

  Future<void> delete(String id) => guard(() async {
        try {
          await _db.from('companies').delete().eq('id', id);
        } on PostgrestException catch (e) {
          if (e.code == '23503') {
            throw const AppException('This company is used in an analysis. Delete those analyses first.');
          }
          rethrow;
        }
      });
}

final companyRepositoryProvider = Provider((ref) => CompanyRepository(ref.watch(supabaseProvider)));

final companiesProvider = FutureProvider<List<Company>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(companyRepositoryProvider).list();
});
