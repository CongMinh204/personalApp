import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/models/focus_session.dart';
import 'package:personal_app/features/timer/countdown_controller.dart';
import 'package:personal_app/features/timer/timer_mode.dart';

import 'timer_test_helpers.dart';

void main() {
  late CountdownEnv env;
  late CountdownController cd;

  setUp(() async {
    env = await CountdownEnv.create();
    cd = env.countdown;
  });

  tearDown(() => env.dispose());

  /// Chạy hết phiên hiện tại (bắt đầu nếu cần, tiến đồng hồ giả tới giờ kết
  /// thúc, rồi tick).
  void finishCurrent() {
    if (cd.isIdle) cd.start();
    env.clock.advance(cd.remaining);
    cd.tick();
  }

  group('trạng thái ban đầu', () {
    test('đứng yên ở Pomodoro, thời lượng lấy từ Cài đặt', () {
      expect(cd.state, RunState.idle);
      expect(cd.mode, TimerMode.pomodoro);
      expect(cd.totalSeconds, 25 * 60);
      expect(cd.remaining, const Duration(minutes: 25));
      expect(cd.progress, 0);
      expect(cd.sessionNumber, 1);
      expect(cd.completedInCycle, 0);
      expect(cd.taskId, isNull);
    });

    test('thời lượng các chế độ theo Cài đặt', () {
      expect(cd.plannedSeconds(TimerMode.pomodoro), 25 * 60);
      expect(cd.plannedSeconds(TimerMode.shortBreak), 5 * 60);
      expect(cd.plannedSeconds(TimerMode.longBreak), 15 * 60);
      expect(cd.plannedSeconds(TimerMode.custom), 10 * 60);
    });

    test('đổi Cài đặt khi đang đứng yên thì áp dụng ngay', () async {
      await env.settings.setPomodoroMinutes(50);
      expect(cd.totalSeconds, 50 * 60);
    });

    test(
      'phiên đang chạy giữ nguyên thời lượng đã chốt khi Cài đặt đổi',
      () async {
        cd.start();
        await env.settings.setPomodoroMinutes(50);
        expect(cd.totalSeconds, 25 * 60);
      },
    );
  });

  group('chạy, tạm dừng, chạy tiếp', () {
    test('thời gian còn lại giảm theo đồng hồ', () {
      cd.start();
      env.clock.minutes(1);
      cd.tick();

      expect(cd.isRunning, isTrue);
      expect(cd.remaining, const Duration(minutes: 24));
      expect(cd.progress, closeTo(1 / 25, 1e-9));
    });

    test('đúng cả khi không có nhịp nào (app chạy nền)', () {
      cd.start();
      env.clock.minutes(10); // không gọi tick

      expect(cd.remaining, const Duration(minutes: 15));
    });

    test('tạm dừng thì thời gian đứng yên, chạy tiếp thì đếm tiếp', () {
      cd.start();
      env.clock.minutes(5);
      cd.pause();
      expect(cd.isPaused, isTrue);

      env.clock.minutes(20); // thời gian tạm dừng không tính
      expect(cd.remaining, const Duration(minutes: 20));

      cd.start();
      env.clock.minutes(2);
      expect(cd.remaining, const Duration(minutes: 18));
    });

    test('toggle: chạy, tạm dừng, chạy tiếp', () {
      cd.toggle();
      expect(cd.isRunning, isTrue);
      cd.toggle();
      expect(cd.isPaused, isTrue);
      cd.toggle();
      expect(cd.isRunning, isTrue);
    });

    test('start khi đang chạy và pause khi đứng yên không làm gì', () {
      cd.pause();
      expect(cd.isIdle, isTrue);

      cd.start();
      env.clock.minutes(1);
      cd.start();
      expect(cd.remaining, const Duration(minutes: 24));
    });

    test('báo người nghe khi đổi trạng thái', () {
      var calls = 0;
      cd.addListener(() => calls++);

      cd.start();
      cd.pause();
      cd.start();

      expect(calls, 3);
    });
  });

  group('hết giờ', () {
    test(
      'tick trước giờ kết thúc không hoàn thành, đúng giờ thì hoàn thành',
      () async {
        cd.start();
        env.clock.advance(const Duration(minutes: 24, seconds: 59));
        cd.tick();
        expect(cd.isRunning, isTrue);
        expect(await env.saved(), isEmpty);

        env.clock.seconds(1);
        cd.tick();
        expect(cd.isIdle, isTrue);
        expect(await env.saved(), hasLength(1));
      },
    );

    test('lưu phiên hoàn thành đúng thời lượng, giờ bắt đầu và việc', () async {
      await env.addTask('a', title: 'Ôn tập');
      cd.selectTask('a', 'Ôn tập');
      final startedAt = env.clock.now;

      finishCurrent();

      final session = (await env.saved()).single;
      expect(session.type, FocusType.pomodoro);
      expect(session.completed, isTrue);
      expect(session.durationSec, 25 * 60);
      expect(session.startedAt, startedAt);
      expect(session.taskId, 'a');
    });

    test('tick trễ (app ở nền lâu) vẫn lưu đúng thời lượng đã đặt', () async {
      cd.start();
      env.clock.minutes(40);
      cd.tick();

      final session = (await env.saved()).single;
      expect(session.durationSec, 25 * 60);
      expect(session.completed, isTrue);
    });

    test('phát sự kiện hết giờ', () async {
      final events = <TimerFinished>[];
      cd.finished.listen(events.add);

      finishCurrent();
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(events.single.mode, TimerMode.pomodoro);
      expect(events.single.durationSec, 25 * 60);
      expect(events.single.autoStarted, isFalse);
    });

    test('hoàn thành xong thì không lưu lần nữa khi tick tiếp', () async {
      finishCurrent();
      cd.tick();
      cd.tick();

      expect(await env.saved(), hasLength(1));
    });
  });

  group('chu kỳ Pomodoro', () {
    test('tập trung → nghỉ ngắn → tập trung, đếm số phiên', () {
      finishCurrent(); // phiên 1
      expect(cd.mode, TimerMode.shortBreak);
      expect(cd.completedInCycle, 1);

      finishCurrent(); // nghỉ ngắn
      expect(cd.mode, TimerMode.pomodoro);
      expect(cd.sessionNumber, 2);
      expect(cd.completedInCycle, 1);
    });

    test('sau phiên thứ 4 là nghỉ dài, rồi chu kỳ bắt đầu lại', () {
      for (var i = 1; i <= 3; i++) {
        finishCurrent(); // phiên tập trung i
        expect(cd.mode, TimerMode.shortBreak, reason: 'sau phiên $i');
        finishCurrent(); // nghỉ ngắn
        expect(cd.mode, TimerMode.pomodoro);
      }
      finishCurrent(); // phiên 4
      expect(cd.mode, TimerMode.longBreak);
      expect(cd.completedInCycle, CountdownController.cycleLength);

      finishCurrent(); // nghỉ dài
      expect(cd.mode, TimerMode.pomodoro);
      expect(cd.completedInCycle, 0);
      expect(cd.sessionNumber, 1);
    });

    test('mỗi chế độ đếm đúng thời lượng của nó', () async {
      await env.settings.setShortBreakMinutes(7);
      finishCurrent();
      expect(cd.mode, TimerMode.shortBreak);
      expect(cd.totalSeconds, 7 * 60);
    });

    test('Tùy chỉnh đứng ngoài chu kỳ: xong vẫn ở Tùy chỉnh', () {
      cd.setMode(TimerMode.custom);
      finishCurrent();

      expect(cd.mode, TimerMode.custom);
      expect(cd.completedInCycle, 0);
    });
  });

  group('tự chạy phiên tiếp theo', () {
    test('bật thì phiên kế tiếp tự chạy và sự kiện ghi rõ', () async {
      await env.settings.setAutoNextSession(true);
      final events = <TimerFinished>[];
      cd.finished.listen(events.add);

      finishCurrent();
      await pumpEventQueue();

      expect(cd.mode, TimerMode.shortBreak);
      expect(cd.isRunning, isTrue);
      expect(events.single.autoStarted, isTrue);
      expect(cd.remaining, const Duration(minutes: 5));
    });

    test('tắt thì phiên kế tiếp đứng yên chờ bấm', () {
      finishCurrent();
      expect(cd.mode, TimerMode.shortBreak);
      expect(cd.isIdle, isTrue);
    });

    test('Tùy chỉnh không tự chạy tiếp dù đã bật', () async {
      await env.settings.setAutoNextSession(true);
      cd.setMode(TimerMode.custom);

      finishCurrent();

      expect(cd.isIdle, isTrue);
    });
  });

  group('phiên bỏ dở', () {
    test(
      'Đặt lại: lưu thời gian chạy thực tế, không tính lúc tạm dừng',
      () async {
        cd.start();
        env.clock.minutes(5);
        cd.pause();
        env.clock.minutes(20); // tạm dừng
        cd.start();
        env.clock.minutes(7);

        cd.reset();

        final session = (await env.saved()).single;
        expect(session.completed, isFalse);
        expect(session.durationSec, 12 * 60);
        expect(cd.isIdle, isTrue);
      },
    );

    test('Đặt lại khi đang tạm dừng cũng lưu', () async {
      cd.start();
      env.clock.minutes(3);
      cd.pause();

      cd.reset();

      expect((await env.saved()).single.durationSec, 3 * 60);
    });

    test('chạy dưới 10 giây rồi dừng thì không lưu', () async {
      cd.start();
      env.clock.seconds(9);

      cd.reset();

      expect(await env.saved(), isEmpty);
    });

    test('chạy đúng 10 giây thì lưu', () async {
      cd.start();
      env.clock.seconds(CountdownController.minSavedSeconds);

      cd.reset();

      expect((await env.saved()).single.durationSec, 10);
    });

    test('Đặt lại khi chưa chạy thì không lưu gì', () async {
      cd.reset();
      expect(await env.saved(), isEmpty);
    });

    test('Đặt lại giữ nguyên chế độ và số phiên của chu kỳ', () {
      finishCurrent(); // phiên 1 xong, đang ở nghỉ ngắn
      finishCurrent(); // nghỉ ngắn xong, về Pomodoro phiên 2
      cd.start();
      env.clock.minutes(3);

      cd.reset();

      expect(cd.mode, TimerMode.pomodoro);
      expect(cd.sessionNumber, 2);
      expect(cd.remaining, const Duration(minutes: 25));
    });

    test('Bỏ qua khi đang chạy: lưu bỏ dở rồi sang phiên kế, không tính hoàn thành', () async {
      cd.start();
      env.clock.minutes(4);

      cd.skip();

      final session = (await env.saved()).single;
      expect(session.completed, isFalse);
      expect(session.durationSec, 4 * 60);
      expect(cd.mode, TimerMode.shortBreak);
      expect(cd.completedInCycle, 0);
      expect(cd.isIdle, isTrue);
    });

    test('Bỏ qua khi đứng yên: chỉ chuyển phiên, không lưu', () async {
      cd.skip();

      expect(cd.mode, TimerMode.shortBreak);
      expect(await env.saved(), isEmpty);
    });

    test('Bỏ qua nghỉ dài thì về Pomodoro và bắt đầu chu kỳ mới', () {
      for (var i = 0; i < 3; i++) {
        finishCurrent();
        finishCurrent();
      }
      finishCurrent(); // phiên 4 -> nghỉ dài
      expect(cd.mode, TimerMode.longBreak);

      cd.skip();

      expect(cd.mode, TimerMode.pomodoro);
      expect(cd.completedInCycle, 0);
    });

    test('đổi chế độ khi đang chạy thì lưu phiên đang chạy là bỏ dở', () async {
      cd.start();
      env.clock.minutes(6);

      cd.setMode(TimerMode.shortBreak);

      final session = (await env.saved()).single;
      expect(session.type, FocusType.pomodoro);
      expect(session.completed, isFalse);
      expect(session.durationSec, 6 * 60);
      expect(cd.mode, TimerMode.shortBreak);
      expect(cd.isIdle, isTrue);
    });

    test('đổi chế độ khi đứng yên chỉ đổi chế độ', () async {
      cd.setMode(TimerMode.longBreak);

      expect(cd.mode, TimerMode.longBreak);
      expect(cd.totalSeconds, 15 * 60);
      expect(await env.saved(), isEmpty);
    });
  });

  group('việc đang tập trung', () {
    test('chọn việc khi đứng yên', () {
      expect(cd.selectTask('a', 'Ôn tập'), isTrue);
      expect(cd.taskId, 'a');
      expect(cd.taskTitle, 'Ôn tập');
    });

    test('không đổi được việc khi đang chạy hoặc tạm dừng', () {
      cd.selectTask('a', 'Việc A');
      cd.start();
      expect(cd.selectTask('b', 'Việc B'), isFalse);
      expect(cd.taskId, 'a');

      cd.pause();
      expect(cd.selectTask('b', 'Việc B'), isFalse);
      expect(cd.taskId, 'a');
    });

    test('chọn "không gắn việc" thì bỏ tên việc', () {
      cd.selectTask('a', 'Việc A');
      cd.selectTask(null, 'bỏ qua');

      expect(cd.taskId, isNull);
      expect(cd.taskTitle, isNull);
    });

    test('giờ nghỉ không gắn với việc nào', () async {
      await env.addTask('a');
      cd.selectTask('a', 'Việc');
      cd.setMode(TimerMode.shortBreak);

      finishCurrent();

      final session = (await env.saved()).single;
      expect(session.type, FocusType.shortBreak);
      expect(session.taskId, isNull);
    });

    test(
      'việc bị xóa trong lúc đếm thì vẫn lưu phiên, không gắn việc',
      () async {
        await env.addTask('a');
        cd.selectTask('a', 'Việc');
        cd.start();
        await env.tasks.delete('a');

        finishCurrent();

        final session = (await env.saved()).single;
        expect(session.taskId, isNull);
        expect(session.completed, isTrue);
      },
    );

    test('thời gian tập trung của việc chỉ tính phiên tập trung', () async {
      await env.addTask('a');
      cd.selectTask('a', 'Việc');
      finishCurrent(); // tập trung 25 phút
      finishCurrent(); // nghỉ ngắn 5 phút
      cd.start();
      env.clock.minutes(10);
      cd.reset(); // bỏ dở 10 phút

      await cd.savesDone;
      final total = await env.focus.totalForTask('a');
      expect(total.seconds, (25 + 10) * 60);
      expect(total.sessions, 2);
    });
  });

  group('Tùy chỉnh', () {
    test('mặc định 10 phút, đổi được trong 1–180 phút', () {
      expect(cd.customMinutes, 10);
      cd.setCustomMinutes(1);
      expect(cd.plannedSeconds(TimerMode.custom), 60);
      cd.setCustomMinutes(180);
      expect(cd.customMinutes, 180);
    });

    test('số phút ngoài khoảng bị từ chối', () {
      expect(() => cd.setCustomMinutes(0), throwsArgumentError);
      expect(() => cd.setCustomMinutes(181), throwsArgumentError);
      expect(cd.customMinutes, 10);
    });

    test('lưu phiên với loại Tùy chỉnh', () async {
      cd.setCustomMinutes(1);
      cd.setMode(TimerMode.custom);

      finishCurrent();

      final session = (await env.saved()).single;
      expect(session.type, FocusType.custom);
      expect(session.durationSec, 60);
    });
  });
}
