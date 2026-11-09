import 'package:flutter/material.dart';

import '../logic/task_groups.dart';
import '../models/task.dart';
import '../utils/vi_date.dart';
import '../widgets/empty_state.dart';
import '../widgets/progress_card.dart';
import '../widgets/quick_add_sheet.dart';
import '../widgets/task_tile.dart';

// Import các màn hình và widget mới cho 4 tính năng
import 'task_edit_screen.dart';
import 'task_detail_screen.dart';
import 'archive_screen.dart';
import 'habit_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required this.initialTasks,
    this.clock = DateTime.now,
    this.onToggleTheme,
  });

  final List<Task> initialTasks;

  /// Nguồn thời gian hiện tại; thay bằng giờ cố định khi test.
  final DateTime Function() clock;
  final VoidCallback? onToggleTheme;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  // Messenger riêng để SnackBar hiện trong Scaffold này và đẩy FAB lên.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final List<Task> _tasks = List.of(widget.initialTasks);
  TaskTag? _filter;

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

  // Cập nhật công việc sau khi xem chi tiết hoặc chỉnh sửa
  void _updateTask(Task updated) {
    final index = _tasks.indexWhere((t) => t.id == updated.id);
    if (index < 0) return;
    setState(() => _tasks[index] = updated);
  }

  // Chuyển sang màn hình xem chi tiết công việc
  void _openDetail(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          task: task,
          onTaskUpdated: _updateTask,
          onTaskDeleted: () => _delete(task),
        ),
      ),
    );
  }

  // Mở kho lưu trữ
  void _openArchive() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchiveScreen(
          archivedTasks: _tasks.where((t) => t.isArchived).toList(),
          onUnarchive: (task) {
            _updateTask(task.copyWith(isArchived: false));
          },
          onDeletePermanent: _delete,
        ),
      ),
    );
  }

  // Menu mở rộng khi bấm nút "+" (FAB)
  Future<void> _openQuickAdd() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.add_task_rounded),
                  ),
                  title: const Text(
                    'Thêm công việc chi tiết',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Nhập đầy đủ giờ, độ ưu tiên, ghi chú'),
                  onTap: () => Navigator.pop(ctx, 'detail_task'),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.flash_on_rounded),
                  ),
                  title: const Text(
                    'Thêm nhanh việc',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Tạo việc nhanh với ngày mặc định'),
                  onTap: () => Navigator.pop(ctx, 'quick_task'),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.repeat_rounded),
                  ),
                  title: const Text(
                    'Thói quen mỗi ngày',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Theo dõi chuỗi streak thói quen'),
                  onTap: () => Navigator.pop(ctx, 'habit'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || !mounted) return;

    if (action == 'detail_task') {
      final newTask = await Navigator.push<Task>(
        context,
        MaterialPageRoute(builder: (_) => const TaskEditScreen()),
      );
      if (newTask != null && mounted) {
        setState(() => _tasks.add(newTask));
      }
    } else if (action == 'quick_task') {
      final task = await showQuickAddSheet(context, now: widget.clock());
      if (task != null && mounted) {
        setState(() => _tasks.add(task));
      }
    } else if (action == 'habit') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HabitScreen()),
      );
    }
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
    // Loại bỏ các task đã lưu trữ khỏi màn hình Hôm nay
    final activeTasks = _tasks.where((t) => !t.isArchived).toList();
    final all = groupTasks(activeTasks, now);
    final filter = _filter;
    final groups = filter == null
        ? all
        : groupTasks(activeTasks.where((t) => t.tag == filter).toList(), now);
    final scheme = Theme.of(context).colorScheme;

    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        floatingActionButton: all.isTodayEmpty
            ? null
            : FloatingActionButton(
                tooltip: 'Thêm việc hoặc thói quen',
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
                  onToggleTheme: widget.onToggleTheme,
                  onSearch: _showSearchSoon,
                  onOpenArchive: _openArchive,
                ),
              ),
              SliverToBoxAdapter(
                child: _TagFilter(
                  selected: filter,
                  onSelected: (tag) => setState(() => _filter = tag),
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
                  now: now,
                  overdue: true,
                ),
              if (groups.today.isNotEmpty)
                ..._section(
                  title: 'Hôm nay · ${groups.today.length}',
                  tasks: groups.today,
                  now: now,
                ),
              if (groups.upcoming.isNotEmpty)
                ..._section(title: 'Sắp tới', tasks: groups.upcoming, now: now),
              if (filter != null &&
                  groups.overdue.isEmpty &&
                  groups.today.isEmpty &&
                  groups.upcoming.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Chưa có việc nào với nhãn "${filter.label}"',
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
              child: GestureDetector(
                onTap: () => _openDetail(task),
                child: TaskTile(
                  task: task,
                  now: now,
                  overdue: overdue,
                  onToggle: () => _toggleDone(task),
                ),
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
    required this.onToggleTheme,
    required this.onSearch,
    required this.onOpenArchive,
  });

  final DateTime now;
  final VoidCallback? onToggleTheme;
  final VoidCallback onSearch;
  final VoidCallback onOpenArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
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
            tooltip: isDark ? 'Chế độ sáng' : 'Chế độ tối',
            style: buttonStyle,
            onPressed: onToggleTheme,
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Kho lưu trữ',
            style: buttonStyle,
            onPressed: onOpenArchive,
            icon: const Icon(Icons.archive_outlined),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Tìm kiếm',
            style: buttonStyle,
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: const Text(
              'A',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagFilter extends StatelessWidget {
  const _TagFilter({required this.selected, required this.onSelected});

  final TaskTag? selected;
  final ValueChanged<TaskTag?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <TaskTag?>[null, ...TaskTag.values];
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
            label: Text(tag?.label ?? 'Tất cả'),
            selected: selected == tag,
            onSelected: (_) => onSelected(tag),
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
