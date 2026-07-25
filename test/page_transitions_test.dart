import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/app.dart';
import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';
import 'package:prosperflow/src/theme/page_transitions.dart';

import 'helpers.dart';

void main() {
  testWidgets('the app registers the custom transition for every platform', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppScope(
        store: fixtureStore(),
        auth: FakeAuthService(signedIn: true),
        sync: NoopSyncEngine(),
        child: const ProsperFlowApp(),
      ),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final builders = app.theme!.pageTransitionsTheme.builders;
    for (final platform in TargetPlatform.values) {
      expect(
        builders[platform],
        isA<AppPageTransitionsBuilder>(),
        reason: '$platform',
      );
    }
  });

  testWidgets('the incoming page fades and slides in during navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(pageTransitionsTheme: appPageTransitionsTheme),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const Scaffold(body: Center(child: Text('page two'))),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump(); // kick off the transition
    await tester.pump(const Duration(milliseconds: 150)); // mid-flight

    // The only transitions theme is ours, so the animating page is wrapped in
    // our FadeTransition (partway) and SlideTransition (still offset).
    final fades = tester.widgetList<FadeTransition>(
      find.byType(FadeTransition),
    );
    expect(
      fades.any((f) => f.opacity.value > 0 && f.opacity.value < 1),
      isTrue,
      reason: 'incoming page should be mid-fade',
    );
    final slides = tester.widgetList<SlideTransition>(
      find.byType(SlideTransition),
    );
    expect(
      slides.any((s) => s.position.value != Offset.zero),
      isTrue,
      reason: 'incoming page should still be sliding',
    );

    await tester.pumpAndSettle();
    expect(find.text('page two'), findsOneWidget);
  });
}
