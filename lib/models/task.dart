enum Priority {
  low('Thấp'),
  medium('Trung bình'),
  high('Cao');

  const Priority(this.label);

  final String label;
}

enum TaskTag {
  study('Học tập'),
  work('Công việc'),
  personal('Cá nhân'),
  health('Sức khỏe');

  const TaskTag(this.label);

  final String label;
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.tag,
    this.due,
    this.end,
    this.hasTime = false,
    this.priority = Priority.medium,
    this.done = false,
    this.subtasksDone = 0,
    this.subtasksTotal = 0,
    this.reminder = false,
    this.repeat = false,
  });

  final String id;
  final String title;
  final TaskTag tag;

  /// Ngày (và giờ bắt đầu nếu [hasTime]) của việc. `null` = không có ngày.
  final DateTime? due;

  /// Giờ kết thúc, chỉ dùng khi [hasTime].
  final DateTime? end;
  final bool hasTime;
  final Priority priority;
  final bool done;
  final int subtasksDone;
  final int subtasksTotal;
  final bool reminder;
  final bool repeat;

  Task copyWith({bool? done}) {
    return Task(
      id: id,
      title: title,
      tag: tag,
      due: due,
      end: end,
      hasTime: hasTime,
      priority: priority,
      done: done ?? this.done,
      subtasksDone: subtasksDone,
      subtasksTotal: subtasksTotal,
      reminder: reminder,
      repeat: repeat,
    );
  }
}
