import 'package:flutter/foundation.dart';

/// 5 tab của thanh dưới, theo đúng thứ tự hiển thị.
enum HomeTab { today, calendar, timer, stats, habits }

/// Tab đang mở của khung app. Màn nào cũng có thể chuyển tab bằng [select]
/// mà không cần biết khung được dựng thế nào (ví dụ nút đồng hồ trên một việc
/// ở Hôm nay mở tab Hẹn giờ).
class ShellController extends ChangeNotifier {
  ShellController([HomeTab initial = HomeTab.today]) : _tab = initial;

  HomeTab _tab;

  HomeTab get tab => _tab;

  void select(HomeTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }
}
