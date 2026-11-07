import 'package:flutter/material.dart' show DateTimeRange;

import '../../utils/dates.dart';
import '../habit_streak.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../repositories/habit_repository.dart';
import 'fake_store.dart';

class FakeHabitRepository implements HabitRepository {
  FakeHabitRepository(this._store);

  final FakeStore _store;

  @override
  Stream<List<Habit>> watchActive() => _store.watch(
    () => List.unmodifiable(_store.habits.values.where((h) => !h.archived)),
  );

  @override
  Stream<List<Habit>> watchArchived() => _store.watch(() {
    final archived = _store.habits.values.where((h) => h.archived).toList()
      ..sort((a, b) => b.archivedAt!.compareTo(a.archivedAt!));
    return List<Habit>.unmodifiable(archived);
  });

  @override
  Future<Habit?> getById(String id) async => _store.habits[id];

  @override
  Stream<Habit?> watchById(String id) => _store.watch(() => _store.habits[id]);

  @override
  Future<void> add(Habit habit) async {
    if (_store.habits.containsKey(habit.id)) {
      throw StateError('Thói quen ${habit.id} đã tồn tại');
    }
    _check(habit);
    _store.habits[habit.id] = habit;
    _store.notifyChanged();
  }

  @override
  Future<void> update(Habit habit) async {
    final stored = _store.habits[habit.id];
    if (stored == null) return;
    _check(habit);
    _store.habits[habit.id] = habit.copyWith(
      archivedAt: () => stored.archivedAt,
    );
    _store.notifyChanged();
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    final habit = _store.habits[id];
    if (habit == null || habit.archived == archived) return;
    _store.habits[id] = habit.copyWith(
      archivedAt: () => archived ? _store.clock() : null,
    );
    _store.notifyChanged();
  }

  @override
  Future<void> delete(String id) async {
    if (_store.habits.remove(id) == null) return;
    _store.habitLogs.removeWhere((_, log) => log.habitId == id);
    _store.notifyChanged();
  }

  @override
  Stream<Map<String, int>> watchCountsOn(DateTime day) => _store.watch(() {
    final key = dateKey(day);
    return Map<String, int>.unmodifiable({
      for (final log in _store.habitLogs.values)
        if (dateKey(log.date) == key) log.habitId: log.count,
    });
  });

  @override
  Future<List<HabitLog>> logsByRange(
    String habitId,
    DateTimeRange range,
  ) async =>
      _store.habitLogs.values
          .where((l) => l.habitId == habitId && rangeContains(range, l.date))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<void> setCount(String habitId, DateTime day, int count) async {
    if (!_store.habits.containsKey(habitId)) {
      throw ArgumentError.value(habitId, 'habitId', 'Thói quen không tồn tại');
    }
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'Số lần không được âm');
    }
    final date = startOfDay(day);
    final key = habitLogKey(habitId, date);
    if (count == 0) {
      _store.habitLogs.remove(key);
    } else {
      _store.habitLogs[key] = HabitLog(
        habitId: habitId,
        date: date,
        count: count,
      );
    }
    _store.notifyChanged();
  }

  @override
  Future<int> increment(String habitId, DateTime day) async {
    final count = (_store.habitLogs[habitLogKey(habitId, day)]?.count ?? 0) + 1;
    await setCount(habitId, day, count);
    return count;
  }

  @override
  Future<int> streakOf(String habitId, {DateTime? today}) async =>
      _streaks(habitId, today ?? _store.clock()).current;

  @override
  Future<int> bestStreakOf(String habitId) async =>
      _streaks(habitId, _store.clock()).best;

  ({int current, int best}) _streaks(String habitId, DateTime today) {
    final habit = _store.habits[habitId];
    if (habit == null) return (current: 0, best: 0);
    final counts = {
      for (final log in _store.habitLogs.values)
        if (log.habitId == habitId) dateKey(log.date): log.count,
    };
    return habitStreaks(habit, counts, today);
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
