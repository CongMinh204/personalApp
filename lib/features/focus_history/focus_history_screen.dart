import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/settings_controller.dart';
import '../../data/models/focus_session.dart';
import '../../data/models/task.dart';
import '../../data/repositories/focus_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/vi_date.dart';
import 'focus_history_logic.dart';

/// Lịch sử các phiên tập trung, mở từ nút lịch sử ở header màn Hẹn giờ.
///
/// Ba tab Ngày / Tuần / Tháng đổi cách gom nhóm danh sách và các ô tóm tắt.
/// Phiên nghỉ không hiện.
class FocusHistoryScreen extends StatefulWidget {
  const FocusHistoryScreen({super.key, this.clock = DateTime.now});

  /// Nguồn thời gian hiện tại; thay bằng giờ cố định khi test.
  final DateTime Function() clock;

  @override
  State<FocusHistoryScreen> createState() => _FocusHistoryScreenState();
}

class _FocusHistoryScreenState extends State<FocusHistoryScreen> {
  late final FocusRepository _focus = context.read<FocusRepository>();
  late final TaskRepository _tasks = context.read<TaskRepository>();

  HistoryRange _range = HistoryRange.day;
  int? _weekStart;

  // Phiên trong khoảng đang hiện, và trong kỳ lớn hơn (cho ô thứ ba). `null`
  // là chưa đọc xong.
  List<FocusSession>? _sessions;
  List<FocusSession>? _bigger;
  Map<String, String> _titles = const {};

  StreamSubscription<List<FocusSession>>? _sessionsSub;
  StreamSubscription<List<FocusSession>>? _biggerSub;
  StreamSubscription<List<Task>>? _tasksSub;

  // Phiên vừa vuốt xóa nhưng luồng chưa phát lại danh sách mới: ẩn ngay để
  // Dismissible không còn nằm trong cây widget.
  final _hidden = <String>{};

  @override
  void initState() {
    super.initState();
    _tasksSub = _tasks.watchAll().listen((tasks) {
      if (!mounted) return;
      setState(() => _titles = {for (final t in tasks) t.id: t.title});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ngày đầu tuần đổi (Cài đặt) thì gom lại.
    final weekStart = Provider.of<SettingsController>(context).weekStart;
    if (weekStart != _weekStart) {
      _weekStart = weekStart;
      _subscribe();
    }
  }

  @override
  void dispose() {
    _sessionsSub?.cancel();
    _biggerSub?.cancel();
    _tasksSub?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _sessionsSub?.cancel();
    _biggerSub?.cancel();
    final now = widget.clock();
    final weekStart = _weekStart!;
    setState(() {
      _sessions = null;
      _bigger = null;
    });
    _sessionsSub = _focus
        .watchByRange(visibleWindow(_range, now, weekStart))
        .listen((sessions) {
          if (mounted) setState(() => _sessions = sessions);
        });
    _biggerSub = _focus
        .watchByRange(biggerPeriod(_range, now, weekStart))
        .listen((sessions) {
          if (mounted) setState(() => _bigger = sessions);
        });
  }

  void _setRange(HistoryRange range) {
    if (range == _range) return;
    _range = range;
    _subscribe();
  }

  Future<void> _delete(FocusSession session) async {
    setState(() => _hidden.add(session.id));
    await _focus.delete(session.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Đã xóa phiên tập trung'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () => _undo(session),
          ),
        ),
      );
  }

  Future<void> _undo(FocusSession session) async {
    try {
      await _focus.add(session);
    } on ArgumentError {
      // Việc của phiên đã bị xóa trong lúc đó: khôi phục ở dạng không gắn việc.
      await _focus.add(session.copyWith(taskId: () => null));
    }
    if (mounted) setState(() => _hidden.remove(session.id));
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    final bigger = _bigger;

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử tập trung')),
      body: sessions == null || bigger == null
          ? const Center(child: CircularProgressIndicator())
          : _content(context, sessions, bigger),
    );
  }

  Widget _content(
    BuildContext context,
    List<FocusSession> stored,
    List<FocusSession> storedBigger,
  ) {
    // Bỏ khỏi _hidden những phiên đã thật sự biến mất khỏi database.
    _hidden.removeWhere((id) => !stored.any((s) => s.id == id));
    final now = widget.clock();
    final weekStart = _weekStart!;
    final sessions = [
      for (final s in stored)
        if (!_hidden.contains(s.id)) s,
    ];
    final bigger = [
      for (final s in storedBigger)
        if (!_hidden.contains(s.id)) s,
    ];

    final current = summarize(
      sessionsStartingIn(sessions, currentPeriod(_range, now, weekStart)),
    );
    final period = summarize(bigger);
    final groups = groupSessions(sessions, _range, now, weekStart);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<HistoryRange>(
            showSelectedIcon: false,
            segments: [
              for (final range in HistoryRange.values)
                ButtonSegment(value: range, label: Text(range.label)),
            ],
            selected: {_range},
            onSelectionChanged: (set) => _setRange(set.first),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _SummaryTile(label: 'Phiên', value: '${current.sessions}'),
            const SizedBox(width: 10),
            _SummaryTile(
              label: 'Hoàn thành',
              value: '${current.completed}/${current.sessions}',
            ),
            const SizedBox(width: 10),
            _SummaryTile(
              label: _range.biggerPeriodLabel,
              value: formatFocusTotal(period.focusSeconds),
            ),
          ],
        ),
        if (groups.isEmpty)
          const _EmptyState()
        else
          for (final group in groups) ...[
            _GroupHeader(group: group),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < group.sessions.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    Dismissible(
                      key: ValueKey(group.sessions[i].id),
                      direction: DismissDirection.endToStart,
                      background: const _DeleteBackground(),
                      onDismissed: (_) => _delete(group.sessions[i]),
                      child: _SessionRow(
                        session: group.sessions[i],
                        taskTitle: _titles[group.sessions[i].taskId],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final HistoryGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              group.title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            formatFocusTotal(group.focusSeconds),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.taskTitle});

  final FocusSession session;

  /// `null` = không gắn việc (hoặc việc đã bị xóa).
  final String? taskTitle;

  String get _kind => switch (session.type) {
    FocusType.pomodoro => 'Pomodoro',
    FocusType.custom => 'Tùy chỉnh',
    FocusType.shortBreak => 'Nghỉ ngắn',
    FocusType.longBreak => 'Nghỉ dài',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = TaskColors.of(context);
    final done = session.completed;

    return ColoredBox(
      color: theme.cardTheme.color ?? scheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    taskTitle ?? 'Không gắn việc',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: taskTitle == null ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${hourMinute(session.startedAt)} – '
                    '${hourMinute(session.endedAt)} · $_kind',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatSessionDuration(session.durationSec),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: done ? colors.green : scheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    done ? 'Hoàn thành' : 'Bỏ dở',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: done ? colors.onGreen : scheme.onErrorContainer,
                    ),
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

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      color: scheme.errorContainer,
      child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.timer_outlined,
              size: 36,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có phiên tập trung nào',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chạy một phiên ở tab Hẹn giờ để thấy lịch sử ở đây.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
