import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// User-presentable error. Repositories convert backend errors into this.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Converts any error into a meaningful message for the UI.
String describeError(Object error) {
  if (error is AppException) return error.message;
  if (error is AuthException) return error.message;
  if (error is StorageException) return 'Storage error: ${error.message}';
  if (error is PostgrestException) {
    return switch (error.code) {
      '23505' => 'A record with these details already exists.',
      '23503' => 'This record is linked to other data and cannot be changed or removed.',
      '23514' => 'The data failed a validation rule: ${error.message}',
      '42501' => 'You do not have permission to perform this action.',
      'PGRST116' => 'The requested record was not found.',
      _ => error.message,
    };
  }
  if (error is TimeoutException) return 'The request timed out. Check your connection and retry.';
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('ClientException') || text.contains('Failed host lookup')) {
    return 'Network unavailable. Check your connection and retry.';
  }
  if (error is ArgumentError) return error.message?.toString() ?? error.toString();
  return 'Something went wrong: $error';
}

/// Runs [body] and rethrows failures as [AppException].
Future<T> guard<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on AppException {
    rethrow;
  } catch (e) {
    throw AppException(describeError(e), cause: e);
  }
}
