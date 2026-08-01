import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the web entry point against re-introducing the stale-deploy bug.
///
/// Flutter's generated service worker is cache-first for main.dart.js, and the
/// worker controlling a page is the one registered on the *previous* visit. So
/// the first load after a deploy served the previous bundle: the thousands
/// separators shipped in "Show thousands separators as money amounts are
/// typed" were invisible on web until a second reload, and looked like a bug
/// in the formatter rather than a stale bundle.
///
/// The end-to-end proof lives in tool/web_deploy_freshness_check.js, which
/// drives a real browser across a real deploy. That needs Chromium, so this
/// cheap check is what runs in CI: it fails if web/index.html goes back to the
/// default bootstrap that registers the worker.
void main() {
  group('web/index.html', () {
    late String html;

    setUpAll(() => html = File('web/index.html').readAsStringSync());

    test('does not use the default service-worker-registering bootstrap', () {
      // The stock `<script src="flutter_bootstrap.js">` registers the service
      // worker with the build's serviceWorkerVersion. Loading the templated
      // flutter.js by hand is what lets us skip registration.
      expect(
        html.contains('<script src="flutter_bootstrap.js"'),
        isFalse,
        reason:
            'the default bootstrap registers the caching service worker, '
            'which serves the previous bundle for one load after a deploy',
      );
      expect(html, contains('{{flutter_js}}'));
      expect(html, contains('{{flutter_build_config}}'));
    });

    test('loads without serviceWorkerSettings, so nothing is registered', () {
      // Matched with the colon it carries as a config key, so prose mentioning
      // the option by name doesn't read as the option being set.
      expect(html, contains('_flutter.loader.load()'));
      expect(
        html.contains('serviceWorkerSettings:'),
        isFalse,
        reason: 'passing serviceWorkerSettings re-enables registration',
      );
    });

    test('clears a worker and caches left by an earlier visit', () {
      // Without this, a browser that registered the old worker keeps being
      // served its cached bundle indefinitely — the fix would never reach the
      // people already affected by it.
      expect(html, contains('serviceWorker'));
      expect(html, contains('unregister()'));
      expect(html, contains('caches.delete'));
    });
  });
}
