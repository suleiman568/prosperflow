import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/credits/credits_screen.dart';
import 'package:prosperflow/src/screens/products/products_screen.dart';
import 'package:prosperflow/src/screens/record_sale/record_sale_screen.dart';
import 'package:prosperflow/src/utils/haptics.dart';

import 'helpers.dart';

/// Records the feedback type of every `HapticFeedback.vibrate` platform call
/// (e.g. 'HapticFeedbackType.mediumImpact'). Returns the growing log.
List<String?> _captureHaptics(WidgetTester tester) {
  final log = <String?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        log.add(call.arguments as String?);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return log;
}

void main() {
  testWidgets('AppHaptics maps each intent to its platform feedback', (
    tester,
  ) async {
    final log = _captureHaptics(tester);

    AppHaptics.success();
    AppHaptics.selection();
    AppHaptics.warning();
    await tester.pump();

    expect(log, const [
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.heavyImpact',
    ]);
  });

  testWidgets('quantity steppers give selection feedback', (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const RecordSaleScreen());
    await tester.pump();
    final log = _captureHaptics(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(log, contains('HapticFeedbackType.selectionClick'));
  });

  testWidgets('collecting a credit gives success feedback', (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const CreditsScreen(), store: fixtureStore());
    await tester.pump();
    final log = _captureHaptics(tester);

    await tester.tap(find.text('Mark as Paid').first);
    await tester.pumpAndSettle();

    expect(log, contains('HapticFeedbackType.mediumImpact'));
  });

  testWidgets('deleting a product gives the heavier warning feedback', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const ProductsScreen(), store: fixtureStore());
    await tester.pump();
    final log = _captureHaptics(tester);

    await tester.drag(find.text('Palm Oil (25L)'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(log, contains('HapticFeedbackType.heavyImpact'));
  });
}
