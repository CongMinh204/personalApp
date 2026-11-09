import 'package:flutter/material.dart' show DateTimeRange;

import '../../data/models/focus_session.dart';
import '../../utils/dates.dart';

/// Cách gom nhóm của màn Lịch sử tập trung (ba tab Ngày / Tuần / Tháng).
enum HistoryRange {
  day('Ngày'),
  week('Tuần'),
  month('Tháng');

  const HistoryRange(this.label);

  final String label;

  /// Số nhóm gần nhất được hiện: 30 ngày, 12 tuần, 12 tháng.
  int get visibleGroups => switch (this) {
    HistoryRange.day => 30,
    HistoryRange.week => 12,
    HistoryRange.month => 12,
  };

  /// Nhãn của ô tóm tắt thứ ba: tổng thời gian tập trung của kỳ lớn hơn.
  String get biggerPeriodLabel => switch (this) {
    HistoryRange.day => 'Tuần này',
    HistoryRange.week => 'Tháng này',
    HistoryRange.month => 'Năm nay',
  };
}

/// Chỉ giữ phiên tập trung (Pomodoro, Tùy chỉnh). Giờ nghỉ không hiện trong
/// lịch sử và không tính vào các số tóm tắt.
List<FocusSession> focusOnly(Iterable<FocusSession> sessions) => [
  for (final s in sessions)
    if (s.type.isFocus) s,
];

/// Đầu của nhóm chứa [t] theo [range]: 00:00 của ngày, ngày đầu tuần, hoặc
/// mùng 1 của tháng.
DateTime groupStart(DateTime t, HistoryRange range, int weekStart) =>
    switch (range) {
      HistoryRange.day => startOfDay(t),
      HistoryRange.week => startOfWeek(t, weekStart),
      HistoryRange.month => DateTime(t.year, t.month),
    };

DateTime _nextGroupStart(DateTime start, HistoryRange range) => switch (range) {
  HistoryRange.day => DateTime(start.year, start.month, start.day + 1),
  HistoryRange.week => DateTime(start.year, start.month, start.day + 7),
  HistoryRange.month => DateTime(start.year, start.month + 1),
};

DateTime _previousGroupStart(DateTime start, HistoryRange range) =>
    switch (range) {
      HistoryRange.day => DateTime(start.year, start.month, start.day - 1),
      HistoryRange.week => DateTime(start.year, start.month, start.day - 7),
      HistoryRange.month => DateTime(start.year, start.month - 1),
    };

/// Kỳ hiện tại của tab [range]: hôm nay, tuần này hoặc tháng này.
DateTimeRange currentPeriod(HistoryRange range, DateTime now, int weekStart) {
  final start = groupStart(now, range, weekStart);
  return DateTimeRange(start: start, end: _nextGroupStart(start, range));
}

/// Kỳ lớn hơn dùng cho ô tóm tắt thứ ba: tuần này (tab Ngày), tháng này (tab
/// Tuần) hoặc năm nay (tab Tháng).
DateTimeRange biggerPeriod(HistoryRange range, DateTime now, int weekStart) =>
    switch (range) {
      HistoryRange.day => weekRange(now, weekStart),
      HistoryRange.week => monthRange(now),
      HistoryRange.month => DateTimeRange(
        start: DateTime(now.year),
        end: DateTime(now.year + 1),
      ),
    };

/// Khoảng thời gian cần đọc để hiện [HistoryRange.visibleGroups] nhóm gần nhất
/// (kể cả nhóm hiện tại).
DateTimeRange visibleWindow(HistoryRange range, DateTime now, int weekStart) {
  final current = currentPeriod(range, now, weekStart);
  var start = current.start;
  for (var i = 1; i < range.visibleGroups; i++) {
    start = _previousGroupStart(start, range);
  }
  return DateTimeRange(start: start, end: current.end);
}

/// Một nhóm phiên trong danh sách (một ngày, một tuần hoặc một tháng).
class HistoryGroup {
  const HistoryGroup({
    required this.start,
    required this.title,
    required this.sessions,
  });

  final DateTime start;
  final String title;

  /// Phiên tập trung của nhóm, mới nhất trước.
  final List<FocusSession> sessions;

  int get focusSeconds => sessions.fold(0, (sum, s) => sum + s.durationSec);
}

/// Gom các phiên tập trung thành nhóm theo [range], nhóm mới nhất trước và
/// trong mỗi nhóm phiên mới nhất trước. Phiên nghỉ bị bỏ. Phiên tính vào nhóm
/// của lúc bắt đầu.
List<HistoryGroup> groupSessions(
  Iterable<FocusSession> sessions,
  HistoryRange range,
  DateTime now,
  int weekStart,
) {
  final byStart = <DateTime, List<FocusSession>>{};
  for (final s in focusOnly(sessions)) {
    byStart
        .putIfAbsent(groupStart(s.startedAt, range, weekStart), () => [])
        .add(s);
  }
  final starts = byStart.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final start in starts)
      HistoryGroup(
        start: start,
        title: groupTitle(start, range, now, weekStart),
        sessions: byStart[start]!
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
      ),
  ];
}

/// Các số ở ba ô tóm tắt.
class HistorySummary {
  const HistorySummary({
    required this.sessions,
    required this.completed,
    required this.focusSeconds,
  });

  /// Số phiên tập trung.
  final int sessions;

  /// Số phiên chạy hết giờ (không tính bỏ dở).
  final int completed;

  /// Tổng thời gian tập trung (giây), kể cả phiên bỏ dở.
  final int focusSeconds;
}

/// Tóm tắt các phiên tập trung trong [sessions].
HistorySummary summarize(Iterable<FocusSession> sessions) {
  final focus = focusOnly(sessions);
  return HistorySummary(
    sessions: focus.length,
    completed: focus.where((s) => s.completed).length,
    focusSeconds: focus.fold(0, (sum, s) => sum + s.durationSec),
  );
}

/// Các phiên có thời điểm bắt đầu trong [range] (gồm start, không gồm end).
List<FocusSession> sessionsStartingIn(
  Iterable<FocusSession> sessions,
  DateTimeRange range,
) => [
  for (final s in sessions)
    if (rangeContains(range, s.startedAt)) s,
];

String _two(int n) => n.toString().padLeft(2, '0');

String _dayMonth(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

/// "Th 5, 29/10" (Thứ Hai là "Th 2", Chủ Nhật là "CN").
String shortDayLabel(DateTime d) {
  final weekday = d.weekday == 7 ? 'CN' : 'Th ${d.weekday + 1}';
  return '$weekday, ${_dayMonth(d)}';
}

/// Tên một nhóm: "Hôm nay · Th 5, 29/10", "Tuần này · 26/10 – 01/11",
/// "Tháng này · Tháng 10/2026"; nhóm cũ hơn chỉ có phần sau dấu "·".
String groupTitle(
  DateTime start,
  HistoryRange range,
  DateTime now,
  int weekStart,
) {
  final current = groupStart(now, range, weekStart);
  switch (range) {
    case HistoryRange.day:
      final label = shortDayLabel(start);
      if (start == current) return 'Hôm nay · $label';
      if (start == _previousGroupStart(current, range)) {
        return 'Hôm qua · $label';
      }
      return label;
    case HistoryRange.week:
      final end = DateTime(start.year, start.month, start.day + 6);
      final label = '${_dayMonth(start)} – ${_dayMonth(end)}';
      if (start == current) return 'Tuần này · $label';
      if (start == _previousGroupStart(current, range)) {
        return 'Tuần trước · $label';
      }
      return label;
    case HistoryRange.month:
      final label = 'Tháng ${start.month}/${start.year}';
      return start == current ? 'Tháng này · $label' : label;
  }
}

/// Tổng thời gian tập trung: "6g 40p", "1g 02p", "25p", "0p".
String formatFocusTotal(int seconds) {
  final minutes = (seconds / 60).round();
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '${rest}p';
  return '${hours}g ${_two(rest)}p';
}

/// Thời lượng của một phiên: "25p", "1g 05p"; dưới 1 phút ghi "<1p".
String formatSessionDuration(int seconds) {
  if (seconds < 60) return '<1p';
  return formatFocusTotal(seconds);
}
