import 'package:flutter/material.dart' show DateTimeRange;

import '../../utils/dates.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';
import 'fake_store.dart';

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository(this._store);

  final FakeStore _store;

  @override
  Stream<List<Task>> watchAll() =>
      _store.watch(() => List.unmodifiable(_all()));

  @override
  Future<List<Task>> getAll() async => _all();

  @override
  Stream<List<Task>> watchByDay(DateTime day) => watchByRange(dayRange(day));

  @override
  Stream<List<Task>> watchByRange(DateTimeRange range) => _store.watch(
    () => List.unmodifiable(
      _sorted(
        _all().where((t) {
          final due = t.due;
          return due != null && rangeContains(range, due);
        }),
      ),
    ),
  );

  @override
  Future<List<Task>> getUnfinished() async =>
      _sorted(_all().where((t) => !t.done));

  @override
  Future<Task?> getById(String id) async => _read(id);

  @override
  Stream<Task?> watchById(String id) => _store.watch(() => _read(id));

  @override
  Future<List<Task>> search(String query) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return [];
    bool matches(Task t) {
      final tagName = _store.tags[t.tagId]?.name ?? '';
      return t.title.toLowerCase().contains(needle) ||
          t.note.toLowerCase().contains(needle) ||
          tagName.toLowerCase().contains(needle);
    }

    return _sorted(_all().where(matches));
  }

  @override
  Future<Map<DateTime, int>> countDoneByDay(DateTimeRange range) async {
    final counts = <DateTime, int>{};
    for (
      var day = startOfDay(range.start);
      day.isBefore(range.end);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      counts[day] = 0;
    }
    for (final task in await getCompletedInRange(range)) {
      final day = startOfDay(task.completedAt!);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<List<Task>> getCompletedInRange(DateTimeRange range) async {
    final completed = _all().where((t) {
      final at = t.completedAt;
      return t.done && at != null && rangeContains(range, at);
    }).toList();
    completed.sort((a, b) => a.completedAt!.compareTo(b.completedAt!));
    return completed;
  }

  @override
  Future<void> add(Task task, {List<Subtask> subtasks = const []}) async {
    if (_store.tasks.containsKey(task.id)) {
      throw StateError('Việc ${task.id} đã tồn tại');
    }
    _check(task, subtasks);
    _store.tasks[task.id] = task;
    _replaceSubtasks(task.id, subtasks);
    _store.notifyChanged();
  }

  @override
  Future<void> update(Task task, {List<Subtask>? subtasks}) async {
    final stored = _store.tasks[task.id];
    if (stored == null) return;
    _check(task, subtasks ?? const []);
    _store.tasks[task.id] = task.copyWith(
      done: stored.done,
      completedAt: () => stored.completedAt,
    );
    if (subtasks != null) _replaceSubtasks(task.id, subtasks);
    _store.notifyChanged();
  }

  @override
  Future<void> setDone(String id, bool done) async {
    final task = _store.tasks[id];
    if (task == null || task.done == done) return;
    _store.tasks[id] = task.copyWith(
      done: done,
      completedAt: () => done ? _store.clock() : null,
    );
    _store.notifyChanged();
  }

  @override
  Future<void> delete(String id) async {
    if (_store.tasks.remove(id) == null) return;
    _removeRelations({id});
    _store.notifyChanged();
  }

  @override
  Future<int> deleteCompleted() async {
    final ids = {
      for (final t in _store.tasks.values)
        if (t.done) t.id,
    };
    if (ids.isEmpty) return 0;
    _store.tasks.removeWhere((id, _) => ids.contains(id));
    _removeRelations(ids);
    _store.notifyChanged();
    return ids.length;
  }

  @override
  Future<List<Subtask>> getSubtasks(String taskId) async => _subtasksOf(taskId);

  @override
  Stream<List<Subtask>> watchSubtasks(String taskId) =>
      _store.watch(() => List.unmodifiable(_subtasksOf(taskId)));

  @override
  Future<void> setSubtaskDone(String subtaskId, bool done) async {
    final subtask = _store.subtasks[subtaskId];
    if (subtask == null || subtask.done == done) return;
    _store.subtasks[subtaskId] = subtask.copyWith(done: done);
    _store.notifyChanged();
  }

  /// Việc kèm số việc con, như khi đọc từ database.
  Task? _read(String id) {
    final task = _store.tasks[id];
    return task == null ? null : _withCounts(task);
  }

  List<Task> _all() => [for (final t in _store.tasks.values) _withCounts(t)];

  Task _withCounts(Task task) {
    var done = 0;
    var total = 0;
    for (final subtask in _store.subtasks.values) {
      if (subtask.taskId != task.id) continue;
      total++;
      if (subtask.done) done++;
    }
    return task.copyWith(subtaskDone: done, subtaskTotal: total);
  }

  List<Subtask> _subtasksOf(String taskId) => [
    for (final s in _store.subtasks.values)
      if (s.taskId == taskId) s,
  ];

  void _check(Task task, List<Subtask> subtasks) {
    if (task.title.trim().isEmpty) {
      throw ArgumentError.value(
        task.title,
        'title',
        'Tiêu đề không được trống',
      );
    }
    final tagId = task.tagId;
    if (tagId != null && !_store.tags.containsKey(tagId)) {
      throw ArgumentError.value(tagId, 'tagId', 'Nhãn không tồn tại');
    }
    for (final subtask in subtasks) {
      if (subtask.taskId != task.id) {
        throw ArgumentError.value(
          subtask.taskId,
          'subtasks',
          'Việc con phải thuộc việc ${task.id}',
        );
      }
      if (subtask.title.trim().isEmpty) {
        throw ArgumentError.value(
          subtask.title,
          'subtasks',
          'Tên việc con không được trống',
        );
      }
      final existing = _store.subtasks[subtask.id];
      if (existing != null && existing.taskId != task.id) {
        throw StateError('Việc con ${subtask.id} đã tồn tại');
      }
    }
  }

  void _replaceSubtasks(String taskId, List<Subtask> subtasks) {
    _store.subtasks.removeWhere((_, s) => s.taskId == taskId);
    for (final subtask in subtasks) {
      _store.subtasks[subtask.id] = subtask;
    }
  }

  /// Như khóa ngoại của SQLite: xóa việc con, phiên tập trung thành không gắn
  /// việc.
  void _removeRelations(Set<String> taskIds) {
    _store.subtasks.removeWhere((_, s) => taskIds.contains(s.taskId));
    _store.sessions.updateAll(
      (_, s) => taskIds.contains(s.taskId) ? s.copyWith(taskId: () => null) : s,
    );
  }
}

/// Sắp theo due tăng dần, việc không có ngày ở cuối; cùng due thì theo lúc
/// tạo.
List<Task> _sorted(Iterable<Task> tasks) => tasks.toList()..sort(_byDue);

int _byDue(Task a, Task b) {
  final ad = a.due;
  final bd = b.due;
  if (ad == null || bd == null) {
    if (ad != bd) return ad == null ? 1 : -1;
  } else if (ad != bd) {
    return ad.compareTo(bd);
  }
  return a.createdAt.compareTo(b.createdAt);
}
