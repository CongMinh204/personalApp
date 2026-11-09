import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/focus_session.dart';

/// Nơi lưu các phiên tập trung (bảng FocusSession trong ERD).
abstract class FocusSessionRepository {
  Future<void> insert(FocusSession session);

  /// Các phiên bắt đầu từ [from] trở đi, mới nhất trước.
  Future<List<FocusSession>> getSince(DateTime from);
}

/// Mở repository phù hợp với nền tảng đang chạy:
/// SQLite trên Android / iOS / macOS, bộ nhớ tạm trên web và Windows / Linux
/// (sqflite không chạy ở đó nếu chưa cài thêm sqflite_common_ffi).
Future<FocusSessionRepository> openFocusSessionRepository() async {
  final sqliteOk =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
  if (!sqliteOk) return InMemoryFocusSessionRepository();
  return SqliteFocusSessionRepository.open();
}

/// Mở database ở lần dùng đầu tiên, nên không cần await trong main().
class LazyFocusSessionRepository implements FocusSessionRepository {
  LazyFocusSessionRepository([
    Future<FocusSessionRepository> Function()? opener,
  ]) : _opener = opener ?? openFocusSessionRepository;

  final Future<FocusSessionRepository> Function() _opener;
  Future<FocusSessionRepository>? _inner;

  Future<FocusSessionRepository> get _repo => _inner ??= _opener();

  @override
  Future<void> insert(FocusSession session) async {
    final repo = await _repo;
    await repo.insert(session);
  }

  @override
  Future<List<FocusSession>> getSince(DateTime from) async {
    final repo = await _repo;
    return repo.getSince(from);
  }
}

class SqliteFocusSessionRepository implements FocusSessionRepository {
  SqliteFocusSessionRepository._(this._db);

  final Database _db;

  static Future<SqliteFocusSessionRepository> open() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'focus_sessions.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
CREATE TABLE FocusSession (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  taskId TEXT,
  taskTitle TEXT,
  type TEXT NOT NULL,
  startedAt INTEGER NOT NULL,
  durationSec INTEGER NOT NULL,
  completed INTEGER NOT NULL DEFAULT 0
)''');
        await db.execute(
          'CREATE INDEX idx_focus_started ON FocusSession(startedAt)',
        );
      },
    );
    return SqliteFocusSessionRepository._(db);
  }

  @override
  Future<void> insert(FocusSession session) async {
    await _db.insert('FocusSession', session.toMap()..remove('id'));
  }

  @override
  Future<List<FocusSession>> getSince(DateTime from) async {
    final rows = await _db.query(
      'FocusSession',
      where: 'startedAt >= ?',
      whereArgs: [from.millisecondsSinceEpoch],
      orderBy: 'startedAt DESC',
    );
    return rows.map(FocusSession.fromMap).toList();
  }
}

/// Dùng khi chưa có SQLite (web, desktop) và trong test. Tắt app là mất.
class InMemoryFocusSessionRepository implements FocusSessionRepository {
  final List<FocusSession> items = [];

  @override
  Future<void> insert(FocusSession session) async => items.add(session);

  @override
  Future<List<FocusSession>> getSince(DateTime from) async {
    final out = items.where((s) => !s.startedAt.isBefore(from)).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return out;
  }
}
