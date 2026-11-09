import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app/dependencies.dart';
import 'app/routes.dart';
import 'app/settings_controller.dart';
import 'app/shell_controller.dart';
import 'data/repositories/focus_repository.dart';
import 'data/repositories/habit_repository.dart';
import 'data/repositories/tag_repository.dart';
import 'data/repositories/task_repository.dart';
import 'features/timer/timer_controller.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.create();
  final settings = await SettingsController.load();
  runApp(PersonalApp(dependencies: dependencies, settings: settings));
}

class PersonalApp extends StatefulWidget {
  const PersonalApp({
    super.key,
    required this.dependencies,
    required this.settings,
  });

  /// Repository của app; test truyền `AppDependencies.fake()`.
  final AppDependencies dependencies;

  /// Cài đặt đã đọc từ shared_preferences.
  final SettingsController settings;

  @override
  State<PersonalApp> createState() => _PersonalAppState();
}

class _PersonalAppState extends State<PersonalApp> {
  final _shell = ShellController();
  late final _timer = TimerController(_shell);

  @override
  void dispose() {
    _timer.dispose();
    _shell.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.dependencies;
    return MultiProvider(
      providers: [
        Provider<TaskRepository>.value(value: deps.tasks),
        Provider<TagRepository>.value(value: deps.tags),
        Provider<FocusRepository>.value(value: deps.focus),
        Provider<HabitRepository>.value(value: deps.habits),
        ChangeNotifierProvider<SettingsController>.value(
          value: widget.settings,
        ),
        ChangeNotifierProvider<ShellController>.value(value: _shell),
        ChangeNotifierProvider<TimerController>.value(value: _timer),
      ],
      // Đổi chủ đề hay màu nhấn trong Cài đặt thì dựng lại theme ngay.
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) {
          final settings = widget.settings;
          return MaterialApp(
            title: 'Việc của tôi',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(accent: settings.accent),
            darkTheme: AppTheme.dark(accent: settings.accent),
            themeMode: settings.themeMode,
            locale: const Locale('vi'),
            supportedLocales: const [Locale('vi'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            onGenerateRoute: AppRoutes.onGenerateRoute,
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}
