import 'dart:math' as math;

import 'package:flutter/material.dart' show DateTimeRange;

import '../../data/models/tag.dart';
import '../../data/models/task.dart';
import '../../utils/dates.dart';
import '../../utils/vi_date.dart';
import '../today/task_groups.dart';

/// Kỳ của tab Thống kê (công tắc 7 ngày / Tháng / Năm).
enum StatsPeriod {
  week('7 ngày'),
  month('Tháng'),
  year('Năm');

  const StatsPeriod(this.label);

  final String label;
}

// ---- Kỳ và kỳ so sánh -------------------------------------------------------

/// Khoảng của kỳ (end không tính), luôn kết thúc ở hết hôm nay:
/// - 7 ngày: 7 ngày gần nhất, tính cả hôm nay;
/// - Tháng: từ ngày 1 của tháng này;
/// - Năm: từ 1/1 của năm nay.
DateTimeRange periodRange(StatsPeriod period, DateTime now) => DateTimeRange(
  start: switch (period) {
    StatsPeriod.week => DateTime(now.year, now.month, now.day - 6),
    StatsPeriod.month => DateTime(now.year, now.month),
    StatsPeriod.year => DateTime(now.year),
  },
  end: DateTime(now.year, now.month, now.day + 1),
);

/// Kỳ liền trước có cùng độ dài, để so sánh số việc hoàn thành:
/// - 7 ngày: 7 ngày ngay trước đó;
/// - Tháng: cùng kỳ tháng trước (hôm nay 10/11 thì là 1–10/10; tháng trước
///   ngắn hơn thì tới hết tháng đó);
/// - Năm: cùng kỳ năm trước (1/1 tới cùng ngày năm trước).
DateTimeRange previousRange(StatsPeriod period, DateTime now) {
  switch (period) {
    case StatsPeriod.week:
      return DateTimeRange(
        start: DateTime(now.year, now.month, now.day - 13),
        end: DateTime(now.year, now.month, now.day - 6),
      );
    case StatsPeriod.month:
      // Ngày 0 của tháng này là ngày cuối tháng trước.
      final day = math.min(now.day, DateTime(now.year, now.month, 0).day);
      return DateTimeRange(
        start: DateTime(now.year, now.month - 1),
        end: DateTime(now.year, now.month - 1, day + 1),
      );
    case StatsPeriod.year:
      final day = math.min(
        now.day,
        DateTime(now.year - 1, now.month + 1, 0).day,
      );
      return DateTimeRange(
        start: DateTime(now.year - 1),
        end: DateTime(now.year - 1, now.month, day + 1),
      );
  }
}

/// "+5 so với tuần trước", "−2 so với cùng kỳ tháng trước" hoặc "Bằng cùng
/// kỳ năm trước".
String comparisonLabel(StatsPeriod period, int current, int previous) {
  final target = switch (period) {
    StatsPeriod.week => 'tuần trước',
    StatsPeriod.month => 'cùng kỳ tháng trước',
    StatsPeriod.year => 'cùng kỳ năm trước',
  };
  final diff = current - previous;
  if (diff == 0) return 'Bằng $target';
  return diff > 0 ? '+$diff so với $target' : '−${-diff} so với $target';
}

// ---- Việc hoàn thành, đúng hạn, quá hạn ------------------------------------

/// Việc đã xong có thời điểm xong (`completedAt`) trong [range].
List<Task> completedIn(Iterable<Task> tasks, DateTimeRange range) => [
  for (final task in tasks)
    if (task.done &&
        task.completedAt != null &&
        rangeContains(range, task.completedAt!))
      task,
];

/// Việc đã xong có đúng hạn không; `null` khi không tính (chưa xong hoặc không
/// có ngày).
///
/// - Việc có giờ: xong trước giờ kết thúc; không có giờ kết thúc thì trước giờ
///   bắt đầu.
/// - Việc cả ngày: xong trước khi hết ngày hẹn.
bool? finishedOnTime(Task task) {
  final due = task.due;
  final completedAt = task.completedAt;
  if (!task.done || due == null || completedAt == null) return null;
  if (!task.hasTime) return dayDiff(due, completedAt) <= 0;
  final end = task.end;
  final deadline = end != null && end.isAfter(due) ? end : due;
  return !completedAt.isAfter(deadline);
}

/// Tỷ lệ việc xong đúng hạn trong các việc đã xong có ngày hẹn.
class OnTimeRate {
  const OnTimeRate({required this.onTime, required this.counted});

  final int onTime;

  /// Số việc được tính (đã xong và có ngày hẹn).
  final int counted;

  /// Phần trăm làm tròn; chưa có việc nào để tính thì `null`.
  int? get percent => counted == 0 ? null : (onTime * 100 / counted).round();

  /// "86%" hoặc "–" khi chưa có việc nào để tính.
  String get label => percent == null ? '–' : '$percent%';
}

OnTimeRate onTimeRate(Iterable<Task> completed) {
  var onTime = 0;
  var counted = 0;
  for (final task in completed) {
    final result = finishedOnTime(task);
    if (result == null) continue;
    counted++;
    if (result) onTime++;
  }
  return OnTimeRate(onTime: onTime, counted: counted);
}

/// Số việc đang quá hạn, đếm như nhóm Quá hạn của màn Hôm nay.
int overdueCount(List<Task> tasks, DateTime now) =>
    groupTasks(tasks, now).overdue.length;

/// "2 việc đang quá hạn" hoặc "Không có việc quá hạn".
String overdueLabel(int count) =>
    count == 0 ? 'Không có việc quá hạn' : '$count việc đang quá hạn';

// ---- Ngày liên tiếp ---------------------------------------------------------

/// Chuỗi ngày liên tiếp có ít nhất một việc hoàn thành.
class DoneStreak {
  const DoneStreak({required this.current, required this.best});

  /// Chuỗi tính tới hôm nay. Hôm nay chưa xong việc nào thì tính tới hôm qua
  /// (chuỗi chưa đứt cho tới hết hôm nay).
  final int current;

  /// Chuỗi dài nhất từ trước tới nay.
  final int best;
}

DoneStreak doneStreak(Iterable<Task> tasks, DateTime now) {
  final days = <DateTime>{
    for (final task in tasks)
      if (task.done && task.completedAt != null) startOfDay(task.completedAt!),
  };

  DateTime previous(DateTime d) => DateTime(d.year, d.month, d.day - 1);

  var day = startOfDay(now);
  if (!days.contains(day)) day = previous(day);
  var current = 0;
  while (days.contains(day)) {
    current++;
    day = previous(day);
  }

  var best = 0;
  var run = 0;
  DateTime? last;
  for (final d in days.toList()..sort()) {
    run = last != null && dayDiff(last, d) == 1 ? run + 1 : 1;
    best = math.max(best, run);
    last = d;
  }
  return DoneStreak(current: current, best: math.max(best, current));
}

// ---- Biểu đồ cột ------------------------------------------------------------

/// Một cột của biểu đồ "Việc hoàn thành".
class ChartBar {
  const ChartBar({
    required this.label,
    required this.spoken,
    required this.value,
    required this.isCurrent,
    required this.isFuture,
  });

  /// Nhãn dưới cột: "T6", "Nay", "15", "12".
  final String label;

  /// Tên đọc cho trình đọc màn hình: "Thứ Sáu", "hôm nay", "ngày 15".
  final String spoken;
  final int value;

  /// Cột của hôm nay (hoặc tháng này ở kỳ Năm): tô đậm.
  final bool isCurrent;

  /// Ngày hoặc tháng chưa tới: để trống.
  final bool isFuture;
}

class DoneChart {
  const DoneChart({
    required this.title,
    required this.bars,
    required this.average,
    required this.unit,
    required this.showValues,
    required this.labelEvery,
  });

  final String title;
  final List<ChartBar> bars;

  /// Trung bình mỗi ngày (hoặc mỗi tháng) tính trên các ngày đã qua, kể cả
  /// hôm nay.
  final double average;

  /// "ngày" hoặc "tháng".
  final String unit;

  /// Ghi số trên đầu cột (kỳ Tháng có tới 31 cột nên không ghi).
  final bool showValues;

  /// Cứ [labelEvery] cột thì ghi một nhãn dưới trục.
  final int labelEvery;

  /// "TB 4,6/ngày".
  String get averageLabel => 'TB ${formatDecimal(average)}/$unit';

  int get maxValue => bars.fold(0, (m, b) => math.max(m, b.value));

  /// "Biểu đồ cột: Thứ Sáu 4, …, hôm nay 5 việc".
  String get semanticsLabel =>
      'Biểu đồ cột: ${[for (final bar in bars)
        if (!bar.isFuture) '${bar.spoken} ${bar.value}'].join(', ')} việc';
}

/// Số có một chữ số thập phân, dấu phẩy kiểu Việt: 4.6 → "4,6"; số tròn thì
/// không ghi phần thập phân (5.0 → "5").
String formatDecimal(double value) {
  final tenths = (value * 10).round();
  if (tenths % 10 == 0) return '${tenths ~/ 10}';
  return (tenths / 10).toStringAsFixed(1).replaceAll('.', ',');
}

/// Biểu đồ số việc hoàn thành của kỳ [period] từ các việc [tasks] (lọc theo
/// `completedAt` trong kỳ).
///
/// - 7 ngày: 7 cột theo ngày, cột cuối là hôm nay ("Nay").
/// - Tháng: mỗi ngày của tháng một cột, ngày chưa tới để trống.
/// - Năm: 12 cột theo tháng.
DoneChart doneChart(StatsPeriod period, Iterable<Task> tasks, DateTime now) {
  final today = startOfDay(now);
  final completed = completedIn(tasks, periodRange(period, now));

  switch (period) {
    case StatsPeriod.week:
    case StatsPeriod.month:
      final perDay = <DateTime, int>{};
      for (final task in completed) {
        final day = startOfDay(task.completedAt!);
        perDay[day] = (perDay[day] ?? 0) + 1;
      }
      final days = period == StatsPeriod.week
          ? [
              for (var i = 6; i >= 0; i--)
                DateTime(today.year, today.month, today.day - i),
            ]
          : [
              for (
                var d = 1;
                d <= DateTime(today.year, today.month + 1, 0).day;
                d++
              )
                DateTime(today.year, today.month, d),
            ];
      final week = period == StatsPeriod.week;
      return DoneChart(
        title: 'Việc hoàn thành mỗi ngày',
        bars: [
          for (final day in days)
            ChartBar(
              label: week
                  ? (day == today ? 'Nay' : weekdayShort(day.weekday))
                  : '${day.day}',
              spoken: day == today
                  ? 'hôm nay'
                  : week
                  ? weekdayName(day.weekday)
                  : 'ngày ${day.day}',
              value: perDay[day] ?? 0,
              isCurrent: day == today,
              isFuture: day.isAfter(today),
            ),
        ],
        average: completed.length / (week ? 7 : today.day),
        unit: 'ngày',
        showValues: week,
        labelEvery: week ? 1 : 7,
      );
    case StatsPeriod.year:
      final perMonth = List<int>.filled(12, 0);
      for (final task in completed) {
        perMonth[task.completedAt!.month - 1]++;
      }
      return DoneChart(
        title: 'Việc hoàn thành mỗi tháng',
        bars: [
          for (var m = 1; m <= 12; m++)
            ChartBar(
              label: '$m',
              spoken: m == today.month ? 'tháng này' : 'tháng $m',
              value: perMonth[m - 1],
              isCurrent: m == today.month,
              isFuture: m > today.month,
            ),
        ],
        average: completed.length / today.month,
        unit: 'tháng',
        showValues: true,
        labelEvery: 1,
      );
  }
}

// ---- Theo nhãn --------------------------------------------------------------

/// Phần của một nhãn trong các việc hoàn thành của kỳ.
class TagShare {
  const TagShare({required this.tag, required this.count, required this.total});

  /// `null` = Không nhãn.
  final Tag? tag;
  final int count;

  /// Tổng số việc hoàn thành của kỳ.
  final int total;

  String get name => tag?.name ?? 'Không nhãn';

  double get fraction => total == 0 ? 0 : count / total;

  int get percent => total == 0 ? 0 : (count * 100 / total).round();

  /// "14 việc · 44%".
  String get detail => '$count việc · $percent%';
}

/// Việc hoàn thành [completed] chia theo nhãn: nhiều việc trước; bằng nhau thì
/// theo tên, "Không nhãn" ở sau. Việc có nhãn không còn trong [tagById] tính là
/// Không nhãn.
List<TagShare> tagShares(Iterable<Task> completed, Map<String, Tag> tagById) {
  final counts = <String?, int>{};
  var total = 0;
  for (final task in completed) {
    final key = tagById.containsKey(task.tagId) ? task.tagId : null;
    counts[key] = (counts[key] ?? 0) + 1;
    total++;
  }
  return [
    for (final entry in counts.entries)
      TagShare(
        tag: entry.key == null ? null : tagById[entry.key],
        count: entry.value,
        total: total,
      ),
  ]..sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    if ((a.tag == null) != (b.tag == null)) return a.tag == null ? 1 : -1;
    return a.name.compareTo(b.name);
  });
}

// ---- Tất cả số liệu của một kỳ ----------------------------------------------

/// Mọi số trên tab Thống kê trừ thời gian tập trung (đọc riêng từ phiên tập
/// trung).
class StatsSummary {
  const StatsSummary({
    required this.done,
    required this.previousDone,
    required this.onTime,
    required this.overdue,
    required this.streak,
    required this.chart,
    required this.tags,
  });

  /// Số việc hoàn thành trong kỳ.
  final int done;

  /// Số việc hoàn thành trong kỳ so sánh (xem [previousRange]).
  final int previousDone;
  final OnTimeRate onTime;
  final int overdue;
  final DoneStreak streak;
  final DoneChart chart;
  final List<TagShare> tags;
}

StatsSummary summarizeStats(
  StatsPeriod period,
  List<Task> tasks,
  Map<String, Tag> tagById,
  DateTime now,
) {
  final completed = completedIn(tasks, periodRange(period, now));
  return StatsSummary(
    done: completed.length,
    previousDone: completedIn(tasks, previousRange(period, now)).length,
    onTime: onTimeRate(completed),
    overdue: overdueCount(tasks, now),
    streak: doneStreak(tasks, now),
    chart: doneChart(period, tasks, now),
    tags: tagShares(completed, tagById),
  );
}
