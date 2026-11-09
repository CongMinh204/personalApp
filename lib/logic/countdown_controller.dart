import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/focus_session_repository.dart';
import '../models/focus_session.dart';
import '../services/timer_notification_service.dart';

enum TimerMode { pomodoro, shortBreak, longBreak, custom }

enum RunState { idle, running, paused }

/// Cấu hình lấy từ màn Cài đặt (SRS 3.6.1): mặc định 25 / 5 / 15, tự chạy tắt.
class TimerSettings {
  const TimerSettings({
    this.pomodoroMin = 25,
    this.shortBreakMin = 5,
    this.longBreakMin = 15,
    this.autoStartNext = false,
  });

  final int pomodoroMin;
  final int shortBreakMin;
  final int longBreakMin;
  final bool autoStartNext;
}

/// Việc được gắn vào phiên ("Đang tập trung cho"). id null = không gắn việc.
class TaskRef {
  const TaskRef(this.id, this.title);
  final String? id;
  final String title;
}

/// Đếm ngược + Pomodoro (UC12, UC13, BR-08).
///
/// Thời gian được tính theo mốc kết thúc [_endAt] chứ không cộng dồn từng tick,
/// nên chạy nền / bị OS làm chậm vẫn đúng (SRS 4.2.3).
class CountdownController extends ChangeNotifier with WidgetsBindingObserver {
  CountdownController({
    required this.repository,
    required this.notifications,
    TimerSettings settings = const TimerSettings(),
    DateTime Function()? now,
  }) : _settings = settings,
       _now = now ?? DateTime.now {
    _remaining = Duration(seconds: totalSeconds);
    WidgetsBinding.instance.addObserver(this);
  }

  static const cycleLength = 4; // BR-08

  final FocusSessionRepository repository;
  final TimerNotifier notifications;
  final DateTime Function() _now;

  TimerSettings _settings;
  TimerMode _mode = TimerMode.pomodoro;
  RunState _state = RunState.idle;
  int _customMinutes = 10;
  int _cycleDone = 0; // số phiên Pomodoro đã xong trong chu kỳ (0..4)
  TaskRef? _task;

  late Duration _remaining; // dùng khi không chạy
  DateTime? _endAt; // dùng khi đang chạy
  DateTime? _startedAt; // lúc bắt đầu phiên (giữ nguyên qua tạm dừng)
  Timer? _ticker;

  final _events = StreamController<String>.broadcast();

  // ---- Trạng thái cho UI ----
  TimerMode get mode => _mode;
  RunState get state => _state;
  int get cycleDone => _cycleDone;
  int get customMinutes => _customMinutes;
  TaskRef? get task => _task;
  Stream<String> get events => _events.stream;

  int get totalSeconds => switch (_mode) {
    TimerMode.pomodoro => _settings.pomodoroMin * 60,
    TimerMode.shortBreak => _settings.shortBreakMin * 60,
    TimerMode.longBreak => _settings.longBreakMin * 60,
    TimerMode.custom => _customMinutes * 60,
  };

  Duration get remaining {
    if (_state != RunState.running) return _remaining;
    final r = _endAt!.difference(_now());
    return r.isNegative ? Duration.zero : r;
  }

  /// Phần vòng còn lại, 1.0 → 0.0.
  double get progress {
    final total = totalSeconds * 1000;
    if (total == 0) return 0;
    return (remaining.inMilliseconds / total).clamp(0.0, 1.0);
  }

  // ---- Hành động ----
  void start() {
    if (_state == RunState.running) return;
    unawaited(notifications.ensurePermissions());
    final now = _now();
    _startedAt ??= now;
    _endAt = now.add(_remaining);
    _state = RunState.running;
    unawaited(
      notifications.scheduleEnd(
        at: _endAt!,
        title: 'Hẹn giờ',
        body: _finishMessage(), // MSG07
      ),
    );
    _startTicker();
    notifyListeners();
  }

  /// UC12 – 3.1: tạm dừng thì hủy thông báo, tiếp tục thì đặt lại.
  void pause() {
    if (_state != RunState.running) return;
    _remaining = remaining;
    _stopTicker();
    unawaited(notifications.cancelEnd());
    _state = RunState.paused;
    notifyListeners();
  }

  void toggle() => _state == RunState.running ? pause() : start();

  /// UC12 – 3.2: về thời lượng ban đầu. Phần đã tập trung được lưu là "bỏ dở"
  /// (không tính hoàn thành) để hiện ở Lịch sử như mockup.
  void reset() {
    _abandon();
    _remaining = Duration(seconds: totalSeconds);
    notifyListeners();
  }

  /// UC12 – 3.3: bỏ qua, chuyển ngay phiên kế tiếp, phiên hiện tại không được tính.
  void skip() {
    final from = _mode;
    _abandon();
    switch (from) {
      case TimerMode.pomodoro:
        _mode = TimerMode.shortBreak;
      case TimerMode.shortBreak:
        _mode = TimerMode.pomodoro;
      case TimerMode.longBreak:
        _cycleDone = 0;
        _mode = TimerMode.pomodoro;
      case TimerMode.custom:
        break;
    }
    _remaining = Duration(seconds: totalSeconds);
    notifyListeners();
  }

  void setMode(TimerMode m) {
    if (m == _mode) return;
    _abandon();
    _mode = m;
    _remaining = Duration(seconds: totalSeconds);
    notifyListeners();
  }

  /// UC13: đặt khoảng thời gian bất kỳ (phút).
  void setCustomMinutes(int minutes) {
    _customMinutes = minutes.clamp(1, 600);
    if (_mode == TimerMode.custom) {
      _abandon();
      _remaining = Duration(seconds: totalSeconds);
    }
    notifyListeners();
  }

  void selectTask(TaskRef? t) {
    _task = t;
    notifyListeners();
  }

  /// Gọi khi người dùng đổi thời lượng trong Cài đặt.
  void updateSettings(TimerSettings s) {
    _settings = s;
    if (_state == RunState.idle) _remaining = Duration(seconds: totalSeconds);
    notifyListeners();
  }

  // ---- Nội bộ ----
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    if (_state != RunState.running) return;
    if (remaining == Duration.zero) {
      _complete();
    } else {
      notifyListeners();
    }
  }

  void _complete() {
    _stopTicker();
    final finished = _mode;
    final message = _finishMessage();
    _persistIfFocus(finished, durationSec: totalSeconds, completed: true);

    _state = RunState.idle;
    _startedAt = null;
    _endAt = null;

    // BR-08: sau mỗi phiên là nghỉ ngắn, đủ 4 phiên thì nghỉ dài, rồi chu kỳ mới.
    switch (finished) {
      case TimerMode.pomodoro:
        _cycleDone++;
        _mode = _cycleDone >= cycleLength
            ? TimerMode.longBreak
            : TimerMode.shortBreak;
      case TimerMode.shortBreak:
        _mode = TimerMode.pomodoro;
      case TimerMode.longBreak:
        _cycleDone = 0;
        _mode = TimerMode.pomodoro;
      case TimerMode.custom:
        break;
    }
    _remaining = Duration(seconds: totalSeconds);
    _events.add(message);
    notifyListeners();

    // UC12 – 4.1: tắt "tự chạy" thì chờ người dùng bấm Bắt đầu.
    if (_settings.autoStartNext && finished != TimerMode.custom) start();
  }

  /// Dừng phiên đang dở (nếu có): lưu phần đã tập trung, hủy thông báo.
  void _abandon() {
    if (_startedAt != null) {
      _persistIfFocus(_mode, durationSec: _elapsedSeconds(), completed: false);
    }
    _stopTicker();
    unawaited(notifications.cancelEnd());
    _startedAt = null;
    _endAt = null;
    _state = RunState.idle;
  }

  int _elapsedSeconds() =>
      ((totalSeconds * 1000 - remaining.inMilliseconds) / 1000).round();

  /// Chỉ ghi phiên tập trung (Pomodoro / tùy chỉnh); giờ nghỉ không ghi.
  void _persistIfFocus(
    TimerMode mode, {
    required int durationSec,
    required bool completed,
  }) {
    final startedAt = _startedAt;
    if (startedAt == null || durationSec <= 0) return;
    final type = switch (mode) {
      TimerMode.pomodoro => SessionType.pomodoro,
      TimerMode.custom => SessionType.custom,
      _ => null,
    };
    if (type == null) return;
    repository
        .insert(
          FocusSession(
            taskId: _task?.id,
            taskTitle: _task?.title,
            type: type,
            startedAt: startedAt,
            durationSec: durationSec,
            completed: completed,
          ),
        )
        .catchError((Object e) {
          debugPrint('Không lưu được FocusSession: $e');
          return 0;
        });
  }

  /// MSG07 + biến thể cho giờ nghỉ / tùy chỉnh.
  String _finishMessage() => switch (_mode) {
    TimerMode.pomodoro =>
      'Hết phiên tập trung! Nghỉ ${_cycleDone + 1 >= cycleLength ? _settings.longBreakMin : _settings.shortBreakMin} phút nhé.',
    TimerMode.shortBreak ||
    TimerMode.longBreak => 'Hết giờ nghỉ! Quay lại tập trung nào.',
    TimerMode.custom => 'Hết giờ!',
  };

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)
      _tick(); // cập nhật ngay khi quay lại app
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicker();
    _events.close();
    super.dispose();
  }
}
