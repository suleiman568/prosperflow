import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the release build's network permission.
///
/// Flutter's template puts `android.permission.INTERNET` in src/debug and
/// src/profile only, where it is there for the Flutter tool's benefit — hot
/// reload talks to the running app over a socket. Those manifests are not
/// merged into a release build, so an app that never declared the permission
/// for itself shipped without it.
///
/// The symptom does not look like a permissions problem, which is why this is
/// worth a test rather than a comment. Android answers every DNS lookup from
/// an app with no INTERNET permission with "No address associated with
/// hostname" (errno 7) — indistinguishable from being offline, on a phone
/// whose browser is loading the same host in the next window. Sign-in, sync
/// and crash reporting were all unreachable in release, and each one failed in
/// a way that pointed somewhere else.
void main() {
  group('android/app/src/main/AndroidManifest.xml', () {
    late String manifest;

    setUpAll(
      () => manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync(),
    );

    test('declares INTERNET, which release builds get from nowhere else', () {
      expect(
        manifest,
        contains('android.permission.INTERNET'),
        reason:
            'without this the release APK cannot resolve any hostname, and '
            'the failure reads as the phone being offline',
      );
    });

    test('the debug manifest is not what release relies on', () {
      // Kept as a statement of the trap: it is entirely reasonable for these
      // to exist, and entirely wrong to depend on them.
      final debug = File(
        'android/app/src/debug/AndroidManifest.xml',
      ).readAsStringSync();
      expect(debug, contains('android.permission.INTERNET'));
      expect(
        File('android/app/src/profile/AndroidManifest.xml').readAsStringSync(),
        contains('android.permission.INTERNET'),
      );
    });
  });
}
