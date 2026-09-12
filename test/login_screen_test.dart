import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/app.dart';
import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/brand/brand_lockup.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';
import 'package:prosperflow/src/widgets/primary_button.dart';
import 'package:prosperflow/src/telemetry/error_reporter.dart';

import 'helpers.dart';
import 'telemetry_test.dart' show RecordingErrorReporter;

Future<FakeAuthService> _pumpApp(WidgetTester tester) async {
  final auth = FakeAuthService(); // signed out
  await tester.pumpWidget(
    AppScope(
      store: fixtureStore(),
      auth: auth,
      sync: NoopSyncEngine(),
      reporter: const NoopErrorReporter(),
      child: const ProsperFlowApp(),
    ),
  );
  return auth;
}

void main() {
  testWidgets('login screen shows branding, inputs, and actions', (
    tester,
  ) async {
    await _pumpApp(tester);

    // The name is drawn as the stacked lockup now, not set as text.
    expect(find.byType(BrandLockup), findsOneWidget);
    expect(find.text('Your digital sales ledger'), findsOneWidget);
    expect(find.text('prosper@market.ng'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(
      find.textContaining('Create account', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('empty credentials are rejected with a toast', (tester) async {
    usePhoneSurface(tester);
    await _pumpApp(tester);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget); // still on login
  });

  testWidgets('signing in navigates to the dashboard with the trader name', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final auth = await _pumpApp(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'prosper@market.ng'),
      'amina@market.ng',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '••••••••'),
      'secret123',
    );
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isTrue);
    expect(find.text('Welcome back, Amina 👋'), findsOneWidget);
  });

  testWidgets('signing in attributes reports to the trader who signed in', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final reporter = RecordingErrorReporter();
    final auth = FakeAuthService(); // signed out, as a fresh launch is
    await tester.pumpWidget(
      AppScope(
        store: fixtureStore(),
        auth: auth,
        sync: NoopSyncEngine(),
        reporter: reporter,
        child: const ProsperFlowApp(),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'prosper@market.ng'),
      'amina@market.ng',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '••••••••'),
      'secret123',
    );
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    // Attribution used to happen only at bootstrap, so a phone that launched
    // signed out — every first run, and every run after a sign-out — reported
    // anonymously for the rest of the session however long the trader used it.
    expect(
      reporter.trader,
      auth.traderId,
      reason: 'sign-in is a path into the app, not a special case',
    );
  });

  testWidgets('a rejected password shows the auth error', (tester) async {
    usePhoneSurface(tester);
    await _pumpApp(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'prosper@market.ng'),
      'amina@market.ng',
    );
    await tester.enterText(find.widgetWithText(TextField, '••••••••'), 'nope');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(
      find.text('⚠ Password must be at least 6 characters'),
      findsOneWidget,
    );
    expect(find.text('Log In'), findsOneWidget); // still on login
  });

  testWidgets('create account signs up and lands on the dashboard', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final auth = await _pumpApp(tester);

    await tester.tap(find.textContaining('Create account', findRichText: true));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Prosper Adeyemi'),
      'Ngozi Bello',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'prosper@market.ng').last,
      'ngozi@market.ng',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '••••••••').last,
      'secret123',
    );
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isTrue);
    expect(find.text('Welcome back, Ngozi Bello 👋'), findsOneWidget);
  });

  testWidgets('signing out from the dashboard returns to login', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final auth = FakeAuthService(signedIn: true);
    await tester.pumpWidget(
      AppScope(
        store: fixtureStore(),
        auth: auth,
        sync: NoopSyncEngine(),
        reporter: const NoopErrorReporter(),
        child: const ProsperFlowApp(),
      ),
    );
    await tester.pump();

    // Signed-in session skips straight to the dashboard.
    expect(find.text('Welcome back, Prosper 👋'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.power_settings_new_rounded));
    await tester.pumpAndSettle();

    // Sign-out now asks to confirm first.
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isFalse);
    expect(find.text('Log In'), findsOneWidget);
  });
}
