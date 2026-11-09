import 'package:flutter/material.dart';

import '../../../data/models/tag.dart';
import '../../../data/models/task.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/vi_date.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.tag,
    required this.now,
    required this.onToggle,
    this.onTap,
    this.onTimer,
    this.overdue = false,
  });

  final Task task;

  /// Nhãn của việc; `null` = Không nhãn (không hiện badge).
  final Tag? tag;
  final DateTime now;
  final VoidCallback onToggle;

  /// Bấm vào việc (mở Chi tiết).
  final VoidCallback? onTap;

  /// Bấm nút đồng hồ để hẹn giờ tập trung cho việc này; chỉ hiện với việc
  /// chưa xong.
  final VoidCallback? onTimer;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = TaskColors.of(context);
    final muted = scheme.onSurfaceVariant;
    final priorityColor = colors.priority(task.priority);
    final tag = this.tag;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
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
                        decoration: task.done
                            ? TextDecoration.lineThrough
                            : null,
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
                        if (task.subtaskTotal > 0)
                          _Meta(
                            icon: Icons.checklist_rounded,
                            label: '${task.subtaskDone}/${task.subtaskTotal}',
                            color: muted,
                          ),
                        if (task.reminderMinutes != null)
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 15,
                            color: muted,
                          ),
                        if (task.repeatRule != RepeatRule.none)
                          Icon(Icons.repeat_rounded, size: 15, color: muted),
                      ],
                    ),
                  ],
                ),
              ),
              if (tag != null) ...[
                const SizedBox(width: 8),
                _TagBadge(tag: tag),
              ],
              if (onTimer != null && !task.done)
                IconButton(
                  tooltip: 'Bấm giờ tập trung: ${task.title}',
                  visualDensity: VisualDensity.compact,
                  onPressed: onTimer,
                  icon: Icon(Icons.timer_outlined, size: 22, color: muted),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.tag});

  final Tag tag;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = TaskColors.of(context).tag(tag.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag.name,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
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
