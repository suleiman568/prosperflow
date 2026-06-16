import 'package:drift/drift.dart';

import 'database_connection.dart';

class AppDatabase extends GeneratedDatabase {
  AppDatabase() : super(openDatabaseConnection());

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (_) => _createSchema(),
      onUpgrade: (migrator, from, to) => _createSchema(),
      beforeOpen: (_) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> ensureInitialized() async {
    await customSelect('SELECT 1').getSingle();
  }

  Future<void> _createSchema() async {
    for (final statement in _schemaStatements) {
      await customStatement(statement);
    }
  }
}

const _metadataColumns = '''
  sync_status TEXT NOT NULL DEFAULT 'synced',
  is_deleted INTEGER NOT NULL DEFAULT 0,
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT
''';

const _schemaStatements = [
  '''
CREATE TABLE IF NOT EXISTS customers (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  company TEXT NOT NULL DEFAULT '',
  $_metadataColumns
)
''',
  '''
CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  name TEXT NOT NULL DEFAULT '',
  sku TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT '',
  cost_price REAL NOT NULL DEFAULT 0,
  selling_price REAL NOT NULL DEFAULT 0,
  stock_quantity INTEGER NOT NULL DEFAULT 0,
  reorder_level INTEGER NOT NULL DEFAULT 0,
  $_metadataColumns
)
''',
  '''
CREATE TABLE IF NOT EXISTS sales (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  customer_id TEXT NOT NULL DEFAULT '',
  product_id TEXT NOT NULL DEFAULT '',
  quantity INTEGER NOT NULL DEFAULT 0,
  unit_price REAL NOT NULL DEFAULT 0,
  total_amount REAL NOT NULL DEFAULT 0,
  payment_status TEXT NOT NULL DEFAULT 'pending',
  sale_date TEXT,
  $_metadataColumns
)
''',
  '''
CREATE TABLE IF NOT EXISTS expenses (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  title TEXT NOT NULL DEFAULT '',
  amount REAL NOT NULL DEFAULT 0,
  category TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  date TEXT,
  $_metadataColumns
)
''',
  '''
CREATE TABLE IF NOT EXISTS revenue (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  title TEXT NOT NULL DEFAULT '',
  amount REAL NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'received',
  date TEXT,
  $_metadataColumns
)
''',
  '''
CREATE TABLE IF NOT EXISTS cashflow (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  amount REAL NOT NULL DEFAULT 0,
  description TEXT NOT NULL DEFAULT '',
  $_metadataColumns
)
''',
  '''
CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  title TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'open',
  due_date TEXT,
  $_metadataColumns
)
''',
  '''
CREATE TABLE IF NOT EXISTS pending_sync (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,
  record_id TEXT NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('create', 'update', 'delete')),
  payload TEXT NOT NULL DEFAULT '{}',
  conflict_strategy TEXT NOT NULL DEFAULT 'latest_update_wins',
  attempt_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
)
''',
  '''
CREATE INDEX IF NOT EXISTS pending_sync_table_record_idx
ON pending_sync (table_name, record_id)
''',
  '''
CREATE INDEX IF NOT EXISTS pending_sync_created_at_idx
ON pending_sync (created_at)
''',
];
