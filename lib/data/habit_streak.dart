import '../utils/dates.dart';
import 'models/habit.dart';

/// Chuỗi ngày hiện tại và dài nhất của [habit] tính đến ngày [today].
///
/// [counts] là số lần đã làm theo khóa ngày `yyyy-MM-dd` (xem `dateKey`).
/// Quy tắc (docs/DATA_CONTRACT.md, mục 5):
/// - chỉ xét ngày có lịch (thứ nằm trong `repeatDays`) từ `startDate` trở đi;
/// - ngày có lịch là "xong" khi số lần ≥ `goalPerDay`;
/// - ngày không có lịch được bỏ qua, không làm đứt chuỗi;
/// - hôm nay chưa xong thì chưa làm đứt chuỗi (ngày chưa kết thúc).
({int current, int best}) habitStreaks(
  Habit habit,
  Map<String, int> counts,
  DateTime today,
) {
  final last = startOfDay(today);
  var current = 0;
  var best = 0;
  for (
    var day = startOfDay(habit.startDate);
    !day.isAfter(last);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    if (!habit.repeatDays.contains(day.weekday)) continue;
    if ((counts[dateKey(day)] ?? 0) >= habit.goalPerDay) {
      current++;
      if (current > best) best = current;
    } else if (day != last) {
      current = 0;
    }
  }
  return (current: current, best: best);
}
