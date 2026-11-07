import 'package:flutter/foundation.dart';

import 'db_values.dart';

/// Loại phiên hẹn giờ. [code] là giá trị lưu trong database, không đổi.
enum FocusType {
  pomodoro('pomodoro', 'Pomodoro'),
  shortBreak('short', 'Nghỉ ngắn'),
  longBreak('long', 'Nghỉ dài'),
  custom('custom', 'Tùy chỉnh');

  const FocusType(this.code, this.label);

  final String code;
  final String label;

  /// Phiên tập trung, không phải giờ nghỉ.
  bool get isFocus => this == pomodoro || this == custom;

  static FocusType fromCode(Object? code) =>
      values.firstWhere((t) => t.code == code, orElse: () => custom);
}

/// Một phiên hẹn giờ đã chạy (hết giờ hoặc bị dừng giữa chừng).
class FocusSession {
  const FocusSession({
    required this.id,
    this.taskId,
    required this.type,
    required this.startedAt,
    required this.durationSec,
    this.completed = false,
  });

  final String id;

  /// Việc được bấm giờ; `null` = không gắn việc (hoặc việc đã bị xóa).
  final String? taskId;
  final FocusType type;
  final DateTime startedAt;

  /// Số giây đã chạy thực tế (phiên bỏ dở thì ít hơn thời lượng đặt).
  final int durationSec;

  /// `true` = chạy hết giờ; `false` = bỏ dở.
  final bool completed;

  DateTime get endedAt => startedAt.add(Duration(seconds: durationSec));

  FocusSession copyWith({
    ValueGetter<String?>? taskId,
    FocusType? type,
    DateTime? startedAt,
    int? durationSec,
    bool? completed,
  }) => FocusSession(
    id: id,
    taskId: taskId != null ? taskId() : this.taskId,
    type: type ?? this.type,
    startedAt: startedAt ?? this.startedAt,
    durationSec: durationSec ?? this.durationSec,
    completed: completed ?? this.completed,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'task_id': taskId,
    'type': type.code,
    'started_at': encodeTime(startedAt),
    'duration_sec': durationSec,
    'completed': encodeBool(completed),
  };

  factory FocusSession.fromMap(Map<String, Object?> map) => FocusSession(
    id: map['id'] as String,
    taskId: map['task_id'] as String?,
    type: FocusType.fromCode(map['type']),
    startedAt: decodeTime(map['started_at'])!,
    durationSec: map['duration_sec'] as int,
    completed: decodeBool(map['completed']),
  );
}
