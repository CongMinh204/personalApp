enum SessionType { pomodoro, shortBreak, longBreak, custom }

/// Bảng FocusSession trong ERD:
/// id, taskId (có thể trống), type, startedAt, durationSec, completed.
///
/// `Task.id` của app là String nên [taskId] cũng là String. [taskTitle] được
/// lưu kèm (chụp lại lúc bắt đầu) để Lịch sử vẫn hiện đúng tên việc dù việc
/// đã bị xóa hoặc đổi tên.
class FocusSession {
  const FocusSession({
    this.id,
    this.taskId,
    this.taskTitle,
    required this.type,
    required this.startedAt,
    required this.durationSec,
    required this.completed,
  });

  final int? id;
  final String? taskId;
  final String? taskTitle;
  final SessionType type;
  final DateTime startedAt;

  /// Số giây đã tập trung thực tế (phiên bỏ dở thì nhỏ hơn thời lượng đặt).
  final int durationSec;
  final bool completed;

  DateTime get endedAt => startedAt.add(Duration(seconds: durationSec));

  Map<String, Object?> toMap() => {
    'id': id,
    'taskId': taskId,
    'taskTitle': taskTitle,
    'type': type.name,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'durationSec': durationSec,
    'completed': completed ? 1 : 0,
  };

  factory FocusSession.fromMap(Map<String, Object?> m) => FocusSession(
    id: m['id'] as int?,
    taskId: m['taskId'] as String?,
    taskTitle: m['taskTitle'] as String?,
    type: SessionType.values.byName(m['type'] as String),
    startedAt: DateTime.fromMillisecondsSinceEpoch(m['startedAt'] as int),
    durationSec: m['durationSec'] as int,
    completed: (m['completed'] as int) == 1,
  );
}
