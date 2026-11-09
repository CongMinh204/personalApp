import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../default_tags.dart';
import 'db_changes.dart';

/// Database SQLite của app: tạo bảng, bật khóa ngoại, thêm 4 nhãn mặc định.
/// Cấu trúc bảng: docs/DATA_CONTRACT.md, mục 3.
class AppDatabase {
  AppDatabase._(this.db, this.changes, this.clock);

  final Database db;

  /// Tín hiệu báo thay đổi dùng chung cho 4 repository.
  final DbChanges changes;

  /// Giờ hiện tại, dùng khi đặt `completed_at`, `archived_at`.
  final DateTime Function() clock;

  /// Phiên bản cấu trúc bảng. Tăng khi đổi bảng và thêm bước vào [_migrations].
  static const version = 1;

  static const fileName = 'personal_app.db';

  /// Mở database. Mặc định là file [fileName] trong thư mục database của app.
  /// Test truyền [path] (hoặc `inMemoryDatabasePath`) và [factory] của ffi.
  static Future<AppDatabase> open({
    String? path,
    DatabaseFactory? factory,
    DateTime Function()? clock,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), fileName);
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        // Mỗi database trong bộ nhớ là một bản riêng, không dùng chung.
        singleInstance: dbPath != inMemoryDatabasePath,
        // Khóa ngoại của SQLite mặc định tắt, phải bật cho từng kết nối.
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );
    return AppDatabase._(db, DbChanges(), clock ?? DateTime.now);
  }

  Future<void> close() async {
    await changes.close();
    await db.close();
  }

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch();
    for (final statement in _createStatements) {
      batch.execute(statement);
    }
    for (final tag in defaultTags) {
      batch.insert('tags', tag.toMap());
    }
    await batch.commit(noResult: true);
  }

  /// Nâng cấp từ bản cũ: chạy lần lượt các bước của mỗi bản sau [oldVersion].
  /// Khi đổi bảng: tăng [version] và thêm bước vào [_migrations].
  static Future<void> _upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (var v = oldVersion + 1; v <= newVersion; v++) {
      final migrate = _migrations[v];
      if (migrate == null) {
        throw StateError('Thiếu bước nâng cấp database lên bản $v');
      }
      await migrate(db);
    }
  }

  static final _migrations = <int, Future<void> Function(Database db)>{};
}

const _createStatements = [
  '''
CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  color TEXT NOT NULL
)''',
  '''
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  tag_id TEXT REFERENCES tags(id) ON DELETE SET NULL,
  due_at INTEGER,
  end_at INTEGER,
  has_time INTEGER NOT NULL DEFAULT 0,
  priority INTEGER NOT NULL DEFAULT 1,
  done INTEGER NOT NULL DEFAULT 0,
  completed_at INTEGER,
  reminder_minutes INTEGER,
  repeat_rule TEXT NOT NULL DEFAULT 'none',
  created_at INTEGER NOT NULL
)''',
  '''
CREATE TABLE subtasks (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  done INTEGER NOT NULL DEFAULT 0
)''',
  '''
CREATE TABLE focus_sessions (
  id TEXT PRIMARY KEY,
  task_id TEXT REFERENCES tasks(id) ON DELETE SET NULL,
  type TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  duration_sec INTEGER NOT NULL,
  completed INTEGER NOT NULL DEFAULT 0
)''',
  '''
CREATE TABLE habits (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  color INTEGER NOT NULL,
  repeat_days TEXT NOT NULL,
  goal_per_day INTEGER NOT NULL DEFAULT 1,
  unit TEXT NOT NULL DEFAULT '',
  reminder_time INTEGER,
  start_date TEXT NOT NULL,
  archived_at INTEGER
)''',
  '''
CREATE TABLE habit_logs (
  habit_id TEXT NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  count INTEGER NOT NULL,
  PRIMARY KEY (habit_id, date)
)''',
  'CREATE INDEX idx_tasks_due_at ON tasks(due_at)',
  'CREATE INDEX idx_tasks_tag_id ON tasks(tag_id)',
  'CREATE INDEX idx_tasks_completed_at ON tasks(completed_at)',
  'CREATE INDEX idx_subtasks_task_id ON subtasks(task_id)',
  'CREATE INDEX idx_focus_sessions_started_at ON focus_sessions(started_at)',
  'CREATE INDEX idx_focus_sessions_task_id ON focus_sessions(task_id)',
];
