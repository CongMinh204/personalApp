import '../../utils/dates.dart';

/// Số lần đã làm một thói quen trong một ngày. Khóa: [habitId] + [date].
class HabitLog {
  const HabitLog({
    required this.habitId,
    required this.date,
    required this.count,
  });

  final String habitId;

  /// Ngày (00:00).
  final DateTime date;

  /// Số lần đã làm trong ngày (> 0; 0 thì không lưu dòng).
  final int count;

  HabitLog copyWith({int? count}) =>
      HabitLog(habitId: habitId, date: date, count: count ?? this.count);

  Map<String, Object?> toMap() => {
    'habit_id': habitId,
    'date': dateKey(date),
    'count': count,
  };

  factory HabitLog.fromMap(Map<String, Object?> map) => HabitLog(
    habitId: map['habit_id'] as String,
    date: parseDateKey(map['date'] as String),
    count: map['count'] as int,
  );
}
