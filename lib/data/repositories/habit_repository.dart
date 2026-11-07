import 'package:flutter/material.dart' show DateTimeRange;

import '../models/habit.dart';
import '../models/habit_log.dart';

/// Lưu và đọc thói quen cùng nhật ký. Xem docs/DATA_CONTRACT.md, mục 4.
abstract interface class HabitRepository {
  /// Thói quen đang dùng (chưa lưu trữ), theo thứ tự tạo.
  Stream<List<Habit>> watchActive();

  /// Thói quen đã lưu trữ, mới lưu trữ trước.
  Stream<List<Habit>> watchArchived();

  Future<Habit?> getById(String id);

  Stream<Habit?> watchById(String id);

  /// Tên trống, `goalPerDay` < 1, `repeatDays` rỗng hoặc ngoài 1–7 →
  /// ArgumentError.
  Future<void> add(Habit habit);

  /// Kiểm tra như [add]. Không đổi `archivedAt` (dùng [setArchived]).
  Future<void> update(Habit habit);

  /// Lưu trữ (`archivedAt` = bây giờ) hoặc khôi phục (`archivedAt` = null).
  Future<void> setArchived(String id, bool archived);

  /// Xóa hẳn thói quen cùng toàn bộ nhật ký.
  Future<void> delete(String id);

  /// Số lần đã làm trong ngày [day] của từng thói quen: habitId → số lần
  /// (không có trong map = 0).
  Stream<Map<String, int>> watchCountsOn(DateTime day);

  /// Nhật ký của một thói quen trong [range], theo ngày tăng dần.
  Future<List<HabitLog>> logsByRange(String habitId, DateTimeRange range);

  /// Đặt số lần của ngày [day]; [count] ≥ 0, 0 = xóa nhật ký ngày đó.
  Future<void> setCount(String habitId, DateTime day, int count);

  /// Tăng 1 lần cho ngày [day], trả về số lần mới.
  Future<int> increment(String habitId, DateTime day);

  /// Chuỗi ngày hiện tại tính đến [today] (mặc định hôm nay). Quy tắc:
  /// docs/DATA_CONTRACT.md, mục 5.
  Future<int> streakOf(String habitId, {DateTime? today});

  /// Chuỗi ngày dài nhất tính đến hôm nay.
  Future<int> bestStreakOf(String habitId);
}
