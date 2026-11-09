import 'package:flutter/material.dart' show DateTimeRange;
import 'package:sqflite/sqflite.dart';

import '../models/db_values.dart';
import '../models/focus_session.dart';
import '../repositories/focus_repository.dart';
import 'app_database.dart';

class SqliteFocusRepository implements FocusRepository {
  SqliteFocusRepository(this._app);

  final AppDatabase _app;

  Database get _db => _app.db;

  @override
  Future<void> add(FocusSession session) async {
    await _db.transaction((txn) async {
      final taskId = session.taskId;
      if (taskId != null) {
        final task = await txn.query(
          'tasks',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [taskId],
        );
        if (task.isEmpty) {
          throw ArgumentError.value(taskId, 'taskId', 'Việc không tồn tại');
        }
      }
      final existing = await txn.query(
        'focus_sessions',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [session.id],
      );
      if (existing.isNotEmpty) {
        throw StateError('Phiên ${session.id} đã tồn tại');
      }
      await txn.insert('focus_sessions', session.toMap());
    });
    _app.changes.notify();
  }

  @override
  Future<List<FocusSession>> sessionsByRange(DateTimeRange range) async {
    final rows = await _db.query(
      'focus_sessions',
      where: 'started_at >= ? AND started_at < ?',
      whereArgs: [encodeTime(range.start), encodeTime(range.end)],
      orderBy: 'started_at DESC, rowid ASC',
    );
    return List.unmodifiable(rows.map(FocusSession.fromMap));
  }

  @override
  Stream<List<FocusSession>> watchByRange(DateTimeRange range) =>
      _app.changes.watch(() => sessionsByRange(range));

  @override
  Future<FocusTotal> totalForTask(String taskId) async {
    final focusCodes = [
      for (final type in FocusType.values)
        if (type.isFocus) type.code,
    ];
    final rows = await _db.rawQuery(
      '''
SELECT COALESCE(SUM(duration_sec), 0) AS seconds, COUNT(*) AS sessions
FROM focus_sessions
WHERE task_id = ? AND type IN (${List.filled(focusCodes.length, '?').join(',')})''',
      [taskId, ...focusCodes],
    );
    return FocusTotal(
      seconds: rows.first['seconds'] as int,
      sessions: rows.first['sessions'] as int,
    );
  }

  @override
  Future<void> delete(String id) async {
    final deleted = await _db.delete(
      'focus_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (deleted > 0) _app.changes.notify();
  }
}
