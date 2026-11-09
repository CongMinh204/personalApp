import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/habits/habit_detail_screen.dart';
import 'package:personal_app/features/habits/habit_edit_screen.dart';

import '../tasks/tasks_test_env.dart';

void main() {
  late TasksEnv env;

  /// Dữ liệu mẫu (tính theo Thứ Năm 29/10/2026), thói quen "Uống 2 lít nước":
  /// mục tiêu 8 ly, bắt đầu 19/09; làm đủ 01–15/10 và 17–28/10 (ngày 16 bỏ lỡ),
  /// hôm nay mới 5/8. Chuỗi 12, dài nhất 15, hoàn thành 27/41 = 66%.
  Future<void> openDetail(
    WidgetTester tester,
    String id, {
    Map<String, Object> prefs = const {},
  }) async {
    env = await TasksEnv.create(sample: true, prefs: prefs);
    await env.openScreen(
      tester,
      HabitDetailScreen(habitId: id, clock: () => testNow),
      size: const Size(1170, 3200),
    );
  }

  /// Giá trị của một ô số ("Chuỗi hiện tại", "Dài nhất", "Hoàn thành").
  Finder stat(String label, String value) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(Card)).first,
    matching: find.text(value),
  );

  Finder day(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  );

  Finder dayCell(int d, {int month = 10}) => find.byKey(
    ValueKey(
      'day-2026-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
    ),
  );

  Future<int> countOn(String id, DateTime d) async =>
      (await env.habits.watchCountsOn(d).first)[id] ?? 0;

  group('thông tin', () {
    testWidgets('tên, mô tả và ba ô số', (tester) async {
      await openDetail(tester, 'habit-water');

      expect(find.widgetWithText(AppBar, 'Chi tiết'), findsOneWidget);
      expect(find.text('Uống 2 lít nước'), findsOneWidget);
      expect(find.text('Mỗi ngày · 8 ly · nhắc lúc 20:00'), findsOneWidget);
      expect(stat('Chuỗi hiện tại', '12'), findsOneWidget);
      expect(stat('Dài nhất', '15'), findsOneWidget);
      expect(stat('Hoàn thành', '66'), findsOneWidget);
    });

    testWidgets('thói quen theo thứ ghi các thứ trong mô tả', (tester) async {
      await openDetail(tester, 'habit-gym');

      expect(find.text('T2 · T4 · T6'), findsOneWidget);
    });

    testWidgets('thói quen không tồn tại', (tester) async {
      await openDetail(tester, 'khong-co');

      expect(find.text('Thói quen này không còn tồn tại'), findsOneWidget);
      expect(find.byTooltip('Sửa thói quen'), findsNothing);
    });
  });

  group('lịch tháng', () {
    testWidgets('tiêu đề, chú thích và hàng thứ bắt đầu từ T2', (tester) async {
      await openDetail(tester, 'habit-water');

      expect(find.text('Tháng 10, 2026'), findsOneWidget);
      expect(find.text('Đã làm'), findsOneWidget); // chú thích
      expect(find.text('Bỏ lỡ'), findsOneWidget); // chú thích
      final headers = [
        for (final h in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
          tester.getCenter(find.text(h)).dx,
      ];
      expect(headers, orderedEquals([...headers]..sort()));
    });

    testWidgets('ngày 1 nằm đúng cột Thứ Năm (3 ô đệm đầu tháng)', (
      tester,
    ) async {
      await openDetail(tester, 'habit-water');

      final cell = tester.getCenter(dayCell(1)).dx;
      final thursday = tester.getCenter(find.text('T5')).dx;
      expect((cell - thursday).abs(), lessThan(2));
    });

    testWidgets('trạng thái các ngày: đã làm, bỏ lỡ, hôm nay, chưa tới', (
      tester,
    ) async {
      await openDetail(tester, 'habit-water');

      expect(day('Ngày 1, Đã làm'), findsOneWidget);
      expect(day('Ngày 15, Đã làm'), findsOneWidget);
      expect(day('Ngày 16, Bỏ lỡ'), findsOneWidget);
      expect(day('Ngày 17, Đã làm'), findsOneWidget);
      expect(day('Ngày 28, Đã làm'), findsOneWidget);
      expect(day('Ngày 29, Hôm nay chưa làm'), findsOneWidget);
      expect(day('Ngày 30, Chưa tới'), findsOneWidget);
      expect(day('Ngày 31, Chưa tới'), findsOneWidget);
    });

    testWidgets('ngày không có lịch hiện là "Không có lịch"', (tester) async {
      await openDetail(tester, 'habit-gym'); // chỉ T2, T4, T6

      expect(day('Ngày 27, Không có lịch'), findsOneWidget); // Thứ Ba
      expect(day('Ngày 28, Đã làm'), findsOneWidget); // Thứ Tư
      expect(day('Ngày 29, Không có lịch'), findsOneWidget); // hôm nay, Thứ Năm
    });

    testWidgets('chuyển về tháng trước tới tháng bắt đầu rồi dừng', (
      tester,
    ) async {
      await openDetail(tester, 'habit-water'); // bắt đầu 19/09

      await tester.tap(find.byTooltip('Tháng trước'));
      await tester.pumpAndSettle();

      expect(find.text('Tháng 9, 2026'), findsOneWidget);
      expect(
        day('Ngày 18, Không có lịch'),
        findsOneWidget,
      ); // trước ngày bắt đầu
      expect(day('Ngày 19, Bỏ lỡ'), findsOneWidget); // ngày bắt đầu, chưa làm
      expect(day('Ngày 30, Bỏ lỡ'), findsOneWidget);
      final previous = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Tháng trước'),
          matching: find.byType(IconButton),
        ),
      );
      expect(previous.onPressed, isNull);
    });

    testWidgets('tiến tới tháng hiện tại thì dừng', (tester) async {
      await openDetail(tester, 'habit-water');
      final next = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Tháng sau'),
          matching: find.byType(IconButton),
        ),
      );
      expect(next.onPressed, isNull);

      await tester.tap(find.byTooltip('Tháng trước'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tháng sau'));
      await tester.pumpAndSettle();

      expect(find.text('Tháng 10, 2026'), findsOneWidget);
    });

    testWidgets('tuần bắt đầu từ Chủ Nhật theo Cài đặt', (tester) async {
      await openDetail(tester, 'habit-water', prefs: {'week_start': 7});

      final headers = [
        for (final h in ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'])
          tester.getCenter(find.text(h)).dx,
      ];
      expect(headers, orderedEquals([...headers]..sort()));
      // 01/10 là Thứ Năm: tuần bắt đầu CN nên nằm ở cột thứ 5.
      expect(
        (tester.getCenter(dayCell(1)).dx - tester.getCenter(find.text('T5')).dx)
            .abs(),
        lessThan(2),
      );
    });
  });

  group('4 tuần gần nhất', () {
    testWidgets('nhãn tuần và tỷ lệ từng tuần', (tester) async {
      await openDetail(tester, 'habit-water');

      expect(find.text('4 tuần gần nhất'), findsOneWidget);
      for (final label in ['5/10', '12/10', '19/10', 'Tuần này']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // 05–11/10: 7/7 ; 12–18/10: 6/7 ; 19–25/10: 7/7 ; tuần này: 3/4.
      expect(find.text('100%'), findsNWidgets(2));
      expect(find.text('86%'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('ngày đầu tuần là Chủ Nhật thì đổi nhãn tuần', (tester) async {
      await openDetail(tester, 'habit-water', prefs: {'week_start': 7});

      for (final label in ['4/10', '11/10', '18/10', 'Tuần này']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });
  });

  group('chấm hôm nay', () {
    testWidgets(
      'nút "Đánh dấu hôm nay đã làm" xong cả mục tiêu, bấm lại là bỏ',
      (tester) async {
        await openDetail(tester, 'habit-water');
        expect(find.text('Đánh dấu hôm nay đã làm'), findsOneWidget);

        await tester.tap(find.text('Đánh dấu hôm nay đã làm'));
        await tester.pumpAndSettle();

        expect(await countOn('habit-water', testNow), 8);
        expect(find.text('Hôm nay đã xong · bấm để bỏ'), findsOneWidget);
        expect(stat('Chuỗi hiện tại', '13'), findsOneWidget);
        expect(stat('Hoàn thành', '68'), findsOneWidget); // 28/41
        expect(day('Ngày 29, Đã làm'), findsOneWidget);
        expect(find.text('100%'), findsNWidgets(3)); // tuần này thành 4/4

        await tester.tap(find.text('Hôm nay đã xong · bấm để bỏ'));
        await tester.pumpAndSettle();

        expect(await countOn('habit-water', testNow), 0);
        expect(find.text('Đánh dấu hôm nay đã làm'), findsOneWidget);
        expect(stat('Chuỗi hiện tại', '12'), findsOneWidget);
      },
    );

    testWidgets('thói quen không có lịch hôm nay thì nút bị tắt', (
      tester,
    ) async {
      await openDetail(tester, 'habit-gym');

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Hôm nay không có lịch'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('chấm ở nơi khác khi màn đang mở thì cập nhật ngay', (
      tester,
    ) async {
      await openDetail(tester, 'habit-running');
      expect(stat('Chuỗi hiện tại', '4'), findsOneWidget);

      await env.habits.setCount('habit-running', testNow, 1);
      await tester.pumpAndSettle();

      expect(stat('Chuỗi hiện tại', '5'), findsOneWidget);
      expect(find.text('Hôm nay đã xong · bấm để bỏ'), findsOneWidget);
    });
  });

  group('bổ sung ngày đã qua', () {
    testWidgets(
      'chạm ngày bỏ lỡ thì thành đã làm, chuỗi và tỷ lệ tự tính lại',
      (tester) async {
        await openDetail(tester, 'habit-water');

        await tester.tap(dayCell(16)); // ngày bỏ lỡ duy nhất trong tháng
        await tester.pumpAndSettle();

        expect(day('Ngày 16, Đã làm'), findsOneWidget);
        expect(await countOn('habit-water', DateTime(2026, 10, 16)), 8);
        // 01–28/10 liền nhau: chuỗi 28, dài nhất 28; hoàn thành 28/41 = 68%.
        expect(stat('Chuỗi hiện tại', '28'), findsOneWidget);
        expect(stat('Dài nhất', '28'), findsOneWidget);
        expect(stat('Hoàn thành', '68'), findsOneWidget);
      },
    );

    testWidgets('chạm lại ngày đã làm thì bỏ đánh dấu', (tester) async {
      await openDetail(tester, 'habit-water');

      await tester.tap(dayCell(20));
      await tester.pumpAndSettle();

      expect(day('Ngày 20, Bỏ lỡ'), findsOneWidget);
      expect(await countOn('habit-water', DateTime(2026, 10, 20)), 0);
      // Đứt chuỗi: từ 21 tới 28 = 8 ngày.
      expect(stat('Chuỗi hiện tại', '8'), findsOneWidget);
    });

    testWidgets('ngày chưa tới không chạm được', (tester) async {
      await openDetail(tester, 'habit-water');

      await tester.tap(dayCell(30));
      await tester.pumpAndSettle();

      expect(await countOn('habit-water', DateTime(2026, 10, 30)), 0);
      expect(day('Ngày 30, Chưa tới'), findsOneWidget);
    });

    testWidgets('ngày không có lịch không chạm được', (tester) async {
      await openDetail(tester, 'habit-gym');

      await tester.tap(dayCell(27)); // Thứ Ba, không có lịch
      await tester.pumpAndSettle();

      expect(await countOn('habit-gym', DateTime(2026, 10, 27)), 0);
      expect(day('Ngày 27, Không có lịch'), findsOneWidget);
    });

    testWidgets('chạm ngày trong tháng trước (đổi tháng rồi chạm)', (
      tester,
    ) async {
      await openDetail(tester, 'habit-water');
      await tester.tap(find.byTooltip('Tháng trước'));
      await tester.pumpAndSettle();

      await tester.tap(dayCell(25, month: 9));
      await tester.pumpAndSettle();

      expect(day('Ngày 25, Đã làm'), findsOneWidget);
      expect(await countOn('habit-water', DateTime(2026, 9, 25)), 8);
    });
  });

  group('sửa từ Chi tiết', () {
    testWidgets('nút bút mở form Sửa, lưu xong Chi tiết cập nhật tên', (
      tester,
    ) async {
      await openDetail(tester, 'habit-water');

      await tester.tap(find.byTooltip('Sửa thói quen'));
      await tester.pumpAndSettle();
      expect(find.byType(HabitEditScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Uống đủ nước');
      await tester.tap(find.widgetWithText(TextButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(find.byType(HabitEditScreen), findsNothing);
      expect(find.byType(HabitDetailScreen), findsOneWidget);
      expect(find.text('Uống đủ nước'), findsOneWidget);
    });

    testWidgets('Lưu trữ từ form Sửa thì Chi tiết cũng đóng', (tester) async {
      await openDetail(tester, 'habit-water');

      await tester.tap(find.byTooltip('Sửa thói quen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu trữ thói quen'));
      await tester.pumpAndSettle();

      expect(find.byType(HabitEditScreen), findsNothing);
      expect(find.byType(HabitDetailScreen), findsNothing);
      expect((await env.habits.getById('habit-water'))!.archived, isTrue);
    });

    testWidgets('Xóa từ form Sửa thì Chi tiết cũng đóng', (tester) async {
      await openDetail(tester, 'habit-water');

      await tester.tap(find.byTooltip('Sửa thói quen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa thói quen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(find.byType(HabitDetailScreen), findsNothing);
      expect(await env.habits.getById('habit-water'), isNull);
    });
  });

  testWidgets('nút quay lại đóng màn', (tester) async {
    await openDetail(tester, 'habit-water');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(HabitDetailScreen), findsNothing);
  });
}
