import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/credits/credits_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('credits list shows total banner and per-customer cards',
      (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const CreditsScreen());
    await tester.pump();

    expect(find.text('TOTAL OUTSTANDING'), findsOneWidget);
    // 18,400 + 30,000 + 21,000.
    expect(find.text('₦69,400'), findsOneWidget);

    expect(find.text('Chioma Ojo'), findsOneWidget);
    expect(find.text('Palm Oil (25L) × 2'), findsOneWidget);
    expect(find.text('₦18,400'), findsOneWidget);
    expect(find.text('Mark as Paid'), findsNWidgets(3));
  });

  testWidgets('mark as paid removes the card and updates the total',
      (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const CreditsScreen());
    await tester.pump();

    await tester.tap(find.text('Mark as Paid').first);
    await tester.pumpAndSettle();

    expect(find.text('Chioma Ojo'), findsNothing);
    // 69,400 − 18,400.
    expect(find.text('₦51,000'), findsOneWidget);
  });

  testWidgets('collecting every credit shows the empty state', (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const CreditsScreen());
    await tester.pump();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Mark as Paid').first);
      await tester.pumpAndSettle();
    }

    expect(find.text('All credits collected!'), findsOneWidget);
    expect(find.text('No customers owe you money.'), findsOneWidget);
    expect(find.text('TOTAL OUTSTANDING'), findsNothing);
  });
}
