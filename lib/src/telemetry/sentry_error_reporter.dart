import 'package:sentry_flutter/sentry_flutter.dart';

import 'error_reporter.dart';

/// Sends reports to Sentry, configured tightly on purpose.
///
/// This app holds people's takings, their customers' names and what they are
/// owed. The defaults of any crash reporter are built for apps where a
/// screenshot or a breadcrumb trail is harmless, and here they are not, so
/// everything that could carry the ledger off the phone is turned off
/// explicitly rather than left at its default — a default can change in a
/// version bump, a line of code cannot.
class SentryErrorReporter implements ErrorReporter {
  const SentryErrorReporter();

  /// Applies the options this app runs with.
  ///
  /// Kept separate from [SentryFlutter.init] so the configuration itself can
  /// be tested: the assertions that matter here are about what is switched
  /// off, and those should not need a network or a real Sentry.
  static void configure(SentryFlutterOptions options, {required String dsn}) {
    options.dsn = dsn;

    // No screenshots. The screen at the moment of a crash is a trader's
    // takings for the day, their customers' debts, or their margins.
    options.attachScreenshot = false;
    options.attachViewHierarchy = false;

    // No personal data, and no guessing at it from the device either.
    options.sendDefaultPii = false;

    // No breadcrumb trail of what was tapped or requested. Tapping through
    // Credits to a customer is not something we need in order to fix a crash,
    // and it is somebody's business.
    options.enableUserInteractionBreadcrumbs = false;
    options.enableAutoNativeBreadcrumbs = false;
    options.maxBreadcrumbs = 20;

    // Not measuring performance, and not tracking sessions: both are steady
    // background traffic, and these phones are on data the trader pays for by
    // the megabyte.
    options.tracesSampleRate = 0.0;
    options.enableAutoSessionTracking = false;

    // The last gate before anything leaves the device.
    options.beforeSend = _scrub;
  }

  /// The last gate: empties the breadcrumb trail and reduces the user down to
  /// an opaque id, whatever put them there.
  ///
  /// Belt and braces over the options above, because a future version could
  /// add a source of context that is on by default, and this runs on every
  /// event regardless of where its contents came from.
  ///
  /// `request` is not cleared here because it cannot be: `copyWith` reads a
  /// null argument as "leave it alone", so there is no way to blank a field
  /// through it. Nothing populates it either — that needs the HTTP or
  /// failed-request integrations, which this app does not add, and
  /// `sendDefaultPii` is off. Worth knowing rather than assuming covered.
  static SentryEvent? _scrub(SentryEvent event, Hint hint) {
    final user = event.user;
    return event.copyWith(
      breadcrumbs: const [],
      // Sentry would otherwise carry email, username and ip address here.
      user: user == null ? null : SentryUser(id: user.id),
    );
  }

  @override
  Future<void> reportCrash(Object error, StackTrace stackTrace) =>
      Sentry.captureException(error, stackTrace: stackTrace);

  @override
  Future<void> reportIssue(
    String kind, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, String> tags = const {},
  }) {
    return Sentry.captureEvent(
      SentryEvent(
        // Not `fatal`: the app is still running and the trader may not have
        // noticed. It is still the thing we most want to see.
        level: SentryLevel.error,
        message: SentryMessage(kind),
        throwable: error,
        tags: {'kind': kind, ...tags},
      ),
      stackTrace: stackTrace,
    );
  }

  @override
  Future<void> setTrader(String? traderId) async {
    await Sentry.configureScope(
      (scope) =>
          scope.setUser(traderId == null ? null : SentryUser(id: traderId)),
    );
  }
}
