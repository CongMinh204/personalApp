import 'package:flutter/foundation.dart';

import '../data/fake/fake_focus_repository.dart';
import '../data/fake/fake_habit_repository.dart';
import '../data/fake/fake_store.dart';
import '../data/fake/fake_tag_repository.dart';
import '../data/fake/fake_task_repository.dart';
import '../data/repositories/focus_repository.dart';
import '../data/repositories/habit_repository.dart';
import '../data/repositories/tag_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/sqlite/app_database.dart';
import '../data/sqlite/sqlite_focus_repository.dart';
import '../data/sqlite/sqlite_habit_repository.dart';
import '../data/sqlite/sqlite_tag_repository.dart';
import '../data/sqlite/sqlite_task_repository.dart';

/// Bộ 4 repository của app. Đây là chỗ DUY NHẤT chọn dùng SQLite hay Fake; các
/// màn chỉ nhận repository qua Provider, không tự tạo.
class AppDependencies {
  const AppDependencies({
    required this.tasks,
    required this.tags,
    required this.focus,
    required this.habits,
    this.close,
  });

  final TaskRepository tasks;
  final TagRepository tags;
  final FocusRepository focus;
  final HabitRepository habits;

  /// Đóng database khi thoát (null với bản Fake).
  final Future<void> Function()? close;

  /// Chọn theo nền tảng: Android, iOS và macOS lưu bằng SQLite; web, Windows
  /// và Linux dùng bản Fake trong bộ nhớ có dữ liệu mẫu (sqflite không chạy ở
  /// đó), tắt app là mất thay đổi.
  static Future<AppDependencies> create() {
    final sqliteSupported =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    return sqliteSupported ? sqlite() : Future.value(AppDependencies.fake());
  }

  /// Lưu bằng SQLite. Truyền [app] để dùng database đã mở sẵn (test).
  static Future<AppDependencies> sqlite({AppDatabase? app}) async {
    final database = app ?? await AppDatabase.open();
    return AppDependencies(
      tasks: SqliteTaskRepository(database),
      tags: SqliteTagRepository(database),
      focus: SqliteFocusRepository(database),
      habits: SqliteHabitRepository(database),
      close: database.close,
    );
  }

  /// Dữ liệu trong bộ nhớ. [sample] = false thì như app mới cài.
  factory AppDependencies.fake({bool sample = true}) {
    final store = sample ? FakeStore.sample() : FakeStore();
    return AppDependencies(
      tasks: FakeTaskRepository(store),
      tags: FakeTagRepository(store),
      focus: FakeFocusRepository(store),
      habits: FakeHabitRepository(store),
    );
  }
}
