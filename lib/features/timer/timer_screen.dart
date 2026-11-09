import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../data/repositories/task_repository.dart';
import 'countdown_controller.dart';
import 'timer_controller.dart';
import 'timer_mode.dart';
import 'widgets/countdown_view.dart';
import 'widgets/stopwatch_view.dart';

/// Tab Hẹn giờ: đếm ngược (Pomodoro) và bấm giờ.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  int _tab = 0; // 0 = Đếm ngược, 1 = Bấm giờ
  StreamSubscription<TimerFinished>? _finishedSub;
  bool _applyingPrepared = false;

  @override
  void initState() {
    super.initState();
    _finishedSub = context.read<CountdownController>().finished.listen(
      _onFinished,
    );
  }

  @override
  void dispose() {
    _finishedSub?.cancel();
    super.dispose();
  }

  /// Hết giờ: rung, phát âm hệ thống và hiện hộp báo (thông báo khi app ở nền
  /// làm ở bước thông báo).
  Future<void> _onFinished(TimerFinished event) async {
    unawaited(_feedback());
    if (!mounted) return;

    final minutes = (event.durationSec / 60).round();
    final text = switch (event.mode) {
      TimerMode.pomodoro => 'Phiên tập trung $minutes phút đã hoàn thành.',
      TimerMode.shortBreak || TimerMode.longBreak => 'Hết giờ nghỉ.',
      TimerMode.custom => 'Hẹn giờ $minutes phút đã hết.',
    };
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.timer_outlined),
        title: const Text('Hết giờ!'),
        content: Text(
          event.autoStarted ? '$text\nPhiên kế tiếp đã tự chạy.' : text,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _feedback() async {
    try {
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Máy không hỗ trợ rung hoặc âm thanh hệ thống: bỏ qua.
    }
  }

  /// Áp dụng việc được chọn sẵn từ nút đồng hồ ở Hôm nay (hoặc nút Bắt đầu ở
  /// Chi tiết việc).
  Future<void> _applyPrepared(TimerController timer) async {
    final id = timer.preparedTaskId;
    if (id == null) return;
    final countdown = context.read<CountdownController>();
    final tasks = context.read<TaskRepository>();
    final messenger = ScaffoldMessenger.of(context);

    if (!countdown.isIdle) {
      timer.clearPrepared();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Đang có phiên chạy. Kết thúc phiên trước khi chọn việc khác.',
            ),
          ),
        );
      return;
    }

    final task = await tasks.getById(id);
    if (!mounted) return;
    if (task != null) {
      // Giờ nghỉ không gắn việc, nên chuyển về Pomodoro để thấy việc đã chọn.
      if (!countdown.mode.isFocus) countdown.setMode(TimerMode.pomodoro);
      countdown.selectTask(task.id, task.title);
      setState(() => _tab = 0);
    }
    timer.clearPrepared();
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<TimerController>();
    if (timer.preparedTaskId != null && !_applyingPrepared) {
      _applyingPrepared = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) await _applyPrepared(timer);
        _applyingPrepared = false;
      });
    }

    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hẹn giờ',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Lịch sử tập trung',
                style: IconButton.styleFrom(
                  backgroundColor: theme.cardTheme.color,
                ),
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.focusHistory),
                icon: const Icon(Icons.history_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.hourglass_bottom_rounded),
                  label: Text('Đếm ngược'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.timer_outlined),
                  label: Text('Bấm giờ'),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (set) => setState(() => _tab = set.first),
            ),
          ),
          const SizedBox(height: 20),
          if (_tab == 0) const CountdownView() else const StopwatchView(),
        ],
      ),
    );
  }
}
