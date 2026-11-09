import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/models/tag.dart';
import '../../data/models/task.dart';
import '../../utils/vi_date.dart';
import 'task_groups.dart';
import 'widgets/empty_state.dart';
import 'widgets/progress_card.dart';
import 'widgets/quick_add_sheet.dart';
import 'widgets/task_tile.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required this.initialTasks,
    this.tags = const [],
    this.clock = DateTime.now,
  });

  final List<Task> initialTasks;

  /// Nhãn để lọc, hiện badge và chọn khi thêm nhanh.
  final List<Tag> tags;

  /// Nguồn thời gian hiện tại; thay bằng giờ cố định khi test.
  final DateTime Function() clock;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  // Messenger riêng để SnackBar hiện trong Scaffold này và đẩy FAB lên.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final List<Task> _tasks = List.of(widget.initialTasks);
  String? _filterTagId;

  void _toggleDone(Task task) {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index < 0) return;
    setState(() => _tasks[index] = task.copyWith(done: !task.done));
  }

  void _delete(Task task) {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index < 0) return;
    setState(() => _tasks.removeAt(index));
    _messengerKey.currentState!
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã xóa "${task.title}"'),
          persist: false,
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () => setState(
              () => _tasks.insert(index.clamp(0, _tasks.length), task),
            ),
          ),
        ),
      );
  }

  Future<void> _openQuickAdd() async {
    final task = await showQuickAddSheet(
      context,
      now: widget.clock(),
      tags: widget.tags,
    );
    if (task == null || !mounted) return;
    setState(() => _tasks.add(task));
  }

  void _showSearchSoon() {
    _messengerKey.currentState!
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Tìm kiếm sẽ có trong bản sau')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.clock();
    final tagById = {for (final tag in widget.tags) tag.id: tag};
    final all = groupTasks(_tasks, now);
    final filter = tagById[_filterTagId];
    final groups = filter == null
        ? all
        : groupTasks(_tasks.where((t) => t.tagId == filter.id).toList(), now);
    final scheme = Theme.of(context).colorScheme;

    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        floatingActionButton: all.isTodayEmpty
            ? null
            : FloatingActionButton(
                tooltip: 'Thêm việc',
                onPressed: _openQuickAdd,
                child: const Icon(Icons.add_rounded, size: 28),
              ),
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  now: now,
                  onSearch: _showSearchSoon,
                  onOpenSettings: () =>
                      Navigator.of(context).pushNamed(AppRoutes.settings),
                ),
              ),
              SliverToBoxAdapter(
                child: _TagFilter(
                  tags: widget.tags,
                  selected: filter?.id,
                  onSelected: (id) => setState(() => _filterTagId = id),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: all.isTodayEmpty
                      ? EmptyState(onAdd: _openQuickAdd)
                      : all.isAllDone
                      ? AllDoneCard(total: all.today.length)
                      : ProgressCard(
                          done: all.todayDone,
                          total: all.today.length,
                          next: nextTask(all.today, now),
                        ),
                ),
              ),
              if (groups.overdue.isNotEmpty)
                ..._section(
                  title: 'Quá hạn · ${groups.overdue.length}',
                  color: scheme.error,
                  tasks: groups.overdue,
                  tagById: tagById,
                  now: now,
                  overdue: true,
                ),
              if (groups.today.isNotEmpty)
                ..._section(
                  title: 'Hôm nay · ${groups.today.length}',
                  tasks: groups.today,
                  tagById: tagById,
                  now: now,
                ),
              if (groups.upcoming.isNotEmpty)
                ..._section(
                  title: 'Sắp tới',
                  tasks: groups.upcoming,
                  tagById: tagById,
                  now: now,
                ),
              if (filter != null &&
                  groups.overdue.isEmpty &&
                  groups.today.isEmpty &&
                  groups.upcoming.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Chưa có việc nào với nhãn "${filter.name}"',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _section({
    required String title,
    required List<Task> tasks,
    required Map<String, Tag> tagById,
    required DateTime now,
    Color? color,
    bool overdue = false,
  }) {
    return [
      SliverToBoxAdapter(
        child: _SectionHeader(title: title, color: color),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.separated(
          itemCount: tasks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Dismissible(
              key: ValueKey(task.id),
              direction: DismissDirection.endToStart,
              background: const _DeleteBackground(),
              onDismissed: (_) => _delete(task),
              child: TaskTile(
                task: task,
                tag: tagById[task.tagId],
                now: now,
                overdue: overdue,
                onToggle: () => _toggleDone(task),
              ),
            );
          },
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.now,
    required this.onSearch,
    required this.onOpenSettings,
  });

  final DateTime now;
  final VoidCallback onSearch;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final buttonStyle = IconButton.styleFrom(
      backgroundColor: theme.cardTheme.color,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headerDate(now),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hôm nay',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tìm kiếm',
            style: buttonStyle,
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Cài đặt',
            style: buttonStyle,
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }
}

class _TagFilter extends StatelessWidget {
  const _TagFilter({
    required this.tags,
    required this.selected,
    required this.onSelected,
  });

  final List<Tag> tags;

  /// Id nhãn đang lọc; `null` = Tất cả.
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <Tag?>[null, ...tags];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tag = options[index];
          return ChoiceChip(
            label: Text(tag?.name ?? 'Tất cả'),
            selected: selected == tag?.id,
            onSelected: (_) => onSelected(tag?.id),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.color});

  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 20, 10),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: color ?? theme.colorScheme.onSurfaceVariant,
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
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
    );
  }
}
