import '../../data/ids.dart';
import '../../data/models/subtask.dart';
import '../../data/models/task.dart';
import '../../data/repositories/task_repository.dart';
import 'recurrence.dart';

/// Một việc vừa bị xóa kèm việc con của nó, để hoàn tác.
class DeletedTask {
  const DeletedTask(this.task, this.subtasks);

  final Task task;
  final List<Subtask> subtasks;
}

/// Các thao tác trên việc dùng chung cho Hôm nay và Chi tiết việc.
class TaskActions {
  TaskActions(this._tasks, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TaskRepository _tasks;
  final DateTime Function() _clock;

  /// Đổi trạng thái xong của [task]. Khi một việc có lặp lại được đánh dấu
  /// xong, việc đã xong được giữ nguyên (để Thống kê đếm) và một việc mới cho
  /// lần kế tiếp được thêm vào, kèm việc con chưa xong. Trả về việc mới đó,
  /// hoặc `null` nếu không có.
  ///
  /// Bỏ đánh dấu xong không xóa việc kế tiếp đã tạo.
  Future<Task?> toggleDone(Task task) async {
    final done = !task.done;
    await _tasks.setDone(task.id, done);
    if (!done) return null;

    final next = nextOccurrence(task, _clock(), id: newId());
    if (next == null) return null;
    final subtasks = nextSubtasks(next.id, await _tasks.getSubtasks(task.id));
    await _tasks.add(next, subtasks: subtasks);
    return next;
  }

  /// Xóa [task] và trả về bản chụp để [undoDelete] khôi phục.
  Future<DeletedTask> delete(Task task) async {
    final snapshot = DeletedTask(task, await _tasks.getSubtasks(task.id));
    await _tasks.delete(task.id);
    return snapshot;
  }

  /// Thêm lại việc và việc con đã xóa. Nếu nhãn của việc đã bị xóa trong
  /// lúc đó thì khôi phục việc ở trạng thái không nhãn.
  ///
  /// Các phiên hẹn giờ đã gắn với việc này đã chuyển thành "không gắn việc"
  /// khi xóa và không được gắn lại.
  Future<void> undoDelete(DeletedTask deleted) async {
    try {
      await _tasks.add(deleted.task, subtasks: deleted.subtasks);
    } on ArgumentError {
      await _tasks.add(
        deleted.task.copyWith(tagId: () => null),
        subtasks: deleted.subtasks,
      );
    }
  }
}
