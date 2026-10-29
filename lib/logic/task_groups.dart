import '../models/task.dart';
import '../utils/vi_date.dart';

class TaskGroups {
  const TaskGroups({
    required this.overdue,
    required this.today,
    required this.upcoming,
  });

  final List<Task> overdue;
  final List<Task> today;
  final List<Task> upcoming;

  int get todayDone => today.where((t) => t.done).length;

  bool get isTodayEmpty => today.isEmpty;

  bool get isAllDone => today.isNotEmpty && todayDone == today.length;
}

/// Việc không có giờ được xếp sau việc có giờ trong cùng một ngày.
int _byTime(Task a, Task b) {
  final ad = a.due, bd = b.due;
  if (ad == null || bd == null) {
    if (ad == null && bd == null) return 0;
    return ad == null ? 1 : -1;
  }
  final byDay = dayDiff(bd, ad);
  if (byDay != 0) return byDay;
  if (a.hasTime != b.hasTime) return a.hasTime ? -1 : 1;
  return ad.compareTo(bd);
}

/// Chia danh sách việc thành Quá hạn / Hôm nay / Sắp tới so với [now].
///
/// - overdue: ngày đã qua và chưa xong (việc quá hạn đã xong thì ẩn).
/// - today: cùng ngày hoặc không có ngày; chưa xong lên trước, rồi theo giờ.
/// - upcoming: sau hôm nay, theo giờ.
TaskGroups groupTasks(List<Task> tasks, DateTime now) {
  final overdue = <Task>[];
  final today = <Task>[];
  final upcoming = <Task>[];

  for (final task in tasks) {
    final due = task.due;
    final diff = due == null ? 0 : dayDiff(now, due);
    if (diff < 0) {
      if (!task.done) overdue.add(task);
    } else if (diff == 0) {
      today.add(task);
    } else {
      upcoming.add(task);
    }
  }

  overdue.sort(_byTime);
  today.sort((a, b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    return _byTime(a, b);
  });
  upcoming.sort(_byTime);

  return TaskGroups(overdue: overdue, today: today, upcoming: upcoming);
}

/// Việc có giờ, chưa xong, bắt đầu sớm nhất sau [now]; `null` nếu không còn.
Task? nextTask(List<Task> today, DateTime now) {
  Task? next;
  for (final task in today) {
    final due = task.due;
    if (task.done || !task.hasTime || due == null || !due.isAfter(now)) {
      continue;
    }
    if (next == null || due.isBefore(next.due!)) next = task;
  }
  return next;
}
