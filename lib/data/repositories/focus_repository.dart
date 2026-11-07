import 'package:flutter/material.dart' show DateTimeRange;

import '../models/focus_session.dart';

/// Lưu và đọc phiên hẹn giờ. Xem docs/DATA_CONTRACT.md, mục 4.
abstract interface class FocusRepository {
  /// Lưu một phiên khi hết giờ hoặc bị dừng. `taskId` phải là việc đang có
  /// hoặc null.
  Future<void> add(FocusSession session);

  /// Phiên có `startedAt` trong [range], mới nhất trước.
  Future<List<FocusSession>> sessionsByRange(DateTimeRange range);

  Stream<List<FocusSession>> watchByRange(DateTimeRange range);

  /// Tổng thời gian và số phiên tập trung (`type.isFocus`, kể cả bỏ dở) của
  /// một việc.
  Future<FocusTotal> totalForTask(String taskId);

  Future<void> delete(String id);
}

/// Kết quả của [FocusRepository.totalForTask].
class FocusTotal {
  const FocusTotal({required this.seconds, required this.sessions});

  final int seconds;
  final int sessions;
}
