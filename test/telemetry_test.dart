import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:prosperflow/src/telemetry/error_reporter.dart';
import 'package:prosperflow/src/telemetry/sentry_error_reporter.dart';
import 'package:prosperflow/src/telemetry/telemetry.dart';

/// Records instead of sending, so the tests can assert that a failure was
/// reported without a network or a real Sentry.
class RecordingErrorReporter implements ErrorReporter {
  final crashes = <(Object, StackTrace)>[];
  final issues = <({String kind, Object? error, Map<String, String> tags})>[];
  String? trader;

  @override
  Future<void> reportCrash(Object error, StackTrace stackTrace) async =>
      crashes.add((error, stackTrace));

  @override
  Future<void> reportIssue(
    String kind, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, String> tags = const {},
  }) async => issues.add((kind: kind, error: error, tags: tags));

  @override
  Future<void> setTrader(String? traderId) async => trader = traderId;
}

void main() {
  group('the routes an error can take out of the app', () {
    late RecordingErrorReporter reporter;
    late FlutterExceptionHandler? originalOnError;

    setUp(() {
      reporter = RecordingErrorReporter();
      originalOnError = FlutterError.onError;
    });

    tearDown(() => FlutterError.onError = originalOnError);

    test('an error with no catch anywhere above it is reported', () async {
      // The case that started this work: supabase_flutter throws from inside a
      // constructor, across an async gap, with nothing to catch it. Before
      // this, that error reached nobody at all.
      await runGuarded(() async {
        unawaited(
          Future<void>.error(StateError('escaped'), StackTrace.current),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }, reporter: reporter);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(reporter.crashes, hasLength(1));
      expect(reporter.crashes.single.$1, isA<StateError>());
    });

    test(
      'a framework error is reported and still reaches the console',
      () async {
        var reachedOriginal = false;
        FlutterError.onError = (_) => reachedOriginal = true;

        await runGuarded(() async {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: StateError('from the framework'),
              stack: StackTrace.current,
            ),
          );
        }, reporter: reporter);

        expect(reporter.crashes, hasLength(1));
        // Reporting an error should not cost a developer the red screen and the
        // console output they debug with.
        expect(reachedOriginal, isTrue);
      },
    );

    test('a framework error with no stack still reports one', () async {
      await runGuarded(() async {
        FlutterError.reportError(
          FlutterErrorDetails(exception: StateError('no stack')),
        );
      }, reporter: reporter);

      expect(reporter.crashes.single.$2, isNotNull);
    });
  });

  group('what the reporter is allowed to send', () {
    // These assert the configuration itself, because the privacy decisions
    // live in it. A default flipping in a version bump would be silent
    // otherwise, and this app holds people's takings and their customers'
    // debts.
    late SentryFlutterOptions options;

    setUp(() {
      options = SentryFlutterOptions();
      SentryErrorReporter.configure(options, dsn: 'https://key@example.test/1');
    });

    test('never a screenshot or a view hierarchy of the ledger', () {
      expect(options.attachScreenshot, isFalse);
      expect(options.attachViewHierarchy, isFalse);
    });

    test('never personal data, and no trail of what was tapped', () {
      expect(options.sendDefaultPii, isFalse);
      expect(options.enableUserInteractionBreadcrumbs, isFalse);
      expect(options.enableAutoNativeBreadcrumbs, isFalse);
    });

    test('no steady background traffic on a metered connection', () {
      expect(options.tracesSampleRate, 0.0);
      expect(options.enableAutoSessionTracking, isFalse);
    });

    test('the scrubber empties breadcrumbs and reduces the user to an id', () {
      final scrubbed =
          options.beforeSend!(
                SentryEvent(
                  breadcrumbs: [Breadcrumb(message: 'tapped Credits')],
                  request: SentryRequest(
                    url: 'https://example.supabase.co/rest/v1/credits',
                    queryString: 'customer_name=eq.Amaka',
                  ),
                  user: SentryUser(
                    id: 'trader-uuid',
                    email: 'trader@example.test',
                    username: 'Prosper',
                    ipAddress: '10.0.0.1',
                  ),
                ),
                Hint(),
              )
              as SentryEvent;

      expect(scrubbed.breadcrumbs, isEmpty);
      // A request URL can carry a customer's name in a filter. Clearable as
      // of Sentry 9, where the event's fields stopped being final.
      expect(scrubbed.request, isNull);
      expect(scrubbed.user!.id, 'trader-uuid');
      expect(scrubbed.user!.email, isNull);
      expect(scrubbed.user!.username, isNull);
      expect(scrubbed.user!.ipAddress, isNull);
    });

    test('an event with no user stays without one', () {
      final scrubbed =
          options.beforeSend!(SentryEvent(), Hint()) as SentryEvent;

      expect(scrubbed.user, isNull);
    });
  });

  group('builds with no DSN', () {
    test('report nothing, rather than failing to start', () async {
      // Every debug run and every checkout without the build flag lands here.
      final reporter = await startReporting();

      expect(reporter, isA<NoopErrorReporter>());
      // And it is safe to call — the Tier 2 sites do not check first.
      await reporter.reportCrash(StateError('x'), StackTrace.current);
      await reporter.reportIssue('sync_failed');
      await reporter.setTrader('trader-uuid');
    });
  });
}
