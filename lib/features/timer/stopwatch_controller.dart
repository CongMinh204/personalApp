import 'dart:async';

import 'package:flutter/foundation.dart';

import 'timer_mode.dart';

/// Đồng hồ bấm giờ có vòng (lap). Chỉ để đo, không lưu vào lịch sử.
///
/// Như đồng hồ đếm ngược, thời gian được tính theo giờ hiện tại nên chạy nền
/// vẫn đúng.
class StopwatchController extends ChangeNotifier {
  StopwatchController({
    DateTime Function()? clock,
    this.autoTick = true,
    this.tickEvery = const Duration(milliseconds: 50),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// `false` thì không tự chạy nhịp (test gọi [tick] bằng tay).
  final bool autoTick;
  final Duration tickEvery;

  RunState _state = RunState.idle;
  int _elapsedBeforeMs = 0;
  DateTime? _segmentStart;

  /// Thời điểm (tính theo [elapsed]) kết thúc vòng gần nhất.
  Duration _lapBase = Duration.zero;
  final _laps = <Duration>[];
  Timer? _timer;

  RunState get state => _state;
  bool get isIdle => _state == RunState.idle;
  bool get isRunning => _state == RunState.running;
  bool get isPaused => _state == RunState.paused;

  /// Tổng thời gian đã chạy.
  Duration get elapsed {
    final segment = _segmentStart;
    final running = segment == null
        ? 0
        : _clock().difference(segment).inMilliseconds;
    return Duration(milliseconds: _elapsedBeforeMs + running);
  }

  /// Thời gian của vòng đang chạy.
  Duration get currentLap => elapsed - _lapBase;

  /// Số thứ tự của vòng đang chạy (1 khi chưa bấm Vòng lần nào).
  int get lapNumber => _laps.length + 1;

  /// Các vòng đã xong, vòng cũ nhất trước.
  List<Duration> get laps => List.unmodifiable(_laps);

  /// Các vòng đã xong, vòng mới nhất trước (thứ tự hiển thị).
  List<Duration> get lapsNewestFirst => _laps.reversed.toList();

  /// Vòng nhanh nhất và chậm nhất. Chỉ có khi đã có ít nhất 2 vòng (một vòng
  /// thì không có gì để so sánh).
  Duration? get fastest => _laps.length < 2 ? null : _laps.reduce(_min);
  Duration? get slowest => _laps.length < 2 ? null : _laps.reduce(_max);

  static Duration _min(Duration a, Duration b) => a <= b ? a : b;
  static Duration _max(Duration a, Duration b) => a >= b ? a : b;

  void start() {
    if (isRunning) return;
    _segmentStart = _clock();
    _state = RunState.running;
    _startTicking();
    notifyListeners();
  }

  void pause() {
    if (!isRunning) return;
    _elapsedBeforeMs = elapsed.inMilliseconds;
    _segmentStart = null;
    _state = RunState.paused;
    _stopTicking();
    notifyListeners();
  }

  /// Nút chính: chạy, tạm dừng hoặc chạy tiếp.
  void toggle() => isRunning ? pause() : start();

  /// Chốt vòng hiện tại và bắt đầu vòng mới. Chỉ có tác dụng khi đang chạy.
  void lap() {
    if (!isRunning) return;
    final now = elapsed;
    _laps.add(now - _lapBase);
    _lapBase = now;
    notifyListeners();
  }

  /// Về 00:00, xóa hết vòng.
  void reset() {
    _stopTicking();
    _state = RunState.idle;
    _elapsedBeforeMs = 0;
    _segmentStart = null;
    _lapBase = Duration.zero;
    _laps.clear();
    notifyListeners();
  }

  /// Báo giao diện cập nhật số đang chạy.
  void tick() {
    if (isRunning) notifyListeners();
  }

  void _startTicking() {
    _stopTicking();
    if (autoTick) _timer = Timer.periodic(tickEvery, (_) => tick());
  }

  void _stopTicking() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTicking();
    super.dispose();
  }
}
