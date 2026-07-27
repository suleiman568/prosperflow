import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/screens/login/login_screen.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';

import 'helpers.dart';

Future<void> _pumpLogin(WidgetTester tester) async {
  usePhoneSurface(tester);
  await tester.pumpWidget(
    AppScope(
      store: fixtureStore(),
      auth: FakeAuthService(), // signed out
      sync: NoopSyncEngine(),
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  await tester.pump();
}

bool _obscured(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).obscureText;

void main() {
  testWidgets('the login password field is hidden until the eye is tapped', (
    tester,
  ) async {
    await _pumpLogin(tester);

    final field = find.widgetWithText(TextField, '••••••••');
    expect(_obscured(tester, field), isTrue); // hidden by default
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    // Reveal.
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(_obscured(tester, field), isFalse);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    // Hide again.
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(_obscured(tester, field), isTrue);
  });

  testWidgets('the reveal toggle does not clear what was typed', (
    tester,
  ) async {
    await _pumpLogin(tester);

    final field = find.widgetWithText(TextField, '••••••••');
    await tester.enterText(field, 'secret123');
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(_obscured(tester, field), isFalse);
    expect(find.text('secret123'), findsOneWidget);
  });

  testWidgets('the create-account password has its own reveal toggle', (
    tester,
  ) async {
    await _pumpLogin(tester);

    await tester.tap(find.textContaining('Create account', findRichText: true));
    await tester.pumpAndSettle();

    // The sheet's password field is the second one on screen.
    final field = find.widgetWithText(TextField, '••••••••').last;
    expect(_obscured(tester, field), isTrue);

    await tester.tap(find.byIcon(Icons.visibility_outlined).last);
    await tester.pump();
    expect(_obscured(tester, field), isFalse);
  });
}
