import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/app/shell_controller.dart';
import 'package:personal_app/data/models/focus_session.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/features/timer/timer_mode.dart';
import 'package:personal_app/features/timer/timer_screen.dart';

import '../tasks/tasks_test_env.dart';

void main() {
  late TasksEnv env;

  Future<void> pumpTimer(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    env = await TasksEnv.create(prefs: prefs);
    await env.tasks.add(
      Task(
        id: 'a',
        title: 'Ôn tập PE Flutter',
        createdAt: DateTime(2026, 10, 1),
      ),
    );
    await env.tasks.add(
      Task(id: 'b', title: 'Họp nhóm', createdAt: DateTime(2026, 10, 2)),
    );
    await env.tasks.add(
      Task(
        id: 'c',
        title: 'Việc đã xong',
        done: true,
        createdAt: DateTime(2026, 10, 3),
      ),
    );
    await env.pump(
      tester,
      const Scaffold(body: TimerScreen()),
      size: const Size(1170, 3000),
    );
  }

  /// Tiến đồng hồ giả rồi cho đồng hồ cập nhật và giao diện vẽ lại.
  Future<void> advance(WidgetTester tester, Duration d) async {
    env.clock.advance(d);
    env.countdown.tick();
    env.stopwatch.tick();
    await tester.pumpAndSettle();
  }

  Finder mode(String label) => find.widgetWithText(ChoiceChip, label);
  Finder play() => find.byTooltip('Bắt đầu');
  Finder pauseButton() => find.byTooltip('Tạm dừng');

  Future<List<FocusSession>> savedSessions() async {
    await env.countdown.savesDone;
    return env.focus.sessionsByRange(
      DateTimeRange(start: DateTime(2000), end: DateTime(2100)),
    );
  }

  group('hiển thị ban đầu', () {
    testWidgets('tiêu đề, hai tab, bốn chế độ và đồng hồ 25:00', (
      tester,
    ) async {
      await pumpTimer(tester);

      expect(find.text('Hẹn giờ'), findsOneWidget);
      expect(find.text('Đếm ngược'), findsOneWidget);
      expect(find.text('Bấm giờ'), findsOneWidget);
      for (final label in ['Pomodoro', 'Nghỉ ngắn', 'Nghỉ dài', 'Tùy chỉnh']) {
        expect(mode(label), findsOneWidget, reason: label);
      }
      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('Phiên 1/4 · Tập trung'), findsOneWidget);
      expect(find.text('Đang tập trung cho'), findsOneWidget);
      expect(find.text('Không gắn việc'), findsOneWidget);
      expect(play(), findsOneWidget);
    });

    testWidgets('thời lượng lấy từ Cài đặt', (tester) async {
      await pumpTimer(tester, prefs: {'pomodoro_minutes': 50});

      expect(find.text('50:00'), findsOneWidget);
    });

    testWidgets('nút Lịch sử tập trung mở màn lịch sử', (tester) async {
      await pumpTimer(tester);

      await tester.tap(find.byTooltip('Lịch sử tập trung'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Lịch sử tập trung'), findsOneWidget);
    });
  });

  group('chế độ', () {
    testWidgets(
      'Nghỉ ngắn và Nghỉ dài đổi thời lượng và dòng phụ, ẩn thẻ việc',
      (tester) async {
        await pumpTimer(tester);

        await tester.tap(mode('Nghỉ ngắn'));
        await tester.pumpAndSettle();
        expect(find.text('05:00'), findsOneWidget);
        expect(find.text('Nghỉ ngắn · thư giãn mắt'), findsOneWidget);
        expect(find.text('Đang tập trung cho'), findsNothing);

        await tester.tap(mode('Nghỉ dài'));
        await tester.pumpAndSettle();
        expect(find.text('15:00'), findsOneWidget);
        expect(find.text('Nghỉ dài · đứng dậy đi lại'), findsOneWidget);
      },
    );

    testWidgets('Tùy chỉnh mở hộp chọn số phút, chọn 1 phút', (tester) async {
      await pumpTimer(tester);

      await tester.tap(mode('Tùy chỉnh'));
      await tester.pumpAndSettle();
      expect(find.text('Hẹn giờ tùy chỉnh'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '1 phút'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(find.text('01:00'), findsOneWidget);
      expect(env.countdown.customMinutes, 1);
    });

    testWidgets('Tùy chỉnh: số phút ngoài 1–180 bị từ chối', (tester) async {
      await pumpTimer(tester);
      await tester.tap(mode('Tùy chỉnh'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập số phút từ 1 đến 180'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '181');
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập số phút từ 1 đến 180'), findsOneWidget);
      expect(find.text('Hẹn giờ tùy chỉnh'), findsWidgets);
    });

    testWidgets('chạm vào số đếm ở chế độ Tùy chỉnh để đổi số phút', (
      tester,
    ) async {
      await pumpTimer(tester);
      await tester.tap(mode('Tùy chỉnh'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('10:00'), findsOneWidget);

      await tester.tap(find.text('10:00'));
      await tester.pumpAndSettle();

      expect(find.text('Hẹn giờ tùy chỉnh'), findsWidgets);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets(
      'đổi chế độ khi đang chạy phải xác nhận; Tiếp tục thì giữ phiên',
      (tester) async {
        await pumpTimer(tester);
        await tester.tap(play());
        await tester.pumpAndSettle();
        await advance(tester, const Duration(minutes: 3));

        await tester.tap(mode('Nghỉ ngắn'));
        await tester.pumpAndSettle();
        expect(find.text('Dừng phiên đang chạy?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Tiếp tục'));
        await tester.pumpAndSettle();

        expect(env.countdown.mode, TimerMode.pomodoro);
        expect(env.countdown.isRunning, isTrue);
        expect(await savedSessions(), isEmpty);
      },
    );

    testWidgets('xác nhận Dừng thì đổi chế độ và lưu phiên bỏ dở', (
      tester,
    ) async {
      await pumpTimer(tester);
      await tester.tap(play());
      await tester.pumpAndSettle();
      await advance(tester, const Duration(minutes: 3));

      await tester.tap(mode('Nghỉ ngắn'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Dừng'));
      await tester.pumpAndSettle();

      expect(env.countdown.mode, TimerMode.shortBreak);
      final sessions = await savedSessions();
      expect(sessions.single.completed, isFalse);
      expect(sessions.single.durationSec, 3 * 60);
    });
  });

  group('chạy và điều khiển', () {
    testWidgets('Bắt đầu rồi đếm ngược theo thời gian', (tester) async {
      await pumpTimer(tester);

      await tester.tap(play());
      await tester.pumpAndSettle();
      expect(pauseButton(), findsOneWidget);

      await advance(tester, const Duration(minutes: 1));
      expect(find.text('24:00'), findsOneWidget);
    });

    testWidgets('Tạm dừng thì số đứng yên, Tiếp tục thì đếm tiếp', (
      tester,
    ) async {
      await pumpTimer(tester);
      await tester.tap(play());
      await advance(tester, const Duration(minutes: 5));

      await tester.tap(pauseButton());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Tiếp tục'), findsOneWidget);
      await advance(tester, const Duration(minutes: 30));
      expect(find.text('20:00'), findsOneWidget);

      await tester.tap(find.byTooltip('Tiếp tục'));
      await advance(tester, const Duration(minutes: 2));
      expect(find.text('18:00'), findsOneWidget);
    });

    testWidgets('Đặt lại về đầu và lưu phiên bỏ dở', (tester) async {
      await pumpTimer(tester);
      await tester.tap(play());
      await advance(tester, const Duration(minutes: 4));

      await tester.tap(find.byTooltip('Đặt lại'));
      await tester.pumpAndSettle();

      expect(find.text('25:00'), findsOneWidget);
      expect(play(), findsOneWidget);
      final session = (await savedSessions()).single;
      expect((session.completed, session.durationSec), (false, 4 * 60));
    });

    testWidgets('Bỏ qua phiên chuyển sang nghỉ ngắn', (tester) async {
      await pumpTimer(tester);

      await tester.tap(find.byTooltip('Bỏ qua phiên'));
      await tester.pumpAndSettle();

      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('Nghỉ ngắn · thư giãn mắt'), findsOneWidget);
    });

    testWidgets('chấm chu kỳ có nhãn Phiên n/4', (tester) async {
      await pumpTimer(tester);

      bool hasLabel(String label) => find
          .byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == label,
          )
          .evaluate()
          .isNotEmpty;
      expect(hasLabel('Phiên 1/4'), isTrue);

      // Xong một phiên tập trung: số phiên đang chờ là 2/4.
      env.countdown.start();
      await advance(tester, const Duration(minutes: 25));
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      expect(hasLabel('Phiên 2/4'), isTrue);
    });
  });

  group('hết giờ', () {
    testWidgets('báo Hết giờ, lưu phiên hoàn thành và chuyển sang nghỉ ngắn', (
      tester,
    ) async {
      await pumpTimer(tester);
      await tester.tap(play());
      await advance(tester, const Duration(minutes: 25));

      expect(find.text('Hết giờ!'), findsOneWidget);
      expect(
        find.text('Phiên tập trung 25 phút đã hoàn thành.'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      expect(find.text('Hết giờ!'), findsNothing);
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('Nghỉ ngắn · thư giãn mắt'), findsOneWidget);

      final session = (await savedSessions()).single;
      expect(session.type, FocusType.pomodoro);
      expect((session.completed, session.durationSec), (true, 25 * 60));
    });

    testWidgets('hẹn giờ tùy chỉnh hết giờ', (tester) async {
      await pumpTimer(tester);
      env.countdown.setCustomMinutes(1);
      env.countdown.setMode(TimerMode.custom);
      await tester.pumpAndSettle();

      await tester.tap(play());
      await advance(tester, const Duration(minutes: 1));

      expect(find.text('Hẹn giờ 1 phút đã hết.'), findsOneWidget);
    });

    testWidgets('bật tự chạy: thông báo phiên kế tiếp đã tự chạy', (
      tester,
    ) async {
      await pumpTimer(tester, prefs: {'auto_next_session': true});
      await tester.tap(play());
      await advance(tester, const Duration(minutes: 25));

      expect(find.textContaining('Phiên kế tiếp đã tự chạy.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      expect(env.countdown.isRunning, isTrue);
      expect(env.countdown.mode, TimerMode.shortBreak);
    });
  });

  group('chọn việc', () {
    testWidgets(
      'liệt kê Không gắn việc và các việc chưa xong, bỏ việc đã xong',
      (tester) async {
        await pumpTimer(tester);

        await tester.tap(find.text('Không gắn việc'));
        await tester.pumpAndSettle();

        expect(find.text('Tập trung cho việc nào?'), findsOneWidget);
        expect(find.text('Ôn tập PE Flutter'), findsOneWidget);
        expect(find.text('Họp nhóm'), findsOneWidget);
        expect(find.text('Việc đã xong'), findsNothing);
      },
    );

    testWidgets(
      'chọn một việc thì thẻ hiện tên việc; chọn lại Không gắn việc',
      (tester) async {
        await pumpTimer(tester);

        await tester.tap(find.text('Không gắn việc'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Họp nhóm'));
        await tester.pumpAndSettle();
        expect(env.countdown.taskId, 'b');
        expect(find.text('Họp nhóm'), findsOneWidget);

        await tester.tap(find.text('Họp nhóm'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Không gắn việc'));
        await tester.pumpAndSettle();
        expect(env.countdown.taskId, isNull);
      },
    );

    testWidgets('phiên được lưu kèm việc đã chọn', (tester) async {
      await pumpTimer(tester);
      await tester.tap(find.text('Không gắn việc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ôn tập PE Flutter'));
      await tester.pumpAndSettle();

      await tester.tap(play());
      await advance(tester, const Duration(minutes: 25));
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();

      expect((await savedSessions()).single.taskId, 'a');
      final total = await env.focus.totalForTask('a');
      expect((total.seconds, total.sessions), (25 * 60, 1));
    });

    testWidgets('đang chạy thì không đổi được việc', (tester) async {
      await pumpTimer(tester);
      await tester.tap(play());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Không gắn việc'));
      await tester.pumpAndSettle();

      expect(find.text('Tập trung cho việc nào?'), findsNothing);
    });
  });

  group('mở từ nút đồng hồ của một việc', () {
    testWidgets('chọn sẵn việc và chuyển về chế độ tập trung', (tester) async {
      await pumpTimer(tester);
      env.countdown.setMode(TimerMode.shortBreak);
      await tester.pumpAndSettle();

      env.timer.prepare('a');
      await tester.pumpAndSettle();

      expect(env.countdown.taskId, 'a');
      expect(env.countdown.mode, TimerMode.pomodoro);
      expect(find.text('Ôn tập PE Flutter'), findsOneWidget);
      expect(env.timer.preparedTaskId, isNull);
      expect(env.shell.tab, HomeTab.timer);
    });

    testWidgets('đang có phiên chạy thì không đổi việc, có thông báo', (
      tester,
    ) async {
      await pumpTimer(tester);
      await tester.tap(play());
      await tester.pumpAndSettle();

      env.timer.prepare('b');
      await tester.pumpAndSettle();

      expect(env.countdown.taskId, isNull);
      expect(find.textContaining('Đang có phiên chạy'), findsOneWidget);
      expect(env.timer.preparedTaskId, isNull);
    });

    testWidgets('đang ở tab Bấm giờ thì quay về tab Đếm ngược', (tester) async {
      await pumpTimer(tester);
      await tester.tap(find.text('Bấm giờ'));
      await tester.pumpAndSettle();
      expect(find.text('00:00.00'), findsOneWidget);

      env.timer.prepare('a');
      await tester.pumpAndSettle();

      expect(find.text('Ôn tập PE Flutter'), findsOneWidget);
      expect(find.text('00:00.00'), findsNothing);
    });
  });

  group('Bấm giờ', () {
    Future<void> openStopwatch(WidgetTester tester) async {
      await pumpTimer(tester);
      await tester.tap(find.text('Bấm giờ'));
      await tester.pumpAndSettle();
    }

    testWidgets('ban đầu 00:00.00, Vòng 1, nút Vòng bị tắt', (tester) async {
      await openStopwatch(tester);

      expect(find.text('00:00.00'), findsOneWidget);
      expect(find.text('Vòng 1'), findsOneWidget);
      final lapButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Vòng'),
      );
      expect(lapButton.onPressed, isNull);
    });

    testWidgets('chạy, đếm theo thời gian, tạm dừng', (tester) async {
      await openStopwatch(tester);

      await tester.tap(play());
      await advance(tester, const Duration(seconds: 5, milliseconds: 230));
      expect(find.text('00:05.23'), findsOneWidget);

      await tester.tap(pauseButton());
      await tester.pumpAndSettle();
      await advance(tester, const Duration(seconds: 20));
      expect(find.text('00:05.23'), findsOneWidget);
    });

    testWidgets('bấm Vòng ghi vòng, nhãn Nhanh nhất và Chậm nhất', (
      tester,
    ) async {
      await openStopwatch(tester);
      await tester.tap(play());
      await advance(tester, const Duration(seconds: 20));
      await tester.tap(find.widgetWithText(FilledButton, 'Vòng'));
      await tester.pumpAndSettle();
      expect(find.text('Vòng 2'), findsOneWidget); // vòng đang chạy
      expect(find.text('Nhanh nhất'), findsNothing); // mới có một vòng

      await advance(tester, const Duration(seconds: 10));
      await tester.tap(find.widgetWithText(FilledButton, 'Vòng'));
      await advance(tester, const Duration(seconds: 15));
      await tester.tap(find.widgetWithText(FilledButton, 'Vòng'));
      await tester.pumpAndSettle();

      expect(find.text('00:20.00'), findsOneWidget);
      expect(find.text('00:10.00'), findsOneWidget);
      expect(find.text('00:15.00'), findsOneWidget);
      expect(find.text('Nhanh nhất'), findsOneWidget);
      expect(find.text('Chậm nhất'), findsOneWidget);
    });

    testWidgets('Đặt lại xóa số và các vòng', (tester) async {
      await openStopwatch(tester);
      await tester.tap(play());
      await advance(tester, const Duration(seconds: 9));
      await tester.tap(find.widgetWithText(FilledButton, 'Vòng'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Đặt lại'));
      await tester.pumpAndSettle();

      expect(find.text('00:00.00'), findsOneWidget);
      expect(find.text('Vòng 1'), findsOneWidget);
      expect(find.text('Nhanh nhất'), findsNothing);
    });

    testWidgets('đổi tab rồi quay lại, bấm giờ vẫn chạy tiếp', (tester) async {
      await openStopwatch(tester);
      await tester.tap(play());
      await advance(tester, const Duration(seconds: 3));

      await tester.tap(find.text('Đếm ngược'));
      await tester.pumpAndSettle();
      await advance(tester, const Duration(seconds: 4));
      await tester.tap(find.text('Bấm giờ'));
      await tester.pumpAndSettle();

      expect(find.text('00:07.00'), findsOneWidget);
    });

    testWidgets('bấm giờ không lưu phiên nào vào lịch sử', (tester) async {
      await openStopwatch(tester);
      await tester.tap(play());
      await advance(tester, const Duration(minutes: 5));
      await tester.tap(find.widgetWithText(FilledButton, 'Đặt lại'));
      await tester.pumpAndSettle();

      expect(await savedSessions(), isEmpty);
    });
  });
}
