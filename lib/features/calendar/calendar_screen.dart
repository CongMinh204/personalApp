import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/settings_controller.dart';
import '../../data/models/tag.dart';
import '../../data/models/task.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import '../../utils/vi_date.dart';
import '../tasks/task_actions.dart';
import '../timer/timer_controller.dart';
import '../today/widgets/task_tile.dart';
import 'calendar_logic.dart';

/// Tab Lịch: lưới tháng hoặc tuần (chấm dưới ngày có việc), bên dưới là việc
/// của ngày đang chọn: việc cả ngày, dải giờ của việc có giờ và danh sách việc
/// (đánh dấu xong, mở chi tiết, hẹn giờ tập trung).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.clock = DateTime.now});

  /// Nguồn thời gian hiện tại; thay bằng giờ cố định khi test.
  final DateTime Function() clock;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // Messenger riêng để SnackBar hiện trong Scaffold của tab này.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  late final TaskRepository _repo = context.read<TaskRepository>();
  late final TaskActions _actions = TaskActions(_repo, clock: widget.clock);
  late final Stream<List<Tag>> _tags = context.read<TagRepository>().watchAll();

  late DateTime _selected = startOfDay(widget.clock());
  CalendarMode _mode = CalendarMode.month;

  // Việc của tháng đang xem (thêm 7 ngày mỗi phía). Chỉ tạo stream mới khi
  // ngày được chọn sang tháng khác, không tạo trong build.
  late DateTimeRange _range = calendarQueryRange(_selected);
  late Stream<List<Task>> _tasks = _repo.watchByRange(_range);

  void _select(DateTime day) {
    setState(() {
      _selected = startOfDay(day);
      final range = calendarQueryRange(_selected);
      if (range != _range) {
        _range = range;
        _tasks = _repo.watchByRange(range);
      }
    });
  }

  void _shift(int step) =>
      _select(shiftSelection(_selected, _mode, step, widget.clock()));

  void _showMessage(String text) {
    _messengerKey.currentState!
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleDone(Task task) async {
    final next = await _actions.toggleDone(task);
    if (next != null && mounted) {
      _showMessage(
        'Đã tạo việc lặp kế tiếp (${taskTimeLabel(next, widget.clock())})',
      );
    }
  }

  void _openDetail(Task task) =>
      Navigator.of(context).pushNamed(AppRoutes.taskDetail, arguments: task.id);

  /// Form Thêm việc với ngày đang chọn điền sẵn.
  void _openAdd() =>
      Navigator.of(context).pushNamed(AppRoutes.taskEdit, arguments: _selected);

  @override
  Widget build(BuildContext context) {
    final weekStart = context.watch<SettingsController>().weekStart;
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: StreamBuilder<List<Tag>>(
            stream: _tags,
            builder: (context, tagsSnapshot) => StreamBuilder<List<Task>>(
              stream: _tasks,
              builder: (context, tasksSnapshot) => _content(
                context,
                weekStart: weekStart,
                tasks: tasksSnapshot,
                tags: tagsSnapshot.data,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context, {
    required int weekStart,
    required AsyncSnapshot<List<Task>> tasks,
    required List<Tag>? tags,
  }) {
    final theme = Theme.of(context);
    final now = widget.clock();
    final today = startOfDay(now);
    // Chưa đọc xong lần đầu, hoặc vừa sang tháng khác và đang đọc lại.
    final loading =
        tags == null ||
        !tasks.hasData ||
        tasks.connectionState == ConnectionState.waiting;
    final byDay = tasksByDay(tasks.data ?? const []);
    final days = _mode == CalendarMode.month
        ? monthGridDays(_selected, weekStart)
        : weekDays(_selected, weekStart);
    final panelColor = theme.cardTheme.color ?? theme.colorScheme.surface;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Header(
            title: monthTitle(_selected),
            mode: _mode,
            onPrevious: () => _shift(-1),
            onNext: () => _shift(1),
            onToday: () => _select(now),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<CalendarMode>(
                showSelectedIcon: false,
                segments: [
                  for (final mode in CalendarMode.values)
                    ButtonSegment(value: mode, label: Text(mode.label)),
                ],
                selected: {_mode},
                onSelectionChanged: (set) => setState(() => _mode = set.first),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: _DayGrid(
              days: days,
              weekStart: weekStart,
              selected: _selected,
              today: today,
              byDay: byDay,
              onSelect: _select,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _DayPanel(
            day: _selected,
            now: now,
            loading: loading,
            tasks: sortDayTasks(byDay[dateKey(_selected)] ?? const []),
            tagById: {for (final tag in tags ?? const <Tag>[]) tag.id: tag},
            color: panelColor,
            onOpen: _openDetail,
            onToggle: _toggleDone,
            onTimer: (task) => context.read<TimerController>().prepare(task.id),
            onAdd: _openAdd,
          ),
        ),
        // Nền của phần dưới kéo dài tới hết màn khi danh sách ngắn.
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(color: panelColor),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.mode,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final String title;
  final CalendarMode mode;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final month = mode == CalendarMode.month;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: month ? 'Tháng trước' : 'Tuần trước',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: month ? 'Tháng sau' : 'Tuần sau',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            onPressed: onToday,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: theme.cardTheme.color,
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: const Text('Hôm nay'),
          ),
        ],
      ),
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.days,
    required this.weekStart,
    required this.selected,
    required this.today,
    required this.byDay,
    required this.onSelect,
  });

  /// Các ngày của lưới, đủ hàng 7 ngày.
  final List<DateTime> days;
  final int weekStart;
  final DateTime selected;
  final DateTime today;
  final Map<String, List<Task>> byDay;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              for (final header in weekdayHeaders(weekStart))
                Expanded(
                  child: Center(
                    child: Text(
                      header,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (var row = 0; row < days.length; row += 7)
          Row(
            children: [
              for (final day in days.sublist(row, row + 7))
                Expanded(
                  child: _DayCell(
                    date: day,
                    selected: day == selected,
                    isToday: day == today,
                    inMonth:
                        day.year == selected.year &&
                        day.month == selected.month,
                    count: byDay[dateKey(day)]?.length ?? 0,
                    onTap: () => onSelect(day),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.inMonth,
    required this.count,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;

  /// Ngày thuộc tháng của ngày đang chọn; ngày của tháng khác hiện mờ.
  final bool inMonth;

  /// Số việc của ngày; có việc thì có chấm dưới số ngày.
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final faded = scheme.onSurfaceVariant.withValues(alpha: 0.55);
    final foreground = selected
        ? scheme.onPrimary
        : inMonth
        ? scheme.onSurface
        : faded;
    final dot = selected
        ? scheme.onPrimary
        : inMonth
        ? scheme.primary
        : scheme.primary.withValues(alpha: 0.4);
    final label = [
      'Ngày ${date.day} tháng ${date.month}',
      if (isToday) 'hôm nay',
      if (count > 0) '$count việc',
    ].join(', ');

    return SizedBox(
      height: 46,
      child: Center(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          // Bỏ ngữ nghĩa của các widget con nên phải gắn hành động bấm ở đây
          // thì trình đọc màn hình mới bấm được.
          onTap: onTap,
          excludeSemantics: true,
          child: InkResponse(
            key: ValueKey('cal-${dateKey(date)}'),
            onTap: onTap,
            radius: 22,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? scheme.primary : null,
                border: Border.all(
                  width: 2,
                  color: isToday && !selected
                      ? scheme.primary
                      : Colors.transparent,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected || isToday
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Container(
                      key: count > 0 ? ValueKey('dot-${dateKey(date)}') : null,
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: count > 0 ? dot : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Phần dưới lưới: việc của ngày đang chọn.
class _DayPanel extends StatelessWidget {
  const _DayPanel({
    required this.day,
    required this.now,
    required this.loading,
    required this.tasks,
    required this.tagById,
    required this.color,
    required this.onOpen,
    required this.onToggle,
    required this.onTimer,
    required this.onAdd,
  });

  final DateTime day;
  final DateTime now;
  final bool loading;

  /// Việc của ngày, đã sắp theo `sortDayTasks`.
  final List<Task> tasks;
  final Map<String, Tag> tagById;
  final Color color;
  final ValueChanged<Task> onOpen;
  final ValueChanged<Task> onToggle;
  final ValueChanged<Task> onTimer;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final allDay = [
      for (final task in tasks)
        if (!task.hasTime) task,
    ];
    final timeline = buildTimeline(tasks, day, now: now);
    final isToday = dayDiff(day, now) == 0;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dayTitle(day, now),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dayCountLabel(tasks.length),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (tasks.isEmpty)
            _EmptyDay(onAdd: onAdd)
          else ...[
            if (allDay.isNotEmpty) ...[
              _AllDayRow(tasks: allDay, onOpen: onOpen),
              const SizedBox(height: 12),
            ],
            if (timeline != null) ...[
              _TimelineView(
                timeline: timeline,
                tagById: tagById,
                nowHour: isToday ? hourOfDay(now) : null,
                onOpen: onOpen,
              ),
              const SizedBox(height: 12),
            ],
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'Việc trong ngày',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final (index, task) in tasks.indexed) ...[
              if (index > 0) const SizedBox(height: 8),
              TaskTile(
                task: task,
                tag: tagById[task.tagId],
                now: now,
                overdue: isOverdue(task, now),
                timeLabel: calendarTimeLabel(task),
                color: theme.scaffoldBackgroundColor,
                onToggle: () => onToggle(task),
                onTap: () => onOpen(task),
                onTimer: () => onTimer(task),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Thêm việc vào ngày này'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              size: 32,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ngày này còn trống',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm việc vào ngày này'),
          ),
        ],
      ),
    );
  }
}

/// "Không có giờ:" và các việc cả ngày.
class _AllDayRow extends StatelessWidget {
  const _AllDayRow({required this.tasks, required this.onOpen});

  final List<Task> tasks;
  final ValueChanged<Task> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chipColor = TaskColors.of(context).tag(TagColor.grey).$1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Không có giờ:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final task in tasks)
                Material(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: ValueKey('allday-${task.id}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onOpen(task),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: task.done
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                          decoration: task.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dải giờ: mốc giờ, khối của từng việc có giờ, vạch giờ hiện tại (hôm nay).
class _TimelineView extends StatelessWidget {
  const _TimelineView({
    required this.timeline,
    required this.tagById,
    required this.nowHour,
    required this.onOpen,
  });

  final Timeline timeline;
  final Map<String, Tag> tagById;

  /// Giờ hiện tại (14.5 = 14:30) khi ngày đang xem là hôm nay.
  final double? nowHour;
  final ValueChanged<Task> onOpen;

  static const hourHeight = 48.0;
  static const _blocksLeft = 56.0;

  String _hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final first = timeline.firstHour;
    final nowHour = this.nowHour;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: timeline.hours * hourHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth - _blocksLeft - 4;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i <= timeline.hours; i++)
                  Positioned(
                    top: i * hourHeight - 7,
                    left: 0,
                    right: 0,
                    height: 14,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 42,
                          child: Text(
                            _hourLabel(first + i),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: scheme.outlineVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final block in timeline.blocks)
                  Positioned(
                    top: (block.start - first) * hourHeight,
                    height: math.max(
                      18,
                      (block.end - block.start) * hourHeight - 4,
                    ),
                    left: _blocksLeft + block.column * width / block.columns,
                    width: width / block.columns - (block.columns > 1 ? 4 : 0),
                    child: _TimelineBlockView(
                      block: block,
                      tag: tagById[block.task.tagId],
                      height: math.max(
                        18,
                        (block.end - block.start) * hourHeight - 4,
                      ),
                      onTap: () => onOpen(block.task),
                    ),
                  ),
                if (nowHour != null)
                  Positioned(
                    top: (nowHour - first) * hourHeight - 5,
                    left: 44,
                    right: 0,
                    child: IgnorePointer(
                      child: Row(
                        key: const ValueKey('now-line'),
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(left: 2),
                            decoration: BoxDecoration(
                              color: TaskColors.of(context).high,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 2,
                              color: TaskColors.of(context).high,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TimelineBlockView extends StatelessWidget {
  const _TimelineBlockView({
    required this.block,
    required this.tag,
    required this.height,
    required this.onTap,
  });

  final TimelineBlock block;
  final Tag? tag;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final task = block.task;
    // Màu theo nhãn của việc (như mockup); không nhãn thì màu xám.
    final (background, foreground) = TaskColors.of(context)
        .tag(tag?.color ?? TagColor.grey);
    final time = calendarTimeLabel(task);
    // Khối thấp (việc 30 phút) chỉ đủ một dòng: tên và giờ nằm cùng dòng, chữ
    // nhỏ hơn và không có lề trên dưới để không bị cắt chữ.
    final lines = ((height - 8) / 17).floor().clamp(1, 8);
    final oneLine = lines == 1;

    return Semantics(
      button: true,
      label: '${task.title}, $time${task.done ? ', đã xong' : ''}',
      onTap: onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: task.done ? 0.6 : 1,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('block-${task.id}'),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: oneLine ? 0 : 6,
              ),
              child: Align(
                alignment: oneLine ? Alignment.centerLeft : Alignment.topLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: task.title,
                        style: TextStyle(
                          fontSize: oneLine ? 12.5 : 13.5,
                          fontWeight: FontWeight.w700,
                          decoration: task.done
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: foreground,
                        ),
                      ),
                      TextSpan(
                        text: oneLine ? '  $time' : '\n$time',
                        style: TextStyle(
                          fontSize: oneLine ? 11.5 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  maxLines: lines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: foreground),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
