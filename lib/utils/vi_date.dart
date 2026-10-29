import '../models/task.dart';

const _weekdays = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];

const _shortWeekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

String _two(int n) => n.toString().padLeft(2, '0');

String _dayMonth(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

/// Số ngày lịch từ [from] đến [to] (bỏ qua giờ). Dùng UTC để tránh lệch do DST.
int dayDiff(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// "Thứ Năm, 29 tháng 10"
String headerDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} tháng ${d.month}';

/// "14:05"
String hourMinute(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// Nhãn thời gian hiển thị trong dòng phụ của việc, ví dụ:
/// "14:00 – 15:00", "Trong ngày", "Hôm qua, 23:59", "Ngày mai · 08:00",
/// "T7, 31/10 · 08:00", "03/11".
String taskTimeLabel(Task task, DateTime now) {
  final due = task.due;
  if (due == null) return 'Trong ngày';

  String? time;
  if (task.hasTime) {
    final end = task.end;
    time = end == null
        ? hourMinute(due)
        : '${hourMinute(due)} – ${hourMinute(end)}';
  }

  switch (dayDiff(now, due)) {
    case 0:
      return time ?? 'Trong ngày';
    case -1:
      return time == null ? 'Hôm qua' : 'Hôm qua, $time';
    case 1:
      return time == null ? 'Ngày mai' : 'Ngày mai · $time';
    default:
      if (time == null) return _dayMonth(due);
      return '${_shortWeekdays[due.weekday - 1]}, ${_dayMonth(due)} · $time';
  }
}
