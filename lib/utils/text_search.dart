// Chuẩn hóa chữ để tìm kiếm: không phân biệt hoa thường và dấu tiếng Việt.

const _accented = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final _fold = <int, String>{
  for (final entry in _accented.entries)
    for (final rune in entry.value.runes) rune: entry.key,
};

/// Chữ thường, bỏ dấu tiếng Việt: "Học tập" → "hoc tap", "Đường" → "duong".
///
/// Cũng bỏ các dấu rời (ký tự kết hợp U+0300–U+036F) để chữ gõ bằng bộ gõ tạo
/// ra dạng tách dấu cũng khớp.
String foldVietnamese(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    if (rune >= 0x0300 && rune <= 0x036F) continue;
    final base = _fold[rune];
    if (base != null) {
      buffer.write(base);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// [haystack] có chứa [needle] không, bỏ qua hoa thường và dấu tiếng Việt.
/// [needle] đã được chuẩn hóa bằng [foldVietnamese] (để chuẩn hóa một lần cho
/// nhiều lần so sánh).
bool containsFolded(String haystack, String foldedNeedle) =>
    foldVietnamese(haystack).contains(foldedNeedle);
