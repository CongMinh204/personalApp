import '../../data/models/focus_session.dart';

/// Chế độ của đồng hồ đếm ngược.
enum TimerMode {
  pomodoro('Pomodoro', FocusType.pomodoro, 'Tập trung'),
  shortBreak('Nghỉ ngắn', FocusType.shortBreak, 'Nghỉ ngắn · thư giãn mắt'),
  longBreak('Nghỉ dài', FocusType.longBreak, 'Nghỉ dài · đứng dậy đi lại'),
  custom('Tùy chỉnh', FocusType.custom, 'Hẹn giờ tùy chỉnh');

  const TimerMode(this.label, this.type, this.description);

  final String label;

  /// Loại phiên được lưu vào `FocusRepository` khi chạy ở chế độ này.
  final FocusType type;

  /// Dòng phụ dưới số đếm (riêng Pomodoro còn kèm "Phiên n/4").
  final String description;

  /// Phiên tập trung (Pomodoro, Tùy chỉnh), không phải giờ nghỉ.
  bool get isFocus => type.isFocus;
}

/// Trạng thái chạy của đồng hồ.
enum RunState { idle, running, paused }

/// Một phiên đếm ngược vừa chạy hết giờ.
class TimerFinished {
  const TimerFinished({
    required this.mode,
    required this.durationSec,
    required this.autoStarted,
  });

  final TimerMode mode;
  final int durationSec;

  /// Phiên kế tiếp đã tự chạy (bật "Tự chạy phiên tiếp theo" trong Cài đặt).
  final bool autoStarted;
}
