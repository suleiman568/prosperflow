import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/telemetry_config.dart';
import 'error_reporter.dart';
import 'sentry_error_reporter.dart';

/// Runs [body] with every route an error can take out of a Flutter app
/// wired to [reporter].
///
/// There are three, and missing any one of them leaves a whole class of
/// failure invisible:
///
///   * [FlutterError.onError] — errors raised inside the framework, which is
///     most of what goes wrong during a build or a layout.
///   * [PlatformDispatcher.instance.onError] — errors from the engine and
///     from async work the framework never sees.
///   * [runZonedGuarded] — everything else that escapes an async gap with no
///     `catch` anywhere above it. This is the one that matters most here: the
///     failure that started this work escapes exactly that way, from a
///     constructor inside supabase_flutter, and has nowhere to go today.
///
/// Errors are still handed on to the original handlers afterwards, so a debug
/// run keeps printing them to the console. Reporting them should not cost the
/// developer the red screen they are used to.
Future<void> runGuarded(
  FutureOr<void> Function() body, {
  required ErrorReporter reporter,
}) async {
  final flutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(
      reporter.reportCrash(
        details.exception,
        details.stack ?? StackTrace.current,
      ),
    );
    flutterOnError?.call(details);
  };

  final platformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(reporter.reportCrash(error, stack));
    return platformOnError?.call(error, stack) ?? true;
  };

  await runZonedGuarded(() async {
    await body();
  }, (error, stack) => unawaited(reporter.reportCrash(error, stack)));
}

/// Builds the reporter this build should use, and starts it.
///
/// Returns [NoopErrorReporter] when no DSN was supplied, which covers debug
/// runs, the web preview and any checkout without the build flag — the app
/// behaves identically, it simply tells nobody.
Future<ErrorReporter> startReporting() async {
  if (!TelemetryConfig.enabled || kIsWeb) return const NoopErrorReporter();

  await SentryFlutter.init(
    (options) =>
        SentryErrorReporter.configure(options, dsn: TelemetryConfig.dsn),
  );
  return const SentryErrorReporter();
}
