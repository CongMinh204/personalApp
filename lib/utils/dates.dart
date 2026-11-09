import 'package:flutter/material.dart' show DateTimeRange;

/// 00:00 của ngày chứa [d] (giờ máy).
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// [count] ngày liên tiếp tính từ ngày [firstDay]: từ 00:00 ngày đầu đến
/// 00:00 ngày sau ngày cuối (end không tính).
DateTimeRange daysRange(DateTime firstDay, int count) {
  final start = startOfDay(firstDay);
  return DateTimeRange(
    start: start,
    end: DateTime(start.year, start.month, start.day + count),
  );
}

/// Cả ngày [day].
DateTimeRange dayRange(DateTime day) => daysRange(day, 1);

/// Cả tháng chứa [day].
DateTimeRange monthRange(DateTime day) => DateTimeRange(
  start: DateTime(day.year, day.month),
  end: DateTime(day.year, day.month + 1),
);

/// 00:00 ngày đầu tuần chứa [d]. [weekStart] theo `DateTime.weekday`: 1 =
/// tuần bắt đầu từ Thứ Hai, 7 = từ Chủ Nhật (xem `week_start` trong Cài đặt).
DateTime startOfWeek(DateTime d, int weekStart) {
  final back = (d.weekday - weekStart + 7) % 7;
  return DateTime(d.year, d.month, d.day - back);
}

/// Cả tuần chứa [day] (7 ngày, từ ngày đầu tuần).
DateTimeRange weekRange(DateTime day, int weekStart) =>
    daysRange(startOfWeek(day, weekStart), 7);

/// [t] có nằm trong [range] không (gồm start, không gồm end).
bool rangeContains(DateTimeRange range, DateTime t) =>
    !t.isBefore(range.start) && t.isBefore(range.end);

/// Khóa ngày 'yyyy-MM-dd', dùng để lưu ngày không có giờ.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// Đọc khóa 'yyyy-MM-dd' thành 00:00 của ngày đó.
DateTime parseDateKey(String key) {
  final parts = key.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String _two(int n) => n.toString().padLeft(2, '0');
