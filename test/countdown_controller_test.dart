import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/focus_session_repository.dart';
import 'package:personal_app/logic/countdown_controller.dart';
import 'package:personal_app/logic/stopwatch_controller.dart';
import 'package:personal_app/models/focus_session.dart';
import 'package:personal_app/services/timer_notification_service.dart';

class _FakeNotifier implements TimerNotifier {
  final scheduled = <(DateTime, String)>[];
  int cancels = 0;

  @override
  Future<void> ensurePermissions() async {}

  @override
  Future<void> scheduleEnd({
    required DateTime at,
    required String title,
    required String body,
  }) async => scheduled.add((at, body));

  @override
  Future<void> cancelEnd() async => cancels++;
}

void main() {
  late DateTime clock;
  late InMemoryFocusSessionRepository repo;
  late _FakeNotifier notifier;
  late CountdownController c;

  setUp(() {
    clock = DateTime(2026, 10, 29, 9, 0);
    repo = InMemoryFocusSessionRepository();
    notifier = _FakeNotifier();
  });

  CountdownController make() {
    c = CountdownController(
      repository: repo,
      notifications: notifier,
      now: () => clock,
    );
    return c;
  }

  /// Tua đồng hồ giả rồi cho Timer.periodic của controller chạy một nhịp.
  Future<void> advance(WidgetTester tester, Duration d) async {
    clock = clock.add(d);
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('mặc định Pomodoro 25 phút, bắt đầu thì đặt thông báo MSG07', (
    tester,
  ) async {
    make();
    expect(c.mode, TimerMode.pomodoro);
    expect(c.remaining, const Duration(minutes: 25));

    c.start();
    expect(c.state, RunState.running);
    expect(
      notifier.scheduled.single.$1,
      clock.add(const Duration(minutes: 25)),
    );
    expect(
      notifier.scheduled.single.$2,
      'Hết phiên tập trung! Nghỉ 5 phút nhé.',
    );
    c.dispose();
  });

  testWidgets('hết giờ: lưu phiên hoàn thành, chuyển sang nghỉ ngắn', (
    tester,
  ) async {
    make();
    c.selectTask(const TaskRef('pe-flutter', 'Ôn tập PE Flutter'));
    final messages = <String>[];
    c.events.listen(messages.add);

    c.start();
    await advance(tester, const Duration(minutes: 25));

    expect(c.state, RunState.idle);
    expect(c.mode, TimerMode.shortBreak);
    expect(c.cycleDone, 1);
    expect(c.remaining, const Duration(minutes: 5));
    expect(messages, ['Hết phiên tập trung! Nghỉ 5 phút nhé.']);

    final s = repo.items.single;
    expect(s.completed, isTrue);
    expect(s.type, SessionType.pomodoro);
    expect(s.durationSec, 25 * 60);
    expect(s.taskId, 'pe-flutter');
    expect(s.taskTitle, 'Ôn tập PE Flutter');
    c.dispose();
  });

  testWidgets(
    'sau 4 phiên Pomodoro là nghỉ dài, xong nghỉ dài thì reset chu kỳ',
    (tester) async {
      make();
      for (var i = 0; i < 4; i++) {
        expect(c.mode, TimerMode.pomodoro);
        c.start();
        await advance(tester, const Duration(minutes: 25));
        if (i < 3) {
          expect(c.mode, TimerMode.shortBreak);
          c.start();
          await advance(tester, const Duration(minutes: 5));
        }
      }
      expect(c.mode, TimerMode.longBreak);
      expect(c.cycleDone, 4);
      expect(c.remaining, const Duration(minutes: 15));

      c.start();
      await advance(tester, const Duration(minutes: 15));
      expect(c.mode, TimerMode.pomodoro);
      expect(c.cycleDone, 0);
      expect(
        repo.items.where((s) => s.completed),
        hasLength(4),
      ); // nghỉ không ghi
      c.dispose();
    },
  );

  testWidgets('tạm dừng giữ nguyên thời gian còn lại và hủy thông báo', (
    tester,
  ) async {
    make();
    c.start();
    await advance(tester, const Duration(minutes: 10));
    c.pause();

    expect(c.state, RunState.paused);
    expect(c.remaining, const Duration(minutes: 15));
    expect(notifier.cancels, 1);

    clock = clock.add(
      const Duration(minutes: 30),
    ); // thời gian trôi lúc đang dừng
    expect(c.remaining, const Duration(minutes: 15));

    c.start(); // tiếp tục → đặt lại thông báo theo phần còn lại
    expect(notifier.scheduled.last.$1, clock.add(const Duration(minutes: 15)));
    c.dispose();
  });

  testWidgets('đặt lại giữa chừng: lưu phiên bỏ dở, không tính hoàn thành', (
    tester,
  ) async {
    make();
    c.start();
    await advance(tester, const Duration(minutes: 12));
    c.reset();

    expect(c.state, RunState.idle);
    expect(c.remaining, const Duration(minutes: 25));
    final s = repo.items.single;
    expect(s.completed, isFalse);
    expect(s.durationSec, 12 * 60);
    c.dispose();
  });

  testWidgets(
    'bỏ qua phiên: không tính, sang nghỉ ngắn, cycleDone không tăng',
    (tester) async {
      make();
      c.start();
      await advance(tester, const Duration(minutes: 3));
      c.skip();

      expect(c.mode, TimerMode.shortBreak);
      expect(c.cycleDone, 0);
      expect(repo.items.single.completed, isFalse);
      c.dispose();
    },
  );

  testWidgets('tự chạy phiên tiếp theo khi bật trong cài đặt', (tester) async {
    make();
    c.updateSettings(const TimerSettings(autoStartNext: true));
    c.start();
    await advance(tester, const Duration(minutes: 25));

    expect(c.mode, TimerMode.shortBreak);
    expect(c.state, RunState.running);
    c.dispose();
  });

  testWidgets('đếm ngược tùy chỉnh theo số phút người dùng đặt', (
    tester,
  ) async {
    make();
    c.setMode(TimerMode.custom);
    c.setCustomMinutes(7);
    expect(c.remaining, const Duration(minutes: 7));

    c.start();
    await advance(tester, const Duration(minutes: 7));
    expect(c.mode, TimerMode.custom);
    expect(repo.items.single.type, SessionType.custom);
    c.dispose();
  });

  test('bấm giờ: ghi vòng, gắn nhãn nhanh nhất / chậm nhất', () {
    var clock = DateTime(2026, 10, 29, 9, 0);
    final sw = StopwatchController(now: () => clock);

    sw.start();
    clock = clock.add(const Duration(seconds: 30));
    sw.lap(); // vòng 1: 30s
    clock = clock.add(const Duration(seconds: 20));
    sw.lap(); // vòng 2: 20s
    clock = clock.add(const Duration(seconds: 40));
    sw.lap(); // vòng 3: 40s

    expect(sw.lapNumber, 4);
    final laps = sw.laps; // mới nhất trước
    expect(laps.map((l) => l.number), [3, 2, 1]);
    expect(laps.firstWhere((l) => l.fastest).number, 2);
    expect(laps.firstWhere((l) => l.slowest).number, 3);

    sw.pause();
    expect(sw.elapsed, const Duration(seconds: 90));
    sw.dispose();
  });
}
