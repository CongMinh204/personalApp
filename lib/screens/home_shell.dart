import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/shell_controller.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/habits/habits_screen.dart';
import '../features/stats/stats_screen.dart';
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
          const CalendarScreen(),
          const TimerScreen(),
          const StatsScreen(),
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
