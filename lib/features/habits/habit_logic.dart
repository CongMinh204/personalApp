import 'package:flutter/material.dart';

import '../../data/models/habit.dart';
import '../../utils/dates.dart';
import '../../utils/vi_date.dart';

export '../../utils/vi_date.dart' show weekdayShort;

// ---- Biểu tượng và màu -----------------------------------------------------

/// Một biểu tượng chọn được cho thói quen. Database chỉ lưu [key] (không lưu mã
/// `IconData`, vì mã đó làm hỏng bản build release).
class HabitIconOption {
  const HabitIconOption(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

const habitIcons = [
  HabitIconOption('drop', 'Giọt nước', Icons.water_drop_outlined),
  HabitIconOption('book', 'Sách', Icons.menu_book_outlined),
  HabitIconOption('heart', 'Sức khỏe', Icons.favorite_border_rounded),
  HabitIconOption('moon', 'Giấc ngủ', Icons.bedtime_outlined),
  HabitIconOption('bolt', 'Năng lượng', Icons.bolt_rounded),
];

/// Biểu tượng của khóa [key]; khóa lạ thì dùng dấu tích.
IconData habitIconData(String key) {
  for (final option in habitIcons) {
    if (option.key == key) return option.icon;
  }
  return Icons.check_circle_outline_rounded;
}

class HabitColorOption {
  const HabitColorOption(this.label, this.color);

  final String label;
  final Color color;
}

/// 5 màu chọn được (như mockup).
const habitColors = [
  HabitColorOption('Xanh tím', Color(0xFF5B4FE0)),
  HabitColorOption('Xanh dương', Color(0xFF1E6FD9)),
  HabitColorOption('Xanh lá', Color(0xFF23774F)),
  HabitColorOption('Cam', Color(0xFFC2410C)),
  HabitColorOption('Hồng', Color(0xFFBE185D)),
];

/// Màu dùng để vẽ biểu tượng và chữ: sáng hơn một chút ở giao diện tối để
/// không bị chìm.
Color habitInkColor(Color color, Brightness brightness) =>
    brightness == Brightness.dark
    ? Color.lerp(color, Colors.white, 0.45)!
    : color;

// ---- Lịch và tiến độ trong ngày -------------------------------------------

/// Thói quen có lịch vào [day] không: thứ nằm trong `repeatDays` và ngày đó
/// không trước ngày bắt đầu.
bool isScheduledOn(Habit habit, DateTime day) =>
    habit.repeatDays.contains(day.weekday) &&
    !startOfDay(day).isBefore(startOfDay(habit.startDate));

/// Đã đủ mục tiêu của ngày chưa.
bool isDone(Habit habit, int count) => count >= habit.goalPerDay;

/// "Mỗi ngày" hoặc "T2 · T4 · T6".
String repeatSummary(Set<int> days) {
  if (days.length == 7) return 'Mỗi ngày';
  final sorted = days.toList()..sort();
  return sorted.map(weekdayShort).join(' · ');
}

/// Dòng tiến độ trong ngày: "5/8 ly" khi mục tiêu nhiều lần, còn lại "Đã xong"
/// hoặc "Chưa làm".
String progressLabel(Habit habit, int count) {
  if (habit.goalPerDay > 1) {
    final unit = habit.unit.isEmpty ? '' : ' ${habit.unit}';
    return '$count/${habit.goalPerDay}$unit';
  }
  return isDone(habit, count) ? 'Đã xong' : 'Chưa làm';
}

/// Số lần mới sau một lần bấm nút chấm của một thói quen đang có [count] lần:
/// mục tiêu 1 lần thì bấm là xong và bấm lại là bỏ xong; mục tiêu nhiều lần thì
/// mỗi lần bấm cộng 1 đến đủ, khi đã đủ bấm lại thì về 0.
int countAfterTap(Habit habit, int count) {
  if (isDone(habit, count)) return 0;
  return habit.goalPerDay > 1 ? count + 1 : habit.goalPerDay;
}

/// Dòng phụ của thói quen không có lịch hôm nay: "T2 · T4 · T6 · Hôm nay nghỉ".
String restDayLabel(Habit habit, DateTime day) {
  if (habit.repeatDays.isEmpty) return 'Hôm nay nghỉ';
  final started = !startOfDay(day).isBefore(startOfDay(habit.startDate));
  return started
      ? '${repeatSummary(habit.repeatDays)} · Hôm nay nghỉ'
      : 'Chưa tới ngày bắt đầu';
}

/// Xếp các thói quen có lịch hôm nay lên trước, giữ nguyên thứ tự tạo trong
/// từng nhóm.
List<Habit> sortForToday(Iterable<Habit> habits, DateTime day) {
  final all = habits.toList();
  return [
    for (final h in all)
      if (isScheduledOn(h, day)) h,
    for (final h in all)
      if (!isScheduledOn(h, day)) h,
  ];
}

/// Số thói quen có lịch hôm nay đã xong trên tổng.
class TodayProgress {
  const TodayProgress({required this.done, required this.total});

  final int done;
  final int total;
}

/// Tiến độ hôm nay: chỉ tính thói quen có lịch vào [day]. [counts] là số lần đã
/// làm trong ngày của từng thói quen (không có trong map = 0).
TodayProgress todayProgress(
  Iterable<Habit> habits,
  Map<String, int> counts,
  DateTime day,
) {
  var done = 0;
  var total = 0;
  for (final h in habits) {
    if (!isScheduledOn(h, day)) continue;
    total++;
    if (isDone(h, counts[h.id] ?? 0)) done++;
  }
  return TodayProgress(done: done, total: total);
}

/// Lời nhắn dưới ô "Thói quen hôm nay".
String todayHint(TodayProgress p) {
  if (p.total == 0) return 'Hôm nay không có thói quen nào cần làm';
  if (p.done == p.total) return 'Tuyệt vời! Bạn đã hoàn thành hết hôm nay';
  return 'Còn ${p.total - p.done} thói quen cần làm';
}

// ---- Form Thêm/sửa --------------------------------------------------------

/// Giới hạn mục tiêu mỗi ngày (số lần).
const habitGoalRange = (1, 99);

/// Giờ nhắc mặc định khi bật "Nhắc mỗi ngày".
const defaultHabitReminder = TimeOfDay(hour: 20, minute: 0);

/// Lỗi của form Thêm/sửa thói quen; `null` = hợp lệ.
class HabitFormErrors {
  const HabitFormErrors({this.name, this.days, this.goal});

  final String? name;
  final String? days;
  final String? goal;

  bool get hasError => name != null || days != null || goal != null;
}

HabitFormErrors validateHabitForm({
  required String name,
  required Set<int> days,
  required int goal,
}) => HabitFormErrors(
  name: name.trim().isEmpty ? 'Vui lòng nhập tên thói quen' : null,
  days: days.isEmpty ? 'Chọn ít nhất một ngày' : null,
  goal: goal < habitGoalRange.$1 || goal > habitGoalRange.$2
      ? 'Mục tiêu từ ${habitGoalRange.$1} đến ${habitGoalRange.$2} lần'
      : null,
);

/// Ghép các trường của form thành một [Habit]. Đơn vị chỉ có nghĩa khi mục
/// tiêu lớn hơn 1 lần nên được bỏ nếu mục tiêu là 1.
Habit buildHabit({
  required String id,
  required String name,
  required String icon,
  required Color color,
  required Set<int> repeatDays,
  required int goalPerDay,
  required String unit,
  required TimeOfDay? reminderTime,
  required DateTime startDate,
  DateTime? archivedAt,
}) => Habit(
  id: id,
  name: name.trim(),
  icon: icon,
  color: color,
  repeatDays: Set.of(repeatDays),
  goalPerDay: goalPerDay,
  unit: goalPerDay > 1 ? unit.trim() : '',
  reminderTime: reminderTime,
  startDate: startOfDay(startDate),
  archivedAt: archivedAt,
);
