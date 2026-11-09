import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/models/focus_session.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/features/focus_history/focus_history_logic.dart';
import 'package:personal_app/features/focus_history/focus_history_screen.dart';

import '../tasks/tasks_test_env.dart';

void main() {
  late TasksEnv env;

  Future<void> addSession(
    String id,
    DateTime startedAt, {
    int minutes = 25,
    bool completed = true,
    FocusType type = FocusType.pomodoro,
    String? taskId,
    int? seconds,
  }) => env.focus.add(
    FocusSession(
      id: id,
      taskId: taskId,
      type: type,
      startedAt: startedAt,
      durationSec: seconds ?? minutes * 60,
      completed: completed,
    ),
  );

  /// Dữ liệu giống mockup. Hôm nay là Thứ Năm 29/10/2026 13:40.
  Future<void> openHistory(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    bool withSessions = true,
  }) async {
    env = await TasksEnv.create(prefs: prefs);
    await env.tasks.add(
      Task(
        id: 'pe',
        title: 'Ôn tập PE Flutter',
        createdAt: DateTime(2026, 10, 1),
      ),
    );
    await env.tasks.add(
      Task(
        id: 'lab',
        title: 'Nộp báo cáo Lab 3 PRM393',
        createdAt: DateTime(2026, 10, 2),
      ),
    );
    if (withSessions) {
      await addSession('s1', DateTime(2026, 10, 29, 9, 5), taskId: 'pe');
      await addSession('s2', DateTime(2026, 10, 29, 10, 15), taskId: 'pe');
      await addSession(
        's3',
        DateTime(2026, 10, 29, 13, 10),
        minutes: 12,
        completed: false,
        taskId: 'lab',
      );
      await addSession(
        's4',
        DateTime(2026, 10, 29, 12),
        minutes: 10,
        type: FocusType.custom,
      );
      await addSession('s5', DateTime(2026, 10, 28, 20), taskId: 'pe');
      await addSession('s6', DateTime(2026, 10, 28, 20, 30));
      // Giờ nghỉ: không hiện trong lịch sử.
      await addSession(
        'nghi',
        DateTime(2026, 10, 29, 11),
        minutes: 5,
        type: FocusType.shortBreak,
      );
    }
    await env.openScreen(
      tester,
      FocusHistoryScreen(clock: () => testNow),
      size: const Size(1170, 4000),
    );
  }

  // Chạm đúng chữ trong nút; chạm vào cả cụm SegmentedButton sẽ trúng nút giữa.
  Finder tab(String label) => find.descendant(
    of: find.byType(SegmentedButton<HistoryRange>),
    matching: find.text(label),
  );

  group('tab Ngày (mặc định)', () {
    testWidgets('nhóm theo ngày: Hôm nay và Hôm qua kèm tổng thời gian', (
      tester,
    ) async {
      await openHistory(tester);

      expect(find.widgetWithText(AppBar, 'Lịch sử tập trung'), findsOneWidget);
      expect(find.text('Hôm nay · Th 5, 29/10'), findsOneWidget);
      expect(find.text('Hôm qua · Th 4, 28/10'), findsOneWidget);
      // Hôm nay: 25 + 25 + 12 + 10 = 72 phút; hôm qua: 50 phút.
      expect(find.text('1g 12p'), findsOneWidget);
      expect(find.text('50p'), findsWidgets);
    });

    testWidgets('mỗi dòng có tên việc, khoảng giờ, loại và thời lượng', (
      tester,
    ) async {
      await openHistory(tester);

      expect(find.text('Ôn tập PE Flutter'), findsNWidgets(3));
      expect(find.text('Nộp báo cáo Lab 3 PRM393'), findsOneWidget);
      expect(find.text('09:05 – 09:30 · Pomodoro'), findsOneWidget);
      expect(find.text('10:15 – 10:40 · Pomodoro'), findsOneWidget);
      expect(find.text('13:10 – 13:22 · Pomodoro'), findsOneWidget);
      expect(find.text('12:00 – 12:10 · Tùy chỉnh'), findsOneWidget);
      expect(find.text('12p'), findsOneWidget);
    });

    testWidgets('phiên không gắn việc ghi "Không gắn việc"', (tester) async {
      await openHistory(tester);

      // Phiên Tùy chỉnh hôm nay và phiên 20:30 hôm qua.
      expect(find.text('Không gắn việc'), findsNWidgets(2));
    });

    testWidgets('huy hiệu Hoàn thành và Bỏ dở', (tester) async {
      await openHistory(tester);

      // 5 phiên hoàn thành + 1 chữ "Hoàn thành" ở ô tóm tắt.
      expect(find.text('Hoàn thành'), findsNWidgets(6));
      expect(find.text('Bỏ dở'), findsOneWidget);
    });

    testWidgets('phiên nghỉ không hiện', (tester) async {
      await openHistory(tester);

      expect(find.textContaining('Nghỉ ngắn'), findsNothing);
      expect(find.text('11:00 – 11:05 · Nghỉ ngắn'), findsNothing);
    });

    testWidgets('ba ô tóm tắt tính cho hôm nay, ô thứ ba là Tuần này', (
      tester,
    ) async {
      await openHistory(tester);

      expect(find.text('Phiên'), findsOneWidget);
      expect(find.text('4'), findsOneWidget); // 4 phiên tập trung hôm nay
      expect(find.text('3/4'), findsOneWidget); // 3 hoàn thành trên 4
      expect(find.text('Tuần này'), findsOneWidget);
      expect(find.text('2g 02p'), findsOneWidget); // 72 + 50 = 122 phút
    });

    testWidgets('phiên dưới 1 phút ghi <1p', (tester) async {
      await openHistory(tester, withSessions: false);
      await addSession(
        'ngan',
        DateTime(2026, 10, 29, 9),
        seconds: 20,
        completed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('<1p'), findsOneWidget);
    });
  });

  group('đổi tab', () {
    testWidgets(
      'Tuần: gom theo tuần, ô tóm tắt tính cho tuần này, ô ba là Tháng này',
      (tester) async {
        await openHistory(tester);

        await tester.tap(tab('Tuần'));
        await tester.pumpAndSettle();

        expect(find.text('Tuần này · 26/10 – 01/11'), findsOneWidget);
        expect(find.text('Hôm nay · Th 5, 29/10'), findsNothing);
        expect(find.text('6'), findsOneWidget); // 6 phiên trong tuần
        expect(find.text('5/6'), findsOneWidget);
        expect(find.text('Tháng này'), findsOneWidget);
        expect(find.text('Tuần này'), findsNothing); // đã thành "Tháng này"
      },
    );

    testWidgets('Tháng: gom theo tháng, ô ba là Năm nay', (tester) async {
      await openHistory(tester);

      await tester.tap(tab('Tháng'));
      await tester.pumpAndSettle();

      expect(find.text('Tháng này · Tháng 10/2026'), findsOneWidget);
      expect(find.text('Năm nay'), findsOneWidget);
      expect(find.text('5/6'), findsOneWidget);
    });

    testWidgets('quay lại tab Ngày thì về cách gom theo ngày', (tester) async {
      await openHistory(tester);

      await tester.tap(tab('Tuần'));
      await tester.pumpAndSettle();
      await tester.tap(tab('Ngày'));
      await tester.pumpAndSettle();

      expect(find.text('Hôm nay · Th 5, 29/10'), findsOneWidget);
      expect(find.text('3/4'), findsOneWidget);
    });

    testWidgets(
      'mỗi tab chỉ hiện đủ số nhóm gần nhất (30 ngày, 12 tuần, 12 tháng)',
      (tester) async {
        await openHistory(tester);
        // 58 ngày trước: ngoài 30 ngày nhưng trong 12 tuần và 12 tháng.
        await addSession('cu', DateTime(2026, 9, 1, 9));
        // Hơn 12 tháng trước: ngoài mọi tab.
        await addSession('rat-cu', DateTime(2025, 9, 1, 9));
        await tester.pumpAndSettle();

        expect(find.text('Th 3, 01/09'), findsNothing);

        await tester.tap(tab('Tuần'));
        await tester.pumpAndSettle();
        expect(find.text('31/08 – 06/09'), findsOneWidget);

        await tester.tap(tab('Tháng'));
        await tester.pumpAndSettle();
        expect(find.text('Tháng 9/2026'), findsOneWidget);
        expect(find.text('Tháng 9/2025'), findsNothing);
      },
    );

    testWidgets('ngày đầu tuần theo Cài đặt (Chủ Nhật)', (tester) async {
      await openHistory(tester, prefs: {'week_start': 7});

      await tester.tap(tab('Tuần'));
      await tester.pumpAndSettle();

      expect(find.text('Tuần này · 25/10 – 31/10'), findsOneWidget);
    });
  });

  group('trạng thái trống', () {
    testWidgets('chưa có phiên nào: thông báo và các ô tóm tắt bằng 0', (
      tester,
    ) async {
      await openHistory(tester, withSessions: false);

      expect(find.text('Chưa có phiên tập trung nào'), findsOneWidget);
      expect(
        find.textContaining('Chạy một phiên ở tab Hẹn giờ'),
        findsOneWidget,
      );
      expect(find.text('0/0'), findsOneWidget);
      expect(find.text('0p'), findsOneWidget);
    });

    testWidgets('chỉ có phiên nghỉ thì vẫn là trạng thái trống', (
      tester,
    ) async {
      await openHistory(tester, withSessions: false);
      await addSession(
        'nghi',
        DateTime(2026, 10, 29, 11),
        minutes: 5,
        type: FocusType.shortBreak,
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có phiên tập trung nào'), findsOneWidget);
    });
  });

  group('cập nhật trực tiếp', () {
    testWidgets('phiên mới được lưu khi màn đang mở thì hiện ngay', (
      tester,
    ) async {
      await openHistory(tester);
      expect(find.text('4'), findsOneWidget);

      await addSession('moi', DateTime(2026, 10, 29, 13, 20), taskId: 'lab');
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
      expect(find.text('13:20 – 13:45 · Pomodoro'), findsOneWidget);
    });

    testWidgets('việc bị xóa thì phiên của nó thành "Không gắn việc"', (
      tester,
    ) async {
      await openHistory(tester);
      expect(find.text('Nộp báo cáo Lab 3 PRM393'), findsOneWidget);

      await env.tasks.delete('lab');
      await tester.pumpAndSettle();

      expect(find.text('Nộp báo cáo Lab 3 PRM393'), findsNothing);
      expect(find.text('Không gắn việc'), findsNWidgets(3));
    });
  });

  group('xóa phiên', () {
    Future<void> swipe(WidgetTester tester, String id) async {
      await tester.drag(find.byKey(ValueKey(id)), const Offset(-700, 0));
      await tester.pumpAndSettle();
    }

    testWidgets('vuốt trái để xóa khỏi lịch sử và khỏi database', (
      tester,
    ) async {
      await openHistory(tester);

      await swipe(tester, 's3'); // phiên bỏ dở 13:10

      expect(find.text('13:10 – 13:22 · Pomodoro'), findsNothing);
      expect(find.text('Bỏ dở'), findsNothing);
      expect(find.text('Đã xóa phiên tập trung'), findsOneWidget);
      expect(find.text('3/3'), findsOneWidget); // ô tóm tắt cập nhật
      final left = await env.focus.sessionsByRange(
        DateTimeRange(start: DateTime(2026), end: DateTime(2027)),
      );
      expect(left.any((s) => s.id == 's3'), isFalse);
    });

    testWidgets('Hoàn tác khôi phục đúng phiên', (tester) async {
      await openHistory(tester);
      await swipe(tester, 's3');

      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();

      expect(find.text('13:10 – 13:22 · Pomodoro'), findsOneWidget);
      expect(find.text('Bỏ dở'), findsOneWidget);
      expect(find.text('3/4'), findsOneWidget);
      final total = await env.focus.totalForTask('lab');
      expect((total.seconds, total.sessions), (12 * 60, 1));
    });

    testWidgets(
      'hoàn tác khi việc đã bị xóa thì khôi phục ở dạng không gắn việc',
      (tester) async {
        await openHistory(tester);
        await swipe(tester, 's3');
        await env.tasks.delete('lab');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Hoàn tác'));
        await tester.pumpAndSettle();

        expect(find.text('13:10 – 13:22 · Pomodoro'), findsOneWidget);
        expect(find.text('Không gắn việc'), findsNWidgets(3));
      },
    );

    testWidgets('xóa phiên cuối cùng của một nhóm thì nhóm biến mất', (
      tester,
    ) async {
      await openHistory(tester);
      expect(find.text('Hôm qua · Th 4, 28/10'), findsOneWidget);

      await swipe(tester, 's5');
      await swipe(tester, 's6');

      expect(find.text('Hôm qua · Th 4, 28/10'), findsNothing);
    });
  });

  testWidgets('nút quay lại đóng màn', (tester) async {
    await openHistory(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(FocusHistoryScreen), findsNothing);
  });
}
