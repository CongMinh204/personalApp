import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app/dependencies.dart';
import 'data/repositories/focus_repository.dart';
import 'data/repositories/habit_repository.dart';
import 'data/repositories/tag_repository.dart';
import 'data/repositories/task_repository.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.create();
  runApp(PersonalApp(dependencies: dependencies));
}

class PersonalApp extends StatefulWidget {
  const PersonalApp({super.key, required this.dependencies});

  /// Repository của app; test truyền `AppDependencies.fake()`.
  final AppDependencies dependencies;

  @override
  State<PersonalApp> createState() => _PersonalAppState();
}

class _PersonalAppState extends State<PersonalApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    final isDark = switch (_themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
    setState(() => _themeMode = isDark ? ThemeMode.light : ThemeMode.dark);
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
      ],
      child: _buildApp(),
    );
  }

  Widget _buildApp() {
    return MaterialApp(
      title: 'Việc của tôi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: HomeShell(onToggleTheme: _toggleTheme),
    );
  }
}
