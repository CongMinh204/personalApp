// Chữ hiển thị cho các giá trị cài đặt.

/// "Nhắc trước" theo số phút: 0 = đúng giờ, 60 = 1 giờ, 1440 = 1 ngày.
String reminderLabel(int minutes) => switch (minutes) {
  0 => 'Đúng giờ',
  1440 => '1 ngày',
  60 => '1 giờ',
  _ => '$minutes phút',
};

String minutesLabel(int minutes) => '$minutes phút';

/// Số phút từ 00:00 thành "07:00".
String clockLabel(int minutesFromMidnight) {
  final h = minutesFromMidnight ~/ 60;
  final m = minutesFromMidnight % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String weekStartLabel(int weekStart) => weekStart == 7 ? 'Chủ Nhật' : 'Thứ Hai';
