import 'dart:async';

/// Báo cho các stream `watch...` đọc lại sau mỗi lần ghi, vì sqflite không tự
/// báo thay đổi.
///
/// Dùng một tín hiệu chung cho mọi bảng: ghi một bảng có thể đổi kết quả của
/// bảng khác (xóa việc thì việc con và phiên tập trung đổi theo, xóa nhãn thì
/// việc đổi theo). Dữ liệu cá nhân nhỏ nên đọc lại thừa không đáng kể, đổi lại
/// không thể sót trường hợp gián tiếp.
class DbChanges {
  final _controller = StreamController<void>.broadcast(sync: true);

  /// Gọi sau khi một lần ghi đã hoàn tất (ngoài transaction).
  void notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  Future<void> close() => _controller.close();

  /// Stream phát kết quả của [read] ngay khi được lắng nghe, rồi phát lại sau
  /// mỗi lần ghi. Các lần đọc chạy lần lượt, kết quả không bị đảo thứ tự: nếu
  /// có ghi khi đang đọc thì đọc lại thêm một lần sau đó.
  Stream<T> watch<T>(Future<T> Function() read) {
    late final StreamController<T> controller;
    StreamSubscription<void>? subscription;
    var running = false;
    var dirty = false;
    var cancelled = false;

    Future<void> load() async {
      if (running) {
        dirty = true;
        return;
      }
      running = true;
      try {
        do {
          dirty = false;
          final value = await read();
          if (!cancelled) controller.add(value);
        } while (dirty && !cancelled);
      } catch (error, stack) {
        if (!cancelled) controller.addError(error, stack);
      } finally {
        running = false;
      }
    }

    controller = StreamController<T>(
      onListen: () {
        subscription = _controller.stream.listen((_) => load());
        load();
      },
      onCancel: () {
        cancelled = true;
        return subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
