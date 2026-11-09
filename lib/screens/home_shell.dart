import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/shell_controller.dart';
import '../features/habits/habits_screen.dart';
import '../features/timer/timer_screen.dart';
import '../features/today/today_screen.dart';

/// Khung 5 tab. Tab đang mở do [ShellController] giữ để màn nào cũng chuyển
/// tab được.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    return Scaffold(
      body: IndexedStack(
        index: shell.tab.index,
        children: [
          const TodayScreen(),
          const _ComingSoon(title: 'Lịch', icon: Icons.calendar_month_rounded),
          const TimerScreen(),
          const _ComingSoon(title: 'Thống kê', icon: Icons.insights_rounded),
          const HabitsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.tab.index,
        onDestinationSelected: (index) => shell.select(HomeTab.values[index]),
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
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department_rounded),
            label: 'Thói quen',
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
