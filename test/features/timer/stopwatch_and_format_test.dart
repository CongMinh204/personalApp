import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/timer/stopwatch_controller.dart';
import 'package:personal_app/features/timer/timer_format.dart';
import 'package:personal_app/features/timer/timer_mode.dart';

import 'timer_test_helpers.dart';

void main() {
  group('formatMmSs', () {
    test('định dạng phút:giây', () {
      expect(formatMmSs(const Duration(minutes: 25)), '25:00');
      expect(formatMmSs(const Duration(minutes: 4, seconds: 7)), '04:07');
      expect(formatMmSs(Duration.zero), '00:00');
    });

    test('làm tròn lên giây: còn 0,2 giây vẫn hiện 00:01', () {
      expect(formatMmSs(const Duration(milliseconds: 200)), '00:01');
      expect(formatMmSs(const Duration(milliseconds: 59001)), '01:00');
      expect(formatMmSs(const Duration(milliseconds: 59000)), '00:59');
    });

    test('phút không bị chặn ở 59, thời gian âm thành 00:00', () {
      expect(formatMmSs(const Duration(minutes: 90)), '90:00');
      expect(formatMmSs(const Duration(seconds: -5)), '00:00');
    });
  });

  group('formatStopwatch', () {
    test('phút:giây.phần trăm giây, cắt bớt không làm tròn', () {
      expect(formatStopwatch(Duration.zero), '00:00.00');
      expect(
        formatStopwatch(
          const Duration(minutes: 12, seconds: 7, milliseconds: 489),
        ),
        '12:07.48',
      );
      expect(formatStopwatch(const Duration(milliseconds: 999)), '00:00.99');
    });
  });

  group('StopwatchController', () {
    late FakeClock clock;
    late StopwatchController sw;

    setUp(() {
      clock = FakeClock();
      sw = StopwatchController(clock: clock.call, autoTick: false);
    });

    tearDown(() => sw.dispose());

    test('ban đầu đứng yên ở 00:00, vòng 1', () {
      expect(sw.state, RunState.idle);
      expect(sw.elapsed, Duration.zero);
      expect(sw.lapNumber, 1);
      expect(sw.laps, isEmpty);
    });

    test('chạy, tạm dừng, chạy tiếp: tính đúng theo đồng hồ', () {
      sw.start();
      clock.seconds(5);
      expect(sw.elapsed, const Duration(seconds: 5));

      sw.pause();
      clock.seconds(30); // thời gian tạm dừng không tính
      expect(sw.elapsed, const Duration(seconds: 5));
      expect(sw.isPaused, isTrue);

      sw.start();
      clock.seconds(2);
      expect(sw.elapsed, const Duration(seconds: 7));
    });

    test('bấm Vòng chốt vòng hiện tại và bắt đầu vòng mới', () {
      sw.start();
      clock.seconds(10);
      sw.lap();
      clock.seconds(25);
      sw.lap();
      clock.seconds(4);

      expect(sw.laps, const [Duration(seconds: 10), Duration(seconds: 25)]);
      expect(sw.lapNumber, 3);
      expect(sw.currentLap, const Duration(seconds: 4));
      expect(sw.elapsed, const Duration(seconds: 39));
    });

    test('danh sách hiển thị vòng mới nhất trước', () {
      sw.start();
      clock.seconds(1);
      sw.lap();
      clock.seconds(2);
      sw.lap();

      expect(sw.lapsNewestFirst, const [
        Duration(seconds: 2),
        Duration(seconds: 1),
      ]);
    });

    test('Vòng chỉ có tác dụng khi đang chạy', () {
      sw.lap();
      expect(sw.laps, isEmpty);

      sw.start();
      clock.seconds(3);
      sw.pause();
      sw.lap();
      expect(sw.laps, isEmpty);
    });

    test('vòng nhanh nhất và chậm nhất chỉ có khi từ 2 vòng trở lên', () {
      sw.start();
      clock.seconds(20);
      sw.lap();
      expect(sw.fastest, isNull);
      expect(sw.slowest, isNull);

      clock.seconds(15);
      sw.lap();
      clock.seconds(30);
      sw.lap();

      expect(sw.fastest, const Duration(seconds: 15));
      expect(sw.slowest, const Duration(seconds: 30));
    });

    test('Đặt lại về 00:00 và xóa hết vòng', () {
      sw.start();
      clock.seconds(8);
      sw.lap();

      sw.reset();

      expect(sw.isIdle, isTrue);
      expect(sw.elapsed, Duration.zero);
      expect(sw.laps, isEmpty);
      expect(sw.lapNumber, 1);
      expect(sw.currentLap, Duration.zero);
    });

    test('Đặt lại rồi chạy lại bắt đầu từ 0', () {
      sw.start();
      clock.seconds(8);
      sw.reset();
      sw.start();
      clock.seconds(2);

      expect(sw.elapsed, const Duration(seconds: 2));
    });

    test('báo người nghe khi đổi', () {
      var calls = 0;
      sw.addListener(() => calls++);

      sw.start();
      clock.seconds(1);
      sw.lap();
      sw.pause();
      sw.reset();

      expect(calls, 4);
    });
  });
}
