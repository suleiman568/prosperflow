import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/data_store.dart';
import 'package:prosperflow/src/data/db/app_database.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/sync/sync_backend.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';

import 'helpers.dart';

class _NoopBackend implements SyncBackend {
  @override
  bool get canPush => false;

  @override
  Future<void> apply(String e, String o, Map<String, dynamic> p) async {}
}

/// Every watch stream the app exposes must survive being listened to more
/// than once — a second listener on a single-subscription stream throws
/// "Bad state: Stream has already been listened to" and red-screens the app.
void main() {
  test('MemoryStore watch streams accept multiple simultaneous listeners',
      () async {
    final store = fixtureStore();
    final stream = store.watchExpenses();

    final a = <List<Expense>>[];
    final b = <List<Expense>>[];
    final subA = stream.listen(a.add);
    final subB = stream.listen(b.add);
    await pumpEventQueue();

    // Both listeners got the initial snapshot.
    expect(a.single, hasLength(5));
    expect(b.single, hasLength(5));

    // Both listeners see subsequent changes.
    await store.addExpense(
      description: 'Second listener check',
      amount: 700,
      category: ExpenseCategory.other,
      spentOn: DateTime.now(),
    );
    await pumpEventQueue();
    expect(a.last, hasLength(6));
    expect(b.last, hasLength(6));

    // Cancelling one listener leaves the other working.
    await subA.cancel();
    await store.deleteExpense(a.last.first.id);
    await pumpEventQueue();
    expect(b.last, hasLength(5));
    await subB.cancel();

    // A cancelled-and-re-listened stream also works (the crash scenario).
    final again = <List<Expense>>[];
    final subC = stream.listen(again.add);
    await pumpEventQueue();
    expect(again.single, hasLength(5));
    await subC.cancel();
  });

  test('watchReport tolerates re-listening across period switches', () async {
    final store = fixtureStore();
    final stream = store.watchReport(ReportPeriod.week);

    final first = await stream.first;
    final second = await stream.first; // second listen on the same instance
    expect(second.expensesTotal, first.expensesTotal);
  });

  testWidgets(
      're-inflated StreamBuilder re-listens to the same stream instance '
      'without crashing (the _SelectionKeepAlive / reparent scenario)',
      (tester) async {
    final store = fixtureStore();

    // Built once — like a ListView child from an earlier frame that
    // _SelectionKeepAlive (or a GlobalKey move) later re-inflates.
    final child = StreamBuilder<List<Product>>(
      stream: store.watchProducts(),
      builder: (_, snapshot) => Text('${snapshot.data?.length ?? '-'}',
          textDirection: TextDirection.ltr),
    );

    await tester.pumpWidget(Center(child: child));
    await tester.pump();
    expect(find.text('4'), findsOneWidget);

    // Swapping the parent type destroys the old element and inflates the
    // SAME widget again: a fresh StreamBuilder state calls initState and
    // listens to the already-listened stream instance. Before
    // MultiListenStream this threw "Stream has already been listened to".
    await tester.pumpWidget(
        Padding(padding: EdgeInsets.zero, child: child));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('4'), findsOneWidget);
  });

  test('NoopSyncEngine.watchState accepts multiple listeners', () async {
    final sync = NoopSyncEngine(lastSyncAt: DateTime.now());
    final stream = sync.watchState();
    final a = await stream.first;
    final b = await stream.first;
    expect(a.online, isTrue);
    expect(b.pendingTotal, 0);
  });

  test('DriftSyncEngine.watchState accepts multiple listeners', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final connectivity = StreamController<bool>.broadcast();
    final engine = DriftSyncEngine(
      db,
      _NoopBackend(),
      connectivity: connectivity.stream,
      initiallyOnline: false,
    );

    final stream = engine.watchState();
    final seenA = <SyncState>[];
    final seenB = <SyncState>[];
    final subA = stream.listen(seenA.add);
    final subB = stream.listen(seenB.add);
    await pumpEventQueue();

    expect(seenA.first.online, isFalse);
    expect(seenB.first.online, isFalse);

    connectivity.add(true);
    await pumpEventQueue();
    expect(seenA.last.online, isTrue);
    expect(seenB.last.online, isTrue);

    await subA.cancel();
    await subB.cancel();
    engine.dispose();
    await connectivity.close();
    await db.close();
  });
}
