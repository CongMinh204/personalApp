import 'dart:async';

import 'package:flutter/material.dart';

import '../models/habit.dart';

class HabitTimerScreen extends StatefulWidget {
  const HabitTimerScreen({
    super.key,
    required this.habit,
    required this.onFinished,
  });

  final Habit habit;
  final VoidCallback onFinished;

  @override
  State<HabitTimerScreen> createState() => _HabitTimerScreenState();
}

class _HabitTimerScreenState extends State<HabitTimerScreen> {
  Timer? _timer;
  late int _totalSeconds;
  late int _remainingSeconds;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.habit.durationMinutes * 60;
    if (_totalSeconds <= 0) _totalSeconds = 60; // Tối thiểu 1 phút
    _remainingSeconds = _totalSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        setState(() => _isRunning = false);
        widget.onFinished();
        _showDoneDialog();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _totalSeconds;
    });
  }

  void _showDoneDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 Xuất sắc!'),
        content: Text(
          'Bạn đã hoàn thành thời gian cho thói quen "${widget.habit.title}". Chuỗi ngày đã được cập nhật!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = _totalSeconds > 0
        ? (_remainingSeconds / _totalSeconds)
        : 0.0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.habit.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: scheme.primary,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(_remainingSeconds),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isRunning
                          ? 'Đang tập trung...'
                          : (_remainingSeconds == _totalSeconds
                                ? 'Sẵn sàng'
                                : 'Tạm dừng'),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 48),

            // 3 nút điều khiển: Dừng, Tiếp tục, Đặt lại
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Nút Đặt lại
                Column(
                  children: [
                    IconButton.filledTonal(
                      iconSize: 32,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Đặt lại',
                      onPressed: _resetTimer,
                    ),
                    const SizedBox(height: 6),
                    const Text('Đặt lại', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(width: 32),

                // 2 & 3. Nút Dừng / Tiếp tục
                Column(
                  children: [
                    IconButton.filled(
                      iconSize: 44,
                      icon: Icon(
                        _isRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      tooltip: _isRunning ? 'Dừng' : 'Tiếp tục',
                      onPressed: _isRunning ? _stopTimer : _startTimer,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isRunning ? 'Dừng' : 'Tiếp tục',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
