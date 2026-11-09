import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme.dart';
import '../stopwatch_controller.dart';
import '../timer_format.dart';
import 'progress_ring.dart';

/// Tab Bấm giờ: số chạy, vòng, các nút điều khiển và danh sách vòng.
class StopwatchView extends StatelessWidget {
  const StopwatchView({super.key});

  @override
  Widget build(BuildContext context) {
    final sw = context.watch<StopwatchController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final running = sw.isRunning;
    final tooltip = running
        ? 'Tạm dừng'
        : sw.isPaused
        ? 'Tiếp tục'
        : 'Bắt đầu';
    // Vòng quay trọn một vòng mỗi phút.
    final fraction = (sw.elapsed.inMilliseconds % 60000) / 60000;

    return Column(
      children: [
        const SizedBox(height: 8),
        ProgressRing(
          fraction: sw.isIdle ? 0 : fraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatStopwatch(sw.elapsed),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vòng ${sw.lapNumber}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 72,
              height: 56,
              child: FilledButton.tonal(
                onPressed: running ? sw.lap : null,
                child: const Text('Vòng'),
              ),
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
              onPressed: sw.toggle,
              icon: Icon(
                running ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
            const SizedBox(width: 28),
            SizedBox(
              width: 72,
              height: 56,
              child: FilledButton.tonal(
                onPressed: sw.reset,
                child: const Text('Đặt lại'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (sw.laps.isNotEmpty) _Laps(controller: sw),
      ],
    );
  }
}

class _Laps extends StatelessWidget {
  const _Laps({required this.controller});

  final StopwatchController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TaskColors.of(context);
    final laps = controller.lapsNewestFirst;
    final fastest = controller.fastest;
    final slowest = controller.slowest;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < laps.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              SizedBox(
                height: 46,
                child: Row(
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(
                        'Vòng ${laps.length - i}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: laps[i] == fastest
                            ? _LapBadge(
                                label: 'Nhanh nhất',
                                background: colors.green,
                                foreground: colors.onGreen,
                              )
                            : laps[i] == slowest
                            ? _LapBadge(
                                label: 'Chậm nhất',
                                background: theme.colorScheme.errorContainer,
                                foreground: theme.colorScheme.onErrorContainer,
                              )
                            : null,
                      ),
                    ),
                    Text(
                      formatStopwatch(laps[i]),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LapBadge extends StatelessWidget {
  const _LapBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}
