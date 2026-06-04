import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prosperflow/src/app/prosper_flow_app.dart';

void main() {
  testWidgets('shows ProsperFlow login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ProsperFlowApp()));

    expect(find.text('ProsperFlow'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
