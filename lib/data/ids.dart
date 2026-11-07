import 'dart:math';

final _random = Random.secure();
var _sequence = 0;

/// Tạo id mới cho một bản ghi (việc, việc con, nhãn, phiên tập trung, thói quen).
///
/// Ghép thời điểm tạo (micro giây, cơ số 36), số đếm trong lần chạy app và
/// phần ngẫu nhiên, nên không trùng kể cả khi tạo nhiều id cùng lúc.
/// Ví dụ: `mgx3k9x2a01-4f7a2c`.
String newId() {
  _sequence = (_sequence + 1) % 1296;
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final sequence = _sequence.toRadixString(36).padLeft(2, '0');
  final random = _random.nextInt(0x7fffffff).toRadixString(36).padLeft(6, '0');
  return '$time$sequence-$random';
}

/// Số nguyên dương 31 bit cố định cho một id chuỗi, dùng làm id thông báo của
/// flutter_local_notifications (cần id kiểu số). Cùng một id luôn cho cùng một
/// số (băm FNV-1a).
int stableIntId(String id) {
  var hash = 0x811c9dc5;
  for (final unit in id.codeUnits) {
    hash ^= unit;
    // hash * 16777619 (mod 2^32), tách làm hai phép nhân để không tràn số.
    hash = (hash * 0x193 + ((hash << 24) & 0xffffffff)) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
