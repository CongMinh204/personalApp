import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/models/habit.dart';
import 'package:personal_app/features/habits/habit_archived_screen.dart';
import 'package:personal_app/utils/dates.dart';

import '../tasks/tasks_test_env.dart';

void main() {
  late TasksEnv env;

  /// Ba thói quen đã lưu trữ của dữ liệu mẫu (tính theo 29/10/2026): "Thiền 10
  /// phút" (chuỗi dài nhất 14, lưu trữ 12/10), "Học từ vựng tiếng Anh" (8,
  /// 21/09), "Không ăn vặt sau 21:00" (5, 09/09).
  Future<void> openArchived(WidgetTester tester, {bool sample = true}) async {
    env = await TasksEnv.create(sample: sample);
    await env.openScreen(tester, const HabitArchivedScreen());
  }

  testWidgets(
    'hiện lời giải thích và các thói quen đã lưu trữ, mới nhất trước',
    (tester) async {
      await openArchived(tester);

      expect(find.widgetWithText(AppBar, 'Đã lưu trữ'), findsOneWidget);
      expect(
        find.textContaining('không hiện ở danh sách và không nhắc nữa'),
        findsOneWidget,
      );
      expect(find.text('Thiền 10 phút'), findsOneWidget);
      expect(find.text('Học từ vựng tiếng Anh'), findsOneWidget);
      expect(find.text('Không ăn vặt sau 21:00'), findsOneWidget);

      final order = [
        tester.getTopLeft(find.text('Thiền 10 phút')).dy,
        tester.getTopLeft(find.text('Học từ vựng tiếng Anh')).dy,
        tester.getTopLeft(find.text('Không ăn vặt sau 21:00')).dy,
      ];
      expect(order, orderedEquals([...order]..sort()));
    },
  );

  testWidgets('mỗi dòng ghi chuỗi dài nhất và ngày lưu trữ', (tester) async {
    await openArchived(tester);

    expect(find.text('Chuỗi dài nhất 14 ngày · lưu trữ 12/10'), findsOneWidget);
    expect(find.text('Chuỗi dài nhất 8 ngày · lưu trữ 21/09'), findsOneWidget);
    expect(find.text('Chuỗi dài nhất 5 ngày · lưu trữ 09/09'), findsOneWidget);
  });

  testWidgets('thói quen đang dùng không có trong danh sách', (tester) async {
    await openArchived(tester);

    expect(find.text('Uống 2 lít nước'), findsNothing);
  });

  group('khôi phục', () {
    testWidgets('Khôi phục đưa thói quen về danh sách đang dùng', (
      tester,
    ) async {
      await openArchived(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Khôi phục').first);
      await tester.pumpAndSettle();

      expect(find.text('Thiền 10 phút'), findsNothing);
      expect(find.text('Đã khôi phục "Thiền 10 phút"'), findsOneWidget);
      final habit = (await env.habits.getById('habit-meditation'))!;
      expect(habit.archived, isFalse);
      // Lịch sử và chuỗi ngày vẫn được giữ.
      expect(await env.habits.bestStreakOf('habit-meditation'), 14);
    });

    testWidgets('khôi phục hết thì hiện trạng thái trống', (tester) async {
      await openArchived(tester);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.widgetWithText(TextButton, 'Khôi phục').first);
        await tester.pumpAndSettle();
      }

      expect(find.text('Chưa có thói quen nào được lưu trữ'), findsOneWidget);
      expect(find.text('Thói quen bạn lưu trữ sẽ nằm ở đây.'), findsOneWidget);
    });
  });

  group('xóa hẳn', () {
    testWidgets('có hộp xác nhận; Hủy thì giữ nguyên', (tester) async {
      await openArchived(tester);

      await tester.tap(find.byTooltip('Xóa hẳn Thiền 10 phút'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa hẳn thói quen này?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();

      expect(find.text('Thiền 10 phút'), findsOneWidget);
      expect(await env.habits.getById('habit-meditation'), isNotNull);
    });

    testWidgets('xác nhận thì xóa thói quen cùng nhật ký', (tester) async {
      await openArchived(tester);
      final range = daysRange(DateTime(2026, 8, 1), 100);
      expect(
        await env.habits.logsByRange('habit-meditation', range),
        isNotEmpty,
      );

      await tester.tap(find.byTooltip('Xóa hẳn Thiền 10 phút'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa hẳn'));
      await tester.pumpAndSettle();

      expect(find.text('Thiền 10 phút'), findsNothing);
      expect(find.text('Đã xóa "Thiền 10 phút"'), findsOneWidget);
      expect(await env.habits.getById('habit-meditation'), isNull);
      expect(await env.habits.logsByRange('habit-meditation', range), isEmpty);
    });
  });

  testWidgets('chưa lưu trữ thói quen nào thì hiện trạng thái trống', (
    tester,
  ) async {
    await openArchived(tester, sample: false);

    expect(find.text('Chưa có thói quen nào được lưu trữ'), findsOneWidget);
  });

  testWidgets('thói quen vừa được lưu trữ khi màn đang mở thì hiện ra', (
    tester,
  ) async {
    await openArchived(tester, sample: false);

    await env.habits.add(_habit('moi', 'Thiền sáng'));
    await env.habits.setArchived('moi', true);
    await tester.pumpAndSettle();

    expect(find.text('Thiền sáng'), findsOneWidget);
    expect(find.text('Chưa có thói quen nào được lưu trữ'), findsNothing);
  });

  testWidgets('nút quay lại đóng màn', (tester) async {
    await openArchived(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(HabitArchivedScreen), findsNothing);
  });
}

Habit _habit(String id, String name) =>
    Habit(id: id, name: name, startDate: DateTime(2026, 10, 1));
