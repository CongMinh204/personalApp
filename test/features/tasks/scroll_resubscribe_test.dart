import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/app/routes.dart';
import 'package:personal_app/features/settings/settings_screen.dart';
import 'package:personal_app/features/tasks/task_edit_screen.dart';

import 'tasks_test_env.dart';

/// Hồi quy: cuộn một phần của form ra khỏi màn hình rồi cuộn lại làm widget
/// bị tạo lại và nghe lại luồng dữ liệu. Luồng đọc từ repository phải nghe lại
/// được, nếu không màn hình hiện lỗi "Stream has already been listened to".
void main() {
  // Màn hình thấp (390x400) để form và Cài đặt buộc phải cuộn.
  const shortScreen = Size(1170, 1200);

  testWidgets('form Thêm việc: cuộn qua phần Nhãn rồi cuộn lại không lỗi', (
    tester,
  ) async {
    final env = await TasksEnv.create();
    await env.open(
      tester,
      AppRoutes.taskEdit,
      arguments: DateTime(2026, 10, 29),
      size: shortScreen,
    );
    final list = find.byType(Scrollable).first;

    // Cuộn xuống tới việc con (phần Nhãn ra khỏi màn hình), rồi lên lại.
    await tester.drag(list, const Offset(0, -2500));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Thêm việc con'), findsOneWidget);
    await tester.drag(list, const Offset(0, 2500));
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, 700));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('form: các chip nhãn không biến mất khi gõ tiêu đề', (
    tester,
  ) async {
    final env = await TasksEnv.create();
    await env.openScreen(
      tester,
      TaskEditScreen(initialDate: DateTime(2026, 10, 29)),
    );
    expect(find.widgetWithText(ChoiceChip, 'Học tập'), findsOneWidget);

    // Mỗi lần gõ, form dựng lại; luồng nhãn không được tạo lại và làm chip
    // nhấp nháy mất.
    await tester.enterText(find.byType(TextField).first, 'A');
    expect(find.widgetWithText(ChoiceChip, 'Học tập'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'AB');
    expect(find.widgetWithText(ChoiceChip, 'Học tập'), findsOneWidget);
  });

  testWidgets('Cài đặt: cuộn qua dòng Quản lý nhãn rồi cuộn lại không lỗi', (
    tester,
  ) async {
    final env = await TasksEnv.create();
    await env.openScreen(tester, const SettingsScreen(), size: shortScreen);
    final list = find.byType(Scrollable).first;

    await tester.drag(list, const Offset(0, -3000));
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('4 nhãn'), findsOneWidget);
  });

  group('bàn phím và con trỏ ở ô Tiêu đề', () {
    // Ô nhập đầu tiên của form là ô Tiêu đề.
    bool titleFocused(WidgetTester tester) => tester
        .widget<EditableText>(find.byType(EditableText).first)
        .focusNode
        .hasFocus;

    testWidgets('mở form thêm việc thì con trỏ ở ô Tiêu đề một lần', (
      tester,
    ) async {
      final env = await TasksEnv.create();
      await env.open(
        tester,
        AppRoutes.taskEdit,
        arguments: DateTime(2026, 10, 29),
        size: shortScreen,
      );

      expect(titleFocused(tester), isTrue);
    });

    testWidgets('cuộn ra rồi cuộn lại không tự đòi lại con trỏ và bàn phím', (
      tester,
    ) async {
      final env = await TasksEnv.create();
      await env.open(
        tester,
        AppRoutes.taskEdit,
        arguments: DateTime(2026, 10, 29),
        size: shortScreen,
      );
      final list = find.byType(Scrollable).first;

      // Người dùng ẩn bàn phím, cuộn xuống rồi cuộn lên lại.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(titleFocused(tester), isFalse);
      await tester.drag(list, const Offset(0, -2500));
      await tester.pumpAndSettle();
      await tester.drag(list, const Offset(0, 2500));
      await tester.pumpAndSettle();

      expect(titleFocused(tester), isFalse);
    });

    testWidgets('sửa việc có sẵn thì không tự bật bàn phím khi mở', (
      tester,
    ) async {
      final env = await TasksEnv.create();
      await env.tasks.add(testTask('a', title: 'Việc cũ'));
      await env.open(tester, AppRoutes.taskEdit, arguments: 'a');

      expect(titleFocused(tester), isFalse);
    });
  });
}
