import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/export/share_export.dart';
import 'package:prosperflow/src/screens/reports/reports_screen.dart';

import 'helpers.dart';

void main() {
  tearDown(() => debugExportHandler = null);

  testWidgets('export shows a spinner and blocks a second export until done', (
    tester,
  ) async {
    usePhoneSurface(tester);

    // Hold the share step open so we can observe the in-progress state.
    final gate = Completer<void>();
    var shares = 0;
    debugExportHandler = (bytes, filename, mimeType) async {
      shares++;
      await gate.future;
    };

    await pumpWithStore(tester, const ReportsScreen());
    await tester.pump();

    IconButton exportButton() =>
        tester.widget<IconButton>(find.byType(IconButton));
    expect(exportButton().onPressed, isNotNull); // enabled at rest

    // Kick off a CSV export; it hangs at the share step.
    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSV spreadsheet'));
    await tester.pump(); // start the sheet-close + export
    // Fixed-duration pumps (not pumpAndSettle — the spinner never settles) to
    // let the bottom sheet finish closing.
    await tester.pump(const Duration(milliseconds: 500));

    // In progress: spinner shown, button disabled, share started exactly once.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(exportButton().onPressed, isNull);
    expect(shares, 1);

    // A tap while busy can't open the export sheet again.
    await tester.tap(find.byType(IconButton), warnIfMissed: false);
    await tester.pump();
    expect(find.text('CSV spreadsheet'), findsNothing);
    expect(shares, 1);

    // Finishing the share clears the busy state and shows the success toast.
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(exportButton().onPressed, isNotNull);
    expect(find.textContaining('report exported'), findsOneWidget);
    expect(shares, 1);
  });
}
