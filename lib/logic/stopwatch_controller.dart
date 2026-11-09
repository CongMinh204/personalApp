import 'dart:async';

import 'package:flutter/foundation.dart';

typedef LapInfo = ({int number, Duration time, bool fastest, bool slowest});

/// Bấm giờ + ghi vòng (UC14). Tính theo mốc thời gian nên không trôi khi UI lag.
class StopwatchController extends ChangeNotifier {
  StopwatchController({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  Duration _accum = Duration.zero;
  DateTime? _startedAt;
  Timer? _ticker;
  Duration _lastLapMark = Duration.zero;
  final List<Duration> _laps = []; // thời gian từng vòng, cũ nhất trước

  bool get isRunning => _startedAt != null;

  Duration get elapsed =>
      _accum +
      (_startedAt == null ? Duration.zero : _now().difference(_startedAt!));

  /// Số vòng hiện tại (đang chạy dở).
  int get lapNumber => _laps.length + 1;

  /// Danh sách vòng, mới nhất trước; gắn nhãn Nhanh nhất / Chậm nhất khi có >= 2 vòng.
  List<LapInfo> get laps {
    if (_laps.isEmpty) return const [];
    final minT = _laps.reduce((a, b) => a < b ? a : b);
    final maxT = _laps.reduce((a, b) => a > b ? a : b);
    final multi = _laps.length > 1;
    final out = <LapInfo>[];
    for (var i = _laps.length - 1; i >= 0; i--) {
      final t = _laps[i];
      final fast = multi && t == minT;
      out.add((
        number: i + 1,
        time: t,
        fastest: fast,
        slowest: multi && t == maxT && !fast,
      ));
    }
    return out;
  }

  void toggle() => isRunning ? pause() : start();

  void start() {
    if (isRunning) return;
    _startedAt = _now();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => notifyListeners(),
    );
    notifyListeners();
  }

  void pause() {
    if (!isRunning) return;
    _accum = elapsed;
    _startedAt = null;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void lap() {
    if (!isRunning) return;
    final e = elapsed;
    _laps.add(e - _lastLapMark);
    _lastLapMark = e;
    notifyListeners();
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;
    _accum = Duration.zero;
    _lastLapMark = Duration.zero;
    _laps.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
