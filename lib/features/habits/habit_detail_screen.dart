import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/settings_controller.dart';
import '../../data/habit_streak.dart';
import '../../data/models/habit.dart';
import '../../data/repositories/habit_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import 'habit_detail_logic.dart';
import 'habit_edit_screen.dart';
import 'habit_logic.dart';

/// Chi tiết một thói quen: chuỗi ngày, tỷ lệ hoàn thành, lịch tháng và 4 tuần
/// gần nhất. Mở khi chạm vào một thói quen ở tab Thói quen.
class HabitDetailScreen extends StatefulWidget {
  const HabitDetailScreen({
    super.key,
    required this.habitId,
    this.clock = DateTime.now,
  });

  final String habitId;

  /// Nguồn thời gian hiện tại; thay bằng giờ cố định khi test.
  final DateTime Function() clock;

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  late final HabitRepository _repo = context.read<HabitRepository>();

  Habit? _habit;
  bool _habitLoaded = false;
  Map<String, int>? _counts;

  /// Tháng đang xem trên lịch (ngày 1 của tháng).
  late DateTime _month = DateTime(widget.clock().year, widget.clock().month);

  StreamSubscription<Habit?>? _habitSub;
  StreamSubscription<Map<String, int>>? _todaySub;

  // Mỗi lần đọc lại nhật ký tăng số này; kết quả của lần cũ đến trễ bị bỏ.
  int _request = 0;

  DateTime get _today => startOfDay(widget.clock());

  @override
  void initState() {
    super.initState();
    _habitSub = _repo.watchById(widget.habitId).listen((habit) {
      if (!mounted) return;
      setState(() {
        _habit = habit;
        _habitLoaded = true;
      });
      _reloadLogs();
    });
    // Chấm hôm nay ở nơi khác (tab Thói quen) thì đọc lại nhật ký.
    _todaySub = _repo.watchCountsOn(_today).listen((_) => _reloadLogs());
  }

  @override
  void dispose() {
    _habitSub?.cancel();
    _todaySub?.cancel();
    super.dispose();
  }

  /// Đọc nhật ký từ ngày bắt đầu tới hôm nay: đủ cho lịch mọi tháng, các tuần,
  /// chuỗi ngày và tỷ lệ hoàn thành.
  Future<void> _reloadLogs() async {
    final habit = _habit;
    if (habit == null) return;
    final id = ++_request;
    final today = _today;
    final logs = await _repo.logsByRange(
      habit.id,
      DateTimeRange(
        start: startOfDay(habit.startDate),
        end: DateTime(today.year, today.month, today.day + 1),
      ),
    );
    if (!mounted || id != _request) return;
    setState(() => _counts = countsByKey(logs));
  }

  /// Bật tắt "đã làm" của một ngày (chạm vào ô lịch hoặc nút ở cuối màn).
  Future<void> _toggleDay(DateTime day) {
    final habit = _habit!;
    final count = _counts?[dateKey(day)] ?? 0;
    return _repo.setCount(habit.id, day, toggledDayCount(habit, count));
  }

  Future<void> _edit() async {
    final result = await Navigator.of(context)
        .pushNamed(AppRoutes.habitEdit, arguments: widget.habitId);
    // Đã lưu trữ hoặc xóa từ form Sửa thì thói quen không còn ở đây nữa.
    if ((result == HabitEditResult.archived ||
            result == HabitEditResult.deleted) &&
        mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final habit = _habit;
    final counts = _counts;

    if (!_habitLoaded || (habit != null && counts == null)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (habit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết')),
        body: const Center(child: Text('Thói quen này không còn tồn tại')),
      );
    }
    return _content(context, habit, counts!);
  }

  Widget _content(BuildContext context, Habit habit, Map<String, int> counts) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = TaskColors.of(context);
    final today = _today;
    final weekStart = Provider.of<SettingsController>(context).weekStart;
    final ink = habitInkColor(habit.color, theme.brightness);
    final streaks = habitStreaks(habit, counts, today);
    final rate = completionRate(habit, counts, today);
    final weeks = recentWeeks(habit, counts, today, weekStart);

    final scheduledToday = isScheduledOn(habit, today);
    final doneToday =
        scheduledToday && isDone(habit, counts[dateKey(today)] ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết'),
        actions: [
          IconButton(
            tooltip: 'Sửa thói quen',
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(habitIconData(habit.icon), color: ink, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detailSubtitle(habit),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatTile(
                label: 'Chuỗi hiện tại',
                value: '${streaks.current}',
                unit: 'ngày',
                color: colors.medium,
              ),
              const SizedBox(width: 10),
              _StatTile(
                label: 'Dài nhất',
                value: '${streaks.best}',
                unit: 'ngày',
              ),
              const SizedBox(width: 10),
              _StatTile(
                label: 'Hoàn thành',
                value: '${rate.percent}',
                unit: '%',
                color: colors.onGreen,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CalendarCard(
            habit: habit,
            counts: counts,
            month: _month,
            today: today,
            weekStart: weekStart,
            ink: ink,
            onPrevious: canGoToPreviousMonth(habit, _month)
                ? () => setState(() => _month = previousMonth(_month))
                : null,
            onNext: canGoToNextMonth(_month, today)
                ? () => setState(() => _month = nextMonth(_month))
                : null,
            onToggle: _toggleDay,
          ),
          const SizedBox(height: 14),
          _WeeksCard(weeks: weeks),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: !scheduledToday
                ? const FilledButton(
                    onPressed: null,
                    child: Text('Hôm nay không có lịch'),
                  )
                : doneToday
                ? FilledButton.tonal(
                    onPressed: () => _toggleDay(today),
                    child: const Text('Hôm nay đã xong · bấm để bỏ'),
                  )
                : FilledButton(
                    onPressed: () => _toggleDay(today),
                    child: const Text('Đánh dấu hôm nay đã làm'),
                  ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              // Thu nhỏ vừa ô khi chữ dài (phông lớn, số nhiều chữ số).
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      unit,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.habit,
    required this.counts,
    required this.month,
    required this.today,
    required this.weekStart,
    required this.ink,
    required this.onPrevious,
    required this.onNext,
    required this.onToggle,
  });

  final Habit habit;
  final Map<String, int> counts;
  final DateTime month;
  final DateTime today;
  final int weekStart;
  final Color ink;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<DateTime> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final grid = monthGrid(habit, month, today, counts, weekStart);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Tháng trước',
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    monthTitle(month),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tháng sau',
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: ink, label: 'Đã làm'),
                const SizedBox(width: 16),
                _LegendDot(
                  color: scheme.surfaceContainerHighest,
                  label: 'Bỏ lỡ',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final header in weekdayHeaders(weekStart))
                  Expanded(
                    child: Center(
                      child: Text(
                        header,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (final row in grid)
              Row(
                children: [
                  for (final cell in row)
                    Expanded(
                      child: cell == null
                          ? const SizedBox(height: 40)
                          : _DayCellView(
                              cell: cell,
                              isToday: cell.date == today,
                              ink: ink,
                              onTap: cell.tappable
                                  ? () => onToggle(cell.date)
                                  : null,
                            ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DayCellView extends StatelessWidget {
  const _DayCellView({
    required this.cell,
    required this.isToday,
    required this.ink,
    required this.onTap,
  });

  final DayCell cell;
  final bool isToday;
  final Color ink;
  final VoidCallback? onTap;

  static const _labels = {
    DayStatus.done: 'Đã làm',
    DayStatus.missed: 'Bỏ lỡ',
    DayStatus.pending: 'Hôm nay chưa làm',
    DayStatus.upcoming: 'Chưa tới',
    DayStatus.rest: 'Không có lịch',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = cell.status == DayStatus.done;

    final Color? background = switch (cell.status) {
      DayStatus.done => ink,
      DayStatus.missed => scheme.surfaceContainerHighest,
      _ => null,
    };
    final Color foreground = switch (cell.status) {
      DayStatus.done =>
        ink.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
      DayStatus.missed => scheme.onSurfaceVariant,
      DayStatus.pending => scheme.onSurface,
      DayStatus.upcoming => scheme.onSurfaceVariant,
      DayStatus.rest => scheme.onSurfaceVariant.withValues(alpha: 0.4),
    };

    return Semantics(
      button: onTap != null,
      label: 'Ngày ${cell.date.day}, ${_labels[cell.status]}',
      excludeSemantics: true,
      child: InkResponse(
        key: ValueKey('day-${dateKey(cell.date)}'),
        onTap: onTap,
        radius: 22,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: isToday
                  ? Border.all(color: scheme.onSurface, width: 2)
                  : null,
            ),
            child: Text(
              '${cell.date.day}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: foreground,
                fontWeight: done || isToday ? FontWeight.w700 : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeksCard extends StatelessWidget {
  const _WeeksCard({required this.weeks});

  final List<WeekBar> weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '4 tuần gần nhất',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 136,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final week in weeks)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${week.percent}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 32,
                            height: (week.percent * 0.7).clamp(8.0, 70.0),
                            decoration: BoxDecoration(
                              color: week.isCurrent
                                  ? scheme.primary
                                  : scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            week.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
