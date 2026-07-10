/// Supabase project configuration (recovered from the original repo).
/// The publishable key is safe to ship in the client; row-level security
/// on the server is what protects data (Backend Plan §6).
class SupabaseConfig {
  const SupabaseConfig._();

  static const bool enabled = true;
  static const String url = 'https://dfvvxytxsysvxvhjqgkx.supabase.co';
  static const String publishableKey =
      'sb_publishable_upsPItfO8cE9-kc-K9aCLA_1XTejT5V';
}
