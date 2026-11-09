import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/models/habit.dart';
import 'package:personal_app/data/models/habit_log.dart';
import 'package:personal_app/features/habits/habit_detail_logic.dart';
import 'package:personal_app/utils/dates.dart';

void main() {
  // Thứ Năm 29/10/2026.
  final today = DateTime(2026, 10, 29, 13, 40);

  Habit habit({
    Set<int> days = const {1, 2, 3, 4, 5, 6, 7},
    int goal = 1,
    String unit = '',
    DateTime? start,
    TimeOfDay? reminder,
  }) => Habit(
    id: 'h',
    name: 'Thói quen',
    repeatDays: days,
    goalPerDay: goal,
    unit: unit,
    reminderTime: reminder,
    startDate: start ?? DateTime(2026, 10, 1),
  );

  /// Nhật ký làm đủ ở các ngày [days] của tháng 10/2026.
  Map<String, int> doneOn(Iterable<int> days, {int count = 1}) => {
    for (final d in days) dateKey(DateTime(2026, 10, d)): count,
  };

  // Mockup: bỏ lỡ ngày 3, 6, 10, 17; đã làm các ngày còn lại tới 28.
  final mockupCounts = doneOn([
    1,
    2,
    4,
    5,
    7,
    8,
    9,
    11,
    12,
    13,
    14,
    15,
    16,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
  ]);

  group('dayStatus', () {
    test('đã làm, bỏ lỡ, hôm nay chưa xong, chưa tới', () {
      final h = habit();
      expect(
        dayStatus(h, DateTime(2026, 10, 5), today, mockupCounts),
        DayStatus.done,
      );
      expect(
        dayStatus(h, DateTime(2026, 10, 3), today, mockupCounts),
        DayStatus.missed,
      );
      expect(
        dayStatus(h, DateTime(2026, 10, 29), today, mockupCounts),
        DayStatus.pending,
      );
      expect(
        dayStatus(h, DateTime(2026, 10, 30), today, mockupCounts),
        DayStatus.upcoming,
      );
    });

    test('hôm nay đã xong thì là done, không phải pending', () {
      final counts = {...mockupCounts, dateKey(DateTime(2026, 10, 29)): 1};
      expect(dayStatus(habit(), today, today, counts), DayStatus.done);
    });

    test('ngày không có lịch hoặc trước ngày bắt đầu là rest', () {
      final gym = habit(days: {1, 3, 5}); // T2, T4, T6
      expect(
        dayStatus(gym, DateTime(2026, 10, 27), today, {}),
        DayStatus.rest,
      ); // Thứ Ba
      expect(
        dayStatus(gym, DateTime(2026, 10, 28), today, {}),
        DayStatus.missed,
      ); // Thứ Tư
      expect(
        dayStatus(habit(), DateTime(2026, 9, 30), today, {}),
        DayStatus.rest, // trước ngày bắt đầu 01/10
      );
    });

    test('làm dở (chưa đủ mục tiêu) tính là bỏ lỡ', () {
      final water = habit(goal: 8);
      final counts = doneOn([20], count: 5);
      expect(
        dayStatus(water, DateTime(2026, 10, 20), today, counts),
        DayStatus.missed,
      );
      expect(
        dayStatus(water, DateTime(2026, 10, 21), today, doneOn([21], count: 8)),
        DayStatus.done,
      );
    });

    test('ngày chưa tới luôn là upcoming dù không có lịch', () {
      final gym = habit(days: {1, 3, 5});
      expect(
        dayStatus(gym, DateTime(2026, 10, 31), today, {}),
        DayStatus.upcoming,
      );
    });

    test('chỉ ô có lịch và không phải ngày chưa tới mới chạm được', () {
      DayCell cell(DayStatus s) => DayCell(DateTime(2026, 10, 1), s, 0);
      expect(cell(DayStatus.done).tappable, isTrue);
      expect(cell(DayStatus.missed).tappable, isTrue);
      expect(cell(DayStatus.pending).tappable, isTrue);
      expect(cell(DayStatus.upcoming).tappable, isFalse);
      expect(cell(DayStatus.rest).tappable, isFalse);
    });
  });

  group('toggledDayCount', () {
    test('chưa xong thì xong ngay cả mục tiêu, đã xong thì về 0', () {
      final water = habit(goal: 8);
      expect(toggledDayCount(water, 0), 8);
      expect(toggledDayCount(water, 5), 8);
      expect(toggledDayCount(water, 8), 0);
      expect(toggledDayCount(habit(), 0), 1);
      expect(toggledDayCount(habit(), 1), 0);
    });
  });

  group('monthGrid', () {
    test(
      'tháng 10/2026 bắt đầu Thứ Năm: 3 ô đệm đầu, tuần bắt đầu Thứ Hai',
      () {
        final grid = monthGrid(
          habit(),
          DateTime(2026, 10),
          today,
          mockupCounts,
          1,
        );

        expect(grid.every((row) => row.length == 7), isTrue);
        expect(grid.first.take(4).map((c) => c?.date.day), [
          null,
          null,
          null,
          1,
        ]);
        expect(grid.length, 5); // 3 + 31 = 34 ô -> 5 hàng
        final days = [
          for (final row in grid)
            for (final c in row)
              if (c != null) c.date.day,
        ];
        expect(days, [for (var d = 1; d <= 31; d++) d]);
      },
    );

    test('trạng thái từng ngày khớp mockup', () {
      final grid = monthGrid(
        habit(),
        DateTime(2026, 10),
        today,
        mockupCounts,
        1,
      );
      final byDay = {
        for (final row in grid)
          for (final c in row)
            if (c != null) c.date.day: c.status,
      };

      for (final missed in [3, 6, 10, 17]) {
        expect(byDay[missed], DayStatus.missed, reason: 'ngày $missed');
      }
      expect(byDay[1], DayStatus.done);
      expect(byDay[28], DayStatus.done);
      expect(byDay[29], DayStatus.pending);
      expect(byDay[30], DayStatus.upcoming);
      expect(byDay[31], DayStatus.upcoming);
    });

    test('tuần bắt đầu từ Chủ Nhật đổi số ô đệm', () {
      // 01/10/2026 là Thứ Năm: tuần bắt đầu CN thì có 4 ô đệm.
      final grid = monthGrid(habit(), DateTime(2026, 10), today, {}, 7);
      expect(grid.first.take(5).map((c) => c?.date.day), [
        null,
        null,
        null,
        null,
        1,
      ]);
    });

    test('tháng bắt đầu đúng ngày đầu tuần thì không có ô đệm đầu', () {
      // 01/06/2026 là Thứ Hai.
      final grid = monthGrid(
        habit(start: DateTime(2026, 1, 1)),
        DateTime(2026, 6),
        today,
        {},
        1,
      );
      expect(grid.first.first?.date, DateTime(2026, 6, 1));
    });

    test('tháng 2 năm nhuận có 29 ngày', () {
      final grid = monthGrid(
        habit(start: DateTime(2020, 1, 1)),
        DateTime(2028, 2),
        DateTime(2028, 3, 1),
        {},
        1,
      );
      final days = [
        for (final row in grid)
          for (final c in row)
            if (c != null) c.date.day,
      ];
      expect(days.length, 29);
    });

    test('ghi số lần đã làm vào ô', () {
      final grid = monthGrid(
        habit(goal: 8),
        DateTime(2026, 10),
        today,
        doneOn([20], count: 5),
        1,
      );
      final cell = [
        for (final row in grid)
          for (final c in row)
            if (c?.date.day == 20) c!,
      ].single;
      expect(cell.count, 5);
    });
  });

  group('tiêu đề và chuyển tháng', () {
    test('monthTitle', () {
      expect(monthTitle(DateTime(2026, 10)), 'Tháng 10, 2026');
      expect(monthTitle(DateTime(2026, 1, 15)), 'Tháng 1, 2026');
    });

    test('previousMonth và nextMonth qua đầu năm và cuối năm', () {
      expect(previousMonth(DateTime(2026, 1)), DateTime(2025, 12));
      expect(nextMonth(DateTime(2025, 12)), DateTime(2026, 1));
    });

    test('lùi tới tháng của ngày bắt đầu thì dừng', () {
      final h = habit(start: DateTime(2026, 8, 20));
      expect(canGoToPreviousMonth(h, DateTime(2026, 10)), isTrue);
      expect(canGoToPreviousMonth(h, DateTime(2026, 9)), isTrue);
      expect(canGoToPreviousMonth(h, DateTime(2026, 8)), isFalse);
    });

    test('tiến tới tháng hiện tại thì dừng', () {
      expect(canGoToNextMonth(DateTime(2026, 9), today), isTrue);
      expect(canGoToNextMonth(DateTime(2026, 10), today), isFalse);
    });

    test('weekdayHeaders theo ngày đầu tuần', () {
      expect(weekdayHeaders(1), ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']);
      expect(weekdayHeaders(7), ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7']);
    });
  });

  group('completionRate', () {
    test(
      'hôm nay nằm trong mẫu số kể cả khi chưa xong (25/29 = 86% như mockup)',
      () {
        // Mockup: tháng 10, 29 ngày từ 01/10 tới 29/10, 4 ngày bỏ lỡ, hôm nay xong.
        final counts = {...mockupCounts, dateKey(DateTime(2026, 10, 29)): 1};
        final c = completionRate(habit(), counts, today);
        expect((c.doneDays, c.scheduledDays), (25, 29));
        expect(c.percent, 86);
      },
    );

    test('hôm nay chưa xong thì tử số ít hơn 1', () {
      final c = completionRate(habit(), mockupCounts, today);
      expect((c.doneDays, c.scheduledDays), (24, 29));
      expect(c.percent, 83);
    });

    test('chỉ đếm ngày có lịch', () {
      final gym = habit(days: {1, 3, 5}); // T2, T4, T6
      final c = completionRate(gym, doneOn([5, 7]), today);
      // Từ 01/10 tới 29/10: 4 Thứ Hai (5, 12, 19, 26) + 4 Thứ Tư (7, 14, 21, 28)
      // + 4 Thứ Sáu (2, 9, 16, 23) = 12 ngày; đã làm 2 (05/10 và 07/10).
      expect(c.scheduledDays, 12);
      expect(c.doneDays, 2);
    });

    test('chưa tới ngày bắt đầu thì 0 và phần trăm 0', () {
      final c = completionRate(habit(start: DateTime(2026, 11, 5)), {}, today);
      expect((c.doneDays, c.scheduledDays, c.percent), (0, 0, 0));
    });
  });

  group('recentWeeks', () {
    test('4 tuần: ba tuần trước theo ngày đầu tuần và "Tuần này"', () {
      final weeks = recentWeeks(
        habit(start: DateTime(2026, 9, 1)),
        mockupCounts,
        today,
        1,
      );

      expect(weeks.map((w) => w.label), ['5/10', '12/10', '19/10', 'Tuần này']);
      expect(weeks.map((w) => w.isCurrent), [false, false, false, true]);
      expect(weeks.first.start, DateTime(2026, 10, 5));
    });

    test('tỷ lệ từng tuần', () {
      // Tuần 05-11/10: bỏ lỡ 06, 10 -> 5/7 ; tuần 12-18/10: bỏ lỡ 17 -> 6/7 ;
      // tuần 19-25/10: 7/7 ; tuần này (26-29/10): 26, 27, 28 xong, 29 chưa -> 3/4.
      final weeks = recentWeeks(
        habit(start: DateTime(2026, 9, 1)),
        mockupCounts,
        today,
        1,
      );

      expect(weeks.map((w) => w.percent), [71, 86, 100, 75]);
      expect(weeks.last.completion.scheduledDays, 4);
    });

    test('tuần này chỉ tính tới hôm nay', () {
      final weeks = recentWeeks(
        habit(start: DateTime(2026, 9, 1)),
        {},
        today,
        1,
      );
      expect(weeks.last.completion.scheduledDays, 4); // 26, 27, 28, 29
    });

    test('tuần chưa có ngày nào có lịch (trước ngày bắt đầu) là 0%', () {
      final weeks = recentWeeks(
        habit(start: DateTime(2026, 10, 20)),
        {},
        today,
        1,
      );
      expect(weeks.first.completion.scheduledDays, 0);
      expect(weeks.first.percent, 0);
    });

    test('tuần bắt đầu từ Chủ Nhật đổi các mốc', () {
      final weeks = recentWeeks(
        habit(start: DateTime(2026, 9, 1)),
        {},
        today,
        7,
      );
      expect(weeks.map((w) => w.label), ['4/10', '11/10', '18/10', 'Tuần này']);
      // Tuần này bắt đầu Chủ Nhật 25/10: 25, 26, 27, 28, 29 = 5 ngày.
      expect(weeks.last.completion.scheduledDays, 5);
    });

    test('thói quen theo thứ chỉ tính các thứ có lịch', () {
      final gym = habit(days: {1, 3, 5}, start: DateTime(2026, 9, 1));
      final weeks = recentWeeks(gym, doneOn([5, 7, 9]), today, 1);
      expect(weeks.first.completion.scheduledDays, 3);
      expect(weeks.first.percent, 100);
    });
  });

  group('detailSubtitle', () {
    test('mục tiêu nhiều lần kèm đơn vị và giờ nhắc', () {
      final water = habit(
        goal: 8,
        unit: 'ly',
        reminder: const TimeOfDay(hour: 20, minute: 0),
      );
      expect(detailSubtitle(water), 'Mỗi ngày · 8 ly · nhắc lúc 20:00');
    });

    test('mục tiêu 1 lần không ghi số lần', () {
      expect(detailSubtitle(habit()), 'Mỗi ngày');
      expect(
        detailSubtitle(habit(reminder: const TimeOfDay(hour: 22, minute: 30))),
        'Mỗi ngày · nhắc lúc 22:30',
      );
    });

    test('theo thứ, nhiều lần không có đơn vị ghi "lần"', () {
      expect(
        detailSubtitle(habit(days: {1, 3, 5}, goal: 3)),
        'T2 · T4 · T6 · 3 lần',
      );
    });
  });

  test('countsByKey gom nhật ký theo khóa ngày', () {
    final counts = countsByKey([
      HabitLog(habitId: 'h', date: DateTime(2026, 10, 5), count: 2),
      HabitLog(habitId: 'h', date: DateTime(2026, 10, 6), count: 1),
    ]);
    expect(counts, {'2026-10-05': 2, '2026-10-06': 1});
  });
}
