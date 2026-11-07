import 'package:flutter/foundation.dart';

import 'db_values.dart';

/// Mức ưu tiên. [code] là giá trị lưu trong database, không đổi.
enum Priority {
  low(0, 'Thấp'),
  medium(1, 'Trung bình'),
  high(2, 'Cao');

  const Priority(this.code, this.label);

  final int code;
  final String label;

  static Priority fromCode(Object? code) =>
      values.firstWhere((p) => p.code == code, orElse: () => medium);
}

/// Kiểu lặp lại của việc. [code] là giá trị lưu trong database, không đổi.
enum RepeatRule {
  none('none', 'Không'),
  daily('day', 'Ngày'),
  weekly('week', 'Tuần'),
  monthly('month', 'Tháng');

  const RepeatRule(this.code, this.label);

  final String code;
  final String label;

  static RepeatRule fromCode(Object? code) =>
      values.firstWhere((r) => r.code == code, orElse: () => none);
}

/// Một việc. Xem docs/DATA_CONTRACT.md, mục Task.
class Task {
  const Task({
    required this.id,
    required this.title,
    this.note = '',
    this.tagId,
    this.due,
    this.end,
    this.hasTime = false,
    this.priority = Priority.medium,
    this.done = false,
    this.completedAt,
    this.reminderMinutes,
    this.repeatRule = RepeatRule.none,
    required this.createdAt,
    this.subtaskDone = 0,
    this.subtaskTotal = 0,
  });

  /// Tạo bằng `newId()` khi tạo việc; không bao giờ đổi.
  final String id;
  final String title;
  final String note;

  /// Id nhãn; `null` = Không nhãn.
  final String? tagId;

  /// Ngày hẹn (kèm giờ bắt đầu nếu [hasTime]); `null` = không có ngày.
  final DateTime? due;

  /// Giờ kết thúc, chỉ có nghĩa khi [hasTime].
  final DateTime? end;

  /// `false` = Cả ngày: chỉ dùng phần ngày của [due].
  final bool hasTime;
  final Priority priority;
  final bool done;

  /// Thời điểm đánh dấu xong, do repository đặt trong `setDone`; `null` khi
  /// chưa xong.
  final DateTime? completedAt;

  /// Nhắc trước [due] bao nhiêu phút; 0 = đúng giờ; `null` = không nhắc.
  final int? reminderMinutes;
  final RepeatRule repeatRule;
  final DateTime createdAt;

  /// Số việc con đã xong / tổng số. Chỉ đọc: repository đếm khi đọc, không
  /// phải cột trong database.
  final int subtaskDone;
  final int subtaskTotal;

  /// Trường có thể trống truyền dạng hàm: `copyWith(tagId: () => null)` để bỏ
  /// nhãn. Bỏ qua tham số thì giữ nguyên giá trị cũ.
  Task copyWith({
    String? title,
    String? note,
    ValueGetter<String?>? tagId,
    ValueGetter<DateTime?>? due,
    ValueGetter<DateTime?>? end,
    bool? hasTime,
    Priority? priority,
    bool? done,
    ValueGetter<DateTime?>? completedAt,
    ValueGetter<int?>? reminderMinutes,
    RepeatRule? repeatRule,
    int? subtaskDone,
    int? subtaskTotal,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      tagId: tagId != null ? tagId() : this.tagId,
      due: due != null ? due() : this.due,
      end: end != null ? end() : this.end,
      hasTime: hasTime ?? this.hasTime,
      priority: priority ?? this.priority,
      done: done ?? this.done,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
      reminderMinutes: reminderMinutes != null
          ? reminderMinutes()
          : this.reminderMinutes,
      repeatRule: repeatRule ?? this.repeatRule,
      createdAt: createdAt,
      subtaskDone: subtaskDone ?? this.subtaskDone,
      subtaskTotal: subtaskTotal ?? this.subtaskTotal,
    );
  }

  /// Một dòng của bảng `tasks` (không gồm số việc con).
  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'note': note,
    'tag_id': tagId,
    'due_at': encodeTime(due),
    'end_at': encodeTime(end),
    'has_time': encodeBool(hasTime),
    'priority': priority.code,
    'done': encodeBool(done),
    'completed_at': encodeTime(completedAt),
    'reminder_minutes': reminderMinutes,
    'repeat_rule': repeatRule.code,
    'created_at': encodeTime(createdAt),
  };

  /// Đọc một dòng; nếu truy vấn có thêm cột `subtask_done`, `subtask_total`
  /// thì đọc luôn số việc con.
  factory Task.fromMap(Map<String, Object?> map) => Task(
    id: map['id'] as String,
    title: map['title'] as String,
    note: (map['note'] as String?) ?? '',
    tagId: map['tag_id'] as String?,
    due: decodeTime(map['due_at']),
    end: decodeTime(map['end_at']),
    hasTime: decodeBool(map['has_time']),
    priority: Priority.fromCode(map['priority']),
    done: decodeBool(map['done']),
    completedAt: decodeTime(map['completed_at']),
    reminderMinutes: map['reminder_minutes'] as int?,
    repeatRule: RepeatRule.fromCode(map['repeat_rule']),
    createdAt: decodeTime(map['created_at'])!,
    subtaskDone: (map['subtask_done'] as int?) ?? 0,
    subtaskTotal: (map['subtask_total'] as int?) ?? 0,
  );
}
