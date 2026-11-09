import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// 24:59 — làm tròn lên để vừa bấm Bắt đầu vẫn hiện 25:00.
String fmtCountdown(Duration d) {
  final s = (d.inMilliseconds + 999) ~/ 1000;
  return '${_two(s ~/ 60)}:${_two(s % 60)}';
}

/// mm:ss.cc cho bấm giờ.
String fmtStopwatch(Duration d) {
  final ms = d.inMilliseconds;
  final s = ms ~/ 1000;
  return '${_two(s ~/ 60)}:${_two(s % 60)}.${_two((ms ~/ 10) % 100)}';
}

/// "25p" (tối thiểu 1p).
String fmtMinutes(int sec) => '${max(1, (sec / 60).round())}p';

/// "1g 02p" hoặc "40p".
String fmtTotal(int sec) {
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  return h > 0 ? '${h}g ${_two(m)}p' : '${m}p';
}

const _weekdays = ['Th 2', 'Th 3', 'Th 4', 'Th 5', 'Th 6', 'Th 7', 'CN'];

/// "Hôm nay · Th 5, 29/10", "Hôm qua · ...", hoặc "Th 3, 27/10".
String fmtDayTitle(DateTime day, DateTime now) {
  final d = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  final base = '${_weekdays[d.weekday - 1]}, ${_two(d.day)}/${_two(d.month)}';
  final diff = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(d.year, d.month, d.day)).inDays;
  if (diff == 0) return 'Hôm nay · $base';
  if (diff == 1) return 'Hôm qua · $base';
  return base;
}

/// Màu cho trạng thái hoàn thành / bỏ dở, nhanh nhất / chậm nhất,
/// lấy từ [TaskColors] để đồng bộ với màn Hôm nay.
extension TimerColors on BuildContext {
  Color get okBg => TaskColors.of(this).green;
  Color get okFg => TaskColors.of(this).onGreen;
  Color get badFg => TaskColors.of(this).high;
  Color get badBg => TaskColors.of(this).high.withValues(alpha: 0.14);

  /// Màu thẻ (trắng ở sáng, #1B1B23 ở tối) giống các Card của app.
  Color get cardColor =>
      Theme.of(this).cardTheme.color ?? Theme.of(this).colorScheme.surface;
}
