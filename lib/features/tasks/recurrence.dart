import '../../data/ids.dart';
import '../../data/models/subtask.dart';
import '../../data/models/task.dart';
import '../../utils/dates.dart';
import '../../utils/vi_date.dart';

/// Ngày hẹn của lần lặp kế tiếp sau [due], giữ nguyên giờ và phút.
///
/// Lặp theo tháng giữ cùng ngày trong tháng; tháng ngắn hơn thì lấy ngày cuối
/// tháng (31/1 → 28/2 hoặc 29/2). Lần lặp sau đó tính tiếp từ ngày đã rút ngắn
/// (28/2 → 28/3), vì việc không lưu ngày gốc.
DateTime nextDue(DateTime due, RepeatRule rule) => switch (rule) {
  RepeatRule.none => due,
  RepeatRule.daily => DateTime(
    due.year,
    due.month,
    due.day + 1,
    due.hour,
    due.minute,
  ),
  RepeatRule.weekly => DateTime(
    due.year,
    due.month,
    due.day + 7,
    due.hour,
    due.minute,
  ),
  RepeatRule.monthly => _addMonth(due),
};

DateTime _addMonth(DateTime d) {
  final month = d.month + 1; // DateTime tự đổi tháng 13 thành tháng 1 năm sau.
  final lastDay = DateTime(d.year, month + 1, 0).day;
  return DateTime(
    d.year,
    month,
    d.day > lastDay ? lastDay : d.day,
    d.hour,
    d.minute,
  );
}

/// Việc cho lần lặp kế tiếp của [task] sau khi nó được hoàn thành, hoặc `null`
/// nếu việc không lặp hoặc không có ngày hẹn.
///
/// Việc mới có id [id], chưa xong, giữ nguyên tiêu đề, ghi chú, nhãn, ưu tiên,
/// nhắc trước và kiểu lặp. Nếu ngày kế tiếp vẫn trước hôm nay (hoàn thành trễ
/// nhiều ngày) thì nhảy tiếp tới lần lặp đầu tiên từ hôm nay trở đi, để không
/// tạo ra một việc đã quá hạn ngay từ đầu.
Task? nextOccurrence(Task task, DateTime now, {required String id}) {
  final due = task.due;
  if (task.repeatRule == RepeatRule.none || due == null) return null;

  final today = startOfDay(now);
  var next = nextDue(due, task.repeatRule);
  var guard = 0;
  while (startOfDay(next).isBefore(today) && guard++ < 2000) {
    next = nextDue(next, task.repeatRule);
  }

  final end = task.end;
  final nextEnd = task.hasTime && end != null
      ? DateTime(
          next.year,
          next.month,
          next.day + dayDiff(due, end),
          end.hour,
          end.minute,
        )
      : null;

  return Task(
    id: id,
    title: task.title,
    note: task.note,
    tagId: task.tagId,
    due: next,
    end: nextEnd,
    hasTime: task.hasTime,
    priority: task.priority,
    reminderMinutes: task.reminderMinutes,
    repeatRule: task.repeatRule,
    createdAt: now,
  );
}

/// Việc con của lần lặp kế tiếp: cùng tên, chưa xong, id mới.
List<Subtask> nextSubtasks(
  String newTaskId,
  List<Subtask> previous, {
  String Function() makeId = newId,
}) => [
  for (final s in previous)
    Subtask(id: makeId(), taskId: newTaskId, title: s.title),
];
