import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/default_tags.dart';
import 'package:personal_app/data/fake/sample_data.dart';
import 'package:personal_app/data/models/tag.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/features/stats/stats_logic.dart';

import '../tasks/tasks_test_env.dart';

// Dữ liệu mẫu theo testNow (Thứ Năm 29/10/2026 13:40), 8 việc đã xong:
// - 23/10 Lab 2 (có giờ, đúng hạn), 24/10 Đọc chương 5 (cả ngày, đúng hạn),
// - 26/10 Dọn phòng (hạn 25/10, trễ), 27/10 Báo cáo EXE201 (đúng hạn) và
//   Chạy bộ (06:00, xong 06:35: trễ), 28/10 Chạy bộ (trễ),
// - 29/10 Chạy bộ (trễ) và Mua sữa và trứng (cả ngày, đúng hạn).
// Đang quá hạn: Lab 3 (28/10) và Gia hạn thẻ thư viện (26/10).
void main() {
  final sample = [...sampleTasks(testNow), ...sampleHistoryTasks(testNow)];
  final tagById = {for (final tag in defaultTags) tag.id: tag};

  DateTimeRange range(DateTime start, DateTime end) =>
      DateTimeRange(start: start, end: end);

  /// Việc đã xong lúc [completedAt].
  Task done(
    String id,
    DateTime completedAt, {
    DateTime? due,
    DateTime? end,
    bool hasTime = false,
    String? tagId,
  }) => Task(
    id: id,
    title: 'Việc $id',
    tagId: tagId,
    due: due,
    end: end,
    hasTime: hasTime,
    done: true,
    completedAt: completedAt,
    createdAt: DateTime(2026, 1, 1),
  );

  group('kỳ và kỳ so sánh', () {
    test('kỳ luôn kết thúc ở hết hôm nay', () {
      expect(
        periodRange(StatsPeriod.week, testNow),
        range(DateTime(2026, 10, 23), DateTime(2026, 10, 30)),
      );
      expect(
        periodRange(StatsPeriod.month, testNow),
        range(DateTime(2026, 10, 1), DateTime(2026, 10, 30)),
      );
      expect(
        periodRange(StatsPeriod.year, testNow),
        range(DateTime(2026, 1, 1), DateTime(2026, 10, 30)),
      );
    });

    test('kỳ so sánh có cùng độ dài', () {
      expect(
        previousRange(StatsPeriod.week, testNow),
        range(DateTime(2026, 10, 16), DateTime(2026, 10, 23)),
      );
      expect(
        previousRange(StatsPeriod.month, testNow),
        range(DateTime(2026, 9, 1), DateTime(2026, 9, 30)),
      );
      expect(
        previousRange(StatsPeriod.year, testNow),
        range(DateTime(2025, 1, 1), DateTime(2025, 10, 30)),
      );
    });

    test('cùng kỳ tháng trước: tháng trước ngắn hơn thì tới hết tháng đó', () {
      expect(
        previousRange(StatsPeriod.month, DateTime(2026, 3, 31, 9)),
        range(DateTime(2026, 2, 1), DateTime(2026, 3, 1)),
      );
      // Tháng 1 so với tháng 12 năm trước.
      expect(
        previousRange(StatsPeriod.month, DateTime(2027, 1, 15)),
        range(DateTime(2026, 12, 1), DateTime(2026, 12, 16)),
      );
    });

    test('cùng kỳ năm trước: 29/2 so với tới hết 28/2 năm trước', () {
      expect(
        previousRange(StatsPeriod.year, DateTime(2028, 2, 29)),
        range(DateTime(2027, 1, 1), DateTime(2027, 3, 1)),
      );
    });

    test('dòng so sánh', () {
      expect(comparisonLabel(StatsPeriod.week, 8, 0), '+8 so với tuần trước');
      expect(
        comparisonLabel(StatsPeriod.month, 3, 5),
        '−2 so với cùng kỳ tháng trước',
      );
      expect(comparisonLabel(StatsPeriod.year, 4, 4), 'Bằng cùng kỳ năm trước');
    });
  });

  group('việc hoàn thành và đúng hạn', () {
    test('chỉ đếm việc đã xong có thời điểm xong trong kỳ', () {
      final week = periodRange(StatsPeriod.week, testNow);
      expect(completedIn(sample, week), hasLength(8));
      expect(
        completedIn([
          done('in', DateTime(2026, 10, 23)),
          done('before', DateTime(2026, 10, 22, 23, 59)),
          testTask('not-done'),
        ], week).map((t) => t.id),
        ['in'],
      );
    });

    test('việc có giờ: xong trước giờ kết thúc là đúng hạn', () {
      final due = DateTime(2026, 10, 29, 14);
      final end = DateTime(2026, 10, 29, 15);
      bool? at(DateTime completedAt) => finishedOnTime(
        done('a', completedAt, due: due, end: end, hasTime: true),
      );
      expect(at(DateTime(2026, 10, 29, 9)), isTrue);
      expect(at(DateTime(2026, 10, 29, 14, 30)), isTrue);
      expect(at(end), isTrue);
      expect(at(DateTime(2026, 10, 29, 15, 1)), isFalse);
    });

    test('việc có giờ, không có giờ kết thúc: xong trước giờ bắt đầu', () {
      final due = DateTime(2026, 10, 29, 6);
      expect(
        finishedOnTime(
          done('a', DateTime(2026, 10, 29, 6, 40), due: due, hasTime: true),
        ),
        isFalse,
      );
      expect(
        finishedOnTime(
          done('b', DateTime(2026, 10, 29, 5, 59), due: due, hasTime: true),
        ),
        isTrue,
      );
      // Giờ kết thúc không sau giờ bắt đầu thì coi như không có.
      expect(
        finishedOnTime(
          done(
            'c',
            DateTime(2026, 10, 29, 6, 30),
            due: due,
            end: DateTime(2026, 10, 29, 5),
            hasTime: true,
          ),
        ),
        isFalse,
      );
    });

    test('việc cả ngày: xong trước khi hết ngày hẹn', () {
      final due = DateTime(2026, 10, 25);
      expect(
        finishedOnTime(done('a', DateTime(2026, 10, 25, 23, 59), due: due)),
        isTrue,
      );
      expect(
        finishedOnTime(done('b', DateTime(2026, 10, 24, 8), due: due)),
        isTrue,
      );
      expect(
        finishedOnTime(done('c', DateTime(2026, 10, 26, 9), due: due)),
        isFalse,
      );
    });

    test('việc không có ngày hoặc chưa xong thì không tính', () {
      expect(finishedOnTime(done('a', DateTime(2026, 10, 29))), isNull);
      expect(finishedOnTime(testTask('b')), isNull);
    });

    test('dữ liệu mẫu 7 ngày: 4/8 việc đúng hạn = 50%', () {
      final rate = onTimeRate(
        completedIn(sample, periodRange(StatsPeriod.week, testNow)),
      );
      expect((rate.onTime, rate.counted), (4, 8));
      expect(rate.label, '50%');
    });

    test('chưa có việc nào để tính thì ghi "–"', () {
      final rate = onTimeRate([done('a', DateTime(2026, 10, 29))]);
      expect(rate.counted, 0);
      expect(rate.percent, isNull);
      expect(rate.label, '–');
    });

    test('đang quá hạn: đếm như nhóm Quá hạn ở Hôm nay', () {
      expect(overdueCount(sample, testNow), 2);
      expect(overdueLabel(2), '2 việc đang quá hạn');
      expect(overdueLabel(0), 'Không có việc quá hạn');
    });
  });

  group('ngày liên tiếp', () {
    List<Task> doneOn(List<DateTime> days) => [
      for (final (i, day) in days.indexed) done('d$i', day),
    ];

    test('dữ liệu mẫu: 26–29/10 liên tiếp (25/10 không có việc xong)', () {
      final streak = doneStreak(sample, testNow);
      expect((streak.current, streak.best), (4, 4));
    });

    test('hôm nay chưa xong việc nào: chuỗi tính tới hôm qua, chưa đứt', () {
      final streak = doneStreak(
        doneOn([
          DateTime(2026, 10, 26, 8),
          DateTime(2026, 10, 27, 8),
          DateTime(2026, 10, 28, 22),
        ]),
        testNow,
      );
      expect(streak.current, 3);
    });

    test('hôm qua và hôm nay đều không có: chuỗi về 0, kỷ lục vẫn giữ', () {
      final streak = doneStreak(
        doneOn([
          for (var d = 1; d <= 10; d++) DateTime(2026, 10, d, 9),
          DateTime(2026, 10, 20, 9),
        ]),
        testNow,
      );
      expect((streak.current, streak.best), (0, 10));
    });

    test('nhiều việc trong một ngày chỉ tính một ngày; qua tháng vẫn liền', () {
      final streak = doneStreak(
        doneOn([
          DateTime(2026, 9, 30, 8),
          DateTime(2026, 10, 1, 8),
          DateTime(2026, 10, 1, 20),
          DateTime(2026, 10, 29, 8),
        ]),
        testNow,
      );
      expect((streak.current, streak.best), (1, 2));
    });

    test('chưa xong việc nào', () {
      final streak = doneStreak([testTask('a')], testNow);
      expect((streak.current, streak.best), (0, 0));
    });
  });

  group('biểu đồ', () {
    test('số thập phân kiểu Việt', () {
      expect(formatDecimal(4.6), '4,6');
      expect(formatDecimal(8 / 7), '1,1');
      expect(formatDecimal(5), '5');
      expect(formatDecimal(0), '0');
      expect(formatDecimal(1.96), '2');
    });

    test('7 ngày: 7 cột theo ngày, cột cuối là hôm nay', () {
      final chart = doneChart(StatsPeriod.week, sample, testNow);
      expect(chart.title, 'Việc hoàn thành mỗi ngày');
      expect(chart.bars.map((b) => b.label), [
        'T6',
        'T7',
        'CN',
        'T2',
        'T3',
        'T4',
        'Nay',
      ]);
      expect(chart.bars.map((b) => b.value), [1, 1, 0, 1, 2, 1, 2]);
      expect(chart.bars.map((b) => b.isCurrent), [
        ...List.filled(6, false),
        true,
      ]);
      expect(chart.bars.any((b) => b.isFuture), isFalse);
      expect(chart.averageLabel, 'TB 1,1/ngày');
      expect(chart.showValues, isTrue);
      expect(
        chart.semanticsLabel,
        'Biểu đồ cột: Thứ Sáu 1, Thứ Bảy 1, Chủ Nhật 0, Thứ Hai 1, '
        'Thứ Ba 2, Thứ Tư 1, hôm nay 2 việc',
      );
    });

    test('Tháng: mỗi ngày một cột, ngày chưa tới để trống', () {
      final chart = doneChart(StatsPeriod.month, sample, testNow);
      expect(chart.bars, hasLength(31));
      expect(chart.bars[28].isCurrent, isTrue); // 29/10
      expect(chart.bars[29].isFuture, isTrue);
      expect(chart.bars[30].isFuture, isTrue);
      expect(chart.bars[27].isFuture, isFalse);
      expect(chart.bars.fold(0, (sum, b) => sum + b.value), 8);
      // Trung bình trên 29 ngày đã qua.
      expect(chart.averageLabel, 'TB 0,3/ngày');
      expect(chart.showValues, isFalse);
      expect(chart.labelEvery, 7);
      expect(
        [
          for (final (i, b) in chart.bars.indexed)
            if (i % chart.labelEvery == 0) b.label,
        ],
        ['1', '8', '15', '22', '29'],
      );
    });

    test('Năm: 12 cột theo tháng', () {
      final chart = doneChart(StatsPeriod.year, sample, testNow);
      expect(chart.title, 'Việc hoàn thành mỗi tháng');
      expect(chart.bars, hasLength(12));
      expect(chart.bars[9].value, 8); // tháng 10
      expect(chart.bars[9].isCurrent, isTrue);
      expect(chart.bars[10].isFuture, isTrue);
      expect(chart.bars[11].isFuture, isTrue);
      // Trung bình trên 10 tháng đã qua.
      expect(chart.averageLabel, 'TB 0,8/tháng');
      expect(chart.showValues, isTrue);
    });
  });

  group('theo nhãn', () {
    test('dữ liệu mẫu 7 ngày: nhiều việc trước, bằng nhau theo tên', () {
      final shares = tagShares(
        completedIn(sample, periodRange(StatsPeriod.week, testNow)),
        tagById,
      );
      expect(shares.map((s) => (s.name, s.detail)), [
        ('Sức khỏe', '3 việc · 38%'),
        ('Cá nhân', '2 việc · 25%'),
        ('Học tập', '2 việc · 25%'),
        ('Công việc', '1 việc · 13%'),
      ]);
      expect(shares.first.fraction, 3 / 8);
    });

    test('không nhãn và nhãn đã xóa gộp thành "Không nhãn", xếp sau', () {
      final shares = tagShares([
        done('a', testNow),
        done('b', testNow, tagId: 'tag-da-xoa'),
        done('c', testNow, tagId: DefaultTagIds.work),
        done('d', testNow, tagId: DefaultTagIds.work),
      ], tagById);
      expect(shares.map((s) => (s.name, s.count)), [
        ('Công việc', 2),
        ('Không nhãn', 2),
      ]);
      expect(shares.last.tag, isNull);
    });

    test('kỳ không có việc nào', () {
      expect(tagShares(const [], tagById), isEmpty);
      expect(const TagShare(tag: null, count: 0, total: 0).percent, 0);
    });
  });

  test('tổng hợp một kỳ (dữ liệu mẫu, 7 ngày)', () {
    final stats = summarizeStats(StatsPeriod.week, sample, tagById, testNow);
    expect(stats.done, 8);
    expect(stats.previousDone, 0);
    expect(stats.onTime.label, '50%');
    expect(stats.overdue, 2);
    expect((stats.streak.current, stats.streak.best), (4, 4));
    expect(stats.chart.bars, hasLength(7));
    expect(stats.tags.first.tag?.color, TagColor.red);
  });
}
