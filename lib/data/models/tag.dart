/// 5 tông màu nhãn như mockup. Màu nền/chữ cho sáng và tối lấy từ
/// `TaskColors.of(context).tag(color)`. [code] là giá trị lưu trong database.
enum TagColor {
  violet('violet', 'Xanh tím'),
  orange('orange', 'Cam'),
  green('green', 'Xanh lá'),
  red('red', 'Đỏ'),
  grey('grey', 'Xám');

  const TagColor(this.code, this.label);

  final String code;
  final String label;

  static TagColor fromCode(Object? code) =>
      values.firstWhere((c) => c.code == code, orElse: () => grey);
}

/// Nhãn của việc. Mỗi việc có tối đa một nhãn.
class Tag {
  const Tag({
    required this.id,
    required this.name,
    this.color = TagColor.violet,
  });

  final String id;

  /// Không trống, không trùng nhãn khác (không phân biệt hoa thường).
  final String name;
  final TagColor color;

  Tag copyWith({String? name, TagColor? color}) =>
      Tag(id: id, name: name ?? this.name, color: color ?? this.color);

  Map<String, Object?> toMap() => {'id': id, 'name': name, 'color': color.code};

  factory Tag.fromMap(Map<String, Object?> map) => Tag(
    id: map['id'] as String,
    name: map['name'] as String,
    color: TagColor.fromCode(map['color']),
  );
}
