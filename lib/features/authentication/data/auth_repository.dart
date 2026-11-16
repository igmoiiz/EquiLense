import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/env.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_providers.dart';
import '../../../shared/models/models.dart';

enum SignUpOutcome { signedIn, confirmationRequired }

class AuthRepository {
  AuthRepository(this._db);
  final SupabaseClient _db;

  GoTrueClient get _auth => _db.auth;

  String? get _redirect => kIsWeb ? Uri.base.origin : Env.mobileAuthRedirect;

  Future<void> signIn(String email, String password) =>
      guard(() => _auth.signInWithPassword(email: email.trim(), password: password));

  Future<SignUpOutcome> signUp({required String email, required String password, required String fullName}) =>
      guard(() async {
        final res = await _auth.signUp(
          email: email.trim(),
          password: password,
          data: {'full_name': fullName.trim()},
          emailRedirectTo: _redirect,
        );
        return res.session != null ? SignUpOutcome.signedIn : SignUpOutcome.confirmationRequired;
      });

  Future<void> sendPasswordReset(String email) =>
      guard(() => _auth.resetPasswordForEmail(email.trim(), redirectTo: _redirect));

  Future<void> updatePassword(String password) => guard(() => _auth.updateUser(UserAttributes(password: password)));

  Future<void> signOut() => guard(() => _auth.signOut());

  Future<Profile> fetchProfile() => guard(() async {
        final row = await _db.from('profiles').select().eq('id', requireUserId(_db)).single();
        return Profile.fromJson(row);
      });

  Future<void> updateProfile({required String fullName, required String currency}) => guard(() => _db
      .from('profiles')
      .update({'full_name': fullName.trim(), 'default_currency': currency.trim().toUpperCase()}).eq(
          'id', requireUserId(_db)));
}

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(supabaseProvider)));

final profileProvider = FutureProvider<Profile>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).fetchProfile();
});
