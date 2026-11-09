String _two(int n) => n.toString().padLeft(2, '0');

/// "25:00", "04:07". Làm tròn lên giây (còn 0,2 giây vẫn hiện 00:01) để số
/// đếm không về 00:00 trước khi hết giờ thật. Phút không bị chặn ở 59.
String formatMmSs(Duration d) {
  final ms = d.inMilliseconds < 0 ? 0 : d.inMilliseconds;
  final total = (ms / 1000).ceil();
  return '${_two(total ~/ 60)}:${_two(total % 60)}';
}

/// "12:07.48" (phút:giây.phần trăm giây) cho đồng hồ bấm giờ. Cắt bớt, không
/// làm tròn.
String formatStopwatch(Duration d) {
  final ms = d.inMilliseconds < 0 ? 0 : d.inMilliseconds;
  final centis = (ms ~/ 10) % 100;
  final totalSeconds = ms ~/ 1000;
  return '${_two(totalSeconds ~/ 60)}:${_two(totalSeconds % 60)}.${_two(centis)}';
}
