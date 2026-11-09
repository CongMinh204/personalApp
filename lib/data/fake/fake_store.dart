import 'dart:async';

import '../../utils/dates.dart';
import '../default_tags.dart';
import '../models/focus_session.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/subtask.dart';
import '../models/tag.dart';
import '../models/task.dart';
import 'sample_data.dart';

/// Dữ liệu trong bộ nhớ dùng chung cho các FakeRepository, đóng vai trò một
/// database: xóa nhãn hay xóa việc ở repository này ảnh hưởng đúng sang dữ
/// liệu của repository khác, giống bản SQLite.
class FakeStore {
  /// Như app mới cài: chỉ có 4 nhãn mặc định.
  FakeStore({DateTime Function()? clock}) : clock = clock ?? DateTime.now {
    for (final tag in defaultTags) {
      tags[tag.id] = tag;
    }
  }

  /// Thêm dữ liệu mẫu (lib/data/fake/sample_data.dart) tính theo ngày hiện
  /// tại của [clock].
  factory FakeStore.sample({DateTime Function()? clock}) {
    final store = FakeStore(clock: clock);
    final now = store.clock();
    for (final task in [...sampleTasks(now), ...sampleHistoryTasks(now)]) {
      store.tasks[task.id] = task;
    }
    for (final subtask in sampleSubtasks()) {
      store.subtasks[subtask.id] = subtask;
    }
    for (final session in sampleFocusSessions(now)) {
      store.sessions[session.id] = session;
    }
    for (final habit in sampleHabits(now)) {
      store.habits[habit.id] = habit;
    }
    for (final log in sampleHabitLogs(now)) {
      store.habitLogs[habitLogKey(log.habitId, log.date)] = log;
    }
    return store;
  }

  /// Giờ hiện tại, dùng khi đặt `completedAt`, `archivedAt`.
  final DateTime Function() clock;

  // Các "bảng". Map của Dart giữ thứ tự thêm vào, giống thứ tự dòng của SQLite.
  final tasks = <String, Task>{};
  final subtasks = <String, Subtask>{};
  final tags = <String, Tag>{};
  final sessions = <String, FocusSession>{};
  final habits = <String, Habit>{};

  /// Khóa: [habitLogKey].
  final habitLogs = <String, HabitLog>{};

  final _changes = StreamController<void>.broadcast(sync: true);

  /// Gọi sau mỗi lần ghi để các stream `watch...` phát lại.
  void notifyChanged() => _changes.add(null);

  /// Stream phát kết quả của [read] ngay khi được lắng nghe, rồi phát lại sau
  /// mỗi lần ghi. Nghe lại được sau khi đã hủy (như bản SQLite), vì widget
  /// trong danh sách cuộn bị tạo lại và nghe lại cùng một luồng.
  Stream<T> watch<T>(T Function() read) {
    late final StreamController<T> controller;
    StreamSubscription<void>? subscription;
    controller = StreamController<T>.broadcast(
      onListen: () {
        controller.add(read());
        subscription = _changes.stream.listen((_) => controller.add(read()));
      },
      onCancel: () {
        subscription?.cancel();
        subscription = null;
      },
    );
    return controller.stream;
  }
}

/// Khóa của một dòng nhật ký thói quen trong [FakeStore.habitLogs].
String habitLogKey(String habitId, DateTime day) => '$habitId|${dateKey(day)}';
