import '../models/tag.dart';
import '../repositories/tag_repository.dart';
import '../tag_name.dart';
import 'fake_store.dart';

class FakeTagRepository implements TagRepository {
  FakeTagRepository(this._store);

  final FakeStore _store;

  @override
  Stream<List<Tag>> watchAll() =>
      _store.watch(() => List.unmodifiable(_store.tags.values));

  @override
  Future<List<Tag>> getAll() async => _store.tags.values.toList();

  @override
  Future<Tag?> getById(String id) async => _store.tags[id];

  @override
  Stream<Map<String, int>> watchTaskCounts() => _store.watch(() {
    final counts = <String, int>{};
    for (final task in _store.tasks.values) {
      final tagId = task.tagId;
      if (tagId != null) counts[tagId] = (counts[tagId] ?? 0) + 1;
    }
    return Map.unmodifiable(counts);
  });

  @override
  Future<void> add(Tag tag) async {
    if (_store.tags.containsKey(tag.id)) {
      throw StateError('Nhãn ${tag.id} đã tồn tại');
    }
    _store.tags[tag.id] = _checked(tag);
    _store.notifyChanged();
  }

  @override
  Future<void> update(Tag tag) async {
    if (!_store.tags.containsKey(tag.id)) return;
    _store.tags[tag.id] = _checked(tag);
    _store.notifyChanged();
  }

  @override
  Future<void> delete(String id) async {
    if (_store.tags.remove(id) == null) return;
    _store.tasks.updateAll(
      (_, t) => t.tagId == id ? t.copyWith(tagId: () => null) : t,
    );
    _store.notifyChanged();
  }

  /// Cắt khoảng trắng hai đầu; báo lỗi nếu tên trống hoặc trùng nhãn khác.
  Tag _checked(Tag tag) {
    final name = tag.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(tag.name, 'name', 'Tên nhãn không được trống');
    }
    final key = tagNameKey(name);
    for (final other in _store.tags.values) {
      if (other.id != tag.id && tagNameKey(other.name) == key) {
        throw DuplicateTagNameException(name);
      }
    }
    return tag.copyWith(name: name);
  }
}
