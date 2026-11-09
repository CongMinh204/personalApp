import 'package:flutter/material.dart';

import '../data/focus_session_repository.dart';
import '../data/sample_tasks.dart';
import '../logic/countdown_controller.dart';
import '../logic/stopwatch_controller.dart';
import '../models/task.dart';
import '../services/timer_notification_service.dart';
import 'timer_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.focusRepository, this.onToggleTheme});

  /// Mặc định mở SQLite ở lần dùng đầu tiên; truyền vào khi test.
  final FocusSessionRepository? focusRepository;
  final VoidCallback? onToggleTheme;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _initialTasks = sampleTasks(DateTime.now());
  int _index = 0;

  // Hẹn giờ: đặt ở shell để đồng hồ vẫn chạy khi chuyển tab.
  late final FocusSessionRepository _focusRepository =
      widget.focusRepository ?? LazyFocusSessionRepository();
  late final CountdownController _countdown = CountdownController(
    repository: _focusRepository,
    notifications: TimerNotificationService.instance,
  );
  final _stopwatch = StopwatchController();

  // Bản sao danh sách việc mới nhất từ màn Hôm nay, dùng cho bộ chọn việc.
  late List<Task> _tasks = _initialTasks;

  @override
  void dispose() {
    _countdown.dispose();
    _stopwatch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          TodayScreen(
            initialTasks: _initialTasks,
            onToggleTheme: widget.onToggleTheme,
            onTasksChanged: (tasks) => _tasks = tasks,
          ),
          const _ComingSoon(title: 'Lịch', icon: Icons.calendar_month_rounded),
          TimerScreen(
            countdown: _countdown,
            stopwatch: _stopwatch,
            repository: _focusRepository,
            loadTasks: () async => [
              for (final t in _tasks)
                if (!t.done) TaskRef(t.id, t.title),
            ],
          ),
          const _ComingSoon(title: 'Thống kê', icon: Icons.insights_rounded),
          const _ComingSoon(title: 'Cài đặt', icon: Icons.settings_outlined),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded),
            label: 'Hôm nay',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Lịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer_rounded),
            label: 'Hẹn giờ',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Thống kê',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(icon, size: 40, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sắp có',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
