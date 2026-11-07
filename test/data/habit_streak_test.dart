import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/habit_streak.dart';
import 'package:personal_app/data/models/habit.dart';
import 'package:personal_app/utils/dates.dart';

void main() {
  // Thứ Năm, 29/10/2026.
  final today = DateTime(2026, 10, 29);

  DateTime daysAgo(int n) => DateTime(2026, 10, 29 - n);

  Map<String, int> doneOn(Iterable<int> days, [int count = 1]) => {
    for (final n in days) dateKey(daysAgo(n)): count,
  };

  Habit habit({Set<int> days = const {1, 2, 3, 4, 5, 6, 7}, int goal = 1}) =>
      Habit(
        id: 'h',
        name: 'Đọc sách',
        repeatDays: days,
        goalPerDay: goal,
        startDate: DateTime(2026, 10, 1),
      );

  test('hôm nay chưa làm thì chưa đứt chuỗi', () {
    expect(habitStreaks(habit(), doneOn([1, 2, 3]), today).current, 3);
  });

  test('hôm nay đã làm thì tính cả hôm nay', () {
    expect(habitStreaks(habit(), doneOn([0, 1, 2, 3]), today).current, 4);
  });

  test('bỏ lỡ một ngày có lịch thì đứt chuỗi; best giữ chuỗi dài nhất', () {
    final streaks = habitStreaks(habit(), doneOn([1, 2, 4, 5, 6, 7, 8]), today);
    expect(streaks, (current: 2, best: 5));
  });

  test('ngày không có lịch được bỏ qua', () {
    // Lịch T2, T4, T6: 28/10 (T4), 26/10 (T2), 23/10 (T6) đều đã làm.
    final gym = habit(days: {1, 3, 5});
    expect(habitStreaks(gym, doneOn([1, 3, 6]), today).current, 3);
  });

  test('chưa đủ mục tiêu trong ngày thì chưa tính là xong', () {
    final water = habit(goal: 8);
    final counts = {
      ...doneOn([1, 2], 8),
      dateKey(daysAgo(3)): 5,
    };
    expect(habitStreaks(water, counts, today), (current: 2, best: 2));
  });

  test('ngày trước startDate không tính', () {
    final newHabit = Habit(id: 'h', name: 'Mới', startDate: daysAgo(2));
    expect(habitStreaks(newHabit, doneOn([1, 2, 3, 4]), today).best, 2);
  });

  test('chưa có nhật ký nào', () {
    expect(habitStreaks(habit(), {}, today), (current: 0, best: 0));
  });
}
