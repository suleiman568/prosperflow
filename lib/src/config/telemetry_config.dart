/// Where crash and error reports go.
///
/// The DSN is supplied at build time rather than committed:
///
///   flutter build apk --dart-define=SENTRY_DSN=https://...
///
/// Empty is the default and means reporting is off, which is what every
/// build without that flag gets — debug runs, the web design preview, and
/// anyone's checkout. Nothing leaves a device by accident because a key was
/// sitting in the repository.
///
/// A DSN is not a secret in the way a service key is — it only permits
/// sending events — but it is still not something a fork of this repository
/// should inherit and start filling with somebody else's crashes.
class TelemetryConfig {
  const TelemetryConfig._();

  static const String dsn = String.fromEnvironment('SENTRY_DSN');

  static bool get enabled => dsn.isNotEmpty;
}
