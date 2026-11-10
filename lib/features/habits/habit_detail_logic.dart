import '../../data/models/habit.dart';
import '../../data/models/habit_log.dart';
import '../../utils/dates.dart';
import '../../utils/vi_date.dart';
import 'habit_logic.dart';

export '../../utils/vi_date.dart' show monthTitle, weekdayHeaders;

/// Trạng thái của một ngày trên lịch tháng.
enum DayStatus {
  /// Có lịch và đã đủ mục tiêu.
  done,

  /// Có lịch, đã qua và chưa đủ mục tiêu (kể cả làm dở).
  missed,

  /// Hôm nay có lịch và chưa đủ mục tiêu: chưa tính là bỏ lỡ vì ngày chưa hết.
  pending,

  /// Sau hôm nay.
  upcoming,

  /// Không có lịch (thứ không nằm trong `repeatDays` hoặc trước ngày bắt đầu).
  rest,
}

/// Một ô ngày của lịch tháng.
class DayCell {
  const DayCell(this.date, this.status, this.count);

  final DateTime date;
  final DayStatus status;

  /// Số lần đã làm trong ngày.
  final int count;

  /// Chạm vào ô để bật tắt "đã làm": chỉ với ngày có lịch và không phải ngày
  /// chưa tới.
  bool get tappable =>
      status == DayStatus.done ||
      status == DayStatus.missed ||
      status == DayStatus.pending;
}

/// Số lần đã làm theo khóa ngày `yyyy-MM-dd` (xem `dateKey`).
Map<String, int> countsByKey(Iterable<HabitLog> logs) => {
  for (final log in logs) dateKey(log.date): log.count,
};

/// Trạng thái của [day] khi hôm nay là [today].
DayStatus dayStatus(
  Habit habit,
  DateTime day,
  DateTime today,
  Map<String, int> counts,
) {
  final d = startOfDay(day);
  final t = startOfDay(today);
  if (d.isAfter(t)) return DayStatus.upcoming;
  if (!isScheduledOn(habit, d)) return DayStatus.rest;
  if (isDone(habit, counts[dateKey(d)] ?? 0)) return DayStatus.done;
  return d == t ? DayStatus.pending : DayStatus.missed;
}

/// Số lần mới của một ngày sau khi chạm vào ô trên lịch hoặc nút ở cuối màn:
/// đã xong thì bỏ xong (về 0), chưa xong thì xong ngay cả mục tiêu.
int toggledDayCount(Habit habit, int count) =>
    isDone(habit, count) ? 0 : habit.goalPerDay;

DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month);

DateTime previousMonth(DateTime month) => DateTime(month.year, month.month - 1);

DateTime nextMonth(DateTime month) => DateTime(month.year, month.month + 1);

/// Có xem được tháng trước [month] không: từ tháng của ngày bắt đầu trở đi.
bool canGoToPreviousMonth(Habit habit, DateTime month) =>
    _firstOfMonth(month).isAfter(_firstOfMonth(habit.startDate));

/// Có xem được tháng sau [month] không: tối đa tới tháng hiện tại.
bool canGoToNextMonth(DateTime month, DateTime today) =>
    _firstOfMonth(month).isBefore(_firstOfMonth(today));

/// Lưới tháng [month]: các hàng 7 ô theo ngày đầu tuần [weekStart]; ô đệm ở đầu
/// và cuối tháng là `null`.
List<List<DayCell?>> monthGrid(
  Habit habit,
  DateTime month,
  DateTime today,
  Map<String, int> counts,
  int weekStart,
) {
  final first = _firstOfMonth(month);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final lead = (first.weekday - weekStart + 7) % 7;

  final cells = <DayCell?>[
    for (var i = 0; i < lead; i++) null,
    for (var day = 1; day <= daysInMonth; day++)
      DayCell(
        DateTime(month.year, month.month, day),
        dayStatus(habit, DateTime(month.year, month.month, day), today, counts),
        counts[dateKey(DateTime(month.year, month.month, day))] ?? 0,
      ),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
}

/// Số ngày có lịch đã xong trên tổng số ngày có lịch.
class Completion {
  const Completion({required this.doneDays, required this.scheduledDays});

  final int doneDays;
  final int scheduledDays;

  /// Phần trăm làm tròn 0–100; chưa có ngày nào có lịch thì 0.
  int get percent =>
      scheduledDays == 0 ? 0 : (doneDays * 100 / scheduledDays).round();
}

/// Tỷ lệ hoàn thành từ ngày bắt đầu đến hôm nay. Hôm nay nằm trong mẫu số kể
/// cả khi chưa xong.
Completion completionRate(
  Habit habit,
  Map<String, int> counts,
  DateTime today,
) {
  final last = startOfDay(today);
  var done = 0;
  var scheduled = 0;
  for (
    var day = startOfDay(habit.startDate);
    !day.isAfter(last);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    if (!isScheduledOn(habit, day)) continue;
    scheduled++;
    if (isDone(habit, counts[dateKey(day)] ?? 0)) done++;
  }
  return Completion(doneDays: done, scheduledDays: scheduled);
}

/// Một cột của biểu đồ "4 tuần gần nhất".
class WeekBar {
  const WeekBar({
    required this.start,
    required this.label,
    required this.completion,
    required this.isCurrent,
  });

  final DateTime start;

  /// "5/10" (ngày đầu tuần) hoặc "Tuần này".
  final String label;
  final Completion completion;
  final bool isCurrent;

  int get percent => completion.percent;
}

/// [count] tuần gần nhất, tuần cũ nhất trước, tuần cuối là tuần này. Mỗi tuần
/// tính các ngày có lịch từ đầu tuần (hoặc ngày bắt đầu) tới hết tuần (tuần này
/// chỉ tới hôm nay).
List<WeekBar> recentWeeks(
  Habit habit,
  Map<String, int> counts,
  DateTime today,
  int weekStart, {
  int count = 4,
}) {
  final thisWeek = startOfWeek(today, weekStart);
  final last = startOfDay(today);
  return [
    for (var i = count - 1; i >= 0; i--)
      () {
        final start = DateTime(
          thisWeek.year,
          thisWeek.month,
          thisWeek.day - 7 * i,
        );
        var done = 0;
        var scheduled = 0;
        for (var d = 0; d < 7; d++) {
          final day = DateTime(start.year, start.month, start.day + d);
          if (day.isAfter(last)) break;
          if (!isScheduledOn(habit, day)) continue;
          scheduled++;
          if (isDone(habit, counts[dateKey(day)] ?? 0)) done++;
        }
        return WeekBar(
          start: start,
          label: i == 0 ? 'Tuần này' : '${start.day}/${start.month}',
          completion: Completion(doneDays: done, scheduledDays: scheduled),
          isCurrent: i == 0,
        );
      }(),
  ];
}

/// Dòng mô tả dưới tên: "Mỗi ngày · 8 ly · nhắc lúc 20:00". Mục tiêu chỉ 1 lần
/// thì không ghi số lần.
String detailSubtitle(Habit habit) {
  final parts = <String>[repeatSummary(habit.repeatDays)];
  if (habit.goalPerDay > 1) {
    parts.add('${habit.goalPerDay} ${habit.unit.isEmpty ? 'lần' : habit.unit}');
  }
  final reminder = habit.reminderTime;
  if (reminder != null) {
    parts.add(
      'nhắc lúc ${hourMinute(DateTime(2000, 1, 1, reminder.hour, reminder.minute))}',
    );
  }
  return parts.join(' · ');
}
