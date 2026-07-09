import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/app.dart';
import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';
import 'package:prosperflow/src/widgets/primary_button.dart';

import 'helpers.dart';

Future<FakeAuthService> _pumpApp(WidgetTester tester) async {
  final auth = FakeAuthService(); // signed out
  await tester.pumpWidget(
    AppScope(store: fixtureStore(), auth: auth, sync: NoopSyncEngine(), child: const ProsperFlowApp()),
  );
  return auth;
}

void main() {
  testWidgets('login screen shows branding, inputs, and actions',
      (tester) async {
    await _pumpApp(tester);

    expect(find.text('ProsperFlow'), findsOneWidget);
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

  testWidgets('signing in navigates to the dashboard with the trader name',
      (tester) async {
    usePhoneSurface(tester);
    final auth = await _pumpApp(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'prosper@market.ng'),
        'amina@market.ng');
    await tester.enterText(
        find.widgetWithText(TextField, '••••••••'), 'secret123');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isTrue);
    expect(find.text('Welcome back, Amina 👋'), findsOneWidget);
  });

  testWidgets('a rejected password shows the auth error', (tester) async {
    usePhoneSurface(tester);
    await _pumpApp(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'prosper@market.ng'),
        'amina@market.ng');
    await tester.enterText(find.widgetWithText(TextField, '••••••••'), 'nope');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text('⚠ Password must be at least 6 characters'),
        findsOneWidget);
    expect(find.text('Log In'), findsOneWidget); // still on login
  });

  testWidgets('create account signs up and lands on the dashboard',
      (tester) async {
    usePhoneSurface(tester);
    final auth = await _pumpApp(tester);

    await tester.tap(find.textContaining('Create account', findRichText: true));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Prosper Adeyemi'), 'Ngozi Bello');
    await tester.enterText(
        find.widgetWithText(TextField, 'prosper@market.ng').last,
        'ngozi@market.ng');
    await tester.enterText(
        find.widgetWithText(TextField, '••••••••').last, 'secret123');
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isTrue);
    expect(find.text('Welcome back, Ngozi Bello 👋'), findsOneWidget);
  });

  testWidgets('signing out from the dashboard returns to login',
      (tester) async {
    usePhoneSurface(tester);
    final auth = FakeAuthService(signedIn: true);
    await tester.pumpWidget(
      AppScope(
          store: fixtureStore(),
          auth: auth,
          sync: NoopSyncEngine(),
          child: const ProsperFlowApp()),
    );
    await tester.pump();

    // Signed-in session skips straight to the dashboard.
    expect(find.text('Welcome back, Prosper 👋'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.power_settings_new_rounded));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isFalse);
    expect(find.text('Log In'), findsOneWidget);
  });
}
