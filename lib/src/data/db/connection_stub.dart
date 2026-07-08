import 'package:drift/drift.dart';

/// Web stub — never called; the web build uses MemoryStore (see main.dart).
QueryExecutor openConnection() =>
    throw UnsupportedError('SQLite is not used on the web build');
