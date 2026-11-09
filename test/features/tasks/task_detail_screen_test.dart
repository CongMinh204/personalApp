import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/app/routes.dart';
import 'package:personal_app/app/shell_controller.dart';
import 'package:personal_app/data/default_tags.dart';
import 'package:personal_app/data/models/focus_session.dart';
import 'package:personal_app/data/models/subtask.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/features/tasks/task_detail_screen.dart';
import 'package:personal_app/features/tasks/task_edit_screen.dart';

import 'tasks_test_env.dart';

void main() {
  late TasksEnv env;

  Future<void> seed({
    bool withFocus = true,
    RepeatRule repeat = RepeatRule.none,
  }) async {
    await env.tasks.add(
      testTask(
        'pe',
        title: 'Ôn tập PE Flutter',
        note: 'Làm lại bài form đăng ký.',
        tagId: DefaultTagIds.study,
        hasTime: true,
        due: DateTime(2026, 10, 29, 19, 30),
        end: DateTime(2026, 10, 29, 21),
        priority: Priority.high,
        reminderMinutes: 15,
        repeat: repeat,
      ),
      subtasks: const [
        Subtask(id: 's1', taskId: 'pe', title: 'Viết validator', done: true),
        Subtask(id: 's2', taskId: 'pe', title: 'Viết unit test'),
        Subtask(id: 's3', taskId: 'pe', title: 'Chạy thử'),
      ],
    );
    if (withFocus) {
      var n = 0;
      for (final (type, seconds) in [
        (FocusType.pomodoro, 25 * 60),
        (FocusType.pomodoro, 25 * 60),
        (FocusType.shortBreak, 5 * 60), // giờ nghỉ không tính
      ]) {
        await env.focus.add(
          FocusSession(
            id: 'f${n++}',
            taskId: 'pe',
            type: type,
            startedAt: DateTime(2026, 10, 29, 8 + n),
            durationSec: seconds,
            completed: true,
          ),
        );
      }
    }
  }

  Future<void> openDetail(WidgetTester tester, String id) async {
    await env.open(tester, AppRoutes.taskDetail, arguments: id);
  }

  Finder titleCheckbox() => find.byType(Checkbox).first;

  group('hiển thị', () {
    testWidgets('đủ thông tin của việc như mockup', (tester) async {
      env = await TasksEnv.create();
      await seed();
      await openDetail(tester, 'pe');

      expect(find.widgetWithText(AppBar, 'Chi tiết việc'), findsOneWidget);
      expect(find.text('Ôn tập PE Flutter'), findsOneWidget);
      expect(find.text('Học tập'), findsOneWidget);
      expect(find.text('Ưu tiên cao'), findsOneWidget);
      expect(find.text('Làm lại bài form đăng ký.'), findsOneWidget);
      expect(find.text('Th 5, 29/10/2026'), findsOneWidget);
      expect(find.text('19:30 → 21:00'), findsOneWidget);
      expect(find.text('15 phút'), findsOneWidget);
      expect(find.text('Không'), findsOneWidget);
      expect(find.text('Việc con'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('Viết validator'), findsOneWidget);
      expect(find.byTooltip('Sửa việc'), findsOneWidget);
    });

    testWidgets('chỉ tính các phiên tập trung, không tính giờ nghỉ', (
      tester,
    ) async {
      env = await TasksEnv.create();
      await seed();
      await openDetail(tester, 'pe');

      expect(find.text('Đã tập trung'), findsOneWidget);
      expect(find.text('50 phút · 2 phiên'), findsOneWidget);
    });

    testWidgets('chưa có phiên nào thì ghi "Chưa tập trung"', (tester) async {
      env = await TasksEnv.create();
      await seed(withFocus: false);
      await openDetail(tester, 'pe');

      expect(find.text('Chưa tập trung'), findsOneWidget);
    });

    testWidgets('việc cả ngày, không nhắc, không ghi chú, không việc con', (
      tester,
    ) async {
      env = await TasksEnv.create();
      await env.tasks.add(testTask('don', title: 'Việc đơn giản'));
      await openDetail(tester, 'don');

      expect(find.text('Cả ngày'), findsOneWidget);
      expect(find.text('Không nhắc'), findsOneWidget);
      expect(find.text('Việc con'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('việc không có ngày', (tester) async {
      env = await TasksEnv.create();
      await env.tasks.add(
        testTask('kn', title: 'Không ngày').copyWith(due: () => null),
      );
      await openDetail(tester, 'kn');

      expect(find.text('Không có ngày'), findsOneWidget);
    });

    testWidgets('id không còn tồn tại', (tester) async {
      env = await TasksEnv.create();
      await openDetail(tester, 'khong-co');

      expect(find.text('Việc này không còn tồn tại'), findsOneWidget);
      expect(find.byTooltip('Sửa việc'), findsNothing);
    });
  });

  group('thao tác', () {
    testWidgets('tick xong và bỏ xong việc, gạch tên khi xong', (tester) async {
      env = await TasksEnv.create();
      await seed();
      await openDetail(tester, 'pe');

      await tester.tap(titleCheckbox());
      await tester.pumpAndSettle();
      expect((await env.tasks.getById('pe'))!.done, isTrue);
      final title = tester.widget<Text>(find.text('Ôn tập PE Flutter'));
      expect(title.style?.decoration, TextDecoration.lineThrough);

      await tester.tap(titleCheckbox());
      await tester.pumpAndSettle();
      expect((await env.tasks.getById('pe'))!.done, isFalse);
    });

    testWidgets('tick việc con thì tiến độ đổi', (tester) async {
      env = await TasksEnv.create();
      await seed();
      await openDetail(tester, 'pe');

      await tester.tap(find.byType(Checkbox).at(2)); // "Viết unit test"
      await tester.pumpAndSettle();

      expect(find.text('2/3'), findsOneWidget);
      final subs = await env.tasks.getSubtasks('pe');
      expect([for (final s in subs) s.done], [true, true, false]);
    });

    testWidgets('xong việc lặp thì báo đã tạo lần kế tiếp', (tester) async {
      env = await TasksEnv.create();
      await seed(repeat: RepeatRule.weekly);
      await openDetail(tester, 'pe');

      await tester.tap(titleCheckbox());
      await tester.pumpAndSettle();

      expect(find.text('Đã tạo việc cho lần lặp kế tiếp'), findsOneWidget);
      expect(await env.tasks.getAll(), hasLength(2));
    });

    testWidgets('Bắt đầu chọn sẵn việc, mở tab Hẹn giờ và về khung chính', (
      tester,
    ) async {
      env = await TasksEnv.create();
      await seed();
      await openDetail(tester, 'pe');

      await tester.tap(find.widgetWithText(FilledButton, 'Bắt đầu'));
      await tester.pumpAndSettle();

      expect(env.timer.preparedTaskId, 'pe');
      expect(env.shell.tab, HomeTab.timer);
      expect(find.byType(TaskDetailScreen), findsNothing);
    });
  });

  group('sửa và xóa', () {
    testWidgets('nút sửa mở form Sửa việc, lưu xong Chi tiết cập nhật', (
      tester,
    ) async {
      env = await TasksEnv.create();
      await seed();
      await openDetail(tester, 'pe');

      await tester.tap(find.byTooltip('Sửa việc'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Sửa việc'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).at(0),
        'Ôn tập PE (đã sửa)',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditScreen), findsNothing);
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      expect(find.text('Ôn tập PE (đã sửa)'), findsOneWidget);
    });

    testWidgets('xóa việc ngay trong form sửa thì Chi tiết cũng đóng', (
      tester,
    ) async {
      env = await TasksEnv.create();
      await seed();
      await openDetail(tester, 'pe');

      await tester.tap(find.byTooltip('Sửa việc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa việc'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(await env.tasks.getById('pe'), isNull);
      expect(find.byType(TaskEditScreen), findsNothing);
      expect(find.byType(TaskDetailScreen), findsNothing);
    });

    testWidgets('xóa có xác nhận, hủy thì giữ nguyên', (tester) async {
      env = await TasksEnv.create();
      await seed();
      await openDetail(tester, 'pe');

      await tester.tap(find.text('Xóa việc này'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa việc này?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();

      expect(await env.tasks.getById('pe'), isNotNull);
      expect(find.byType(TaskDetailScreen), findsOneWidget);
    });

    testWidgets('xóa xong đóng màn, hoàn tác khôi phục cả việc con', (
      tester,
    ) async {
      env = await TasksEnv.create();
      await seed();
      await openDetail(tester, 'pe');

      await tester.tap(find.text('Xóa việc này'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(await env.tasks.getById('pe'), isNull);
      expect(find.byType(TaskDetailScreen), findsNothing);
      expect(find.text('Đã xóa "Ôn tập PE Flutter"'), findsOneWidget);

      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();

      final restored = (await env.tasks.getById('pe'))!;
      expect(restored.title, 'Ôn tập PE Flutter');
      expect(await env.tasks.getSubtasks('pe'), hasLength(3));
    });
  });
}
