import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the on-device SQLite database (Android/iOS/desktop).
/// The web build uses [MemoryStore] instead — see main.dart.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'prosperflow.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
