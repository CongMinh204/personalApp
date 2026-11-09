import 'package:sqflite/sqflite.dart';

import '../models/tag.dart';
import '../repositories/tag_repository.dart';
import '../tag_name.dart';
import 'app_database.dart';

class SqliteTagRepository implements TagRepository {
  SqliteTagRepository(this._app);

  final AppDatabase _app;

  Database get _db => _app.db;

  @override
  Stream<List<Tag>> watchAll() => _app.changes.watch(getAll);

  @override
  Future<List<Tag>> getAll() async {
    final rows = await _db.query('tags', orderBy: 'rowid');
    return List.unmodifiable(rows.map(Tag.fromMap));
  }

  @override
  Future<Tag?> getById(String id) async {
    final rows = await _db.query('tags', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Tag.fromMap(rows.first);
  }

  @override
  Stream<Map<String, int>> watchTaskCounts() => _app.changes.watch(() async {
    final rows = await _db.rawQuery('''
SELECT tag_id, COUNT(*) AS total FROM tasks
WHERE tag_id IS NOT NULL GROUP BY tag_id''');
    return Map<String, int>.unmodifiable({
      for (final row in rows) row['tag_id'] as String: row['total'] as int,
    });
  });

  @override
  Future<void> add(Tag tag) async {
    await _db.transaction((txn) async {
      final existing = await txn.query(
        'tags',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [tag.id],
      );
      if (existing.isNotEmpty) throw StateError('Nhãn ${tag.id} đã tồn tại');
      final checked = await _checked(txn, tag);
      await txn.insert('tags', checked.toMap());
    });
    _app.changes.notify();
  }

  @override
  Future<void> update(Tag tag) async {
    final changed = await _db.transaction((txn) async {
      final existing = await txn.query(
        'tags',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [tag.id],
      );
      if (existing.isEmpty) return false;
      final checked = await _checked(txn, tag);
      await txn.update(
        'tags',
        checked.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [tag.id],
      );
      return true;
    });
    if (changed) _app.changes.notify();
  }

  @override
  Future<void> delete(String id) async {
    // Khóa ngoại ON DELETE SET NULL đưa các việc dùng nhãn về không nhãn.
    final deleted = await _db.delete('tags', where: 'id = ?', whereArgs: [id]);
    if (deleted > 0) _app.changes.notify();
  }

  /// Cắt khoảng trắng hai đầu; báo lỗi nếu tên trống hoặc trùng nhãn khác. So
  /// tên trong Dart bằng [tagNameKey] vì SQLite chỉ bỏ qua hoa thường với chữ
  /// không dấu.
  Future<Tag> _checked(DatabaseExecutor db, Tag tag) async {
    final name = tag.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(tag.name, 'name', 'Tên nhãn không được trống');
    }
    final key = tagNameKey(name);
    final rows = await db.query('tags', columns: ['id', 'name']);
    for (final row in rows) {
      if (row['id'] != tag.id && tagNameKey(row['name'] as String) == key) {
        throw DuplicateTagNameException(name);
      }
    }
    return tag.copyWith(name: name);
  }
}
