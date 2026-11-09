import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/models/focus_session.dart';
import 'package:personal_app/features/focus_history/focus_history_logic.dart';
import 'package:personal_app/utils/dates.dart';

void main() {
  // Thứ Năm 29/10/2026 13:40.
  final now = DateTime(2026, 10, 29, 13, 40);

  FocusSession session(
    String id,
    DateTime startedAt, {
    int minutes = 25,
    bool completed = true,
    FocusType type = FocusType.pomodoro,
    String? taskId,
  }) => FocusSession(
    id: id,
    taskId: taskId,
    type: type,
    startedAt: startedAt,
    durationSec: minutes * 60,
    completed: completed,
  );

  group('startOfWeek và weekRange', () {
    test('tuần bắt đầu từ Thứ Hai', () {
      // Thứ Năm 29/10 -> Thứ Hai 26/10.
      expect(
        startOfWeek(DateTime(2026, 10, 29, 15), 1),
        DateTime(2026, 10, 26),
      );
      // Chính Thứ Hai thì giữ nguyên.
      expect(startOfWeek(DateTime(2026, 10, 26, 9), 1), DateTime(2026, 10, 26));
      // Chủ Nhật 01/11 thuộc tuần bắt đầu 26/10.
      expect(startOfWeek(DateTime(2026, 11, 1), 1), DateTime(2026, 10, 26));
    });

    test('tuần bắt đầu từ Chủ Nhật', () {
      // Thứ Năm 29/10 -> Chủ Nhật 25/10.
      expect(startOfWeek(DateTime(2026, 10, 29), 7), DateTime(2026, 10, 25));
      expect(startOfWeek(DateTime(2026, 10, 25), 7), DateTime(2026, 10, 25));
      // Thứ Bảy 31/10 vẫn thuộc tuần bắt đầu 25/10.
      expect(startOfWeek(DateTime(2026, 10, 31), 7), DateTime(2026, 10, 25));
    });

    test('qua đầu tháng và đầu năm', () {
      expect(startOfWeek(DateTime(2026, 11, 2), 1), DateTime(2026, 11, 2));
      expect(startOfWeek(DateTime(2026, 1, 1), 1), DateTime(2025, 12, 29));
    });

    test('weekRange gồm 7 ngày, end không tính', () {
      final r = weekRange(DateTime(2026, 10, 29), 1);
      expect(r.start, DateTime(2026, 10, 26));
      expect(r.end, DateTime(2026, 11, 2));
    });
  });

  group('kỳ hiện tại, kỳ lớn hơn và khoảng đọc', () {
    test('kỳ hiện tại của từng tab', () {
      expect(
        currentPeriod(HistoryRange.day, now, 1),
        DateTimeRange(
          start: DateTime(2026, 10, 29),
          end: DateTime(2026, 10, 30),
        ),
      );
      expect(
        currentPeriod(HistoryRange.week, now, 1),
        DateTimeRange(
          start: DateTime(2026, 10, 26),
          end: DateTime(2026, 11, 2),
        ),
      );
      expect(
        currentPeriod(HistoryRange.month, now, 1),
        DateTimeRange(start: DateTime(2026, 10), end: DateTime(2026, 11)),
      );
    });

    test('kỳ lớn hơn: tuần này, tháng này, năm nay', () {
      expect(
        biggerPeriod(HistoryRange.day, now, 1),
        DateTimeRange(
          start: DateTime(2026, 10, 26),
          end: DateTime(2026, 11, 2),
        ),
      );
      expect(
        biggerPeriod(HistoryRange.week, now, 1),
        DateTimeRange(start: DateTime(2026, 10), end: DateTime(2026, 11)),
      );
      expect(
        biggerPeriod(HistoryRange.month, now, 1),
        DateTimeRange(start: DateTime(2026), end: DateTime(2027)),
      );
    });

    test('nhãn ô tóm tắt thứ ba theo tab', () {
      expect(HistoryRange.day.biggerPeriodLabel, 'Tuần này');
      expect(HistoryRange.week.biggerPeriodLabel, 'Tháng này');
      expect(HistoryRange.month.biggerPeriodLabel, 'Năm nay');
    });

    test('khoảng đọc: 30 ngày, 12 tuần, 12 tháng gần nhất', () {
      final day = visibleWindow(HistoryRange.day, now, 1);
      expect(day.start, DateTime(2026, 9, 30)); // 30 ngày kể cả hôm nay
      expect(day.end, DateTime(2026, 10, 30));

      final week = visibleWindow(HistoryRange.week, now, 1);
      expect(week.start, DateTime(2026, 8, 10)); // 12 tuần kể cả tuần này
      expect(week.end, DateTime(2026, 11, 2));

      final month = visibleWindow(HistoryRange.month, now, 1);
      expect(month.start, DateTime(2025, 11)); // 12 tháng kể cả tháng này
      expect(month.end, DateTime(2026, 11));
    });
  });

  group('groupSessions', () {
    test('gom theo ngày, ngày mới nhất trước, phiên mới nhất trước', () {
      final groups = groupSessions(
        [
          session('a', DateTime(2026, 10, 28, 20)),
          session('b', DateTime(2026, 10, 29, 9, 5)),
          session('c', DateTime(2026, 10, 29, 10, 15)),
          session('d', DateTime(2026, 10, 29, 13, 10)),
        ],
        HistoryRange.day,
        now,
        1,
      );

      expect(groups.map((g) => g.title), [
        'Hôm nay · Th 5, 29/10',
        'Hôm qua · Th 4, 28/10',
      ]);
      expect(groups[0].sessions.map((s) => s.id), ['d', 'c', 'b']);
      expect(groups[1].sessions.map((s) => s.id), ['a']);
    });

    test('phiên nghỉ bị bỏ, phiên Tùy chỉnh được giữ', () {
      final groups = groupSessions(
        [
          session('tt', DateTime(2026, 10, 29, 9)),
          session(
            'ng',
            DateTime(2026, 10, 29, 9, 30),
            type: FocusType.shortBreak,
          ),
          session('nd', DateTime(2026, 10, 29, 10), type: FocusType.longBreak),
          session('tc', DateTime(2026, 10, 29, 11), type: FocusType.custom),
        ],
        HistoryRange.day,
        now,
        1,
      );

      expect(groups.single.sessions.map((s) => s.id), ['tc', 'tt']);
    });

    test('tên ngày cũ hơn không có "Hôm nay"/"Hôm qua"', () {
      final groups = groupSessions(
        [
          session('a', DateTime(2026, 10, 27, 8)),
          session('b', DateTime(2026, 10, 25, 8)),
        ],
        HistoryRange.day,
        now,
        1,
      );

      expect(groups.map((g) => g.title), ['Th 3, 27/10', 'CN, 25/10']);
    });

    test('gom theo tuần, tuần bắt đầu từ Thứ Hai', () {
      final groups = groupSessions(
        [
          session('a', DateTime(2026, 10, 29, 9)), // tuần này (26/10 - 01/11)
          session('b', DateTime(2026, 10, 26, 7)), // tuần này, Thứ Hai
          session(
            'c',
            DateTime(2026, 10, 25, 22),
          ), // tuần trước (19/10 - 25/10)
          session('d', DateTime(2026, 10, 10, 8)), // cũ hơn
        ],
        HistoryRange.week,
        now,
        1,
      );

      expect(groups.map((g) => g.title), [
        'Tuần này · 26/10 – 01/11',
        'Tuần trước · 19/10 – 25/10',
        '05/10 – 11/10',
      ]);
      expect(groups[0].sessions.map((s) => s.id), ['a', 'b']);
    });

    test('tuần bắt đầu từ Chủ Nhật đổi cách gom', () {
      final sessions = [
        session('a', DateTime(2026, 10, 29, 9)),
        session('b', DateTime(2026, 10, 25, 9)), // Chủ Nhật
      ];

      expect(groupSessions(sessions, HistoryRange.week, now, 1).length, 2);
      final sunday = groupSessions(sessions, HistoryRange.week, now, 7);
      expect(sunday.length, 1); // cùng tuần 25/10 - 31/10
      expect(sunday.single.title, 'Tuần này · 25/10 – 31/10');
    });

    test('gom theo tháng', () {
      final groups = groupSessions(
        [
          session('a', DateTime(2026, 10, 1, 8)),
          session('b', DateTime(2026, 10, 29, 8)),
          session('c', DateTime(2026, 9, 30, 8)),
          session('d', DateTime(2025, 12, 5, 8)),
        ],
        HistoryRange.month,
        now,
        1,
      );

      expect(groups.map((g) => g.title), [
        'Tháng này · Tháng 10/2026',
        'Tháng 9/2026',
        'Tháng 12/2025',
      ]);
      expect(groups[0].sessions.map((s) => s.id), ['b', 'a']);
    });

    test('phiên tính vào nhóm của lúc bắt đầu (qua nửa đêm)', () {
      final groups = groupSessions(
        [session('a', DateTime(2026, 10, 28, 23, 50), minutes: 25)],
        HistoryRange.day,
        now,
        1,
      );

      expect(groups.single.title, 'Hôm qua · Th 4, 28/10');
    });

    test('tổng thời gian tập trung của nhóm', () {
      final groups = groupSessions(
        [
          session('a', DateTime(2026, 10, 29, 9), minutes: 25),
          session(
            'b',
            DateTime(2026, 10, 29, 10),
            minutes: 12,
            completed: false,
          ),
        ],
        HistoryRange.day,
        now,
        1,
      );

      expect(groups.single.focusSeconds, 37 * 60);
    });

    test('không có phiên nào thì không có nhóm', () {
      expect(groupSessions([], HistoryRange.day, now, 1), isEmpty);
    });
  });

  group('summarize và sessionsStartingIn', () {
    test('đếm phiên, hoàn thành và tổng thời gian (kể cả bỏ dở)', () {
      final s = summarize([
        session('a', DateTime(2026, 10, 29, 9), minutes: 25),
        session('b', DateTime(2026, 10, 29, 10), minutes: 25),
        session('c', DateTime(2026, 10, 29, 13), minutes: 12, completed: false),
      ]);

      expect(s.sessions, 3);
      expect(s.completed, 2);
      expect(s.focusSeconds, 62 * 60);
    });

    test('phiên nghỉ không tính', () {
      final s = summarize([
        session('a', DateTime(2026, 10, 29, 9)),
        session(
          'b',
          DateTime(2026, 10, 29, 9, 30),
          minutes: 5,
          type: FocusType.shortBreak,
        ),
      ]);

      expect((s.sessions, s.completed, s.focusSeconds), (1, 1, 25 * 60));
    });

    test('rỗng thì toàn số 0', () {
      final s = summarize([]);
      expect((s.sessions, s.completed, s.focusSeconds), (0, 0, 0));
    });

    test('sessionsStartingIn chỉ giữ phiên bắt đầu trong khoảng (gồm start, không gồm end)', () {
      final range = dayRange(DateTime(2026, 10, 29));
      final inside = sessionsStartingIn([
        session('truoc', DateTime(2026, 10, 28, 23, 59)),
        session('dau', DateTime(2026, 10, 29)),
        session('giua', DateTime(2026, 10, 29, 12)),
        session('sau', DateTime(2026, 10, 30)),
      ], range);

      expect(inside.map((s) => s.id), ['dau', 'giua']);
    });
  });

  group('định dạng thời lượng', () {
    test('formatFocusTotal', () {
      expect(formatFocusTotal(0), '0p');
      expect(formatFocusTotal(25 * 60), '25p');
      expect(formatFocusTotal(62 * 60), '1g 02p');
      expect(formatFocusTotal((6 * 60 + 40) * 60), '6g 40p');
      expect(formatFocusTotal(60 * 60), '1g 00p');
    });

    test('formatFocusTotal làm tròn tới phút gần nhất', () {
      expect(formatFocusTotal(89), '1p');
      expect(formatFocusTotal(90), '2p');
    });

    test('formatSessionDuration: dưới 1 phút ghi <1p', () {
      expect(formatSessionDuration(0), '<1p');
      expect(formatSessionDuration(59), '<1p');
      expect(formatSessionDuration(60), '1p');
      expect(formatSessionDuration(25 * 60), '25p');
      expect(formatSessionDuration(65 * 60), '1g 05p');
    });
  });

  test('shortDayLabel: Thứ Hai là Th 2, Chủ Nhật là CN', () {
    expect(shortDayLabel(DateTime(2026, 10, 26)), 'Th 2, 26/10');
    expect(shortDayLabel(DateTime(2026, 10, 29)), 'Th 5, 29/10');
    expect(shortDayLabel(DateTime(2026, 10, 31)), 'Th 7, 31/10');
    expect(shortDayLabel(DateTime(2026, 11, 1)), 'CN, 01/11');
  });
}
