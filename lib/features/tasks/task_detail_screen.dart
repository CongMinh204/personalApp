import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../data/models/subtask.dart';
import '../../data/models/tag.dart';
import '../../data/models/task.dart';
import '../../data/repositories/focus_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../theme/app_theme.dart';
import '../timer/timer_controller.dart';
import 'task_actions.dart';
import 'task_edit_screen.dart';
import 'task_labels.dart';

/// Chi tiết một việc: thông tin, việc con, thời gian đã tập trung. Mở khi bấm
/// tên việc ở Hôm nay.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late final TaskRepository _tasks = context.read<TaskRepository>();
  late final TagRepository _tags = context.read<TagRepository>();
  late final TaskActions _actions = TaskActions(_tasks);
  late final Stream<Task?> _task = _tasks.watchById(widget.taskId);
  late final Stream<List<Subtask>> _subtasks = _tasks.watchSubtasks(
    widget.taskId,
  );
  late final Stream<List<Tag>> _tagList = _tags.watchAll();
  late final Future<FocusTotal> _focus = context
      .read<FocusRepository>()
      .totalForTask(widget.taskId);

  Future<void> _toggleDone(Task task) async {
    final next = await _actions.toggleDone(task);
    if (next == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Đã tạo việc cho lần lặp kế tiếp')),
      );
  }

  Future<void> _edit() async {
    // Route do AppRoutes tạo không biết kiểu kết quả, nên nhận Object? rồi so
    // sánh với TaskEditResult.
    final result = await Navigator.of(context)
        .pushNamed(AppRoutes.taskEdit, arguments: widget.taskId);
    if (result == TaskEditResult.deleted && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _start() {
    context.read<TimerController>().prepare(widget.taskId);
    // Quay về khung 5 tab, đang ở tab Hẹn giờ.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _delete(Task task) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa việc này?'),
        content: Text('"${task.title}" và các việc con của nó sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final deleted = await _actions.delete(task);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã xóa "${task.title}"'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () => _actions.undoDelete(deleted),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Task?>(
      stream: _task,
      builder: (context, snapshot) {
        final task = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Chi tiết việc'),
            actions: [
              if (task != null)
                IconButton(
                  tooltip: 'Sửa việc',
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : task == null
              ? const Center(child: Text('Việc này không còn tồn tại'))
              : _content(context, task),
        );
      },
    );
  }

  Widget _content(BuildContext context, Task task) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: task.done,
                      onChanged: (_) => _toggleDone(task),
                      shape: const CircleBorder(),
                      semanticLabel: task.done
                          ? 'Bỏ đánh dấu xong'
                          : 'Đánh dấu xong',
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          task.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: task.done ? muted : null,
                            decoration: task.done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StreamBuilder<List<Tag>>(
                        stream: _tagList,
                        builder: (context, snapshot) {
                          final tag = (snapshot.data ?? const <Tag>[])
                              .where((t) => t.id == task.tagId)
                              .firstOrNull;
                          return tag == null
                              ? const SizedBox.shrink()
                              : _Badge(
                                  label: tag.name,
                                  colors: TaskColors.of(context).tag(tag.color),
                                );
                        },
                      ),
                      _PriorityBadge(priority: task.priority),
                    ],
                  ),
                ),
                if (task.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 14, 0, 0),
                    child: Text(task.note, style: theme.textTheme.bodyLarge),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Ngày',
                  value: dueDateLabel(task),
                ),
                const Divider(height: 1),
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  label: 'Giờ',
                  value: dueTimeLabel(task),
                ),
                const Divider(height: 1),
                _InfoRow(
                  icon: Icons.notifications_none_rounded,
                  label: 'Nhắc trước',
                  value: reminderValueLabel(task),
                ),
                const Divider(height: 1),
                _InfoRow(
                  icon: Icons.repeat_rounded,
                  label: 'Lặp lại',
                  value: task.repeatRule.label,
                ),
              ],
            ),
          ),
        ),
        if (task.subtaskTotal > 0) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Việc con',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '${task.subtaskDone}/${task.subtaskTotal}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 8),
                    child: LinearProgressIndicator(
                      value: task.subtaskDone / task.subtaskTotal,
                      borderRadius: BorderRadius.circular(8),
                      minHeight: 6,
                    ),
                  ),
                  StreamBuilder<List<Subtask>>(
                    stream: _subtasks,
                    builder: (context, snapshot) => Column(
                      children: [
                        for (final s in snapshot.data ?? const <Subtask>[])
                          Row(
                            children: [
                              Checkbox(
                                value: s.done,
                                onChanged: (v) =>
                                    _tasks.setSubtaskDone(s.id, v ?? false),
                                shape: const CircleBorder(),
                                semanticLabel: s.title,
                              ),
                              Expanded(
                                child: Text(
                                  s.title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: s.done ? muted : null,
                                    decoration: s.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Đã tập trung', style: theme.textTheme.bodyLarge),
                ),
                FutureBuilder<FocusTotal>(
                  future: _focus,
                  builder: (context, snapshot) => Text(
                    snapshot.hasData ? focusTotalLabel(snapshot.data!) : '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Bắt đầu'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          onPressed: () => _delete(task),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Xóa việc này'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          Icon(icon, size: 20, color: muted),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.colors});

  final String label;
  final (Color, Color) colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: colors.$2, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final color = TaskColors.of(context).priority(priority);
    return _Badge(
      label: priorityLabel(priority),
      colors: (color.withValues(alpha: 0.14), color),
    );
  }
}
