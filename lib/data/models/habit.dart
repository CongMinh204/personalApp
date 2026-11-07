import 'package:flutter/material.dart';

import '../../utils/dates.dart';
import 'db_values.dart';

/// Một thói quen. Xem docs/DATA_CONTRACT.md, mục Habit.
class Habit {
  const Habit({
    required this.id,
    required this.name,
    this.icon = 'drop',
    this.color = const Color(0xFF5B4FE0),
    this.repeatDays = const {1, 2, 3, 4, 5, 6, 7},
    this.goalPerDay = 1,
    this.unit = '',
    this.reminderTime,
    required this.startDate,
    this.archivedAt,
  });

  final String id;
  final String name;

  /// Khóa biểu tượng: drop, book, heart, moon, bolt.
  final String icon;
  final Color color;

  /// Các thứ cần làm: 1 = Thứ Hai … 7 = Chủ Nhật (như `DateTime.weekday`).
  final Set<int> repeatDays;

  /// Số lần cần làm trong ngày để tính là xong (≥ 1).
  final int goalPerDay;

  /// Đơn vị hiển thị, ví dụ 'ly'; có thể rỗng.
  final String unit;

  /// Giờ nhắc mỗi ngày; `null` = không nhắc.
  final TimeOfDay? reminderTime;

  /// Ngày bắt đầu (00:00); những ngày trước đó không tính vào chuỗi.
  final DateTime startDate;

  /// Thời điểm lưu trữ; `null` = đang dùng.
  final DateTime? archivedAt;

  bool get archived => archivedAt != null;

  /// Trường có thể trống truyền dạng hàm, như `Task.copyWith`.
  Habit copyWith({
    String? name,
    String? icon,
    Color? color,
    Set<int>? repeatDays,
    int? goalPerDay,
    String? unit,
    ValueGetter<TimeOfDay?>? reminderTime,
    DateTime? startDate,
    ValueGetter<DateTime?>? archivedAt,
  }) => Habit(
    id: id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    repeatDays: repeatDays ?? this.repeatDays,
    goalPerDay: goalPerDay ?? this.goalPerDay,
    unit: unit ?? this.unit,
    reminderTime: reminderTime != null ? reminderTime() : this.reminderTime,
    startDate: startDate ?? this.startDate,
    archivedAt: archivedAt != null ? archivedAt() : this.archivedAt,
  );

  Map<String, Object?> toMap() {
    final reminder = reminderTime;
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color.toARGB32(),
      'repeat_days': (repeatDays.toList()..sort()).join(','),
      'goal_per_day': goalPerDay,
      'unit': unit,
      'reminder_time': reminder == null
          ? null
          : reminder.hour * 60 + reminder.minute,
      'start_date': dateKey(startDate),
      'archived_at': encodeTime(archivedAt),
    };
  }

  factory Habit.fromMap(Map<String, Object?> map) {
    final days = map['repeat_days'] as String;
    final reminder = map['reminder_time'] as int?;
    return Habit(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: Color(map['color'] as int),
      repeatDays: days.isEmpty
          ? const <int>{}
          : {for (final d in days.split(',')) int.parse(d)},
      goalPerDay: map['goal_per_day'] as int,
      unit: (map['unit'] as String?) ?? '',
      reminderTime: reminder == null
          ? null
          : TimeOfDay(hour: reminder ~/ 60, minute: reminder % 60),
      startDate: parseDateKey(map['start_date'] as String),
      archivedAt: decodeTime(map['archived_at']),
    );
  }
}
