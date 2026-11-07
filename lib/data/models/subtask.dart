import 'db_values.dart';

/// Việc con của một việc. Hiển thị theo thứ tự thêm vào.
class Subtask {
  const Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    this.done = false,
  });

  final String id;

  /// Việc chứa việc con này; xóa việc thì việc con bị xóa theo.
  final String taskId;
  final String title;
  final bool done;

  Subtask copyWith({String? title, bool? done}) => Subtask(
    id: id,
    taskId: taskId,
    title: title ?? this.title,
    done: done ?? this.done,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'task_id': taskId,
    'title': title,
    'done': encodeBool(done),
  };

  factory Subtask.fromMap(Map<String, Object?> map) => Subtask(
    id: map['id'] as String,
    taskId: map['task_id'] as String,
    title: map['title'] as String,
    done: decodeBool(map['done']),
  );
}
