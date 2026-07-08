import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/app.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/widgets/primary_button.dart';

import 'helpers.dart';

void main() {
  testWidgets('login screen shows branding, inputs, and actions',
      (tester) async {
    await tester.pumpWidget(
      AppScope(store: fixtureStore(), child: const ProsperFlowApp()),
    );

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

  testWidgets('logging in navigates to the dashboard', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      AppScope(store: fixtureStore(), child: const ProsperFlowApp()),
    );

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Prosper 👋'), findsOneWidget);
  });
}
