/// Where the app sends the things that went wrong.
///
/// An interface rather than a direct call to a vendor, for the same reason
/// [SyncBackend] is one: the tests need to assert that a failure was reported
/// without any network, and the web preview needs it to do nothing at all.
///
/// Two kinds, deliberately. A crash is something that escaped and the trader
/// probably saw. An issue is something the app handled — a sync that failed
/// and will be retried, a restore that has not finished — which nobody would
/// otherwise hear about, because handling it well is exactly what makes it
/// invisible.
abstract class ErrorReporter {
  /// Something escaped: an uncaught Flutter error, or an error that reached
  /// the zone with nothing to catch it.
  Future<void> reportCrash(Object error, StackTrace stackTrace);

  /// Something the app dealt with, but that should not be happening.
  ///
  /// [kind] is a short stable slug, not a sentence — it is what groups these
  /// together so a handful of phones failing the same way reads as one
  /// problem rather than a scatter.
  Future<void> reportIssue(
    String kind, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, String> tags = const {},
  });

  /// Attaches the signed-in trader, so a report can be tied to a ledger
  /// without naming anybody. The id is the account's opaque uuid and nothing
  /// else — no email, no display name.
  ///
  /// Null clears it, which sign-out must do: the next trader's reports must
  /// not carry the previous one's id.
  Future<void> setTrader(String? traderId);
}

/// Does nothing, and is the right answer in several places: the web design
/// preview, tests that are not about reporting, and any build with no DSN
/// configured.
class NoopErrorReporter implements ErrorReporter {
  const NoopErrorReporter();

  @override
  Future<void> reportCrash(Object error, StackTrace stackTrace) async {}

  @override
  Future<void> reportIssue(
    String kind, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, String> tags = const {},
  }) async {}

  @override
  Future<void> setTrader(String? traderId) async {}
}
