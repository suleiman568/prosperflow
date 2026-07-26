import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/app.dart';
import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';
import 'package:prosperflow/src/widgets/confirm_dialog.dart';

import 'helpers.dart';

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
