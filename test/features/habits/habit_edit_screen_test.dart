import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/app/routes.dart';
import 'package:personal_app/data/models/habit.dart';
import 'package:personal_app/features/habits/habit_edit_screen.dart';
import 'package:personal_app/features/habits/habit_logic.dart';
import 'package:personal_app/features/habits/widgets/habit_pickers.dart';
import 'package:personal_app/utils/dates.dart';

import '../tasks/tasks_test_env.dart';

void main() {
  late TasksEnv env;

  Future<void> openAdd(WidgetTester tester, {bool sample = false}) async {
    env = await TasksEnv.create(sample: sample);
    await env.openScreen(
      tester,
      HabitEditScreen(clock: () => testNow),
      size: const Size(1170, 4500),
    );
  }

  Future<void> openEdit(WidgetTester tester, String id) async {
    env = await TasksEnv.create(sample: true);
    await env.open(tester, AppRoutes.habitEdit, arguments: id);
  }

  Finder nameField() => find.byType(TextField).first;
  Finder save() => find.widgetWithText(TextButton, 'Lưu');

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(save());
    await tester.pumpAndSettle();
  }

  /// Chạm đúng chữ trong nút (không chạm vào tâm cả SegmentedButton).
  Finder segment(String label) => find.descendant(
    of: find.byType(SegmentedButton<bool>),
    matching: find.text(label),
  );

  Finder chip(String label) => find.widgetWithText(FilterChip, label);

  bool chipSelected(WidgetTester tester, String label) =>
      tester.widget<FilterChip>(chip(label)).selected;

  Future<Habit> onlyHabit() async {
    final all = await env.habits.watchActive().first;
    expect(all, hasLength(1));
    return all.single;
  }

  group('thêm thói quen', () {
    testWidgets('có tiêu đề, giá trị mặc định và con trỏ ở ô tên', (
      tester,
    ) async {
      await openAdd(tester);

      expect(find.widgetWithText(AppBar, 'Thêm thói quen'), findsOneWidget);
      expect(find.text('Lưu trữ thói quen'), findsNothing);
      expect(find.text('Xóa thói quen'), findsNothing);
      expect(find.text('29/10/2026'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasFocus,
        isTrue,
      );
    });

    testWidgets('lưu với giá trị mặc định', (tester) async {
      await openAdd(tester);

      await tester.enterText(nameField(), '  Uống nước  ');
      await tapSave(tester);

      expect(await env.lastResult, HabitEditResult.saved);
      final habit = await onlyHabit();
      expect(habit.name, 'Uống nước');
      expect(habit.icon, 'drop');
      expect(habit.color, habitColors.first.color);
      expect(habit.repeatDays, {1, 2, 3, 4, 5, 6, 7});
      expect(habit.goalPerDay, 1);
      expect(habit.unit, '');
      expect(habit.reminderTime, isNull);
      expect(habit.startDate, DateTime(2026, 10, 29));
      expect(habit.archived, isFalse);
    });

    testWidgets('tên trống thì báo lỗi và không lưu', (tester) async {
      await openAdd(tester);

      await tapSave(tester);

      expect(find.text('Vui lòng nhập tên thói quen'), findsOneWidget);
      expect(await env.habits.watchActive().first, isEmpty);
    });

    testWidgets('chọn biểu tượng và màu', (tester) async {
      await openAdd(tester);

      await tester.tap(
        find
            .descendant(
              of: find.byType(HabitIconPicker),
              matching: find.byType(InkWell),
            )
            .at(1), // Sách
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(HabitColorPicker),
              matching: find.byType(InkResponse),
            )
            .at(2), // Xanh lá
      );
      await tester.pumpAndSettle();
      await tester.enterText(nameField(), 'Đọc sách');
      await tapSave(tester);

      final habit = await onlyHabit();
      expect(habit.icon, 'book');
      expect(habit.color, habitColors[2].color);
    });
  });

  group('lặp lại', () {
    testWidgets('chuyển sang Theo thứ thì chọn sẵn thứ của hôm nay', (
      tester,
    ) async {
      await openAdd(tester);
      expect(chip('T2'), findsNothing);

      await tester.tap(segment('Theo thứ'));
      await tester.pumpAndSettle();

      for (final label in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']) {
        expect(chip(label), findsOneWidget, reason: label);
      }
      expect(chipSelected(tester, 'T5'), isTrue); // hôm nay Thứ Năm
      expect(chipSelected(tester, 'T2'), isFalse);
    });

    testWidgets('lưu các thứ đã chọn', (tester) async {
      await openAdd(tester);
      await tester.tap(segment('Theo thứ'));
      await tester.pumpAndSettle();

      await tester.tap(chip('T2'));
      await tester.tap(chip('T4'));
      await tester.tap(chip('T5')); // bỏ thứ của hôm nay
      await tester.pumpAndSettle();
      await tester.enterText(nameField(), 'Tập gym');
      await tapSave(tester);

      expect((await onlyHabit()).repeatDays, {1, 3});
    });

    testWidgets('bỏ hết các thứ thì báo phải chọn ít nhất một ngày', (
      tester,
    ) async {
      await openAdd(tester);
      await tester.tap(segment('Theo thứ'));
      await tester.pumpAndSettle();
      await tester.tap(chip('T5')); // bỏ thứ duy nhất đang chọn
      await tester.pumpAndSettle();
      await tester.enterText(nameField(), 'Tập gym');

      await tapSave(tester);

      expect(find.text('Chọn ít nhất một ngày'), findsOneWidget);
      expect(await env.habits.watchActive().first, isEmpty);
    });

    testWidgets('quay lại Mỗi ngày thì chọn đủ 7 thứ', (tester) async {
      await openAdd(tester);
      await tester.tap(segment('Theo thứ'));
      await tester.pumpAndSettle();
      await tester.tap(segment('Mỗi ngày'));
      await tester.pumpAndSettle();
      await tester.enterText(nameField(), 'A');
      await tapSave(tester);

      expect((await onlyHabit()).repeatDays, {1, 2, 3, 4, 5, 6, 7});
    });
  });

  group('mục tiêu mỗi ngày', () {
    testWidgets('mặc định 1, không giảm xuống dưới 1, chưa có ô đơn vị', (
      tester,
    ) async {
      await openAdd(tester);

      expect(find.text('1'), findsOneWidget);
      final minus = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Giảm mục tiêu'),
          matching: find.byType(IconButton),
        ),
      );
      expect(minus.onPressed, isNull);
      expect(find.text('Đơn vị (không bắt buộc)'), findsNothing);
    });

    testWidgets('mục tiêu lớn hơn 1 thì có ô đơn vị và được lưu', (
      tester,
    ) async {
      await openAdd(tester);

      for (var i = 0; i < 7; i++) {
        await tester.tap(find.byTooltip('Tăng mục tiêu'));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('8'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Đơn vị (không bắt buộc)'),
        'ly',
      );
      await tester.enterText(nameField(), 'Uống nước');
      await tapSave(tester);

      final habit = await onlyHabit();
      expect(habit.goalPerDay, 8);
      expect(habit.unit, 'ly');
    });

    testWidgets('đưa mục tiêu về 1 thì ẩn ô đơn vị và bỏ đơn vị', (
      tester,
    ) async {
      await openAdd(tester);
      await tester.tap(find.byTooltip('Tăng mục tiêu'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Đơn vị (không bắt buộc)'),
        'ly',
      );
      await tester.tap(find.byTooltip('Giảm mục tiêu'));
      await tester.pumpAndSettle();
      expect(find.text('Đơn vị (không bắt buộc)'), findsNothing);

      await tester.enterText(nameField(), 'Đọc sách');
      await tapSave(tester);

      final habit = await onlyHabit();
      expect((habit.goalPerDay, habit.unit), (1, ''));
    });

    testWidgets('mục tiêu tối đa 99', (tester) async {
      await openAdd(tester);

      for (var i = 0; i < 98; i++) {
        await tester.tap(find.byTooltip('Tăng mục tiêu'));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('99'), findsOneWidget);
      final plus = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Tăng mục tiêu'),
          matching: find.byType(IconButton),
        ),
      );
      expect(plus.onPressed, isNull);
    });
  });

  group('nhắc và ngày bắt đầu', () {
    testWidgets('bật nhắc thì có giờ nhắc mặc định 20:00, tắt thì bỏ nhắc', (
      tester,
    ) async {
      await openAdd(tester);
      expect(find.text('Giờ nhắc'), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Giờ nhắc'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      await tester.enterText(nameField(), 'Uống nước');
      await tapSave(tester);
      expect(
        (await onlyHabit()).reminderTime,
        const TimeOfDay(hour: 20, minute: 0),
      );
    });

    testWidgets('tắt nhắc thì không lưu giờ nhắc', (tester) async {
      await openAdd(tester);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.enterText(nameField(), 'A');
      await tapSave(tester);

      expect((await onlyHabit()).reminderTime, isNull);
    });
  });

  group('sửa thói quen', () {
    testWidgets('điền sẵn mọi trường của thói quen', (tester) async {
      await openEdit(tester, 'habit-water');

      expect(find.widgetWithText(AppBar, 'Sửa thói quen'), findsOneWidget);
      expect(find.text('Uống 2 lít nước'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Đơn vị (không bắt buộc)'),
            )
            .controller!
            .text,
        'ly',
      );
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('Lưu trữ thói quen'), findsOneWidget);
      expect(find.text('Xóa thói quen'), findsOneWidget);
    });

    testWidgets('thói quen theo thứ hiện đúng các thứ đã chọn', (tester) async {
      await openEdit(tester, 'habit-gym');

      expect(chipSelected(tester, 'T2'), isTrue);
      expect(chipSelected(tester, 'T4'), isTrue);
      expect(chipSelected(tester, 'T6'), isTrue);
      expect(chipSelected(tester, 'T3'), isFalse);
    });

    testWidgets('lưu thay đổi, giữ nguyên nhật ký và trạng thái lưu trữ', (
      tester,
    ) async {
      await openEdit(tester, 'habit-water');

      await tester.enterText(nameField(), 'Uống đủ nước');
      await tapSave(tester);

      expect(await env.lastResult, HabitEditResult.saved);
      final saved = (await env.habits.getById('habit-water'))!;
      expect(saved.name, 'Uống đủ nước');
      expect(saved.goalPerDay, 8);
      // Chuỗi ngày không đổi vì nhật ký còn nguyên.
      expect(await env.habits.streakOf('habit-water', today: testNow), 12);
    });

    testWidgets('không có con trỏ ở ô tên khi mở form sửa', (tester) async {
      await openEdit(tester, 'habit-water');

      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasFocus,
        isFalse,
      );
    });

    testWidgets('id không tồn tại thì báo không tìm thấy', (tester) async {
      env = await TasksEnv.create();
      await env.open(tester, AppRoutes.habitEdit, arguments: 'khong-co');

      expect(find.text('Không tìm thấy thói quen này'), findsOneWidget);
      expect(tester.widget<TextButton>(save()).onPressed, isNull);
    });
  });

  group('lưu trữ và xóa', () {
    testWidgets('Lưu trữ đưa thói quen vào danh sách đã lưu trữ, có Hoàn tác', (
      tester,
    ) async {
      await openEdit(tester, 'habit-reading');

      await tester.tap(find.text('Lưu trữ thói quen'));
      await tester.pumpAndSettle();

      expect(await env.lastResult, HabitEditResult.archived);
      expect((await env.habits.getById('habit-reading'))!.archived, isTrue);
      expect(find.text('Đã lưu trữ "Đọc sách 20 phút"'), findsOneWidget);

      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();
      expect((await env.habits.getById('habit-reading'))!.archived, isFalse);
    });

    testWidgets('Xóa có hộp xác nhận; Hủy thì giữ nguyên', (tester) async {
      await openEdit(tester, 'habit-reading');

      await tester.tap(find.text('Xóa thói quen'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa thói quen này?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();

      expect(await env.habits.getById('habit-reading'), isNotNull);
    });

    testWidgets('xác nhận Xóa thì xóa thói quen cùng toàn bộ nhật ký', (
      tester,
    ) async {
      await openEdit(tester, 'habit-reading');
      final range = daysRange(DateTime(2026, 9, 1), 100);
      expect(await env.habits.logsByRange('habit-reading', range), isNotEmpty);

      await tester.tap(find.text('Xóa thói quen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(await env.lastResult, HabitEditResult.deleted);
      expect(await env.habits.getById('habit-reading'), isNull);
      expect(await env.habits.logsByRange('habit-reading', range), isEmpty);
      expect(find.text('Đã xóa "Đọc sách 20 phút"'), findsOneWidget);
    });
  });
}
