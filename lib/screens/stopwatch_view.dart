import 'package:flutter/material.dart';

import '../logic/stopwatch_controller.dart';
import '../utils/timer_format.dart';
import '../widgets/progress_ring.dart';

/// Tab "Bấm giờ" (SRS 3.4.2, UC14).
class StopwatchView extends StatelessWidget {
  const StopwatchView({super.key, required this.controller});

  final StopwatchController controller;

  @override
  Widget build(BuildContext context) {
    final sw = controller;
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: sw,
      builder: (context, _) {
        final elapsed = sw.elapsed;
        final laps = sw.laps;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
          children: [
            Center(
              child: ProgressRing(
                // vòng chạy theo giây trong phút
                progress: (elapsed.inMilliseconds % 60000) / 60000,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fmtStopwatch(elapsed),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vòng ${sw.lapNumber}',
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
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 56,
                  child: FilledButton.tonal(
                    onPressed: sw.isRunning ? sw.lap : null,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Vòng',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                IconButton.filled(
                  tooltip: sw.isRunning ? 'Tạm dừng' : 'Bắt đầu',
                  onPressed: sw.toggle,
                  icon: Icon(
                    sw.isRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
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
                SizedBox(
                  width: 72,
                  height: 56,
                  child: FilledButton.tonal(
                    onPressed: elapsed > Duration.zero ? sw.reset : null,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Đặt lại',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            if (laps.isNotEmpty) ...[
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < laps.length; i++)
                      _LapRow(lap: laps[i], first: i == 0),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LapRow extends StatelessWidget {
  const _LapRow({required this.lap, required this.first});

  final LapInfo lap;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasBadge = lap.fastest || lap.slowest;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              'Vòng ${lap.number}',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: hasBadge
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: lap.fastest ? context.okBg : context.badBg,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        lap.fastest ? 'Nhanh nhất' : 'Chậm nhất',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: lap.fastest ? context.okFg : context.badFg,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Text(
            fmtStopwatch(lap.time),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
