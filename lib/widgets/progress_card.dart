import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme/app_theme.dart';
import '../utils/vi_date.dart';

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.done,
    required this.total,
    this.next,
  });

  final int done;
  final int total;
  final Task? next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onPrimary = scheme.onPrimary;
    final next = this.next;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Tiến độ hôm nay',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ),
              Text(
                '$done/$total',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(end: total == 0 ? 0 : done / total),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
              color: onPrimary,
              backgroundColor: onPrimary.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: onPrimary.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  next == null
                      ? 'Còn ${total - done} việc chưa xong'
                      : 'Tiếp theo: ${next.title} lúc ${hourMinute(next.due!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AllDoneCard extends StatelessWidget {
  const AllDoneCard({super.key, required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TaskColors.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.green,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 36, color: colors.onGreen),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xong hết việc hôm nay!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Đã hoàn thành $total việc. Nghỉ ngơi chút nhé.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
