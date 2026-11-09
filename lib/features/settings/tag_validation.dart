import '../../data/models/tag.dart';
import '../../data/tag_name.dart';

/// Độ dài tối đa của tên nhãn khi nhập (chỉ giới hạn ở giao diện để badge
/// không bị tràn; repository không giới hạn).
const tagNameMaxLength = 24;

/// Kiểm tra tên nhãn trước khi lưu. Trả về thông báo lỗi tiếng Việt, hoặc
/// `null` nếu hợp lệ.
///
/// - Tên rỗng hoặc chỉ có khoảng trắng là lỗi.
/// - Trùng nhãn khác là lỗi, không phân biệt hoa thường kể cả chữ có dấu (cùng
///   quy tắc [tagNameKey] của repository).
/// - Khi sửa nhãn, truyền [editingId] để nhãn không bị coi là trùng với chính
///   nó.
String? validateTagName(
  String name,
  Iterable<Tag> existing, {
  String? editingId,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Nhập tên nhãn';
  final key = tagNameKey(trimmed);
  for (final tag in existing) {
    if (tag.id != editingId && tagNameKey(tag.name) == key) {
      return 'Nhãn "${tag.name}" đã tồn tại';
    }
  }
  return null;
}
