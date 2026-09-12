import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:prosperflow/src/auth/supabase_auth_service.dart';

/// Drives the real [SupabaseAuthService] against a mock transport, so the
/// assertions are about what a trader would actually be shown.
SupabaseAuthService authServiceThat({
  Object? throwing,
  String? responds,
  int status = 200,
}) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: MockClient((request) async {
      if (throwing != null) throw throwing;
      return http.Response(
        responds ?? '{}',
        status,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
  return SupabaseAuthService(client);
}

void main() {
  group('what a trader is told when sign-in fails', () {
    test('a lost connection is put in words they can act on', () async {
      // What the phone actually produced: an app with no INTERNET permission
      // cannot resolve any hostname, and gotrue hands the raw transport text
      // back as the exception message.
      final auth = authServiceThat(
        throwing: http.ClientException(
          "Failed host lookup: 'dfvvxytxsysvxvhjqgkx.supabase.co' "
          '(OS Error: No address associated with hostname, errno = 7)',
        ),
      );

      final message = await auth.signIn(
        email: 'trader@example.test',
        password: 'correct-horse',
      );

      expect(message, "📴 Can't connect — check your internet and try again");
      // None of this belongs in front of somebody trying to open their books.
      expect(message, isNot(contains('SocketException')));
      expect(message, isNot(contains('ClientException')));
      expect(message, isNot(contains('errno')));
      expect(message, isNot(contains('supabase.co')));
    });

    test('a wrong password still says so', () async {
      // The opposite mistake would be hiding everything behind one message:
      // this one the trader can actually do something about.
      final auth = authServiceThat(
        responds:
            '{"error":"invalid_grant",'
            '"error_description":"Invalid login credentials"}',
        status: 400,
      );

      final message = await auth.signIn(
        email: 'trader@example.test',
        password: 'wrong',
      );

      expect(message, isNotNull);
      expect(message, contains('Invalid login credentials'));
    });

    test('sign-up and password reset get the same treatment', () async {
      final auth = authServiceThat(
        throwing: http.ClientException('Failed host lookup: whatever'),
      );

      expect(
        await auth.signUp(
          name: 'Prosper',
          email: 'trader@example.test',
          password: 'correct-horse',
        ),
        "📴 Can't connect — check your internet and try again",
      );
      expect(
        await auth.resetPassword('trader@example.test'),
        "📴 Can't connect — check your internet and try again",
      );
    });
  });
}
