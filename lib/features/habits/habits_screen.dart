import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../data/models/habit.dart';
import '../../data/repositories/habit_repository.dart';
import '../../utils/dates.dart';
import '../../utils/vi_date.dart';
import 'habit_logic.dart';
import 'widgets/habit_tile.dart';

/// Tab Thói quen: tiến độ hôm nay và danh sách thói quen đang dùng.
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key, this.clock = DateTime.now});

  /// Nguồn thời gian hiện tại; thay bằng giờ cố định khi test.
  final DateTime Function() clock;

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  late final HabitRepository _repo = context.read<HabitRepository>();

  late DateTime _day = startOfDay(widget.clock());
  List<Habit>? _habits;
  Map<String, int>? _counts;
  Map<String, int> _streaks = const {};
  bool _streaksLoaded = false;

  StreamSubscription<List<Habit>>? _habitsSub;
  StreamSubscription<Map<String, int>>? _countsSub;

  // Mỗi lần tính lại chuỗi ngày tăng số này; kết quả của lần cũ đến trễ bị bỏ.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _habitsSub = _repo.watchActive().listen((habits) {
      if (!mounted) return;
      setState(() => _habits = habits);
      _refreshStreaks();
    });
    _subscribeCounts();
  }

  @override
  void dispose() {
    _habitsSub?.cancel();
    _countsSub?.cancel();
    super.dispose();
  }

  void _subscribeCounts() {
    _countsSub?.cancel();
    _countsSub = _repo.watchCountsOn(_day).listen((counts) {
      if (!mounted) return;
      setState(() => _counts = counts);
      _refreshStreaks();
    });
  }

  /// Qua nửa đêm khi app vẫn mở thì đọc lại số lần của ngày mới.
  void _checkDay() {
    final today = startOfDay(widget.clock());
    if (today == _day) return;
    _day = today;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _subscribeCounts();
    });
  }

  /// Chuỗi ngày đổi mỗi khi số lần hôm nay hoặc danh sách thay đổi.
  Future<void> _refreshStreaks() async {
    final habits = _habits;
    if (habits == null || _counts == null) return;
    final id = ++_request;
    final now = widget.clock();
    final result = <String, int>{};
    await Future.wait([
      for (final h in habits)
        _repo.streakOf(h.id, today: now).then((s) => result[h.id] = s),
    ]);
    if (!mounted || id != _request) return;
    setState(() {
      _streaks = result;
      _streaksLoaded = true;
    });
  }

  Future<void> _toggle(Habit habit) {
    final count = _counts?[habit.id] ?? 0;
    return _repo.setCount(habit.id, _day, countAfterTap(habit, count));
  }

  void _openAdd() => Navigator.of(context).pushNamed(AppRoutes.habitEdit);

  void _openArchived() =>
      Navigator.of(context).pushNamed(AppRoutes.habitArchived);

  void _openHabit(Habit habit) =>
      Navigator.of(context)
          .pushNamed(AppRoutes.habitDetail, arguments: habit.id);

  @override
  Widget build(BuildContext context) {
    _checkDay();
    final habits = _habits;
    final counts = _counts;
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: habits == null || counts == null || !_streaksLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _header(context),
                const SizedBox(height: 16),
                if (habits.isEmpty)
                  _EmptyState(onAdd: _openAdd)
                else ...[
                  _TodayCard(
                    progress: todayProgress(habits, counts, _day),
                    theme: theme,
                  ),
                  const SizedBox(height: 14),
                  for (final habit in sortForToday(habits, _day)) ...[
                    HabitTile(
                      habit: habit,
                      count: counts[habit.id] ?? 0,
                      streak: _streaks[habit.id] ?? 0,
                      scheduledToday: isScheduledOn(habit, _day),
                      today: _day,
                      onTap: () => _openHabit(habit),
                      onToggle: () => _toggle(habit),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final style = IconButton.styleFrom(backgroundColor: theme.cardTheme.color);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headerDate(widget.clock()),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Thói quen',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Đã lưu trữ',
          style: style,
          onPressed: _openArchived,
          icon: const Icon(Icons.inventory_2_outlined),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Thêm thói quen',
          style: style,
          onPressed: _openAdd,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.progress, required this.theme});

  final TodayProgress progress;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final fraction = progress.total == 0 ? 0.0 : progress.done / progress.total;

    return Card(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Thói quen hôm nay',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                Text(
                  '${progress.done}/${progress.total}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: scheme.onPrimary.withValues(alpha: 0.25),
              color: scheme.onPrimary,
            ),
            const SizedBox(height: 10),
            Text(
              todayHint(progress),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimary.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              size: 40,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Chưa có thói quen nào',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tạo một thói quen nhỏ và giữ chuỗi ngày mỗi ngày.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm thói quen'),
          ),
        ],
      ),
    );
  }
}
