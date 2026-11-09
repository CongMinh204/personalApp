import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/settings_controller.dart';
import '../../data/ids.dart';
import '../../data/models/focus_session.dart';
import '../../data/repositories/focus_repository.dart';
import 'timer_mode.dart';

/// Đồng hồ đếm ngược và chu kỳ Pomodoro.
///
/// Thời gian còn lại được tính theo giờ hiện tại (`đã chạy = tổng các đoạn đã
/// chạy`), không cộng dồn từng nhịp, nên app chạy nền hay hệ điều hành làm
/// chậm nhịp thì số đếm vẫn đúng khi mở lại.
///
/// Lưu phiên vào `FocusRepository`:
/// - chạy hết giờ: lưu `completed = true`, thời lượng bằng thời lượng đặt;
/// - bị dừng giữa chừng (Đặt lại, Bỏ qua, đổi chế độ): lưu `completed = false`
///   với thời gian đã chạy thực tế (không tính lúc tạm dừng), nếu đã chạy từ
///   [minSavedSeconds] giây trở lên (dưới ngưỡng coi như bấm nhầm, không lưu);
/// - chưa bấm Chạy thì không lưu gì.
class CountdownController extends ChangeNotifier {
  CountdownController({
    required this.repository,
    required this.settings,
    DateTime Function()? clock,
    this.autoTick = true,
    this.tickEvery = const Duration(milliseconds: 250),
    String Function()? makeId,
  }) : _clock = clock ?? DateTime.now,
       _makeId = makeId ?? newId;

  /// Số phiên tập trung trong một chu kỳ Pomodoro trước khi nghỉ dài.
  static const cycleLength = 4;

  /// Phiên bỏ dở chạy ít hơn số giây này thì không lưu.
  static const minSavedSeconds = 10;

  /// Mặc định của chế độ Tùy chỉnh, và khoảng cho phép (phút).
  static const defaultCustomMinutes = 10;
  static const customMinutesRange = (1, 180);

  final FocusRepository repository;
  final SettingsController settings;
  final DateTime Function() _clock;
  final String Function() _makeId;

  /// `false` thì không tự chạy nhịp (test gọi [tick] bằng tay).
  final bool autoTick;
  final Duration tickEvery;

  final _finished = StreamController<TimerFinished>.broadcast();

  TimerMode _mode = TimerMode.pomodoro;
  RunState _state = RunState.idle;
  int _customMinutes = defaultCustomMinutes;
  int _completedInCycle = 0;

  String? _taskId;
  String? _taskTitle;

  // Phiên đang chạy hoặc tạm dừng.
  DateTime? _startedAt;
  int _targetSec = 0;
  int _elapsedBeforeMs = 0;
  DateTime? _segmentStart;
  // Việc của phiên đang chạy, chốt lúc bắt đầu.
  String? _sessionTaskId;

  Timer? _timer;
  Future<void> _lastSave = Future.value();

  /// Phiên vừa hết giờ (để màn hình báo bằng rung, âm thanh, hộp thoại).
  Stream<TimerFinished> get finished => _finished.stream;

  /// Chờ lưu xong các phiên đang lưu (dùng trong test).
  Future<void> get savesDone => _lastSave;

  TimerMode get mode => _mode;
  RunState get state => _state;
  bool get isIdle => _state == RunState.idle;
  bool get isRunning => _state == RunState.running;
  bool get isPaused => _state == RunState.paused;

  int get customMinutes => _customMinutes;

  /// Số phiên tập trung đã hoàn thành trong chu kỳ hiện tại (0–4).
  int get completedInCycle => _completedInCycle;

  /// "Phiên 2/4": số thứ tự của phiên Pomodoro đang hoặc sắp chạy.
  int get sessionNumber => (_completedInCycle % cycleLength) + 1;

  String? get taskId => _taskId;
  String? get taskTitle => _taskTitle;

  /// Thời lượng đặt cho chế độ [mode] theo Cài đặt (giây).
  int plannedSeconds(TimerMode mode) => switch (mode) {
    TimerMode.pomodoro => settings.pomodoroMinutes * 60,
    TimerMode.shortBreak => settings.shortBreakMinutes * 60,
    TimerMode.longBreak => settings.longBreakMinutes * 60,
    TimerMode.custom => _customMinutes * 60,
  };

  /// Tổng thời lượng của phiên hiện tại (đã chốt nếu đang chạy, còn không thì
  /// theo Cài đặt hiện tại).
  int get totalSeconds => isIdle ? plannedSeconds(_mode) : _targetSec;

  int get _elapsedMs {
    final segment = _segmentStart;
    final running = segment == null
        ? 0
        : _clock().difference(segment).inMilliseconds;
    return _elapsedBeforeMs + running;
  }

  /// Thời gian đã chạy của phiên hiện tại.
  Duration get elapsed => Duration(milliseconds: isIdle ? 0 : _elapsedMs);

  Duration get remaining {
    final left = totalSeconds * 1000 - (isIdle ? 0 : _elapsedMs);
    return Duration(milliseconds: left < 0 ? 0 : left);
  }

  /// Tỷ lệ đã chạy, 0–1.
  double get progress {
    final total = totalSeconds * 1000;
    if (isIdle || total <= 0) return 0;
    return (_elapsedMs / total).clamp(0.0, 1.0);
  }

  // ---- Chọn việc và chế độ -------------------------------------------------

  /// Chọn việc cho phiên kế tiếp. Chỉ đổi được khi đồng hồ đang đứng yên;
  /// trả về `false` nếu đang có phiên chạy hoặc tạm dừng.
  bool selectTask(String? id, String? title) {
    if (!isIdle) return false;
    _taskId = id;
    _taskTitle = id == null ? null : title;
    notifyListeners();
    return true;
  }

  /// Đổi chế độ. Đang có phiên thì phiên đó bị dừng giữa chừng (và được lưu
  /// nếu đã chạy đủ lâu).
  void setMode(TimerMode mode) {
    if (mode == _mode && isIdle) return;
    _abandonCurrent();
    _mode = mode;
    notifyListeners();
  }

  /// Đặt số phút cho chế độ Tùy chỉnh, trong [customMinutesRange].
  void setCustomMinutes(int minutes) {
    if (minutes < customMinutesRange.$1 || minutes > customMinutesRange.$2) {
      throw ArgumentError.value(
        minutes,
        'minutes',
        'Phải từ ${customMinutesRange.$1} đến ${customMinutesRange.$2} phút',
      );
    }
    if (minutes == _customMinutes) return;
    _customMinutes = minutes;
    notifyListeners();
  }

  // ---- Điều khiển ---------------------------------------------------------

  /// Chạy (từ đứng yên) hoặc chạy tiếp (từ tạm dừng).
  void start() {
    if (isRunning) return;
    final now = _clock();
    if (isIdle) {
      _startedAt = now;
      _targetSec = plannedSeconds(_mode);
      _elapsedBeforeMs = 0;
      // Chỉ phiên tập trung gắn với việc; giờ nghỉ không thuộc việc nào.
      _sessionTaskId = _mode.isFocus ? _taskId : null;
    }
    _segmentStart = now;
    _state = RunState.running;
    _startTicking();
    notifyListeners();
  }

  void pause() {
    if (!isRunning) return;
    _elapsedBeforeMs = _elapsedMs;
    _segmentStart = null;
    _state = RunState.paused;
    _stopTicking();
    notifyListeners();
  }

  /// Nút chính: chạy, tạm dừng hoặc chạy tiếp.
  void toggle() => isRunning ? pause() : start();

  /// Đặt lại phiên hiện tại về đầu. Phiên đã chạy được lưu là bỏ dở (nếu đủ
  /// lâu). Số phiên trong chu kỳ không đổi.
  void reset() {
    if (isIdle) return;
    _abandonCurrent();
    notifyListeners();
  }

  /// Bỏ qua phiên: phiên đang chạy được lưu là bỏ dở (nếu đủ lâu) rồi chuyển
  /// sang phiên kế tiếp, không tính là hoàn thành.
  void skip() {
    _abandonCurrent();
    _advance();
    notifyListeners();
  }

  /// Cập nhật theo giờ hiện tại và kết thúc phiên nếu đã hết giờ. Chạy tự
  /// động mỗi [tickEvery] khi [autoTick] bật.
  void tick() {
    if (isRunning && _elapsedMs >= _targetSec * 1000) {
      _complete();
    } else if (isRunning) {
      notifyListeners();
    }
  }

  // ---- Nội bộ -------------------------------------------------------------

  void _complete() {
    final finishedMode = _mode;
    final seconds = _targetSec;
    _save(completed: true, durationSec: seconds);

    if (finishedMode == TimerMode.pomodoro) _completedInCycle++;
    _resetSession();
    _advance();

    final auto = settings.autoNextSession && _mode != TimerMode.custom;
    _finished.add(
      TimerFinished(
        mode: finishedMode,
        durationSec: seconds,
        autoStarted: auto,
      ),
    );
    if (auto) {
      // Phiên kế tiếp bắt đầu từ lúc phát hiện hết giờ, không tính bù phần trễ.
      start();
    } else {
      notifyListeners();
    }
  }

  /// Dừng phiên đang có (nếu có), lưu là bỏ dở khi đủ lâu, về đứng yên.
  void _abandonCurrent() {
    if (isIdle) return;
    final seconds = _elapsedMs ~/ 1000;
    if (seconds >= minSavedSeconds) {
      _save(completed: false, durationSec: seconds);
    }
    _resetSession();
  }

  void _resetSession() {
    _stopTicking();
    _state = RunState.idle;
    _startedAt = null;
    _segmentStart = null;
    _elapsedBeforeMs = 0;
    _sessionTaskId = null;
  }

  /// Chuyển sang phiên kế tiếp của chu kỳ Pomodoro:
  /// tập trung → nghỉ ngắn (nghỉ dài sau phiên thứ 4) → tập trung.
  void _advance() {
    switch (_mode) {
      case TimerMode.pomodoro:
        _mode = _completedInCycle >= cycleLength
            ? TimerMode.longBreak
            : TimerMode.shortBreak;
      case TimerMode.shortBreak:
        _mode = TimerMode.pomodoro;
      case TimerMode.longBreak:
        _mode = TimerMode.pomodoro;
        _completedInCycle = 0;
      case TimerMode.custom:
        break; // Tùy chỉnh đứng ngoài chu kỳ.
    }
  }

  void _save({required bool completed, required int durationSec}) {
    final session = FocusSession(
      id: _makeId(),
      taskId: _sessionTaskId,
      type: _mode.type,
      startedAt: _startedAt!,
      durationSec: durationSec,
      completed: completed,
    );
    _lastSave = _lastSave.then((_) => _persist(session));
  }

  Future<void> _persist(FocusSession session) async {
    try {
      await repository.add(session);
    } on ArgumentError {
      // Việc đã bị xóa trong lúc đang đếm: lưu phiên ở trạng thái không gắn việc.
      await repository.add(session.copyWith(taskId: () => null));
    }
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
    _finished.close();
    super.dispose();
  }
}
