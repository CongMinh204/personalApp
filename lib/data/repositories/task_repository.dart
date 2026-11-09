import 'package:flutter/material.dart' show DateTimeRange;

import '../models/subtask.dart';
import '../models/task.dart';

/// Lưu và đọc việc, việc con. Xem docs/DATA_CONTRACT.md, mục 4.
abstract interface class TaskRepository {
  /// Mọi việc (cả đã xong). Màn Hôm nay tự nhóm Quá hạn/Hôm nay/Sắp tới.
  Stream<List<Task>> watchAll();

  /// Mọi việc, đọc một lần (dự phòng, chưa màn nào dùng).
  Future<List<Task>> getAll();

  /// Việc có `due` trong ngày [day] (không gồm việc không có ngày), sắp theo
  /// due.
  Stream<List<Task>> watchByDay(DateTime day);

  /// Việc có `due` trong [range] (không tính `range.end`), sắp theo due.
  Stream<List<Task>> watchByRange(DateTimeRange range);

  /// Việc chưa xong, sắp theo due; việc không có ngày ở cuối.
  Future<List<Task>> getUnfinished();

  Future<Task?> getById(String id);

  Stream<Task?> watchById(String id);

  /// Tìm trong tiêu đề, ghi chú và tên nhãn, không phân biệt hoa thường và
  /// dấu tiếng Việt ("hoc tap" tìm ra "Học tập").
  /// [query] rỗng trả về danh sách rỗng. Sắp theo due, việc không có ngày ở
  /// cuối.
  Future<List<Task>> search(String query);

  /// Số việc hoàn thành mỗi ngày trong [range], tính theo `completedAt`. Có
  /// đủ mọi ngày trong khoảng (khóa là 00:00 của ngày), ngày không có việc = 0.
  Future<Map<DateTime, int>> countDoneByDay(DateTimeRange range);

  /// Việc có `completedAt` trong [range], sắp theo completedAt.
  Future<List<Task>> getCompletedInRange(DateTimeRange range);

  /// Thêm việc mới cùng việc con (`taskId` của việc con phải bằng `task.id`).
  /// Hoàn tác xóa: gọi lại với đúng task và việc con cũ.
  Future<void> add(Task task, {List<Subtask> subtasks = const []});

  /// Lưu thay đổi của việc. Không đổi `done`/`completedAt` (dùng [setDone]).
  /// Truyền [subtasks] thì thay toàn bộ việc con của việc này bằng danh sách
  /// đó.
  Future<void> update(Task task, {List<Subtask>? subtasks});

  /// Đánh dấu xong (`completedAt` = bây giờ) hoặc bỏ xong (`completedAt` =
  /// null).
  Future<void> setDone(String id, bool done);

  /// Xóa việc: việc con bị xóa theo, phiên tập trung chuyển thành không gắn
  /// việc.
  Future<void> delete(String id);

  /// Xóa mọi việc đã hoàn thành, trả về số việc đã xóa.
  Future<int> deleteCompleted();

  /// Việc con của một việc, theo thứ tự thêm.
  Future<List<Subtask>> getSubtasks(String taskId);

  Stream<List<Subtask>> watchSubtasks(String taskId);

  Future<void> setSubtaskDone(String subtaskId, bool done);
}
