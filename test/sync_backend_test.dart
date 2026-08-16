import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:prosperflow/src/sync/sync_backend.dart';

/// Drives the real [SupabaseSyncBackend] against a mock transport, so the
/// assertions are about the request it actually sends and the response it
/// actually gets back — not a hand-rolled stand-in for postgrest.
///
/// The behaviour under test is easy to miss by reading the code: PostgREST
/// answers an update that matches no row with `204 No Content`, which is
/// exactly what a successful update returns, and postgrest-dart treats any
/// 2xx as success. So a write refused by row-level security used to come back
/// clean, the engine deleted it from the outbox, and the edit was gone.
void main() {
  late List<http.Request> requests;

  /// A signed-in client whose transport is mocked. The session is set
  /// directly rather than through a sign-in call, so no network is involved
  /// and the trader id is fixed.
  Future<SupabaseSyncBackend> backendReturning(
    String body, {
    int status = 200,
  }) async {
    requests = [];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        // postgrest reads response.request to decide how to parse, so the
        // mock has to carry it back.
        return http.Response(
          body,
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'test-access-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'test-refresh-token',
        'user': {
          'id': 'trader-a',
          'aud': 'authenticated',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': DateTime.now().toIso8601String(),
        },
      }),
    );
    return SupabaseSyncBackend(client);
  }

  group('update ops', () {
    test('a refused update raises instead of reporting success', () async {
      // RLS filtered the row out: the update matched nothing.
      final backend = await backendReturning('[]');

      await expectLater(
        backend.apply('product', 'update', {
          'id': 'p1',
          'name': 'Palm Oil',
          'stock': 5,
        }),
        throwsA(isA<StateError>()),
      );
    });

    test('an applied update returns normally', () async {
      final backend = await backendReturning(
        jsonEncode([
          {'id': 'p1', 'name': 'Palm Oil', 'stock': 5},
        ]),
      );

      await backend.apply('product', 'update', {
        'id': 'p1',
        'name': 'Palm Oil',
        'stock': 5,
      });

      // One PATCH, asking for the affected rows back — without the select
      // there is nothing in the response to tell the two cases apart.
      expect(requests.single.method, 'PATCH');
      expect(requests.single.url.path, contains('products'));
      expect(requests.single.url.query, contains('id=eq.p1'));
    });

    test('ownership is never patched', () async {
      final backend = await backendReturning(
        jsonEncode([
          {'id': 'p1'},
        ]),
      );

      await backend.apply('product', 'update', {
        'id': 'p1',
        'name': 'Palm Oil',
        'trader_id': 'someone-else',
      });

      final sent = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(sent.containsKey('trader_id'), isFalse);
      expect(sent.containsKey('id'), isFalse); // moved to the filter
      expect(sent['name'], 'Palm Oil');
    });

    test('credits are keyed on sale_id, not id', () async {
      final backend = await backendReturning(
        jsonEncode([
          {'sale_id': 's1'},
        ]),
      );

      await backend.apply('credit', 'update', {
        'sale_id': 's1',
        'status': 'paid',
      });

      expect(requests.single.url.query, contains('sale_id=eq.s1'));
    });
  });

  group('create ops', () {
    test('creates upsert so a replayed push cannot double-count', () async {
      final backend = await backendReturning(
        jsonEncode([
          {'id': 's1'},
        ]),
      );

      await backend.apply('sale', 'create', {'id': 's1', 'total': 18400});

      // POST with a merge-duplicates resolution is what makes the outbox safe
      // to replay after a dropped response.
      expect(requests.single.method, 'POST');
      expect(
        requests.single.headers['Prefer'],
        contains('resolution=merge-duplicates'),
      );
    });

    test(
      'a refused create already fails loudly, so it is left alone',
      () async {
        // An insert that violates the RLS WITH CHECK comes back as an error
        // rather than an empty 2xx, so this path needs no extra guard.
        final backend = await backendReturning(
          jsonEncode({
            'message': 'new row violates row-level security policy',
            'code': '42501',
          }),
          status: 403,
        );

        await expectLater(
          backend.apply('sale', 'create', {'id': 's1', 'total': 18400}),
          throwsA(isA<PostgrestException>()),
        );
      },
    );
  });
}
