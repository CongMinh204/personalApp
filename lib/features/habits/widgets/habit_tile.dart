import 'package:flutter/material.dart';

import '../../../data/models/habit.dart';
import '../../../theme/app_theme.dart';
import '../habit_logic.dart';

/// Một dòng thói quen ở tab Thói quen: biểu tượng màu, tên, chuỗi ngày, tiến độ
/// trong ngày và nút chấm.
class HabitTile extends StatelessWidget {
  const HabitTile({
    super.key,
    required this.habit,
    required this.count,
    required this.streak,
    required this.scheduledToday,
    required this.today,
    required this.onTap,
    required this.onToggle,
  });

  final Habit habit;

  /// Số lần đã làm hôm nay.
  final int count;

  /// Chuỗi ngày hiện tại.
  final int streak;
  final bool scheduledToday;
  final DateTime today;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = TaskColors.of(context);
    final ink = habitInkColor(habit.color, theme.brightness);
    final done = scheduledToday && isDone(habit, count);
    final multi = habit.goalPerDay > 1;

    final tooltip = !scheduledToday
        ? 'Không có lịch hôm nay'
        : done
        ? 'Bỏ đánh dấu: ${habit.name}'
        : multi
        ? 'Thêm một lần: ${habit.name}'
        : 'Hoàn thành: ${habit.name}';

    return Opacity(
      opacity: scheduledToday ? 1 : 0.6,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(habitIconData(habit.icon), color: ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (!scheduledToday)
                        Text(
                          restDayLabel(habit, today),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (streak > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 16,
                                    color: colors.medium,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$streak ngày',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.medium,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            Text(
                              progressLabel(habit, count),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: done
                                    ? colors.onGreen
                                    : scheme.onSurfaceVariant,
                                fontWeight: done ? FontWeight.w600 : null,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tooltip,
                  onPressed: scheduledToday ? onToggle : null,
                  style: IconButton.styleFrom(
                    fixedSize: const Size(44, 44),
                    backgroundColor: done ? scheme.primary : null,
                    foregroundColor: done ? scheme.onPrimary : ink,
                    side: done ? null : BorderSide(color: ink, width: 2),
                  ),
                  icon: Icon(
                    done
                        ? Icons.check_rounded
                        : multi
                        ? Icons.add_rounded
                        : Icons.check_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
