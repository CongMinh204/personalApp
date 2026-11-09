import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/app/routes.dart';
import 'package:personal_app/data/default_tags.dart';
import 'package:personal_app/data/models/subtask.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/features/tasks/task_edit_screen.dart';

import 'tasks_test_env.dart';

void main() {
  late TasksEnv env;
  final day = DateTime(2026, 10, 29);

  Future<void> openAdd(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    bool withClock = false,
  }) async {
    env = await TasksEnv.create(prefs: prefs);
    if (withClock) {
      await env.openScreen(
        tester,
        TaskEditScreen(initialDate: day, clock: () => testNow),
      );
    } else {
      await env.open(tester, AppRoutes.taskEdit, arguments: day);
    }
  }

  Future<void> openEdit(WidgetTester tester, String id) async {
    await env.open(tester, AppRoutes.taskEdit, arguments: id);
  }

  Finder titleField() => find.byType(TextField).at(0);
  Finder noteField() => find.byType(TextField).at(1);
  Finder save() => find.widgetWithText(TextButton, 'Lưu');

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(save());
    await tester.pumpAndSettle();
  }

  bool chipSelected(WidgetTester tester, String label) => tester
      .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
      .selected;

  Future<Task> onlyTask() async {
    final all = await env.tasks.getAll();
    expect(all, hasLength(1));
    return all.single;
  }

  group('thêm việc', () {
    testWidgets('có tiêu đề màn và ngày điền sẵn', (tester) async {
      await openAdd(tester);

      expect(find.widgetWithText(AppBar, 'Thêm việc'), findsOneWidget);
      expect(find.text('Th 5, 29/10/2026'), findsOneWidget);
      expect(find.text('Xóa việc'), findsNothing);
    });

    testWidgets('tiêu đề trống thì báo lỗi và không lưu', (tester) async {
      await openAdd(tester);

      await tapSave(tester);

      expect(find.text('Vui lòng nhập tên việc'), findsOneWidget);
      expect(find.byType(TaskEditScreen), findsOneWidget);
      expect(await env.tasks.getAll(), isEmpty);
    });

    testWidgets('lưu với giá trị mặc định', (tester) async {
      await openAdd(tester);

      await tester.enterText(titleField(), '  Học Flutter  ');
      await tapSave(tester);

      expect(await env.lastResult, TaskEditResult.saved);
      final task = await onlyTask();
      expect(task.title, 'Học Flutter');
      expect(task.due, DateTime(2026, 10, 29));
      expect(task.hasTime, isFalse);
      expect(task.end, isNull);
      expect(task.reminderMinutes, 15);
      expect(task.priority, Priority.medium);
      expect(task.repeatRule, RepeatRule.none);
      expect(task.tagId, isNull);
      expect(task.done, isFalse);
    });

    testWidgets('nhắc trước mặc định lấy từ Cài đặt', (tester) async {
      await openAdd(tester, prefs: {'default_reminder_minutes': 60});

      expect(chipSelected(tester, '1 giờ'), isTrue);
      expect(chipSelected(tester, '15 phút'), isFalse);
    });

    testWidgets('lưu ghi chú, ưu tiên, nhắc trước và lặp lại đã chọn', (
      tester,
    ) async {
      await openAdd(tester);

      await tester.enterText(titleField(), 'Họp nhóm');
      await tester.enterText(noteField(), '  Mang laptop ');
      await tester.tap(find.text('Cao'));
      await tester.tap(find.text('1 giờ'));
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<RepeatRule>),
          matching: find.text('Tuần'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lặp mỗi Thứ Năm hằng tuần'), findsOneWidget);
      await tapSave(tester);

      final task = await onlyTask();
      expect(task.note, 'Mang laptop');
      expect(task.priority, Priority.high);
      expect(task.reminderMinutes, 60);
      expect(task.repeatRule, RepeatRule.weekly);
    });
  });

  group('nhắc trước', () {
    testWidgets('bấm lại mức đang chọn để bỏ nhắc', (tester) async {
      await openAdd(tester);
      expect(chipSelected(tester, '15 phút'), isTrue);

      await tester.tap(find.text('15 phút'));
      await tester.pumpAndSettle();
      expect(chipSelected(tester, '15 phút'), isFalse);

      await tester.enterText(titleField(), 'Không nhắc');
      await tapSave(tester);
      expect((await onlyTask()).reminderMinutes, isNull);
    });

    testWidgets('chỉ chọn được một mức', (tester) async {
      await openAdd(tester);

      await tester.tap(find.text('5 phút'));
      await tester.pumpAndSettle();

      expect(chipSelected(tester, '5 phút'), isTrue);
      expect(chipSelected(tester, '15 phút'), isFalse);
    });
  });

  group('giờ', () {
    testWidgets('mặc định cả ngày, tắt Cả ngày thì có giờ bắt đầu', (
      tester,
    ) async {
      await openAdd(tester, withClock: true);
      expect(find.text('Giờ bắt đầu'), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      // Giờ hiện tại 13:40 thì gợi ý giờ bắt đầu là 14:00.
      expect(find.text('14:00'), findsOneWidget);

      await tester.enterText(titleField(), 'Họp');
      await tapSave(tester);
      final task = await onlyTask();
      expect(task.hasTime, isTrue);
      expect(task.due, DateTime(2026, 10, 29, 14));
      expect(task.end, isNull);
    });

    testWidgets('giờ kết thúc không sau giờ bắt đầu thì báo lỗi', (
      tester,
    ) async {
      await openAdd(tester, withClock: true);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Chọn giờ kết thúc = giờ gợi ý (14:00) bằng nút OK của bộ chọn giờ.
      await tester.tap(find.text('Giờ kết thúc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Bỏ giờ kết thúc'), findsOneWidget);

      await tester.enterText(titleField(), 'Họp');
      await tapSave(tester);
      expect(find.text('Giờ kết thúc phải sau giờ bắt đầu'), findsOneWidget);
      expect(await env.tasks.getAll(), isEmpty);

      // Bỏ giờ kết thúc thì lưu được.
      await tester.tap(find.byTooltip('Bỏ giờ kết thúc'));
      await tester.pumpAndSettle();
      await tapSave(tester);
      expect((await onlyTask()).hasTime, isTrue);
    });
  });

  group('ngày và lặp lại', () {
    testWidgets('bỏ ngày thì ẩn phần giờ, tắt lặp lại và lưu việc không ngày', (
      tester,
    ) async {
      await openAdd(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<RepeatRule>),
          matching: find.text('Ngày'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Bỏ ngày'));
      await tester.pumpAndSettle();

      expect(find.text('Không có ngày'), findsOneWidget);
      expect(find.text('Cả ngày'), findsNothing);
      expect(find.text('Chọn ngày để đặt lặp lại'), findsOneWidget);
      final repeat = tester.widget<SegmentedButton<RepeatRule>>(
        find.byType(SegmentedButton<RepeatRule>),
      );
      expect(repeat.selected, {RepeatRule.none});
      expect(repeat.onSelectionChanged, isNull);

      await tester.enterText(titleField(), 'Việc không ngày');
      await tapSave(tester);
      final task = await onlyTask();
      expect(task.due, isNull);
      expect(task.hasTime, isFalse);
    });
  });

  group('nhãn', () {
    testWidgets('mỗi việc một nhãn, bấm lại để bỏ nhãn', (tester) async {
      await openAdd(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Học tập'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Công việc'));
      await tester.pumpAndSettle();
      expect(chipSelected(tester, 'Học tập'), isFalse);
      expect(chipSelected(tester, 'Công việc'), isTrue);

      await tester.enterText(titleField(), 'Có nhãn');
      await tapSave(tester);
      expect((await onlyTask()).tagId, DefaultTagIds.work);
    });

    testWidgets('bấm lại nhãn đang chọn thì bỏ nhãn', (tester) async {
      await openAdd(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Học tập'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Học tập'));
      await tester.pumpAndSettle();

      expect(chipSelected(tester, 'Học tập'), isFalse);
    });

    testWidgets('tạo nhãn mới ngay trong form và chọn luôn nhãn đó', (
      tester,
    ) async {
      await openAdd(tester);

      await tester.tap(find.widgetWithText(ActionChip, 'Nhãn mới'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Gia đình',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(chipSelected(tester, 'Gia đình'), isTrue);
      final created = (await env.tags.getAll()).last;
      expect(created.name, 'Gia đình');

      await tester.enterText(titleField(), 'Việc gia đình');
      await tapSave(tester);
      expect((await onlyTask()).tagId, created.id);
    });

    testWidgets('tên nhãn mới trùng nhãn có sẵn thì báo lỗi', (tester) async {
      await openAdd(tester);

      await tester.tap(find.widgetWithText(ActionChip, 'Nhãn mới'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'học tập',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('đã tồn tại'), findsOneWidget);
      expect(await env.tags.getAll(), hasLength(4));
    });

    testWidgets('hủy hộp thoại nhãn mới thì không chọn nhãn nào', (
      tester,
    ) async {
      await openAdd(tester);

      await tester.tap(find.widgetWithText(ActionChip, 'Nhãn mới'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();

      expect(await env.tags.getAll(), hasLength(4));
    });
  });

  group('việc con', () {
    testWidgets('thêm, tick và xóa việc con, đếm số đã xong', (tester) async {
      await openAdd(tester);
      expect(find.text('Việc con · 0/0'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(2), 'Con 1');
      await tester.tap(find.byTooltip('Thêm việc con'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), 'Con 2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Việc con · 0/2'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('Việc con · 1/2'), findsOneWidget);

      await tester.tap(find.byTooltip('Xóa việc con Con 2'));
      await tester.pumpAndSettle();
      expect(find.text('Việc con · 1/1'), findsOneWidget);
      expect(find.text('Con 2'), findsNothing);

      await tester.enterText(titleField(), 'Có việc con');
      await tapSave(tester);
      final task = await onlyTask();
      final subs = await env.tasks.getSubtasks(task.id);
      expect([for (final s in subs) (s.title, s.done)], [('Con 1', true)]);
    });

    testWidgets('việc con đang gõ dở trong ô nhập vẫn được lưu', (
      tester,
    ) async {
      await openAdd(tester);

      await tester.enterText(titleField(), 'Việc');
      await tester.enterText(find.byType(TextField).at(2), '  Con gõ dở ');
      await tapSave(tester);

      final subs = await env.tasks.getSubtasks((await onlyTask()).id);
      expect([for (final s in subs) s.title], ['Con gõ dở']);
    });

    testWidgets('không có biểu tượng kéo thả sắp xếp', (tester) async {
      await openAdd(tester);
      await tester.enterText(find.byType(TextField).at(2), 'Con 1');
      await tester.tap(find.byTooltip('Thêm việc con'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
      expect(find.byType(ReorderableListView), findsNothing);
    });
  });

  group('sửa việc', () {
    Future<void> seed() async {
      await env.tasks.add(
        testTask(
          't1',
          title: 'Học bài',
          note: 'Ghi chú cũ',
          tagId: DefaultTagIds.study,
          hasTime: true,
          due: DateTime(2026, 10, 29, 19, 30),
          end: DateTime(2026, 10, 29, 21),
          priority: Priority.high,
          reminderMinutes: 30,
          repeat: RepeatRule.weekly,
          done: true,
        ),
        subtasks: const [
          Subtask(id: 's1', taskId: 't1', title: 'Con 1', done: true),
          Subtask(id: 's2', taskId: 't1', title: 'Con 2'),
        ],
      );
    }

    testWidgets('điền sẵn mọi trường của việc', (tester) async {
      env = await TasksEnv.create();
      await seed();
      await openEdit(tester, 't1');

      expect(find.widgetWithText(AppBar, 'Sửa việc'), findsOneWidget);
      expect(find.text('Học bài'), findsOneWidget);
      expect(find.text('Ghi chú cũ'), findsOneWidget);
      expect(find.text('Th 5, 29/10/2026'), findsOneWidget);
      expect(find.text('19:30'), findsOneWidget);
      expect(find.text('21:00'), findsOneWidget);
      expect(chipSelected(tester, '30 phút'), isTrue);
      expect(chipSelected(tester, 'Học tập'), isTrue);
      expect(
        tester
            .widget<SegmentedButton<Priority>>(
              find.byType(SegmentedButton<Priority>),
            )
            .selected,
        {Priority.high},
      );
      expect(
        tester
            .widget<SegmentedButton<RepeatRule>>(
              find.byType(SegmentedButton<RepeatRule>),
            )
            .selected,
        {RepeatRule.weekly},
      );
      expect(find.text('Việc con · 1/2'), findsOneWidget);
      expect(find.text('Xóa việc'), findsOneWidget);
    });

    testWidgets('lưu thay đổi, giữ trạng thái xong, thay việc con', (
      tester,
    ) async {
      env = await TasksEnv.create();
      await seed();
      await openEdit(tester, 't1');

      await tester.enterText(titleField(), 'Học bài mới');
      await tester.tap(find.byTooltip('Xóa việc con Con 2'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), 'Con 3');
      await tester.tap(find.byTooltip('Thêm việc con'));
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(await env.lastResult, TaskEditResult.saved);
      final saved = (await env.tasks.getById('t1'))!;
      expect(saved.title, 'Học bài mới');
      expect(saved.done, isTrue);
      expect(saved.completedAt, DateTime(2026, 10, 29, 9));
      expect(saved.due, DateTime(2026, 10, 29, 19, 30));
      final subs = await env.tasks.getSubtasks('t1');
      expect(
        [for (final s in subs) (s.title, s.done)],
        [('Con 1', true), ('Con 3', false)],
      );
    });

    testWidgets('xóa việc có hộp xác nhận', (tester) async {
      env = await TasksEnv.create();
      await seed();
      await openEdit(tester, 't1');

      await tester.tap(find.text('Xóa việc'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa việc này?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();
      expect(await env.tasks.getById('t1'), isNotNull);

      await tester.tap(find.text('Xóa việc'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(await env.tasks.getById('t1'), isNull);
      expect(await env.lastResult, TaskEditResult.deleted);
    });

    testWidgets('id không tồn tại thì báo không tìm thấy', (tester) async {
      env = await TasksEnv.create();
      await openEdit(tester, 'khong-co');

      expect(find.text('Không tìm thấy việc này'), findsOneWidget);
      expect(tester.widget<TextButton>(save()).onPressed, isNull);
    });
  });
}
