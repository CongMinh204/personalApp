import 'package:flutter/material.dart' show TimeOfDay;

import '../../data/models/task.dart';
import '../../utils/vi_date.dart';

/// Lỗi của form Thêm/sửa việc; `null` = hợp lệ.
class TaskFormErrors {
  const TaskFormErrors({this.title, this.time, this.repeat});

  final String? title;
  final String? time;
  final String? repeat;

  bool get hasError => title != null || time != null || repeat != null;
}

int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

/// Kiểm tra các trường của form trước khi lưu.
///
/// - Tiêu đề không được trống.
/// - Việc có giờ (không phải cả ngày) phải có giờ bắt đầu; giờ kết thúc (nếu
///   có) phải sau giờ bắt đầu.
/// - Việc lặp lại cần có ngày.
TaskFormErrors validateTaskForm({
  required String title,
  required DateTime? date,
  required bool allDay,
  required TimeOfDay? start,
  required TimeOfDay? end,
  required RepeatRule repeat,
}) {
  String? timeError;
  if (date != null && !allDay) {
    if (start == null) {
      timeError = 'Chọn giờ bắt đầu';
    } else if (end != null && _minutes(end) <= _minutes(start)) {
      timeError = 'Giờ kết thúc phải sau giờ bắt đầu';
    }
  }
  return TaskFormErrors(
    title: title.trim().isEmpty ? 'Vui lòng nhập tên việc' : null,
    time: timeError,
    repeat: repeat != RepeatRule.none && date == null
        ? 'Việc lặp lại cần có ngày'
        : null,
  );
}

/// Ghép các trường của form thành một [Task].
///
/// Không có ngày thì không có giờ. Cả ngày thì `due` là 00:00 của ngày đó và
/// không có giờ kết thúc.
Task buildTask({
  required String id,
  required DateTime createdAt,
  required String title,
  required String note,
  required DateTime? date,
  required bool allDay,
  required TimeOfDay? start,
  required TimeOfDay? end,
  required int? reminderMinutes,
  required RepeatRule repeat,
  required Priority priority,
  required String? tagId,
  bool done = false,
  DateTime? completedAt,
}) {
  final timed = date != null && !allDay && start != null;
  DateTime at(TimeOfDay t) =>
      DateTime(date!.year, date.month, date.day, t.hour, t.minute);
  return Task(
    id: id,
    title: title.trim(),
    note: note.trim(),
    tagId: tagId,
    due: date == null
        ? null
        : timed
        ? at(start)
        : DateTime(date.year, date.month, date.day),
    end: timed && end != null ? at(end) : null,
    hasTime: timed,
    priority: priority,
    done: done,
    completedAt: completedAt,
    reminderMinutes: reminderMinutes,
    repeatRule: repeat,
    createdAt: createdAt,
  );
}

/// Dòng mô tả kiểu lặp dưới nút chọn, ví dụ "Lặp mỗi Thứ Năm hằng tuần".
/// Trả về `null` nếu không lặp hoặc chưa có ngày.
String? repeatDescription(DateTime? date, TimeOfDay? start, RepeatRule rule) {
  if (date == null || rule == RepeatRule.none) return null;
  final time = start == null
      ? ''
      : ' lúc ${hourMinute(DateTime(2000, 1, 1, start.hour, start.minute))}';
  return switch (rule) {
    RepeatRule.none => null,
    RepeatRule.daily => 'Lặp mỗi ngày$time',
    RepeatRule.weekly => 'Lặp mỗi ${weekdayName(date.weekday)} hằng tuần$time',
    RepeatRule.monthly =>
      date.day > 28
          ? 'Lặp ngày ${date.day} hằng tháng (tháng ngắn hơn lấy ngày cuối '
                'tháng)$time'
          : 'Lặp ngày ${date.day} hằng tháng$time',
  };
}
