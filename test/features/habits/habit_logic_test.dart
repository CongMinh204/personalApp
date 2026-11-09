import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/models/habit.dart';
import 'package:personal_app/features/habits/habit_logic.dart';

void main() {
  // Thứ Năm 29/10/2026.
  final today = DateTime(2026, 10, 29, 13, 40);

  Habit habit({
    String id = 'h',
    Set<int> days = const {1, 2, 3, 4, 5, 6, 7},
    int goal = 1,
    String unit = '',
    DateTime? start,
  }) => Habit(
    id: id,
    name: 'Thói quen $id',
    repeatDays: days,
    goalPerDay: goal,
    unit: unit,
    startDate: start ?? DateTime(2026, 10, 1),
  );

  group('biểu tượng và màu', () {
    test('5 biểu tượng với khóa cố định theo hợp đồng', () {
      expect(
        [for (final o in habitIcons) o.key],
        ['drop', 'book', 'heart', 'moon', 'bolt'],
      );
    });

    test('khóa ra đúng biểu tượng, khóa lạ thì dùng dấu tích', () {
      expect(habitIconData('book'), Icons.menu_book_outlined);
      expect(habitIconData('khong-co'), Icons.check_circle_outline_rounded);
    });

    test('5 màu như mockup', () {
      expect(
        [for (final c in habitColors) c.color.toARGB32()],
        [0xFF5B4FE0, 0xFF1E6FD9, 0xFF23774F, 0xFFC2410C, 0xFFBE185D],
      );
    });

    test('giao diện tối thì màu sáng hơn, giao diện sáng giữ nguyên', () {
      const color = Color(0xFF23774F);
      expect(habitInkColor(color, Brightness.light), color);
      final dark = habitInkColor(color, Brightness.dark);
      expect(dark.computeLuminance(), greaterThan(color.computeLuminance()));
    });
  });

  group('lịch', () {
    test('weekdayShort: Thứ Hai là T2, Chủ Nhật là CN', () {
      expect(
        [for (var d = 1; d <= 7; d++) weekdayShort(d)],
        ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
      );
    });

    test('có lịch khi thứ nằm trong repeatDays', () {
      final gym = habit(days: {1, 3, 5}); // T2, T4, T6
      expect(isScheduledOn(gym, DateTime(2026, 10, 26)), isTrue); // Thứ Hai
      expect(isScheduledOn(gym, DateTime(2026, 10, 28)), isTrue); // Thứ Tư
      expect(isScheduledOn(gym, DateTime(2026, 10, 29)), isFalse); // Thứ Năm
    });

    test('không có lịch trước ngày bắt đầu', () {
      final h = habit(start: DateTime(2026, 10, 29));
      expect(isScheduledOn(h, DateTime(2026, 10, 28)), isFalse);
      expect(isScheduledOn(h, DateTime(2026, 10, 29, 23, 59)), isTrue);
    });

    test('repeatSummary: Mỗi ngày hoặc các thứ theo thứ tự trong tuần', () {
      expect(repeatSummary({1, 2, 3, 4, 5, 6, 7}), 'Mỗi ngày');
      expect(repeatSummary({5, 1, 3}), 'T2 · T4 · T6');
      expect(repeatSummary({7, 6}), 'T7 · CN');
      expect(repeatSummary({4}), 'T5');
    });

    test('restDayLabel', () {
      expect(
        restDayLabel(habit(days: {1, 3, 5}), today),
        'T2 · T4 · T6 · Hôm nay nghỉ',
      );
      expect(
        restDayLabel(habit(start: DateTime(2026, 11, 5)), today),
        'Chưa tới ngày bắt đầu',
      );
    });

    test('sortForToday: có lịch hôm nay lên trước, giữ thứ tự trong nhóm', () {
      final sorted = sortForToday([
        habit(id: 'gym', days: {1, 3, 5}), // hôm nay nghỉ
        habit(id: 'a'),
        habit(id: 'yoga', days: {2}), // Thứ Ba, hôm nay nghỉ
        habit(id: 'b'),
      ], today);

      expect([for (final h in sorted) h.id], ['a', 'b', 'gym', 'yoga']);
    });
  });

  group('tiến độ và chạm nút chấm', () {
    test('isDone khi số lần đạt mục tiêu', () {
      final water = habit(goal: 8);
      expect(isDone(water, 7), isFalse);
      expect(isDone(water, 8), isTrue);
      expect(isDone(water, 9), isTrue);
    });

    test(
      'progressLabel: nhiều lần kèm đơn vị, một lần là Đã xong/Chưa làm',
      () {
        expect(progressLabel(habit(goal: 8, unit: 'ly'), 5), '5/8 ly');
        expect(progressLabel(habit(goal: 3), 1), '1/3');
        expect(progressLabel(habit(), 0), 'Chưa làm');
        expect(progressLabel(habit(), 1), 'Đã xong');
      },
    );

    test('mục tiêu 1 lần: bấm là xong, bấm lại là bỏ xong', () {
      final h = habit();
      expect(countAfterTap(h, 0), 1);
      expect(countAfterTap(h, 1), 0);
    });

    test('mục tiêu nhiều lần: cộng 1 đến đủ, đủ rồi bấm thì về 0', () {
      final water = habit(goal: 3);
      expect(countAfterTap(water, 0), 1);
      expect(countAfterTap(water, 1), 2);
      expect(countAfterTap(water, 2), 3);
      expect(countAfterTap(water, 3), 0);
    });

    test('todayProgress chỉ tính thói quen có lịch hôm nay', () {
      final habits = [
        habit(id: 'a'),
        habit(id: 'b', goal: 8),
        habit(id: 'c'),
        habit(id: 'gym', days: {1, 3, 5}), // nghỉ hôm nay
      ];

      final p = todayProgress(habits, {'a': 1, 'b': 5, 'gym': 1}, today);

      expect((p.done, p.total), (1, 3));
    });

    test('todayProgress khi không có thói quen nào có lịch', () {
      final p = todayProgress(
        [
          habit(days: {1}),
        ],
        {},
        today,
      );
      expect((p.done, p.total), (0, 0));
    });

    test('todayHint', () {
      expect(
        todayHint(const TodayProgress(done: 2, total: 5)),
        'Còn 3 thói quen cần làm',
      );
      expect(
        todayHint(const TodayProgress(done: 5, total: 5)),
        'Tuyệt vời! Bạn đã hoàn thành hết hôm nay',
      );
      expect(
        todayHint(const TodayProgress(done: 0, total: 0)),
        'Hôm nay không có thói quen nào cần làm',
      );
    });
  });

  group('form Thêm/sửa', () {
    HabitFormErrors validate({
      String name = 'Uống nước',
      Set<int> days = const {1, 2, 3},
      int goal = 1,
    }) => validateHabitForm(name: name, days: days, goal: goal);

    test('hợp lệ thì không có lỗi', () {
      expect(validate().hasError, isFalse);
    });

    test('tên trống hoặc chỉ khoảng trắng là lỗi', () {
      expect(validate(name: '').name, 'Vui lòng nhập tên thói quen');
      expect(validate(name: '   ').name, 'Vui lòng nhập tên thói quen');
    });

    test('phải chọn ít nhất một ngày', () {
      expect(validate(days: {}).days, 'Chọn ít nhất một ngày');
    });

    test('mục tiêu từ 1 đến 99, kể cả hai đầu', () {
      expect(validate(goal: 0).goal, 'Mục tiêu từ 1 đến 99 lần');
      expect(validate(goal: 1).goal, isNull);
      expect(validate(goal: 99).goal, isNull);
      expect(validate(goal: 100).goal, 'Mục tiêu từ 1 đến 99 lần');
    });

    test('buildHabit cắt khoảng trắng và đưa ngày bắt đầu về 00:00', () {
      final h = buildHabit(
        id: 'x',
        name: '  Uống nước  ',
        icon: 'drop',
        color: habitColors[1].color,
        repeatDays: {1, 3},
        goalPerDay: 8,
        unit: ' ly ',
        reminderTime: defaultHabitReminder,
        startDate: DateTime(2026, 10, 1, 15, 30),
      );

      expect(h.name, 'Uống nước');
      expect(h.unit, 'ly');
      expect(h.startDate, DateTime(2026, 10, 1));
      expect(h.repeatDays, {1, 3});
      expect(h.reminderTime, const TimeOfDay(hour: 20, minute: 0));
      expect(h.archived, isFalse);
    });

    test('đơn vị bị bỏ khi mục tiêu chỉ 1 lần', () {
      final h = buildHabit(
        id: 'x',
        name: 'Đọc sách',
        icon: 'book',
        color: habitColors[0].color,
        repeatDays: {1},
        goalPerDay: 1,
        unit: 'ly',
        reminderTime: null,
        startDate: DateTime(2026, 10, 1),
      );
      expect(h.unit, '');
      expect(h.reminderTime, isNull);
    });

    test('buildHabit giữ archivedAt khi được truyền (khi sửa)', () {
      final at = DateTime(2026, 10, 20);
      final h = buildHabit(
        id: 'x',
        name: 'A',
        icon: 'drop',
        color: habitColors[0].color,
        repeatDays: {1},
        goalPerDay: 1,
        unit: '',
        reminderTime: null,
        startDate: DateTime(2026, 10, 1),
        archivedAt: at,
      );
      expect(h.archivedAt, at);
    });
  });
}
