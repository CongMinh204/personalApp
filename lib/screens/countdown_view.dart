import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/countdown_controller.dart';
import '../utils/timer_format.dart';
import '../widgets/progress_ring.dart';

/// Tab "Đếm ngược" (SRS 3.4.1): chế độ, vòng tiến độ, chấm phiên,
/// "Đang tập trung cho", nút Đặt lại / Bắt đầu-Tạm dừng / Bỏ qua.
class CountdownView extends StatelessWidget {
  const CountdownView({
    super.key,
    required this.controller,
    required this.onPickTask,
  });

  final CountdownController controller;
  final VoidCallback onPickTask;

  static const _modes = [
    (TimerMode.pomodoro, 'Pomodoro'),
    (TimerMode.shortBreak, 'Nghỉ ngắn'),
    (TimerMode.longBreak, 'Nghỉ dài'),
    (TimerMode.custom, 'Tùy chỉnh'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildBody(context, controller),
    );
  }

  Widget _buildBody(BuildContext context, CountdownController c) {
    final cs = Theme.of(context).colorScheme;
    final running = c.state == RunState.running;
    final canEditCustom =
        c.mode == TimerMode.custom && c.state == RunState.idle;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        children: [
          // Chế độ
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (mode, label) in _modes) ...[
                  ChoiceChip(
                    label: Text(label),
                    selected: c.mode == mode,
                    onSelected: (_) => c.setMode(mode),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Vòng tiến độ
          ProgressRing(
            progress: c.progress,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canEditCustom ? () => _pickMinutes(context, c) : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fmtCountdown(c.remaining),
                    style: const TextStyle(
                      fontSize: 58,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(c),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4 chấm phiên
          Semantics(
            label:
                'Đã xong ${c.cycleDone} trên ${CountdownController.cycleLength} phiên',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < CountdownController.cycleLength; i++) ...[
                  Container(
                    width: 28,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i < c.cycleDone
                          ? cs.primary
                          : (i == c.cycleDone &&
                                c.mode == TimerMode.pomodoro &&
                                c.state != RunState.idle)
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                    ),
                  ),
                  if (i < CountdownController.cycleLength - 1)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Đang tập trung cho
          Material(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onPickTask,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.task_alt_rounded,
                        size: 20,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đang tập trung cho',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.task?.title ?? 'Không gắn việc',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Nút điều khiển
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Đặt lại',
                onPressed: c.reset,
                icon: const Icon(Icons.restart_alt_rounded),
                iconSize: 24,
                style: IconButton.styleFrom(fixedSize: const Size(56, 56)),
              ),
              const SizedBox(width: 28),
              IconButton.filled(
                tooltip: running ? 'Tạm dừng' : 'Bắt đầu',
                onPressed: c.toggle,
                icon: Icon(
                  running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                iconSize: 38,
                style: IconButton.styleFrom(
                  fixedSize: const Size(84, 84),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(width: 28),
              IconButton.filledTonal(
                tooltip: 'Bỏ qua phiên',
                onPressed: c.skip,
                icon: const Icon(Icons.skip_next_rounded),
                iconSize: 24,
                style: IconButton.styleFrom(fixedSize: const Size(56, 56)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _subtitle(CountdownController c) => switch (c.mode) {
    TimerMode.pomodoro =>
      'Phiên ${(c.cycleDone + 1).clamp(1, CountdownController.cycleLength)}/${CountdownController.cycleLength} · Tập trung',
    TimerMode.shortBreak => 'Nghỉ ngắn · thư giãn mắt',
    TimerMode.longBreak => 'Nghỉ dài · đứng dậy đi lại',
    TimerMode.custom =>
      c.state == RunState.idle
          ? 'Tùy chỉnh · chạm để đổi'
          : 'Hẹn giờ tùy chỉnh',
  };

  Future<void> _pickMinutes(BuildContext context, CountdownController c) async {
    final input = TextEditingController(text: '${c.customMinutes}');
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đặt thời gian'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(suffixText: 'phút'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(input.text)),
            child: const Text('Đặt'),
          ),
        ],
      ),
    );
    if (minutes != null && minutes > 0) c.setCustomMinutes(minutes);
  }
}
