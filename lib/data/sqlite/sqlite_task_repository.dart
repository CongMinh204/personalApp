import 'package:flutter/material.dart' show DateTimeRange;
import 'package:sqflite/sqflite.dart';

import '../../utils/dates.dart';
import '../models/db_values.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';
import 'app_database.dart';

/// Đọc việc kèm số việc con (đếm từ bảng `subtasks` mỗi lần đọc) và tên nhãn
/// (cho [SqliteTaskRepository.search]).
const _selectTask = '''
SELECT t.*,
  (SELECT COUNT(*) FROM subtasks s WHERE s.task_id = t.id) AS subtask_total,
  (SELECT COUNT(*) FROM subtasks s
     WHERE s.task_id = t.id AND s.done = 1) AS subtask_done,
  g.name AS tag_name
FROM tasks t LEFT JOIN tags g ON g.id = t.tag_id''';

/// Sắp theo due tăng dần, việc không có ngày ở cuối; cùng due thì theo lúc
/// tạo, rồi theo thứ tự thêm.
const _orderByDue =
    'ORDER BY t.due_at IS NULL, t.due_at, t.created_at, t.rowid';

class SqliteTaskRepository implements TaskRepository {
  SqliteTaskRepository(this._app);

  final AppDatabase _app;

  Database get _db => _app.db;

  @override
  Stream<List<Task>> watchAll() => _app.changes.watch(getAll);

  @override
  Future<List<Task>> getAll() async {
    final rows = await _db.rawQuery('$_selectTask ORDER BY t.rowid');
    return List.unmodifiable(rows.map(Task.fromMap));
  }

  @override
  Stream<List<Task>> watchByDay(DateTime day) => watchByRange(dayRange(day));

  @override
  Stream<List<Task>> watchByRange(DateTimeRange range) =>
      _app.changes.watch(() async {
        final rows = await _db.rawQuery(
          '$_selectTask WHERE t.due_at >= ? AND t.due_at < ? $_orderByDue',
          [encodeTime(range.start), encodeTime(range.end)],
        );
        return List<Task>.unmodifiable(rows.map(Task.fromMap));
      });

  @override
  Future<List<Task>> getUnfinished() async {
    final rows = await _db.rawQuery(
      '$_selectTask WHERE t.done = 0 $_orderByDue',
    );
    return rows.map(Task.fromMap).toList();
  }

  @override
  Future<Task?> getById(String id) async {
    final rows = await _db.rawQuery('$_selectTask WHERE t.id = ?', [id]);
    return rows.isEmpty ? null : Task.fromMap(rows.first);
  }

  @override
  Stream<Task?> watchById(String id) => _app.changes.watch(() => getById(id));

  /// Lọc trong Dart thay vì `LIKE`: SQLite chỉ bỏ qua hoa thường với chữ không
  /// dấu, nên "ÔN TẬP" không khớp "ôn tập". Dữ liệu cá nhân nhỏ nên không chậm.
  @override
  Future<List<Task>> search(String query) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return [];
    final rows = await _db.rawQuery('$_selectTask $_orderByDue');
    return [
      for (final row in rows)
        if ((row['title'] as String).toLowerCase().contains(needle) ||
            (row['note'] as String).toLowerCase().contains(needle) ||
            ((row['tag_name'] as String?) ?? '').toLowerCase().contains(needle))
          Task.fromMap(row),
    ];
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
    final rows = await _db.rawQuery(
      '''
$_selectTask
WHERE t.done = 1 AND t.completed_at >= ? AND t.completed_at < ?
ORDER BY t.completed_at, t.rowid''',
      [encodeTime(range.start), encodeTime(range.end)],
    );
    return rows.map(Task.fromMap).toList();
  }

  @override
  Future<void> add(Task task, {List<Subtask> subtasks = const []}) async {
    await _db.transaction((txn) async {
      final existing = await txn.query(
        'tasks',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [task.id],
      );
      if (existing.isNotEmpty) throw StateError('Việc ${task.id} đã tồn tại');
      await _check(txn, task, subtasks);
      await txn.insert('tasks', task.toMap());
      await _replaceSubtasks(txn, task.id, subtasks);
    });
    _app.changes.notify();
  }

  @override
  Future<void> update(Task task, {List<Subtask>? subtasks}) async {
    final changed = await _db.transaction((txn) async {
      final existing = await txn.query(
        'tasks',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [task.id],
      );
      if (existing.isEmpty) return false;
      await _check(txn, task, subtasks ?? const []);
      // done và completed_at chỉ đổi bằng setDone.
      final values = task.toMap()
        ..remove('id')
        ..remove('done')
        ..remove('completed_at');
      await txn.update('tasks', values, where: 'id = ?', whereArgs: [task.id]);
      if (subtasks != null) await _replaceSubtasks(txn, task.id, subtasks);
      return true;
    });
    if (changed) _app.changes.notify();
  }

  @override
  Future<void> setDone(String id, bool done) async {
    final updated = await _db.update(
      'tasks',
      {
        'done': encodeBool(done),
        'completed_at': done ? encodeTime(_app.clock()) : null,
      },
      where: 'id = ? AND done != ?',
      whereArgs: [id, encodeBool(done)],
    );
    if (updated > 0) _app.changes.notify();
  }

  @override
  Future<void> delete(String id) async {
    // Khóa ngoại: việc con bị xóa theo, phiên tập trung về không gắn việc.
    final deleted = await _db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    if (deleted > 0) _app.changes.notify();
  }

  @override
  Future<int> deleteCompleted() async {
    final deleted = await _db.delete('tasks', where: 'done = 1');
    if (deleted > 0) _app.changes.notify();
    return deleted;
  }

  @override
  Future<List<Subtask>> getSubtasks(String taskId) async {
    final rows = await _db.query(
      'subtasks',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'rowid',
    );
    return List.unmodifiable(rows.map(Subtask.fromMap));
  }

  @override
  Stream<List<Subtask>> watchSubtasks(String taskId) =>
      _app.changes.watch(() => getSubtasks(taskId));

  @override
  Future<void> setSubtaskDone(String subtaskId, bool done) async {
    final updated = await _db.update(
      'subtasks',
      {'done': encodeBool(done)},
      where: 'id = ? AND done != ?',
      whereArgs: [subtaskId, encodeBool(done)],
    );
    if (updated > 0) _app.changes.notify();
  }

  Future<void> _check(
    DatabaseExecutor db,
    Task task,
    List<Subtask> subtasks,
  ) async {
    if (task.title.trim().isEmpty) {
      throw ArgumentError.value(
        task.title,
        'title',
        'Tiêu đề không được trống',
      );
    }
    final tagId = task.tagId;
    if (tagId != null) {
      final tag = await db.query(
        'tags',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [tagId],
      );
      if (tag.isEmpty) {
        throw ArgumentError.value(tagId, 'tagId', 'Nhãn không tồn tại');
      }
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
      final existing = await db.query(
        'subtasks',
        columns: ['task_id'],
        where: 'id = ?',
        whereArgs: [subtask.id],
      );
      if (existing.isNotEmpty && existing.first['task_id'] != task.id) {
        throw StateError('Việc con ${subtask.id} đã tồn tại');
      }
    }
  }

  /// Thay toàn bộ việc con của [taskId]; thứ tự trong [subtasks] là thứ tự
  /// hiển thị.
  Future<void> _replaceSubtasks(
    DatabaseExecutor db,
    String taskId,
    List<Subtask> subtasks,
  ) async {
    await db.delete('subtasks', where: 'task_id = ?', whereArgs: [taskId]);
    for (final subtask in subtasks) {
      await db.insert('subtasks', subtask.toMap());
    }
  }
}
