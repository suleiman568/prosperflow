import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Production [AuthService] backed by Supabase Auth.
///
/// supabase_flutter persists the session (access + refresh tokens) locally
/// and refreshes it automatically, so a trader who signed in once stays
/// signed in through long offline stretches (Backend Plan §2: refresh
/// tokens survive offline periods). Only the first sign-in / sign-up
/// needs connectivity.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  static const _offlineMessage =
      '📴 No connection — check your network and try again';

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  String get traderName {
    final user = _client.auth.currentUser;
    final name = user?.userMetadata?['name'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
    final email = user?.email ?? '';
    final prefix = email.split('@').first.trim();
    if (prefix.isEmpty) return 'Trader';
    return prefix[0].toUpperCase() + prefix.substring(1);
  }

  @override
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return _offlineMessage;
    }
  }

  @override
  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      if (response.session == null) {
        // Email confirmation is enabled on the project.
        return '📧 Check your email to confirm your account, then log in';
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return _offlineMessage;
    }
  }

  @override
  Future<String?> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return _offlineMessage;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Local sign-out must always succeed, even offline.
      await _client.auth.signOut(scope: SignOutScope.local);
    }
  }
}
