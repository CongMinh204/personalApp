import 'package:flutter/material.dart';

import '../../utils/dates.dart';
import '../default_tags.dart';
import '../models/focus_session.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/subtask.dart';
import '../models/task.dart';

// Dữ liệu mẫu cho bản Fake, tính theo ngày của `now`. Id cố định để test và
// các màn tham chiếu được (ví dụ 'pe-flutter').

DateTime _at(DateTime now, int dayOffset, [int hour = 0, int minute = 0]) =>
    DateTime(now.year, now.month, now.day + dayOffset, hour, minute);

/// 8 việc của màn Hôm nay: 2 quá hạn, 4 hôm nay (2 đã xong), 2 sắp tới.
List<Task> sampleTasks(DateTime now) {
  DateTime day(int offset, [int hour = 0, int minute = 0]) =>
      _at(now, offset, hour, minute);
  final created = day(-7, 9);

  return [
    // Quá hạn
    Task(
      id: 'lab3',
      title: 'Nộp báo cáo Lab 3 PRM393',
      tagId: DefaultTagIds.study,
      due: day(-1, 23, 59),
      hasTime: true,
      priority: Priority.high,
      reminderMinutes: 60,
      createdAt: created,
    ),
    Task(
      id: 'library-card',
      title: 'Gia hạn thẻ thư viện',
      tagId: DefaultTagIds.personal,
      due: day(-3),
      priority: Priority.low,
      createdAt: created,
    ),

    // Hôm nay
    Task(
      id: 'exe201',
      title: 'Họp nhóm EXE201',
      tagId: DefaultTagIds.work,
      due: day(0, 14),
      end: day(0, 15),
      hasTime: true,
      priority: Priority.medium,
      reminderMinutes: 15,
      createdAt: created,
    ),
    Task(
      id: 'pe-flutter',
      title: 'Ôn tập PE Flutter (form validate)',
      note: 'Làm lại bài form đăng ký và viết unit test cho các hàm validate.',
      tagId: DefaultTagIds.study,
      due: day(0, 19, 30),
      end: day(0, 21),
      hasTime: true,
      priority: Priority.high,
      reminderMinutes: 15,
      createdAt: created,
      subtaskDone: 1,
      subtaskTotal: 3,
    ),
    Task(
      id: 'running',
      title: 'Chạy bộ 30 phút',
      tagId: DefaultTagIds.health,
      due: day(0, 6),
      hasTime: true,
      priority: Priority.low,
      done: true,
      completedAt: day(0, 6, 40),
      repeatRule: RepeatRule.daily,
      createdAt: created,
    ),
    Task(
      id: 'groceries',
      title: 'Mua sữa và trứng',
      tagId: DefaultTagIds.personal,
      due: day(0),
      priority: Priority.low,
      done: true,
      completedAt: day(0, 8, 15),
      createdAt: created,
    ),

    // Sắp tới
    Task(
      id: 'midterm',
      title: 'Thi giữa kỳ PRM393',
      tagId: DefaultTagIds.study,
      due: day(2, 8),
      hasTime: true,
      priority: Priority.high,
      reminderMinutes: 1440,
      createdAt: created,
    ),
    Task(
      id: 'mom-birthday',
      title: 'Sinh nhật mẹ',
      tagId: DefaultTagIds.personal,
      due: day(5),
      priority: Priority.medium,
      createdAt: created,
    ),
  ];
}

/// Việc đã xong trong tuần trước, để màn Thống kê có số liệu. Không hiện ở
/// màn Hôm nay (việc quá hạn đã xong bị ẩn).
List<Task> sampleHistoryTasks(DateTime now) {
  DateTime day(int offset, [int hour = 0, int minute = 0]) =>
      _at(now, offset, hour, minute);

  Task done(
    String id,
    String title,
    String tagId,
    DateTime due,
    DateTime completedAt, {
    bool hasTime = false,
    Priority priority = Priority.medium,
    RepeatRule repeatRule = RepeatRule.none,
  }) => Task(
    id: id,
    title: title,
    tagId: tagId,
    due: due,
    hasTime: hasTime,
    priority: priority,
    done: true,
    completedAt: completedAt,
    repeatRule: repeatRule,
    createdAt: day(-10, 9),
  );

  return [
    done(
      'lab2',
      'Nộp báo cáo Lab 2 PRM393',
      DefaultTagIds.study,
      day(-6, 23, 59),
      day(-6, 21, 10),
      hasTime: true,
      priority: Priority.high,
    ),
    done(
      'reading-ch5',
      'Đọc chương 5 giáo trình PRM393',
      DefaultTagIds.study,
      day(-5),
      day(-5, 20),
    ),
    // Xong trễ một ngày.
    done(
      'clean-room',
      'Dọn phòng',
      DefaultTagIds.personal,
      day(-4),
      day(-3, 9),
      priority: Priority.low,
    ),
    done(
      'exe201-report',
      'Gửi báo cáo tiến độ EXE201',
      DefaultTagIds.work,
      day(-2, 17),
      day(-2, 16, 30),
      hasTime: true,
    ),
    // Các lần đã xong của việc lặp lại "Chạy bộ 30 phút".
    done(
      'running-2',
      'Chạy bộ 30 phút',
      DefaultTagIds.health,
      day(-2, 6),
      day(-2, 6, 35),
      hasTime: true,
      priority: Priority.low,
      repeatRule: RepeatRule.daily,
    ),
    done(
      'running-1',
      'Chạy bộ 30 phút',
      DefaultTagIds.health,
      day(-1, 6),
      day(-1, 6, 40),
      hasTime: true,
      priority: Priority.low,
      repeatRule: RepeatRule.daily,
    ),
  ];
}

/// 3 việc con của "Ôn tập PE Flutter", 1 việc đã xong.
List<Subtask> sampleSubtasks() => const [
  Subtask(
    id: 'pe-flutter-1',
    taskId: 'pe-flutter',
    title: 'Viết validator cho email',
    done: true,
  ),
  Subtask(
    id: 'pe-flutter-2',
    taskId: 'pe-flutter',
    title: 'Viết validator cho mật khẩu',
  ),
  Subtask(
    id: 'pe-flutter-3',
    taskId: 'pe-flutter',
    title: 'Viết unit test cho form',
  ),
];

/// Phiên tập trung hôm nay và hôm qua, như màn Lịch sử tập trung.
List<FocusSession> sampleFocusSessions(DateTime now) {
  DateTime day(int offset, int hour, int minute) =>
      _at(now, offset, hour, minute);

  FocusSession pomodoro(
    String id,
    String? taskId,
    DateTime startedAt,
    int minutes, {
    bool completed = true,
  }) => FocusSession(
    id: id,
    taskId: taskId,
    type: FocusType.pomodoro,
    startedAt: startedAt,
    durationSec: minutes * 60,
    completed: completed,
  );

  return [
    pomodoro('focus-1', 'pe-flutter', day(0, 9, 5), 25),
    pomodoro('focus-2', 'pe-flutter', day(0, 10, 15), 25),
    pomodoro('focus-3', 'lab3', day(0, 13, 10), 12, completed: false),
    pomodoro('focus-4', 'pe-flutter', day(-1, 20, 0), 25),
    FocusSession(
      id: 'focus-5',
      type: FocusType.shortBreak,
      startedAt: day(-1, 20, 25),
      durationSec: 300,
      completed: true,
    ),
    pomodoro('focus-6', null, day(-1, 20, 30), 25),
  ];
}

/// 6 thói quen đang dùng và 3 đã lưu trữ, như mockup.
List<Habit> sampleHabits(DateTime now) {
  DateTime day(int offset) => _at(now, offset);

  return [
    Habit(
      id: 'habit-water',
      name: 'Uống 2 lít nước',
      icon: 'drop',
      color: const Color(0xFF5B4FE0),
      goalPerDay: 8,
      unit: 'ly',
      reminderTime: const TimeOfDay(hour: 20, minute: 0),
      startDate: day(-40),
    ),
    Habit(
      id: 'habit-reading',
      name: 'Đọc sách 20 phút',
      icon: 'book',
      color: const Color(0xFF23774F),
      startDate: day(-40),
    ),
    Habit(
      id: 'habit-running',
      name: 'Chạy bộ 30 phút',
      icon: 'heart',
      color: const Color(0xFFBE185D),
      startDate: day(-40),
    ),
    Habit(
      id: 'habit-flutter',
      name: 'Ôn Flutter 1 giờ',
      icon: 'bolt',
      color: const Color(0xFFC2410C),
      startDate: day(-40),
    ),
    Habit(
      id: 'habit-sleep',
      name: 'Ngủ trước 23:00',
      icon: 'moon',
      color: const Color(0xFF1E6FD9),
      reminderTime: const TimeOfDay(hour: 22, minute: 30),
      startDate: day(-40),
    ),
    Habit(
      id: 'habit-gym',
      name: 'Tập gym',
      icon: 'heart',
      color: const Color(0xFF1E6FD9),
      repeatDays: const {1, 3, 5},
      startDate: day(-40),
    ),

    // Đã lưu trữ
    Habit(
      id: 'habit-meditation',
      name: 'Thiền 10 phút',
      icon: 'moon',
      startDate: day(-70),
      archivedAt: day(-17),
    ),
    Habit(
      id: 'habit-vocab',
      name: 'Học từ vựng tiếng Anh',
      icon: 'book',
      color: const Color(0xFF23774F),
      startDate: day(-70),
      archivedAt: day(-38),
    ),
    Habit(
      id: 'habit-snack',
      name: 'Không ăn vặt sau 21:00',
      icon: 'moon',
      color: const Color(0xFFC2410C),
      startDate: day(-70),
      archivedAt: day(-50),
    ),
  ];
}

/// Nhật ký cho [sampleHabits]: ví dụ "Uống 2 lít nước" có chuỗi 12 ngày (dài
/// nhất 15) và hôm nay mới uống 5/8 ly.
List<HabitLog> sampleHabitLogs(DateTime now) {
  final today = startOfDay(now);
  final logs = <HabitLog>[];

  void add(String habitId, int daysAgo, int count) => logs.add(
    HabitLog(
      habitId: habitId,
      date: DateTime(today.year, today.month, today.day - daysAgo),
      count: count,
    ),
  );

  // [length] ngày liền nhau đều đạt mục tiêu, ngày gần nhất là [endDaysAgo]
  // ngày trước.
  void run(
    String habitId,
    int goal, {
    required int endDaysAgo,
    required int length,
  }) {
    for (var i = 0; i < length; i++) {
      add(habitId, endDaysAgo + i, goal);
    }
  }

  run('habit-water', 8, endDaysAgo: 1, length: 12);
  run('habit-water', 8, endDaysAgo: 14, length: 15);
  add('habit-water', 0, 5);
  run('habit-reading', 1, endDaysAgo: 0, length: 9);
  run('habit-running', 1, endDaysAgo: 1, length: 4);
  run('habit-flutter', 1, endDaysAgo: 1, length: 5);
  run('habit-sleep', 1, endDaysAgo: 0, length: 3);
  for (var i = 1; i <= 14; i++) {
    final date = DateTime(today.year, today.month, today.day - i);
    if (const {1, 3, 5}.contains(date.weekday)) {
      add('habit-gym', i, 1);
    }
  }
  run('habit-meditation', 1, endDaysAgo: 18, length: 14);
  run('habit-vocab', 1, endDaysAgo: 39, length: 8);
  run('habit-snack', 1, endDaysAgo: 51, length: 5);
  return logs;
}
