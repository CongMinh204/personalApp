import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/models/habit.dart';
import 'package:personal_app/features/habits/habit_archived_screen.dart';
import 'package:personal_app/features/habits/habit_detail_screen.dart';
import 'package:personal_app/features/habits/habit_edit_screen.dart';
import 'package:personal_app/features/habits/habits_screen.dart';

import '../tasks/tasks_test_env.dart';

void main() {
  late TasksEnv env;

  /// Dữ liệu mẫu của app (tính theo Thứ Năm 29/10/2026): 5 thói quen có lịch hôm
  /// nay (nước 5/8, đọc sách xong, chạy bộ chưa, ôn Flutter chưa, ngủ sớm xong)
  /// và "Tập gym" chỉ T2·T4·T6 nên hôm nay nghỉ.
  Future<void> openHabits(WidgetTester tester, {bool sample = true}) async {
    env = await TasksEnv.create(sample: sample);
    await env.pump(
      tester,
      Scaffold(body: HabitsScreen(clock: () => testNow)),
      size: const Size(1170, 3000),
    );
  }

  Finder check(String name) => find.byTooltip('Hoàn thành: $name');
  Finder uncheck(String name) => find.byTooltip('Bỏ đánh dấu: $name');
  Finder plusOne(String name) => find.byTooltip('Thêm một lần: $name');

  group('hiển thị', () {
    testWidgets(
      'tiêu đề, ngày và ô "Thói quen hôm nay" chỉ tính ngày có lịch',
      (tester) async {
        await openHabits(tester);

        expect(find.text('Thói quen'), findsOneWidget);
        expect(find.text('Thứ Năm, 29 tháng 10'), findsOneWidget);
        expect(find.text('Thói quen hôm nay'), findsOneWidget);
        expect(find.text('2/5'), findsOneWidget);
        expect(find.text('Còn 3 thói quen cần làm'), findsOneWidget);
      },
    );

    testWidgets('mỗi thói quen có tên, chuỗi ngày và tiến độ', (tester) async {
      await openHabits(tester);

      for (final name in [
        'Uống 2 lít nước',
        'Đọc sách 20 phút',
        'Chạy bộ 30 phút',
        'Ôn Flutter 1 giờ',
        'Ngủ trước 23:00',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('12 ngày'), findsOneWidget); // nước
      expect(find.text('9 ngày'), findsOneWidget); // đọc sách
      expect(find.text('4 ngày'), findsOneWidget); // chạy bộ
      expect(find.text('5 ngày'), findsOneWidget); // ôn Flutter
      expect(find.text('3 ngày'), findsOneWidget); // ngủ sớm
      expect(find.text('5/8 ly'), findsOneWidget);
      expect(find.text('Đã xong'), findsNWidgets(2));
      expect(find.text('Chưa làm'), findsNWidgets(2));
    });

    testWidgets('thói quen không có lịch hôm nay mờ đi, ở cuối, nút bị tắt', (
      tester,
    ) async {
      await openHabits(tester);

      expect(find.text('Tập gym'), findsOneWidget);
      expect(find.text('T2 · T4 · T6 · Hôm nay nghỉ'), findsOneWidget);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Không có lịch hôm nay'),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);
      // Nằm sau các thói quen có lịch.
      final gymY = tester.getTopLeft(find.text('Tập gym')).dy;
      final sleepY = tester.getTopLeft(find.text('Ngủ trước 23:00')).dy;
      expect(gymY, greaterThan(sleepY));
    });

    testWidgets('chưa có thói quen nào thì hiện trạng thái trống', (
      tester,
    ) async {
      await openHabits(tester, sample: false);

      expect(find.text('Chưa có thói quen nào'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Thêm thói quen'),
        findsOneWidget,
      );
      expect(find.text('Thói quen hôm nay'), findsNothing);
    });
  });

  group('chấm trong ngày', () {
    testWidgets(
      'mục tiêu 1 lần: bấm là xong, chuỗi và tiến độ tăng, bấm lại là bỏ xong',
      (tester) async {
        await openHabits(tester);

        await tester.tap(check('Chạy bộ 30 phút'));
        await tester.pumpAndSettle();
        expect(find.text('3/5'), findsOneWidget);
        expect(
          find.text('5 ngày'),
          findsNWidgets(2),
        ); // chạy bộ 4 -> 5, ôn Flutter 5
        expect(find.text('Đã xong'), findsNWidgets(3));
        expect(
          await env.habits.watchCountsOn(testNow).first,
          containsPair('habit-running', 1),
        );

        await tester.tap(uncheck('Chạy bộ 30 phút'));
        await tester.pumpAndSettle();
        expect(find.text('2/5'), findsOneWidget);
        expect(find.text('4 ngày'), findsOneWidget);
        expect(find.text('Chưa làm'), findsNWidgets(2));
      },
    );

    testWidgets(
      'mục tiêu nhiều lần: mỗi lần bấm cộng 1, đủ thì xong, đủ rồi bấm là về 0',
      (tester) async {
        await openHabits(tester);

        await tester.tap(plusOne('Uống 2 lít nước'));
        await tester.pumpAndSettle();
        expect(find.text('6/8 ly'), findsOneWidget);
        expect(find.text('2/5'), findsOneWidget); // chưa đủ

        await tester.tap(plusOne('Uống 2 lít nước'));
        await tester.pumpAndSettle();
        await tester.tap(plusOne('Uống 2 lít nước'));
        await tester.pumpAndSettle();
        expect(find.text('8/8 ly'), findsOneWidget);
        expect(find.text('3/5'), findsOneWidget);
        expect(find.text('13 ngày'), findsOneWidget); // chuỗi 12 + hôm nay

        await tester.tap(uncheck('Uống 2 lít nước'));
        await tester.pumpAndSettle();
        expect(find.text('0/8 ly'), findsOneWidget);
        expect(find.text('2/5'), findsOneWidget);
        expect(find.text('12 ngày'), findsOneWidget);
      },
    );

    testWidgets('xong hết thì hiện lời chúc', (tester) async {
      await openHabits(tester);

      await tester.tap(check('Chạy bộ 30 phút'));
      await tester.pumpAndSettle();
      await tester.tap(check('Ôn Flutter 1 giờ'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(plusOne('Uống 2 lít nước'));
        await tester.pumpAndSettle();
      }

      expect(find.text('5/5'), findsOneWidget);
      expect(
        find.text('Tuyệt vời! Bạn đã hoàn thành hết hôm nay'),
        findsOneWidget,
      );
    });
  });

  group('cập nhật trực tiếp', () {
    testWidgets('thói quen mới thêm khi màn đang mở thì hiện ra', (
      tester,
    ) async {
      await openHabits(tester, sample: false);

      await env.habits.add(
        Habit(id: 'moi', name: 'Thiền sáng', startDate: DateTime(2026, 10, 1)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thiền sáng'), findsOneWidget);
      expect(find.text('Chưa có thói quen nào'), findsNothing);
      expect(find.text('0/1'), findsOneWidget);
    });

    testWidgets('lưu trữ một thói quen thì nó biến khỏi danh sách', (
      tester,
    ) async {
      await openHabits(tester);

      await env.habits.setArchived('habit-water', true);
      await tester.pumpAndSettle();

      expect(find.text('Uống 2 lít nước'), findsNothing);
      expect(find.text('2/4'), findsOneWidget); // còn 4 thói quen có lịch
    });
  });

  group('điều hướng', () {
    testWidgets('nút Thêm thói quen mở form thêm', (tester) async {
      await openHabits(tester);

      await tester.tap(find.byTooltip('Thêm thói quen'));
      await tester.pumpAndSettle();

      expect(find.byType(HabitEditScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Thêm thói quen'), findsOneWidget);
    });

    testWidgets('nút "Thêm thói quen" ở màn trống cũng mở form thêm', (
      tester,
    ) async {
      await openHabits(tester, sample: false);

      await tester.tap(find.widgetWithText(FilledButton, 'Thêm thói quen'));
      await tester.pumpAndSettle();

      expect(find.byType(HabitEditScreen), findsOneWidget);
    });

    testWidgets('nút Đã lưu trữ mở danh sách đã lưu trữ', (tester) async {
      await openHabits(tester);

      await tester.tap(find.byTooltip('Đã lưu trữ'));
      await tester.pumpAndSettle();

      expect(find.byType(HabitArchivedScreen), findsOneWidget);
    });

    testWidgets('bấm vào một thói quen mở Chi tiết của nó', (tester) async {
      await openHabits(tester);

      await tester.tap(find.text('Đọc sách 20 phút'));
      await tester.pumpAndSettle();

      expect(find.byType(HabitDetailScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Chi tiết'), findsOneWidget);
      expect(find.text('Đọc sách 20 phút'), findsOneWidget);
    });
  });
}
