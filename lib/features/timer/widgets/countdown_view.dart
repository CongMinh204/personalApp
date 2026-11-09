import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../countdown_controller.dart';
import '../timer_format.dart';
import '../timer_mode.dart';
import 'custom_minutes_dialog.dart';
import 'progress_ring.dart';
import 'task_picker_sheet.dart';

/// Tab Đếm ngược: chế độ, vòng tròn, chấm chu kỳ, việc đang tập trung và các
/// nút điều khiển.
class CountdownView extends StatelessWidget {
  const CountdownView({super.key});

  @override
  Widget build(BuildContext context) {
    final cd = context.watch<CountdownController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canPickCustom = cd.mode == TimerMode.custom && cd.isIdle;

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mode in TimerMode.values)
              ChoiceChip(
                label: Text(mode.label),
                selected: cd.mode == mode,
                onSelected: (_) => _selectMode(context, cd, mode),
              ),
          ],
        ),
        const SizedBox(height: 20),
        ProgressRing(
          // Vòng đầy khi sẵn sàng, vơi dần khi đếm ngược.
          fraction: 1 - cd.progress,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: canPickCustom ? () => _pickCustom(context, cd) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatMmSs(cd.remaining),
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontSize: 58,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(cd, canPickCustom),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _CycleDots(controller: cd),
        const SizedBox(height: 20),
        if (cd.mode.isFocus) _TaskCard(controller: cd),
        if (cd.mode.isFocus) const SizedBox(height: 20),
        _Controls(controller: cd),
      ],
    );
  }

  String _subtitle(CountdownController cd, bool canPickCustom) {
    if (cd.mode == TimerMode.pomodoro) {
      return 'Phiên ${cd.sessionNumber}/${CountdownController.cycleLength}'
          ' · ${cd.mode.description}';
    }
    if (canPickCustom) return '${cd.mode.description} · chạm để đổi';
    return cd.mode.description;
  }

  Future<void> _selectMode(
    BuildContext context,
    CountdownController cd,
    TimerMode mode,
  ) async {
    if (mode == cd.mode) return;
    if (!cd.isIdle) {
      final stop = await confirmStopSession(context);
      if (stop != true) return;
    }
    cd.setMode(mode);
    if (mode == TimerMode.custom && context.mounted) {
      await _pickCustom(context, cd);
    }
  }

  Future<void> _pickCustom(BuildContext context, CountdownController cd) async {
    final minutes = await showCustomMinutesDialog(
      context,
      initial: cd.customMinutes,
    );
    if (minutes != null) cd.setCustomMinutes(minutes);
  }
}

/// Hỏi lại trước khi dừng một phiên đang chạy (đổi chế độ).
Future<bool?> confirmStopSession(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Dừng phiên đang chạy?'),
      content: const Text(
        'Phiên hiện tại sẽ dừng và được lưu là bỏ dở nếu đã chạy đủ lâu.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Tiếp tục'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Dừng'),
        ),
      ],
    ),
  );
}

/// 4 chấm của chu kỳ Pomodoro: chấm đã hoàn thành tô đậm, phiên hiện tại tô
/// nhạt.
class _CycleDots extends StatelessWidget {
  const _CycleDots({required this.controller});

  final CountdownController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = controller.completedInCycle;
    final currentIsPomodoro = controller.mode == TimerMode.pomodoro;

    return Semantics(
      label:
          'Phiên ${controller.sessionNumber}/${CountdownController.cycleLength}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < CountdownController.cycleLength; i++)
            Container(
              width: 28,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: i < done
                    ? scheme.primary
                    : (currentIsPomodoro && i == done)
                    ? scheme.primary.withValues(alpha: 0.4)
                    : scheme.surfaceContainerHighest,
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.controller});

  final CountdownController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = controller.isIdle;

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? () => _pick(context) : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.center_focus_strong_outlined,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đang tập trung cho',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        controller.taskTitle ?? 'Không gắn việc',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: controller.taskId == null
                              ? scheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final choice = await showTaskPicker(context, selectedId: controller.taskId);
    if (choice != null) controller.selectTask(choice.id, choice.title);
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller});

  final CountdownController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final running = controller.isRunning;
    final tooltip = running
        ? 'Tạm dừng'
        : controller.isPaused
        ? 'Tiếp tục'
        : 'Bắt đầu';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          tooltip: 'Đặt lại',
          iconSize: 26,
          style: IconButton.styleFrom(fixedSize: const Size(56, 56)),
          onPressed: controller.reset,
          icon: const Icon(Icons.replay_rounded),
        ),
        const SizedBox(width: 28),
        IconButton.filled(
          tooltip: tooltip,
          iconSize: 40,
          style: IconButton.styleFrom(
            fixedSize: const Size(84, 84),
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: controller.toggle,
          icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
        ),
        const SizedBox(width: 28),
        IconButton.filledTonal(
          tooltip: 'Bỏ qua phiên',
          iconSize: 26,
          style: IconButton.styleFrom(fixedSize: const Size(56, 56)),
          onPressed: controller.skip,
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}
