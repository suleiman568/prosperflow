import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/app.dart';
import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';
import 'package:prosperflow/src/widgets/confirm_dialog.dart';
import 'package:prosperflow/src/telemetry/error_reporter.dart';

import 'helpers.dart';
import 'telemetry_test.dart' show RecordingErrorReporter;

void main() {
  testWidgets('sign-out can be cancelled and stays on the dashboard', (
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
    expect(find.text('Welcome back, Prosper 👋'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.power_settings_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);

    // Cancelling leaves the trader signed in on the dashboard.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isTrue);
    expect(find.text('Welcome back, Prosper 👋'), findsOneWidget);
  });

  testWidgets('signing out detaches the trader from any later report', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final auth = FakeAuthService(signedIn: true);
    final reporter = RecordingErrorReporter();
    await tester.pumpWidget(
      AppScope(
        store: fixtureStore(),
        auth: auth,
        sync: NoopSyncEngine(),
        reporter: reporter,
        child: const ProsperFlowApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.power_settings_new_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isFalse);
    // Between sign-out and the next sign-in, anything this phone reports would
    // otherwise still carry the id of the trader who just left. A market phone
    // gets handed over; this is the moment it happens.
    expect(
      reporter.traderWrites,
      contains(null),
      reason: 'sign-out must clear the trader, not wait for the next sign-in',
    );
    expect(reporter.trader, isNull);
  });

  testWidgets('confirmDialog returns true on confirm and false on cancel', (
    tester,
  ) async {
    Future<bool>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => result = confirmDialog(
                context,
                title: 'Sign out?',
                message: "You'll need to sign in again.",
                confirmLabel: 'Sign out',
                destructive: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });
}
