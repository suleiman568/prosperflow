/// Auth surface used by the UI. Implementations: [SupabaseAuthService]
/// (production) and [FakeAuthService] (web preview + tests).
///
/// Methods return `null` on success or a human-readable message to show
/// in a toast — the market-stall UX never sees raw exceptions.
abstract class AuthService {
  bool get isSignedIn;

  /// Display name for the Dashboard greeting.
  String get traderName;

  Future<String?> signIn({required String email, required String password});

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<String?> resetPassword(String email);

  Future<void> signOut();
}

/// In-memory auth used on the web preview and in widget tests.
class FakeAuthService implements AuthService {
  FakeAuthService({bool signedIn = false, String name = 'Prosper'})
      : _signedIn = signedIn,
        _name = name;

  bool _signedIn;
  String _name;

  @override
  bool get isSignedIn => _signedIn;

  @override
  String get traderName => _name;

  @override
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (password.length < 6) return 'Password must be at least 6 characters';
    _signedIn = true;
    _name = _nameFromEmail(email);
    return null;
  }

  @override
  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (password.length < 6) return 'Password must be at least 6 characters';
    _signedIn = true;
    _name = name;
    return null;
  }

  @override
  Future<String?> resetPassword(String email) async => null;

  @override
  Future<void> signOut() async => _signedIn = false;

  static String _nameFromEmail(String email) {
    final prefix = email.split('@').first.trim();
    if (prefix.isEmpty) return 'Trader';
    return prefix[0].toUpperCase() + prefix.substring(1);
  }
}
