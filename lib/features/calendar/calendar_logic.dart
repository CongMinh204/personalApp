import 'dart:math' as math;

import 'package:flutter/material.dart' show DateTimeRange;

import '../../data/models/task.dart';
import '../../utils/dates.dart';
import '../../utils/vi_date.dart';

/// Cách xem của tab Lịch.
enum CalendarMode {
  month('Tháng'),
  week('Tuần');

  const CalendarMode(this.label);

  final String label;
}

// ---- Lưới ngày --------------------------------------------------------------

/// Khoảng việc tab Lịch đọc khi ngày đang chọn nằm trong tháng của [day]: cả
/// tháng, thêm 7 ngày mỗi phía cho các ngày của tháng trước và tháng sau hiện
/// ở lưới tháng, hay ở tuần chứa ngày đang chọn. Chỉ đổi khi sang tháng khác.
DateTimeRange calendarQueryRange(DateTime day) => DateTimeRange(
  start: DateTime(day.year, day.month, 1 - 7),
  end: DateTime(day.year, day.month + 1, 1 + 7),
);

/// Các ngày của lưới tháng chứa [month]: đủ các tuần 7 ngày (bắt đầu từ
/// [weekStart], 1 = Thứ Hai, 7 = Chủ Nhật) phủ cả tháng, gồm vài ngày cuối
/// tháng trước và đầu tháng sau.
List<DateTime> monthGridDays(DateTime month, int weekStart) {
  final last = DateTime(month.year, month.month + 1, 0);
  final days = <DateTime>[];
  for (
    var day = startOfWeek(DateTime(month.year, month.month), weekStart);
    !day.isAfter(last) || days.length % 7 != 0;
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    days.add(day);
  }
  return days;
}

/// 7 ngày của tuần chứa [day].
List<DateTime> weekDays(DateTime day, int weekStart) {
  final start = startOfWeek(day, weekStart);
  return [
    for (var i = 0; i < 7; i++)
      DateTime(start.year, start.month, start.day + i),
  ];
}

/// Ngày được chọn sau khi bấm ◀ ([step] = -1) hoặc ▶ ([step] = 1).
///
/// - Xem tháng: sang tháng trước/sau và chọn ngày 1; nếu đó là tháng hiện tại
///   thì chọn hôm nay.
/// - Xem tuần: lùi hoặc tiến đúng 7 ngày (giữ nguyên thứ).
DateTime shiftSelection(
  DateTime selected,
  CalendarMode mode,
  int step,
  DateTime today,
) {
  switch (mode) {
    case CalendarMode.week:
      return DateTime(selected.year, selected.month, selected.day + 7 * step);
    case CalendarMode.month:
      final month = DateTime(selected.year, selected.month + step);
      if (month.year == today.year && month.month == today.month) {
        return startOfDay(today);
      }
      return month;
  }
}

// ---- Việc của ngày ----------------------------------------------------------

/// "Hôm nay · Thứ Năm, 29/10" hoặc "Thứ Bảy, 31/10".
String dayTitle(DateTime day, DateTime today) {
  final title = '${weekdayName(day.weekday)}, ${day.day}/${day.month}';
  return dayDiff(today, day) == 0 ? 'Hôm nay · $title' : title;
}

/// "3 việc"; ngày trống thì không ghi gì.
String dayCountLabel(int count) => count == 0 ? '' : '$count việc';

/// Việc có ngày, gom theo khóa `dateKey` của ngày hẹn (việc không có ngày
/// không hiện trên Lịch).
Map<String, List<Task>> tasksByDay(Iterable<Task> tasks) {
  final byDay = <String, List<Task>>{};
  for (final task in tasks) {
    final due = task.due;
    if (due == null) continue;
    (byDay[dateKey(due)] ??= []).add(task);
  }
  return byDay;
}

/// Thứ tự danh sách việc dưới lịch: chưa xong lên trước; rồi việc có giờ theo
/// giờ bắt đầu; việc cả ngày ở cuối.
List<Task> sortDayTasks(Iterable<Task> tasks) {
  return tasks.toList()..sort((a, b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    if (a.hasTime != b.hasTime) return a.hasTime ? -1 : 1;
    final byDue = a.due!.compareTo(b.due!);
    if (byDue != 0) return byDue;
    final byCreated = a.createdAt.compareTo(b.createdAt);
    return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
  });
}

/// Giờ của việc trong danh sách dưới lịch (ngày đã ghi ở tiêu đề):
/// "14:00 – 15:00", "08:00" hoặc "Cả ngày".
String calendarTimeLabel(Task task) {
  final due = task.due;
  if (due == null || !task.hasTime) return 'Cả ngày';
  final end = task.end;
  return end == null
      ? hourMinute(due)
      : '${hourMinute(due)} – ${hourMinute(end)}';
}

/// Việc chưa xong có ngày hẹn trước hôm nay (như nhóm Quá hạn ở Hôm nay).
bool isOverdue(Task task, DateTime now) {
  final due = task.due;
  return !task.done && due != null && dayDiff(now, due) < 0;
}

// ---- Dải giờ ----------------------------------------------------------------

/// Thời lượng tối thiểu của một khối: việc chỉ có giờ bắt đầu (hoặc giờ kết
/// thúc không hợp lệ) hiện thành khối 30 phút.
const minBlockHours = 0.5;

/// Một việc có giờ trên dải giờ. Giờ tính bằng số thập phân trong ngày
/// (14.5 = 14:30).
class TimelineBlock {
  const TimelineBlock({
    required this.task,
    required this.start,
    required this.end,
    required this.column,
    required this.columns,
  });

  final Task task;
  final double start;

  /// Giờ kết thúc để vẽ: ít nhất [start] + [minBlockHours], tối đa 24.
  final double end;

  /// Cột của khối (0 = trái nhất) trong nhóm các việc trùng giờ.
  final int column;

  /// Số cột của nhóm việc trùng giờ chứa khối này.
  final int columns;
}

/// Dải giờ của một ngày: các mốc giờ từ [firstHour]:00 tới [lastHour]:00.
class Timeline {
  const Timeline({
    required this.firstHour,
    required this.lastHour,
    required this.blocks,
  });

  final int firstHour;
  final int lastHour;
  final List<TimelineBlock> blocks;

  int get hours => lastHour - firstHour;
}

double hourOfDay(DateTime t) => t.hour + t.minute / 60;

/// Dải giờ cho các việc có giờ của ngày [day] trong [tasks] (bỏ qua việc cả
/// ngày và việc của ngày khác). Không có việc có giờ thì trả về `null`.
///
/// - Việc không có giờ kết thúc, hoặc kết thúc không sau giờ bắt đầu: hiện
///   30 phút. Việc kết thúc sang ngày sau: cắt ở 24:00.
/// - Các việc trùng giờ chia cột cạnh nhau.
/// - Dải giờ từ 1 giờ trước việc sớm nhất tới 1 giờ sau việc muộn nhất; nếu
///   [now] thuộc ngày [day] thì mở rộng để có vạch giờ hiện tại.
Timeline? buildTimeline(Iterable<Task> tasks, DateTime day, {DateTime? now}) {
  final raw = <_RawBlock>[];
  for (final task in tasks) {
    final due = task.due;
    if (!task.hasTime || due == null || dayDiff(day, due) != 0) continue;
    final start = hourOfDay(due);
    final end = task.end;
    var finish = start + minBlockHours;
    if (end != null && end.isAfter(due)) {
      finish = dayDiff(due, end) > 0 ? 24.0 : hourOfDay(end);
    }
    raw.add(
      _RawBlock(
        task,
        start,
        math.min(24, math.max(finish, start + minBlockHours)),
      ),
    );
  }
  if (raw.isEmpty) return null;

  // Sớm trước; cùng giờ bắt đầu thì việc dài hơn ở cột trái.
  raw.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : b.end.compareTo(a.end);
  });

  final blocks = <TimelineBlock>[];
  var group = <_RawBlock>[];
  var columnEnds = <double>[];
  var groupEnd = 0.0;

  void closeGroup() {
    for (final b in group) {
      blocks.add(
        TimelineBlock(
          task: b.task,
          start: b.start,
          end: b.end,
          column: b.column,
          columns: columnEnds.length,
        ),
      );
    }
    group = [];
    columnEnds = [];
  }

  for (final b in raw) {
    if (group.isNotEmpty && b.start >= groupEnd) closeGroup();
    final free = columnEnds.indexWhere((end) => end <= b.start);
    if (free == -1) {
      b.column = columnEnds.length;
      columnEnds.add(b.end);
    } else {
      b.column = free;
      columnEnds[free] = b.end;
    }
    groupEnd = group.isEmpty ? b.end : math.max(groupEnd, b.end);
    group.add(b);
  }
  closeGroup();

  var first = raw.map((b) => b.start).reduce(math.min).floor() - 1;
  var last = raw.map((b) => b.end).reduce(math.max).ceil() + 1;
  if (now != null && dayDiff(day, now) == 0) {
    final hour = hourOfDay(now);
    first = math.min(first, hour.floor());
    last = math.max(last, hour.floor() + 1);
  }
  return Timeline(
    firstHour: math.max(0, first),
    lastHour: math.min(24, last),
    blocks: blocks,
  );
}

class _RawBlock {
  _RawBlock(this.task, this.start, this.end);

  final Task task;
  final double start;
  final double end;
  int column = 0;
}
