import 'package:flutter/foundation.dart';

import '../../app/shell_controller.dart';

/// Điều khiển tab Hẹn giờ. Hiện mới có phần chọn sẵn việc; đếm ngược, bấm giờ
/// và lưu phiên làm ở bước Hẹn giờ.
class TimerController extends ChangeNotifier {
  TimerController(this._shell);

  final ShellController _shell;

  String? _preparedTaskId;

  /// Việc được chọn sẵn cho phiên tiếp theo, null nếu không gắn việc.
  String? get preparedTaskId => _preparedTaskId;

  /// Chọn sẵn việc [taskId] rồi chuyển sang tab Hẹn giờ. Nút đồng hồ trên mỗi
  /// việc ở Hôm nay gọi hàm này.
  void prepare(String taskId) {
    _preparedTaskId = taskId;
    _shell.select(HomeTab.timer);
    notifyListeners();
  }

  /// Bỏ việc đã chọn sẵn (khi người dùng chọn "Không gắn việc" hoặc phiên đã
  /// bắt đầu).
  void clearPrepared() {
    if (_preparedTaskId == null) return;
    _preparedTaskId = null;
    notifyListeners();
  }
}
