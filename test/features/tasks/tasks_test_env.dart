import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/app/routes.dart';
import 'package:personal_app/app/settings_controller.dart';
import 'package:personal_app/app/shell_controller.dart';
import 'package:personal_app/data/fake/fake_focus_repository.dart';
import 'package:personal_app/data/fake/fake_store.dart';
import 'package:personal_app/data/fake/fake_tag_repository.dart';
import 'package:personal_app/data/fake/fake_task_repository.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/data/repositories/focus_repository.dart';
import 'package:personal_app/data/repositories/tag_repository.dart';
import 'package:personal_app/data/repositories/task_repository.dart';
import 'package:personal_app/features/timer/timer_controller.dart';
import 'package:personal_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Giờ cố định dùng trong các test của việc: Thứ Năm 29/10/2026 13:40.
final testNow = DateTime(2026, 10, 29, 13, 40);

/// Môi trường test cho các màn của việc: repository Fake dùng chung một
/// [FakeStore], cài đặt, tab đang mở và [TimerController].
class TasksEnv {
  TasksEnv._(this.store, this.settings, this.shell) {
    timer = TimerController(shell);
  }

  final FakeStore store;
  final SettingsController settings;
  final ShellController shell;
  late final TimerController timer;

  late final tasks = FakeTaskRepository(store);
  late final tags = FakeTagRepository(store);
  late final focus = FakeFocusRepository(store);

  /// [sample] = true thì có dữ liệu mẫu của app (tính theo [testNow]).
  static Future<TasksEnv> create({
    bool sample = false,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    return TasksEnv._(
      sample
          ? FakeStore.sample(clock: () => testNow)
          : FakeStore(clock: () => testNow),
      SettingsController.fromPrefs(await SharedPreferences.getInstance()),
      ShellController(),
    );
  }

  /// Dựng một app có đủ Provider và routes, với [home] là màn đầu tiên.
  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(1170, 2532),
  }) async {
    // Mặc định màn hình cỡ điện thoại (390x844).
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<TaskRepository>.value(value: tasks),
          Provider<TagRepository>.value(value: tags),
          Provider<FocusRepository>.value(value: focus),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<ShellController>.value(value: shell),
          ChangeNotifierProvider<TimerController>.value(value: timer),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  NavigatorState _navigator(WidgetTester tester) =>
      tester.state<NavigatorState>(find.byType(Navigator).first);

  /// Kết quả (giá trị khi màn vừa mở đóng lại) của lần [open] hoặc
  /// [openScreen] gần nhất.
  Future<Object?> lastResult = Future.value();

  /// Mở một route có tên trên nền một màn trống (để màn đó có chỗ quay lại).
  Future<void> open(
    WidgetTester tester,
    String route, {
    Object? arguments,
    Size size = const Size(1170, 5000),
  }) async {
    await pump(tester, const Scaffold(body: SizedBox()), size: size);
    lastResult = _navigator(tester)
        .pushNamed<Object?>(route, arguments: arguments);
    await tester.pumpAndSettle();
  }

  /// Mở một màn bất kỳ trên nền một màn trống.
  Future<void> openScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(1170, 5000),
  }) async {
    await pump(tester, const Scaffold(body: SizedBox()), size: size);
    lastResult = _navigator(tester)
        .push<Object?>(MaterialPageRoute<Object?>(builder: (_) => screen));
    await tester.pumpAndSettle();
  }
}

/// Một việc cho test, mặc định hạn hôm nay (cả ngày).
Task testTask(
  String id, {
  String? title,
  String note = '',
  String? tagId,
  DateTime? due,
  DateTime? end,
  bool hasTime = false,
  Priority priority = Priority.medium,
  bool done = false,
  int? reminderMinutes,
  RepeatRule repeat = RepeatRule.none,
}) => Task(
  id: id,
  title: title ?? 'Việc $id',
  note: note,
  tagId: tagId,
  due: due ?? DateTime(2026, 10, 29),
  end: end,
  hasTime: hasTime,
  priority: priority,
  done: done,
  completedAt: done ? DateTime(2026, 10, 29, 9) : null,
  reminderMinutes: reminderMinutes,
  repeatRule: repeat,
  createdAt: DateTime(2026, 10, 1),
);
