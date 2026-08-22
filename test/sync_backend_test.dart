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
        }, trader: 'trader-a'),
        throwsA(isA<WriteRefused>()),
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
      }, trader: 'trader-a');

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
      }, trader: 'trader-a');

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
      }, trader: 'trader-a');

      expect(requests.single.url.query, contains('sale_id=eq.s1'));
    });
  });

  group('whose ledger a push joins', () {
    test('a row is never filed under whoever is signed in now', () async {
      // The engine checks who owns the local database before calling, but a
      // sign-in can complete between there and the row going out — and it is
      // this session read, not that check, that decides whose ledger the row
      // joins. No transaction spans a network call, so the guard has to live
      // where the stamping happens.
      final backend = await backendReturning(
        jsonEncode([
          {'id': 's1'},
        ]),
      );

      await expectLater(
        backend.apply('sale', 'create', {
          'id': 's1',
          'total': 18400,
        }, trader: 'trader-b'),
        throwsA(isA<TraderChanged>()),
      );
      expect(
        requests,
        isEmpty,
        reason: 'nothing may go out under the wrong session',
      );
    });

    test('the stamped owner is the trader the push was made for', () async {
      final backend = await backendReturning(
        jsonEncode([
          {'id': 's1'},
        ]),
      );

      await backend.apply('sale', 'create', {
        'id': 's1',
        'total': 18400,
      }, trader: 'trader-a');

      final sent = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(sent['trader_id'], 'trader-a');
    });
  });

  group('pull queries', () {
    test('an opening pull filters on nothing and orders on the pair', () async {
      final backend = await backendReturning(jsonEncode([]));

      await backend.fetchSince('product', null, limit: 50);

      final query = Uri.decodeFull(requests.single.url.query);
      expect(query, isNot(contains('server_updated_at.gt')));
      // The primary key is in the ordering, not just the watermark: rows
      // written by one transaction share a watermark, and a page boundary
      // inside a tied group would otherwise skip the rest of it.
      expect(
        query,
        matches(RegExp(r'order=server_updated_at\.asc[^,]*,id\.asc')),
      );
      expect(query, contains('limit=50'));
    });

    test('resuming asks for the rest of the tied group too', () async {
      final backend = await backendReturning(jsonEncode([]));
      final at = DateTime.utc(2026, 3, 1);

      await backend.fetchSince('product', PullCursor(at, 'p1'));

      final query = Uri.decodeFull(requests.single.url.query);
      // Strictly later rows, OR the same watermark with a later key.
      expect(query, contains('server_updated_at.gt.${at.toIso8601String()}'));
      expect(query, contains('server_updated_at.eq.${at.toIso8601String()}'));
      expect(query, contains('id.gt.p1'));
    });

    test('a rewound cursor re-covers its window inclusively', () async {
      final backend = await backendReturning(jsonEncode([]));
      final at = DateTime.utc(2026, 3, 1);

      // lastId null means "start here", not "resume after a row" — a strict
      // greater-than would step over the window it is meant to re-cover.
      await backend.fetchSince('sale', PullCursor(at, null));

      final query = Uri.decodeFull(requests.single.url.query);
      expect(query, contains('server_updated_at=gte.${at.toIso8601String()}'));
    });

    test('credits page on sale_id', () async {
      final backend = await backendReturning(jsonEncode([]));

      await backend.fetchSince('credit', PullCursor(DateTime.utc(2026), 's1'));

      final query = Uri.decodeFull(requests.single.url.query);
      expect(query, contains('sale_id.gt.s1'));
      expect(
        query,
        matches(RegExp(r'order=server_updated_at\.asc[^,]*,sale_id\.asc')),
      );
    });

    test('a short page means caught up, a full one means more', () async {
      Map<String, dynamic> row(String id, String at) => {
        'id': id,
        'server_updated_at': at,
      };

      final short = await backendReturning(
        jsonEncode([row('p1', '2026-03-01T00:00:00.000Z')]),
      );
      expect(
        (await short.fetchSince('product', null, limit: 2)).cursor,
        isNull,
      );

      final full = await backendReturning(
        jsonEncode([
          row('p1', '2026-03-01T00:00:00.000Z'),
          row('p2', '2026-03-01T00:00:00.000Z'),
        ]),
      );
      final page = await full.fetchSince('product', null, limit: 2);
      expect(page.cursor, isNotNull);
      // Resumes from the last row of the page, keeping its key so the tied
      // group continues rather than restarting.
      expect(page.cursor!.lastId, 'p2');
    });
  });

  group('PullCursor', () {
    test('survives a round trip through storage', () {
      final cursor = PullCursor(DateTime.utc(2026, 3, 1, 12, 30), 'p1');
      final restored = PullCursor.decode(cursor.encode())!;
      expect(restored.watermark, cursor.watermark);
      expect(restored.lastId, 'p1');
    });

    test('rewinding drops the key so the window is re-covered', () {
      final cursor = PullCursor(DateTime.utc(2026, 3, 1, 12, 30), 'p1');
      final rewound = cursor.rewound(const Duration(minutes: 2));
      expect(rewound.watermark, DateTime.utc(2026, 3, 1, 12, 28));
      expect(rewound.lastId, isNull);
    });

    test('unreadable stored values start from the beginning', () {
      expect(PullCursor.decode(null), isNull);
      expect(PullCursor.decode(''), isNull);
      expect(PullCursor.decode('not-a-date|p1'), isNull);
    });
  });

  group('create ops', () {
    test('a create never rewrites a row already on the server', () async {
      final backend = await backendReturning(
        jsonEncode([
          {'id': 's1'},
        ]),
      );

      await backend.apply('sale', 'create', {
        'id': 's1',
        'total': 18400,
      }, trader: 'trader-a');

      // Upserting on the client key is what makes the outbox safe to replay
      // after a dropped response. Ignoring the duplicate rather than merging
      // it is what stops that replay undoing whatever has happened to the row
      // since — and what stops a device that upgraded holding a staler view
      // of a pre-v6 product overwriting an opening another device already
      // established, which would move stock under everyone who had it right.
      expect(requests.single.method, 'POST');
      expect(
        requests.single.headers['Prefer'],
        contains('resolution=ignore-duplicates'),
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
          backend.apply('sale', 'create', {
            'id': 's1',
            'total': 18400,
          }, trader: 'trader-a'),
          throwsA(isA<PostgrestException>()),
        );
      },
    );
  });
}
