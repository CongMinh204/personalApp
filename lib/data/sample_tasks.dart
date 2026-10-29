import '../models/task.dart';

/// Dữ liệu mẫu, tính theo ngày của [now].
List<Task> sampleTasks(DateTime now) {
  DateTime day(int offset, [int hour = 0, int minute = 0]) =>
      DateTime(now.year, now.month, now.day + offset, hour, minute);

  return [
    // Quá hạn
    Task(
      id: 'lab3',
      title: 'Nộp báo cáo Lab 3 PRM393',
      tag: TaskTag.study,
      due: day(-1, 23, 59),
      hasTime: true,
      priority: Priority.high,
      reminder: true,
    ),
    Task(
      id: 'library-card',
      title: 'Gia hạn thẻ thư viện',
      tag: TaskTag.personal,
      due: day(-3),
      priority: Priority.low,
    ),

    // Hôm nay
    Task(
      id: 'exe201',
      title: 'Họp nhóm EXE201',
      tag: TaskTag.work,
      due: day(0, 14),
      end: day(0, 15),
      hasTime: true,
      priority: Priority.medium,
      reminder: true,
    ),
    Task(
      id: 'pe-flutter',
      title: 'Ôn tập PE Flutter (form validate)',
      tag: TaskTag.study,
      due: day(0, 19, 30),
      end: day(0, 21),
      hasTime: true,
      priority: Priority.high,
      subtasksDone: 1,
      subtasksTotal: 3,
      reminder: true,
    ),
    Task(
      id: 'running',
      title: 'Chạy bộ 30 phút',
      tag: TaskTag.health,
      due: day(0, 6),
      hasTime: true,
      priority: Priority.low,
      done: true,
      repeat: true,
    ),
    Task(
      id: 'groceries',
      title: 'Mua sữa và trứng',
      tag: TaskTag.personal,
      due: day(0),
      priority: Priority.low,
      done: true,
    ),

    // Sắp tới
    Task(
      id: 'midterm',
      title: 'Thi giữa kỳ PRM393',
      tag: TaskTag.study,
      due: day(2, 8),
      hasTime: true,
      priority: Priority.high,
      reminder: true,
    ),
    Task(
      id: 'mom-birthday',
      title: 'Sinh nhật mẹ',
      tag: TaskTag.personal,
      due: day(5),
      priority: Priority.medium,
      reminder: true,
      repeat: true,
    ),
  ];
}
