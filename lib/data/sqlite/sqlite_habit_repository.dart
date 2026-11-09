import 'package:flutter/material.dart' show DateTimeRange;
import 'package:sqflite/sqflite.dart';

import '../../utils/dates.dart';
import '../habit_streak.dart';
import '../models/db_values.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../repositories/habit_repository.dart';
import 'app_database.dart';

class SqliteHabitRepository implements HabitRepository {
  SqliteHabitRepository(this._app);

  final AppDatabase _app;

  Database get _db => _app.db;

  @override
  Stream<List<Habit>> watchActive() => _app.changes.watch(() async {
    final rows = await _db.query(
      'habits',
      where: 'archived_at IS NULL',
      orderBy: 'rowid',
    );
    return List<Habit>.unmodifiable(rows.map(Habit.fromMap));
  });

  @override
  Stream<List<Habit>> watchArchived() => _app.changes.watch(() async {
    final rows = await _db.query(
      'habits',
      where: 'archived_at IS NOT NULL',
      orderBy: 'archived_at DESC, rowid',
    );
    return List<Habit>.unmodifiable(rows.map(Habit.fromMap));
  });

  @override
  Future<Habit?> getById(String id) async {
    final rows = await _db.query('habits', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Habit.fromMap(rows.first);
  }

  @override
  Stream<Habit?> watchById(String id) => _app.changes.watch(() => getById(id));

  @override
  Future<void> add(Habit habit) async {
    _check(habit);
    await _db.transaction((txn) async {
      final existing = await txn.query(
        'habits',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [habit.id],
      );
      if (existing.isNotEmpty) {
        throw StateError('Thói quen ${habit.id} đã tồn tại');
      }
      await txn.insert('habits', habit.toMap());
    });
    _app.changes.notify();
  }

  @override
  Future<void> update(Habit habit) async {
    _check(habit);
    // archived_at chỉ đổi bằng setArchived.
    final values = habit.toMap()
      ..remove('id')
      ..remove('archived_at');
    final updated = await _db.update(
      'habits',
      values,
      where: 'id = ?',
      whereArgs: [habit.id],
    );
    if (updated > 0) _app.changes.notify();
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    final updated = await _db.update(
      'habits',
      {'archived_at': archived ? encodeTime(_app.clock()) : null},
      where: archived
          ? 'id = ? AND archived_at IS NULL'
          : 'id = ? AND archived_at IS NOT NULL',
      whereArgs: [id],
    );
    if (updated > 0) _app.changes.notify();
  }

  @override
  Future<void> delete(String id) async {
    // Khóa ngoại: nhật ký bị xóa theo.
    final deleted = await _db.delete(
      'habits',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (deleted > 0) _app.changes.notify();
  }

  @override
  Stream<Map<String, int>> watchCountsOn(DateTime day) => _app.changes.watch(
    () async {
      final rows = await _db.query(
        'habit_logs',
        where: 'date = ?',
        whereArgs: [dateKey(day)],
      );
      return Map<String, int>.unmodifiable({
        for (final row in rows) row['habit_id'] as String: row['count'] as int,
      });
    },
  );

  @override
  Future<List<HabitLog>> logsByRange(
    String habitId,
    DateTimeRange range,
  ) async {
    final rows = await _db.query(
      'habit_logs',
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'date',
    );
    return [
      for (final log in rows.map(HabitLog.fromMap))
        if (rangeContains(range, log.date)) log,
    ];
  }

  @override
  Future<void> setCount(String habitId, DateTime day, int count) async {
    await _db.transaction((txn) => _setCount(txn, habitId, day, count));
    _app.changes.notify();
  }

  @override
  Future<int> increment(String habitId, DateTime day) async {
    final next = await _db.transaction((txn) async {
      final current = await _countOf(txn, habitId, day);
      final next = current + 1;
      await _setCount(txn, habitId, day, next);
      return next;
    });
    _app.changes.notify();
    return next;
  }

  @override
  Future<int> streakOf(String habitId, {DateTime? today}) async =>
      (await _streaks(habitId, today ?? _app.clock())).current;

  @override
  Future<int> bestStreakOf(String habitId) async =>
      (await _streaks(habitId, _app.clock())).best;

  Future<({int current, int best})> _streaks(
    String habitId,
    DateTime today,
  ) async {
    final habit = await getById(habitId);
    if (habit == null) return (current: 0, best: 0);
    final rows = await _db.query(
      'habit_logs',
      where: 'habit_id = ?',
      whereArgs: [habitId],
    );
    final counts = {
      for (final row in rows) row['date'] as String: row['count'] as int,
    };
    return habitStreaks(habit, counts, today);
  }

  Future<int> _countOf(
    DatabaseExecutor db,
    String habitId,
    DateTime day,
  ) async {
    final rows = await db.query(
      'habit_logs',
      columns: ['count'],
      where: 'habit_id = ? AND date = ?',
      whereArgs: [habitId, dateKey(day)],
    );
    return rows.isEmpty ? 0 : rows.first['count'] as int;
  }

  Future<void> _setCount(
    DatabaseExecutor db,
    String habitId,
    DateTime day,
    int count,
  ) async {
    final habit = await db.query(
      'habits',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [habitId],
    );
    if (habit.isEmpty) {
      throw ArgumentError.value(habitId, 'habitId', 'Thói quen không tồn tại');
    }
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'Số lần không được âm');
    }
    final date = startOfDay(day);
    if (count == 0) {
      await db.delete(
        'habit_logs',
        where: 'habit_id = ? AND date = ?',
        whereArgs: [habitId, dateKey(date)],
      );
    } else {
      await db.insert(
        'habit_logs',
        HabitLog(habitId: habitId, date: date, count: count).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  void _check(Habit habit) {
    if (habit.name.trim().isEmpty) {
      throw ArgumentError.value(
        habit.name,
        'name',
        'Tên thói quen không được trống',
      );
    }
    if (habit.goalPerDay < 1) {
      throw ArgumentError.value(
        habit.goalPerDay,
        'goalPerDay',
        'Mục tiêu mỗi ngày phải từ 1 trở lên',
      );
    }
    if (habit.repeatDays.isEmpty ||
        habit.repeatDays.any((d) => d < 1 || d > 7)) {
      throw ArgumentError.value(
        habit.repeatDays,
        'repeatDays',
        'Ngày lặp phải nằm trong 1–7 và không được rỗng',
      );
    }
  }
}
