import '../../data/models/task.dart';
import '../../data/repositories/focus_repository.dart';
import '../../utils/vi_date.dart';
import '../settings/settings_labels.dart';

// Chữ hiển thị cho các trường của việc, dùng ở màn Chi tiết việc.

/// "Ưu tiên cao", "Ưu tiên trung bình", "Ưu tiên thấp".
String priorityLabel(Priority priority) =>
    'Ưu tiên ${priority.label.toLowerCase()}';

/// "Th 5, 29/10/2026" hoặc "Không có ngày".
String dueDateLabel(Task task) {
  final due = task.due;
  return due == null ? 'Không có ngày' : fullDate(due);
}

/// "19:30 → 21:00", "19:30" (chỉ giờ bắt đầu) hoặc "Cả ngày".
String dueTimeLabel(Task task) {
  final due = task.due;
  if (!task.hasTime || due == null) return 'Cả ngày';
  final end = task.end;
  return end == null
      ? hourMinute(due)
      : '${hourMinute(due)} → ${hourMinute(end)}';
}

/// "15 phút", "Đúng giờ" hoặc "Không nhắc".
String reminderValueLabel(Task task) {
  final minutes = task.reminderMinutes;
  return minutes == null ? 'Không nhắc' : reminderLabel(minutes);
}

/// "50 phút · 2 phiên", hoặc "Chưa tập trung" nếu chưa có phiên nào.
String focusTotalLabel(FocusTotal total) {
  if (total.sessions == 0) return 'Chưa tập trung';
  final minutes = (total.seconds / 60).round();
  final time = minutes == 0 ? 'dưới 1 phút' : '$minutes phút';
  return '$time · ${total.sessions} phiên';
}
