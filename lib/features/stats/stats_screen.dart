import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/focus_session.dart';
import '../../data/models/tag.dart';
import '../../data/models/task.dart';
import '../../data/repositories/focus_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../theme/app_theme.dart';
import '../focus_history/focus_history_logic.dart';
import 'stats_logic.dart';

/// Tab Thống kê: 4 ô tóm tắt (việc hoàn thành, đúng hạn, ngày liên tiếp, thời
/// gian tập trung), biểu đồ việc hoàn thành và phần chia theo nhãn của kỳ đang
/// chọn (7 ngày / Tháng / Năm).
///
/// Đọc việc bằng `watchAll()` nên số liệu tự cập nhật khi việc được hoàn
/// thành ở tab khác (tab này luôn được giữ trong khung 5 tab).
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, this.clock = DateTime.now});

  /// Nguồn thời gian hiện tại; thay bằng giờ cố định khi test.
  final DateTime Function() clock;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final Stream<List<Task>> _tasks = context
      .read<TaskRepository>()
      .watchAll();
  late final Stream<List<Tag>> _tags = context.read<TagRepository>().watchAll();
  late final FocusRepository _focus = context.read<FocusRepository>();

  StatsPeriod _period = StatsPeriod.week;

  // Phiên tập trung của kỳ đang xem. Chỉ tạo stream mới khi đổi kỳ, không
  // tạo trong build.
  late Stream<List<FocusSession>> _sessions = _focus.watchByRange(
    periodRange(_period, widget.clock()),
  );

  void _setPeriod(StatsPeriod period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      _sessions = _focus.watchByRange(periodRange(period, widget.clock()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Tag>>(
          stream: _tags,
          builder: (context, tagsSnapshot) => StreamBuilder<List<Task>>(
            stream: _tasks,
            builder: (context, tasksSnapshot) =>
                StreamBuilder<List<FocusSession>>(
                  stream: _sessions,
                  builder: (context, sessionsSnapshot) {
                    if (!tagsSnapshot.hasData || !tasksSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _content(
                      context,
                      tasks: tasksSnapshot.data!,
                      tags: tagsSnapshot.data!,
                      sessions: sessionsSnapshot.data ?? const [],
                    );
                  },
                ),
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context, {
    required List<Task> tasks,
    required List<Tag> tags,
    required List<FocusSession> sessions,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = TaskColors.of(context);
    final now = widget.clock();
    final stats = summarizeStats(_period, tasks, {
      for (final tag in tags) tag.id: tag,
    }, now);
    // Vừa đổi kỳ thì stream mới chưa phát: lọc theo kỳ để không cộng nhầm
    // phiên của kỳ trước.
    final focus = summarize(
      sessionsStartingIn(sessions, periodRange(_period, now)),
    );
    final muted = scheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
          child: Text(
            'Thống kê',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<StatsPeriod>(
            showSelectedIcon: false,
            segments: [
              for (final period in StatsPeriod.values)
                ButtonSegment(value: period, label: Text(period.label)),
            ],
            selected: {_period},
            onSelectionChanged: (set) => _setPeriod(set.first),
          ),
        ),
        const SizedBox(height: 12),
        _TileRow(
          left: _StatTile(
            key: const ValueKey('tile-done'),
            value: '${stats.done}',
            label: 'việc hoàn thành',
            note: comparisonLabel(_period, stats.done, stats.previousDone),
            noteColor: stats.done > stats.previousDone
                ? colors.tag(TagColor.green).$2
                : muted,
          ),
          right: _StatTile(
            key: const ValueKey('tile-on-time'),
            value: stats.onTime.label,
            label: 'đúng hạn',
            note: overdueLabel(stats.overdue),
            noteColor: stats.overdue > 0 ? colors.high : muted,
          ),
        ),
        const SizedBox(height: 10),
        _TileRow(
          left: _StatTile(
            key: const ValueKey('tile-streak'),
            value: '${stats.streak.current}',
            icon: Icon(
              Icons.local_fire_department_outlined,
              size: 22,
              color: colors.medium,
            ),
            label: 'ngày liên tiếp',
            note: 'Kỷ lục: ${stats.streak.best} ngày',
            noteColor: muted,
          ),
          right: _StatTile(
            key: const ValueKey('tile-focus'),
            value: formatFocusTotal(focus.focusSeconds),
            label: 'thời gian tập trung',
            note: '${focus.sessions} phiên tập trung',
            noteColor: muted,
          ),
        ),
        const SizedBox(height: 12),
        _ChartCard(key: const ValueKey('chart'), chart: stats.chart),
        const SizedBox(height: 12),
        _TagCard(shares: stats.tags),
      ],
    );
  }
}

/// Hai ô cạnh nhau, cao bằng nhau.
class _TileRow extends StatelessWidget {
  const _TileRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 10),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.note,
    required this.noteColor,
    this.icon,
  });

  final String value;
  final String label;
  final String note;
  final Color noteColor;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = this.icon;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (icon != null) ...[const SizedBox(width: 6), icon],
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: noteColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({super.key, required this.chart});

  final DoneChart chart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    chart.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  chart.averageLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Trình đọc màn hình đọc cả biểu đồ thành một mục (như mockup).
            Semantics(
              container: true,
              label: chart.semanticsLabel,
              excludeSemantics: true,
              child: _Bars(chart: chart),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.chart});

  final DoneChart chart;

  /// Chiều cao vùng cột và chiều cao của cột cao nhất (như mockup).
  static const _area = 150.0;
  static const _tallest = 118.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    // Kỳ Tháng có tới 31 cột: cột mảnh, khe hẹp, góc bo nhỏ.
    final dense = chart.bars.length > 12;
    final top = Radius.circular(dense ? 3 : 10);
    final bottom = Radius.circular(dense ? 1 : 4);
    final maxValue = math.max(chart.maxValue, 1);
    final soft = scheme.primary.withValues(alpha: 0.35);
    // Hàng nhãn cao theo cỡ chữ của máy.
    final labelHeight = MediaQuery.textScalerOf(context).scale(18);

    return Column(
      children: [
        SizedBox(
          height: _area,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (index, bar) in chart.bars.indexed)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: dense ? 1 : 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (chart.showValues && !bar.isFuture)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${bar.value}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: bar.isCurrent
                                      ? scheme.onSurface
                                      : muted,
                                ),
                              ),
                            ),
                          ),
                        if (!bar.isFuture)
                          Container(
                            key: ValueKey('bar-$index'),
                            height: bar.value == 0
                                ? 3
                                : math.max(6, bar.value / maxValue * _tallest),
                            constraints: const BoxConstraints(maxWidth: 30),
                            decoration: BoxDecoration(
                              color: bar.value == 0
                                  ? scheme.surfaceContainerHighest
                                  : bar.isCurrent
                                  ? scheme.primary
                                  : soft,
                              borderRadius: BorderRadius.vertical(
                                top: top,
                                bottom: bottom,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final (index, bar) in chart.bars.indexed)
              Expanded(
                child: SizedBox(
                  height: labelHeight,
                  // Nhãn có thể rộng hơn cột (kỳ Tháng): cho tràn đều hai bên.
                  // minWidth phải là 0: cột rộng hơn 48 (máy 411 dp trở lên)
                  // thì ràng buộc bị ngược và nhãn không được vẽ.
                  child: OverflowBox(
                    minWidth: 0,
                    maxWidth: 48,
                    minHeight: 0,
                    maxHeight: labelHeight,
                    child: Text(
                      index % chart.labelEvery == 0 ? bar.label : '',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: bar.isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: bar.isCurrent ? scheme.onSurface : muted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TagCard extends StatelessWidget {
  const _TagCard({required this.shares});

  final List<TagShare> shares;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = TaskColors.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Theo nhãn',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (shares.isEmpty)
              Text(
                'Chưa có việc hoàn thành trong kỳ này',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              for (final (index, share) in shares.indexed) ...[
                if (index > 0) const SizedBox(height: 12),
                MergeSemantics(
                  child: Column(
                    key: ValueKey('tag-share-${share.tag?.id ?? 'none'}'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              share.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            share.detail,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 8,
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: colors.tag(TagColor.grey).$1,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: share.fraction,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: share.tag == null
                                  ? scheme.outline
                                  : colors.tag(share.tag!.color).$2,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
