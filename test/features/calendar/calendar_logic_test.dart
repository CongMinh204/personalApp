import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/features/calendar/calendar_logic.dart';
import 'package:personal_app/utils/vi_date.dart';

import '../tasks/tasks_test_env.dart';

void main() {
  // testNow: Thứ Năm 29/10/2026 13:40.
  final today = DateTime(2026, 10, 29);

  Task timed(String id, DateTime start, {DateTime? end, bool done = false}) =>
      testTask(id, due: start, end: end, hasTime: true, done: done);

  group('lưới ngày', () {
    test('khoảng đọc việc: cả tháng thêm 7 ngày mỗi phía', () {
      expect(
        calendarQueryRange(DateTime(2026, 10, 29)),
        DateTimeRange(start: DateTime(2026, 9, 24), end: DateTime(2026, 11, 8)),
      );
      // Mọi ngày trong tháng cho cùng một khoảng: chỉ đọc lại khi sang tháng.
      expect(
        calendarQueryRange(DateTime(2026, 10, 1)),
        calendarQueryRange(DateTime(2026, 10, 31)),
      );
    });

    test('tháng 10/2026, tuần bắt đầu Thứ Hai: 5 hàng từ 28/9 tới 1/11', () {
      final days = monthGridDays(DateTime(2026, 10, 29), 1);
      expect(days, hasLength(35));
      expect(days.first, DateTime(2026, 9, 28));
      expect(days.last, DateTime(2026, 11, 1));
      expect(days.first.weekday, DateTime.monday);
    });

    test('tuần bắt đầu Chủ Nhật: từ 27/9 tới 31/10', () {
      final days = monthGridDays(DateTime(2026, 10, 1), 7);
      expect(days, hasLength(35));
      expect(days.first, DateTime(2026, 9, 27));
      expect(days.last, DateTime(2026, 10, 31));
      expect(days.first.weekday, DateTime.sunday);
    });

    test('tháng 2/2027 vừa đúng 4 hàng, tháng 8/2026 cần 6 hàng', () {
      final february = monthGridDays(DateTime(2027, 2), 1);
      expect(february, hasLength(28));
      expect(february.first, DateTime(2027, 2, 1));
      expect(february.last, DateTime(2027, 2, 28));

      final august = monthGridDays(DateTime(2026, 8, 15), 1);
      expect(august, hasLength(42));
      expect(august.first, DateTime(2026, 7, 27));
      expect(august.last, DateTime(2026, 9, 6));
    });

    test('các ngày liên tiếp, không trùng (kể cả qua đổi giờ mùa hè)', () {
      final days = monthGridDays(DateTime(2026, 3), 1);
      for (var i = 1; i < days.length; i++) {
        final prev = days[i - 1];
        expect(
          days[i],
          DateTime(prev.year, prev.month, prev.day + 1),
          reason: '$i',
        );
      }
    });

    test('tuần chứa một ngày theo ngày đầu tuần', () {
      expect(weekDays(DateTime(2026, 10, 29), 1), [
        for (var d = 26; d <= 31; d++) DateTime(2026, 10, d),
        DateTime(2026, 11, 1),
      ]);
      expect(weekDays(DateTime(2026, 10, 29), 7), [
        for (var d = 25; d <= 31; d++) DateTime(2026, 10, d),
      ]);
    });

    test('hàng tiêu đề thứ theo ngày đầu tuần', () {
      expect(weekdayHeaders(1), ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']);
      expect(weekdayHeaders(7), ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7']);
      expect(monthTitle(DateTime(2026, 10, 29)), 'Tháng 10, 2026');
    });
  });

  group('◀ ▶', () {
    test('xem tháng: sang tháng khác thì chọn ngày 1', () {
      expect(
        shiftSelection(today, CalendarMode.month, 1, today),
        DateTime(2026, 11, 1),
      );
      expect(
        shiftSelection(today, CalendarMode.month, -1, today),
        DateTime(2026, 9, 1),
      );
      // 31/1 sang tháng 2 không bị tràn sang tháng 3.
      expect(
        shiftSelection(DateTime(2027, 1, 31), CalendarMode.month, 1, today),
        DateTime(2027, 2, 1),
      );
      expect(
        shiftSelection(DateTime(2026, 12, 15), CalendarMode.month, 1, today),
        DateTime(2027, 1, 1),
      );
    });

    test('xem tháng: quay về tháng hiện tại thì chọn hôm nay', () {
      expect(
        shiftSelection(DateTime(2026, 11, 1), CalendarMode.month, -1, testNow),
        today,
      );
    });

    test('xem tuần: lùi hoặc tiến đúng 7 ngày', () {
      expect(
        shiftSelection(today, CalendarMode.week, 1, today),
        DateTime(2026, 11, 5),
      );
      expect(
        shiftSelection(today, CalendarMode.week, -1, today),
        DateTime(2026, 10, 22),
      );
    });
  });

  group('việc của ngày', () {
    test('tiêu đề ngày và số việc', () {
      expect(dayTitle(today, testNow), 'Hôm nay · Thứ Năm, 29/10');
      expect(dayTitle(DateTime(2026, 10, 31), testNow), 'Thứ Bảy, 31/10');
      expect(dayTitle(DateTime(2026, 11, 5), testNow), 'Thứ Năm, 5/11');
      expect(dayCountLabel(0), '');
      expect(dayCountLabel(3), '3 việc');
    });

    test('gom việc theo ngày hẹn, bỏ việc không có ngày', () {
      final noDate = Task(
        id: 'no-date',
        title: 'Không ngày',
        createdAt: DateTime(2026, 10, 1),
      );
      final byDay = tasksByDay([
        testTask('a'),
        timed('b', DateTime(2026, 10, 29, 23, 59)),
        testTask('c', due: DateTime(2026, 10, 30)),
        noDate,
      ]);
      expect(byDay.keys, unorderedEquals(['2026-10-29', '2026-10-30']));
      expect(byDay['2026-10-29']!.map((t) => t.id), ['a', 'b']);
      expect(byDay['2026-10-30']!.map((t) => t.id), ['c']);
    });

    test('danh sách: chưa xong trước, có giờ theo giờ, cả ngày ở cuối', () {
      final sorted = sortDayTasks([
        timed('running', DateTime(2026, 10, 29, 6), done: true),
        testTask('all-day'),
        timed('pe', DateTime(2026, 10, 29, 19, 30)),
        timed('exe', DateTime(2026, 10, 29, 14)),
        testTask('groceries', done: true),
      ]);
      expect(sorted.map((t) => t.id), [
        'exe',
        'pe',
        'all-day',
        'running',
        'groceries',
      ]);
    });

    test('nhãn giờ trong danh sách', () {
      expect(
        calendarTimeLabel(
          timed(
            'a',
            DateTime(2026, 10, 29, 14),
            end: DateTime(2026, 10, 29, 15),
          ),
        ),
        '14:00 – 15:00',
      );
      expect(calendarTimeLabel(timed('b', DateTime(2026, 10, 31, 8))), '08:00');
      expect(calendarTimeLabel(testTask('c')), 'Cả ngày');
    });

    test('quá hạn: chưa xong và ngày hẹn trước hôm nay', () {
      expect(
        isOverdue(timed('a', DateTime(2026, 10, 28, 23, 59)), testNow),
        isTrue,
      );
      expect(
        isOverdue(
          timed('b', DateTime(2026, 10, 28, 23, 59), done: true),
          testNow,
        ),
        isFalse,
      );
      // Việc hôm nay đã qua giờ vẫn chưa tính là quá hạn (như màn Hôm nay).
      expect(
        isOverdue(timed('c', DateTime(2026, 10, 29, 9)), testNow),
        isFalse,
      );
      expect(
        isOverdue(testTask('d', due: DateTime(2026, 11, 1)), testNow),
        isFalse,
      );
    });
  });

  group('dải giờ', () {
    test('không có việc có giờ thì không có dải giờ', () {
      expect(buildTimeline([testTask('a')], today), isNull);
      expect(buildTimeline(const [], today), isNull);
    });

    test(
      'ngày mẫu: từ 1 giờ trước việc sớm nhất tới 1 giờ sau việc muộn nhất',
      () {
        final timeline = buildTimeline(
          [
            timed('running', DateTime(2026, 10, 29, 6), done: true),
            timed(
              'exe',
              DateTime(2026, 10, 29, 14),
              end: DateTime(2026, 10, 29, 15),
            ),
            timed(
              'pe',
              DateTime(2026, 10, 29, 19, 30),
              end: DateTime(2026, 10, 29, 21),
            ),
            testTask('groceries'),
          ],
          today,
          now: testNow,
        )!;
        expect(timeline.firstHour, 5);
        expect(timeline.lastHour, 22);
        expect(timeline.hours, 17);
        expect(timeline.blocks.map((b) => b.task.id), ['running', 'exe', 'pe']);
        expect(timeline.blocks.map((b) => (b.start, b.end)), [
          (6.0, 6.5),
          (14.0, 15.0),
          (19.5, 21.0),
        ]);
        expect(timeline.blocks.every((b) => b.columns == 1), isTrue);
      },
    );

    test(
      'việc chỉ có giờ bắt đầu, quá ngắn hoặc giờ kết thúc sai: 30 phút',
      () {
        final timeline = buildTimeline([
          timed('start-only', DateTime(2026, 10, 29, 8)),
          timed(
            'short',
            DateTime(2026, 10, 29, 10),
            end: DateTime(2026, 10, 29, 10, 10),
          ),
          timed(
            'wrong',
            DateTime(2026, 10, 29, 12),
            end: DateTime(2026, 10, 29, 11),
          ),
        ], today)!;
        expect(timeline.blocks.map((b) => (b.start, b.end)), [
          (8.0, 8.5),
          (10.0, 10.5),
          (12.0, 12.5),
        ]);
      },
    );

    test('việc kéo sang ngày sau bị cắt ở 24:00', () {
      final timeline = buildTimeline([
        timed(
          'late',
          DateTime(2026, 10, 29, 23),
          end: DateTime(2026, 10, 30, 1),
        ),
        timed('last', DateTime(2026, 10, 29, 23, 45)),
      ], today)!;
      expect(timeline.blocks.map((b) => (b.start, b.end)), [
        (23.0, 24.0),
        (23.75, 24.0),
      ]);
      expect(timeline.firstHour, 22);
      expect(timeline.lastHour, 24);
    });

    test('chỉ lấy việc có giờ của đúng ngày đó', () {
      final timeline = buildTimeline([
        timed('today', DateTime(2026, 10, 29, 9)),
        timed('tomorrow', DateTime(2026, 10, 30, 9)),
        testTask('all-day'),
      ], today)!;
      expect(timeline.blocks.map((b) => b.task.id), ['today']);
    });

    test('việc trùng giờ chia cột, nhóm không trùng thì một cột', () {
      final timeline = buildTimeline([
        timed('a', DateTime(2026, 10, 29, 9), end: DateTime(2026, 10, 29, 11)),
        timed('b', DateTime(2026, 10, 29, 10), end: DateTime(2026, 10, 29, 12)),
        // Bắt đầu đúng lúc a kết thúc: dùng lại cột của a.
        timed(
          'c',
          DateTime(2026, 10, 29, 11),
          end: DateTime(2026, 10, 29, 12, 30),
        ),
        timed('d', DateTime(2026, 10, 29, 13), end: DateTime(2026, 10, 29, 14)),
      ], today)!;
      final byId = {for (final b in timeline.blocks) b.task.id: b};
      expect((byId['a']!.column, byId['a']!.columns), (0, 2));
      expect((byId['b']!.column, byId['b']!.columns), (1, 2));
      expect((byId['c']!.column, byId['c']!.columns), (0, 2));
      expect((byId['d']!.column, byId['d']!.columns), (0, 1));
    });

    test('cùng giờ bắt đầu: việc dài hơn ở cột trái', () {
      final timeline = buildTimeline([
        timed(
          'short',
          DateTime(2026, 10, 29, 9),
          end: DateTime(2026, 10, 29, 10),
        ),
        timed(
          'long',
          DateTime(2026, 10, 29, 9),
          end: DateTime(2026, 10, 29, 11),
        ),
      ], today)!;
      final byId = {for (final b in timeline.blocks) b.task.id: b};
      expect(byId['long']!.column, 0);
      expect(byId['short']!.column, 1);
    });

    test('hôm nay: dải giờ mở rộng để có vạch giờ hiện tại', () {
      final evening = timed(
        'pe',
        DateTime(2026, 10, 29, 19, 30),
        end: DateTime(2026, 10, 29, 21),
      );
      expect(buildTimeline([evening], today)!.firstHour, 18);
      // 13:40 thì dải giờ bắt đầu từ 13:00.
      expect(buildTimeline([evening], today, now: testNow)!.firstHour, 13);
      // 23:30 thì dải giờ kéo tới 24:00.
      final lateNow = DateTime(2026, 10, 29, 23, 30);
      expect(buildTimeline([evening], today, now: lateNow)!.lastHour, 24);
      // Xem ngày khác thì không mở rộng.
      expect(
        buildTimeline(
          [evening],
          today,
          now: DateTime(2026, 10, 28, 8),
        )!.firstHour,
        18,
      );
    });
  });
}
