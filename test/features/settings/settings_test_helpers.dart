import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/app/routes.dart';
import 'package:personal_app/app/settings_controller.dart';
import 'package:personal_app/data/fake/fake_store.dart';
import 'package:personal_app/data/fake/fake_tag_repository.dart';
import 'package:personal_app/data/fake/fake_task_repository.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/data/repositories/tag_repository.dart';
import 'package:personal_app/data/repositories/task_repository.dart';
import 'package:personal_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Môi trường chung để dựng một màn của Cài đặt trong test: repository Fake
/// dùng chung một [FakeStore], [SettingsController] đọc từ prefs giả, và theme
/// đổi theo cài đặt như `PersonalApp`.
class SettingsTestEnv {
  SettingsTestEnv._(this.store, this.settings);

  final FakeStore store;
  final SettingsController settings;

  late final tasks = FakeTaskRepository(store);
  late final tags = FakeTagRepository(store);

  static Future<SettingsTestEnv> create({
    Map<String, Object> prefs = const {},
    List<Task> tasks = const [],
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final env = SettingsTestEnv._(
      FakeStore(),
      SettingsController.fromPrefs(await SharedPreferences.getInstance()),
    );
    for (final task in tasks) {
      await env.tasks.add(task);
    }
    return env;
  }

  /// Dựng [screen] làm màn đầu tiên của một app có đủ Provider và routes.
  Future<void> pump(WidgetTester tester, Widget screen) async {
    // Màn hình cỡ điện thoại (390x844).
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<TaskRepository>.value(value: tasks),
          Provider<TagRepository>.value(value: tags),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
        ],
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light(accent: settings.accent),
            darkTheme: AppTheme.dark(accent: settings.accent),
            themeMode: settings.themeMode,
            locale: const Locale('vi'),
            supportedLocales: const [Locale('vi')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            onGenerateRoute: AppRoutes.onGenerateRoute,
            home: screen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Một việc đơn giản cho test.
Task testTask(
  String id, {
  String? tagId,
  bool done = false,
  DateTime? completedAt,
}) => Task(
  id: id,
  title: 'Việc $id',
  tagId: tagId,
  done: done,
  completedAt: completedAt,
  createdAt: DateTime(2026, 11, 9),
);
