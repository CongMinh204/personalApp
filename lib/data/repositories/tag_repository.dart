import '../models/tag.dart';

/// Lưu và đọc nhãn. Xem docs/DATA_CONTRACT.md, mục 4.
abstract interface class TagRepository {
  /// Mọi nhãn, theo thứ tự tạo.
  Stream<List<Tag>> watchAll();

  Future<List<Tag>> getAll();

  Future<Tag?> getById(String id);

  /// Số việc (cả đã xong) của từng nhãn: tagId → số việc. Nhãn chưa có việc
  /// nào thì không có trong map.
  Stream<Map<String, int>> watchTaskCounts();

  /// Thêm nhãn. Tên được cắt khoảng trắng hai đầu; tên trống → ArgumentError;
  /// trùng nhãn khác (không phân biệt hoa thường) → [DuplicateTagNameException].
  Future<void> add(Tag tag);

  /// Sửa tên hoặc màu, kiểm tra như [add].
  Future<void> update(Tag tag);

  /// Xóa nhãn; các việc đang dùng nhãn này chuyển thành không nhãn.
  Future<void> delete(String id);
}

/// Tên nhãn đã có (không phân biệt hoa thường).
class DuplicateTagNameException implements Exception {
  const DuplicateTagNameException(this.name);

  final String name;

  @override
  String toString() => 'Nhãn "$name" đã tồn tại';
}
