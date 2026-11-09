import 'package:flutter/material.dart' show DateTimeRange;
import 'package:personal_app/app/settings_controller.dart';
import 'package:personal_app/data/fake/fake_focus_repository.dart';
import 'package:personal_app/data/fake/fake_store.dart';
import 'package:personal_app/data/fake/fake_task_repository.dart';
import 'package:personal_app/data/models/focus_session.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/features/timer/countdown_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Đồng hồ giả: tiến thời gian bằng tay.
class FakeClock {
  FakeClock([DateTime? start]) : now = start ?? DateTime(2026, 11, 10, 9);

  DateTime now;

  DateTime call() => now;

  void advance(Duration d) => now = now.add(d);

  void seconds(int s) => advance(Duration(seconds: s));

  void minutes(int m) => advance(Duration(minutes: m));
}

/// Bộ đồ dùng chung cho test đồng hồ đếm ngược: đồng hồ giả, repository Fake
/// và cài đặt.
class CountdownEnv {
  CountdownEnv._(this.clock, this.store, this.settings) {
    focus = FakeFocusRepository(store);
    tasks = FakeTaskRepository(store);
    countdown = CountdownController(
      repository: focus,
      settings: settings,
      clock: clock.call,
      autoTick: false,
      makeId: () => 'phien-${_n++}',
    );
  }

  final FakeClock clock;
  final FakeStore store;
  final SettingsController settings;
  late final FakeFocusRepository focus;
  late final FakeTaskRepository tasks;
  late final CountdownController countdown;
  int _n = 0;

  static Future<CountdownEnv> create({
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final clock = FakeClock();
    return CountdownEnv._(
      clock,
      FakeStore(clock: clock.call),
      SettingsController.fromPrefs(await SharedPreferences.getInstance()),
    );
  }

  /// Mọi phiên đã lưu, theo thứ tự lưu (cũ nhất trước).
  Future<List<FocusSession>> saved() async {
    await countdown.savesDone;
    // sessionsByRange trả về mới nhất trước; đảo lại cho cũ nhất trước.
    final all = await focus.sessionsByRange(_wide);
    return all.reversed.toList();
  }

  Future<void> addTask(String id, {String title = 'Việc'}) =>
      tasks.add(Task(id: id, title: title, createdAt: DateTime(2026, 11, 1)));

  void dispose() => countdown.dispose();
}

final _wide = DateTimeRange(start: DateTime(2000), end: DateTime(2100));
