import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

/// Emits on every auth change (sign in/out, token refresh, password recovery).
final authStateProvider = StreamProvider<AuthState>((ref) => ref.watch(supabaseProvider).auth.onAuthStateChange);

/// Current user id; throws if called while signed out.
String requireUserId(SupabaseClient client) {
  final id = client.auth.currentUser?.id;
  if (id == null) throw StateError('Not signed in');
  return id;
}
