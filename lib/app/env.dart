/// Client configuration. Values can be overridden at build time:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
///
/// The publishable key is designed to be public: it grants nothing beyond what
/// Row Level Security allows an authenticated user. Never put the service-role
/// (secret) key here.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oilfsgaelmnzdubiolgu.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_mmTA4gMnhWCX9hJaYJ0cHA_QHkF8q9b',
  );

  /// Deep link used by password-reset and sign-up confirmation emails on mobile.
  static const mobileAuthRedirect = 'com.equilense.equilense://auth-callback';

  static const documentsBucket = 'financial-documents';
  static const maxUploadBytes = 25 * 1024 * 1024;
}
