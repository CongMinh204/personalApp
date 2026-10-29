import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme/app_theme.dart';
import '../utils/vi_date.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.now,
    required this.onToggle,
    this.overdue = false,
  });

  final Task task;
  final DateTime now;
  final VoidCallback onToggle;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = TaskColors.of(context);
    final muted = scheme.onSurfaceVariant;
    final priorityColor = colors.priority(task.priority);
    final (tagBackground, tagForeground) = colors.tag(task.tag, scheme);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 12, 14, 12),
        child: Row(
          children: [
            Checkbox(
              value: task.done,
              onChanged: (_) => onToggle(),
              semanticLabel: task.title,
              shape: const CircleBorder(),
              fillColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? scheme.primary
                    : Colors.transparent,
              ),
              side: WidgetStateBorderSide.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? const BorderSide(color: Colors.transparent)
                    : BorderSide(color: priorityColor, width: 2),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: task.done ? muted : scheme.onSurface,
                      decoration: task.done ? TextDecoration.lineThrough : null,
                      decorationColor: muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Meta(
                        icon: Icons.schedule_rounded,
                        label: taskTimeLabel(task, now),
                        color: overdue ? scheme.error : muted,
                      ),
                      if (task.subtasksTotal > 0)
                        _Meta(
                          icon: Icons.checklist_rounded,
                          label: '${task.subtasksDone}/${task.subtasksTotal}',
                          color: muted,
                        ),
                      if (task.reminder)
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 15,
                          color: muted,
                        ),
                      if (task.repeat)
                        Icon(Icons.repeat_rounded, size: 15, color: muted),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tagBackground,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                task.tag.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tagForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
