import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/app/shell_controller.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/features/calendar/calendar_logic.dart';
import 'package:personal_app/features/calendar/calendar_screen.dart';
import 'package:personal_app/features/tasks/task_detail_screen.dart';
import 'package:personal_app/features/tasks/task_edit_screen.dart';
import 'package:personal_app/features/today/widgets/task_tile.dart';

import '../tasks/tasks_test_env.dart';

// Dữ liệu mẫu theo testNow (Thứ Năm 29/10/2026 13:40):
// - 29/10: Chạy bộ 06:00 (xong), Mua sữa và trứng (cả ngày, xong),
//   Họp nhóm EXE201 14:00–15:00, Ôn tập PE Flutter 19:30–21:00.
// - 28/10: Nộp báo cáo Lab 3 23:59 (quá hạn) và Chạy bộ (xong).
// - 31/10: Thi giữa kỳ PRM393 08:00. 3/11: Sinh nhật mẹ (cả ngày).
// - 30/10 trống.
void main() {
  late TasksEnv env;

  /// Màn cao để mọi phần của tab Lịch đều nằm trong màn hình khi bấm.
  const tall = Size(1170, 7000);

  Future<void> openCalendar(
    WidgetTester tester, {
    bool sample = true,
    Map<String, Object> prefs = const {},
    Size size = tall,
  }) async {
    env = await TasksEnv.create(sample: sample, prefs: prefs);
    await env.pump(tester, CalendarScreen(clock: () => testNow), size: size);
  }

  Finder cell(DateTime day) => find.byKey(
    ValueKey(
      'cal-${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}',
    ),
  );

  Finder dot(String key) => find.byKey(ValueKey('dot-$key'));

  Finder tile(String id) =>
      find.byWidgetPredicate((w) => w is TaskTile && w.task.id == id);

  Future<void> tapDay(WidgetTester tester, DateTime day) async {
    await tester.tap(cell(day));
    await tester.pumpAndSettle();
  }

  Future<void> tapTooltip(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  Future<void> tapMode(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<CalendarMode>),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('mở tab', () {
    testWidgets('tháng hiện tại, chọn sẵn hôm nay', (tester) async {
      await openCalendar(tester);

      expect(find.text('Tháng 10, 2026'), findsOneWidget);
      expect(find.text('Hôm nay · Thứ Năm, 29/10'), findsOneWidget);
      expect(find.text('4 việc'), findsOneWidget);
      // Lưới tháng 5 hàng: 28/9 tới 1/11.
      expect(cell(DateTime(2026, 9, 28)), findsOneWidget);
      expect(cell(DateTime(2026, 11, 1)), findsOneWidget);
      expect(cell(DateTime(2026, 9, 27)), findsNothing);
      expect(
        tester.getSemantics(cell(DateTime(2026, 10, 29))),
        matchesSemantics(
          label: 'Ngày 29 tháng 10, hôm nay, 4 việc',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('chấm dưới các ngày có việc', (tester) async {
      await openCalendar(tester);

      expect(dot('2026-10-29'), findsOneWidget);
      expect(dot('2026-10-28'), findsOneWidget);
      expect(dot('2026-10-31'), findsOneWidget);
      expect(dot('2026-10-30'), findsNothing);
      expect(dot('2026-10-01'), findsNothing);
    });

    testWidgets('tuần bắt đầu Chủ Nhật theo Cài đặt', (tester) async {
      await openCalendar(tester, prefs: {'week_start': 7});

      expect(cell(DateTime(2026, 9, 27)), findsOneWidget);
      expect(cell(DateTime(2026, 10, 31)), findsOneWidget);
      expect(cell(DateTime(2026, 11, 1)), findsNothing);
      // Cột đầu là CN.
      expect(
        tester.getTopLeft(find.text('CN')).dx,
        lessThan(tester.getTopLeft(find.text('T2')).dx),
      );
    });
  });

  group('việc của ngày đang chọn', () {
    testWidgets('việc cả ngày, dải giờ và vạch giờ hiện tại', (tester) async {
      await openCalendar(tester);

      expect(find.text('Không có giờ:'), findsOneWidget);
      expect(find.byKey(const ValueKey('allday-groceries')), findsOneWidget);
      for (final id in ['running', 'exe201', 'pe-flutter']) {
        expect(find.byKey(ValueKey('block-$id')), findsOneWidget, reason: id);
      }
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('22:00'), findsOneWidget);
      expect(find.byKey(const ValueKey('now-line')), findsOneWidget);
      // Khối 14:00–15:00 nằm trên khối 19:30–21:00.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('block-exe201'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('block-pe-flutter'))).dy,
        ),
      );
    });

    testWidgets('danh sách việc của ngày: chưa xong trước, theo giờ', (
      tester,
    ) async {
      await openCalendar(tester);

      expect(find.text('Việc trong ngày'), findsOneWidget);
      expect(find.byType(TaskTile), findsNWidgets(4));
      final order = ['exe201', 'pe-flutter', 'running', 'groceries'];
      for (var i = 1; i < order.length; i++) {
        expect(
          tester.getTopLeft(tile(order[i - 1])).dy,
          lessThan(tester.getTopLeft(tile(order[i])).dy),
          reason: '${order[i - 1]} trước ${order[i]}',
        );
      }
      // Ngày đã ghi ở tiêu đề nên danh sách chỉ ghi giờ.
      expect(
        find.descendant(
          of: tile('exe201'),
          matching: find.text('14:00 – 15:00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile('groceries'), matching: find.text('Cả ngày')),
        findsOneWidget,
      );
    });

    testWidgets('chọn ngày khác: đổi tiêu đề, dải giờ và danh sách', (
      tester,
    ) async {
      await openCalendar(tester);

      await tapDay(tester, DateTime(2026, 10, 31));

      expect(find.text('Thứ Bảy, 31/10'), findsOneWidget);
      expect(find.text('1 việc'), findsOneWidget);
      expect(find.byKey(const ValueKey('block-midterm')), findsOneWidget);
      expect(find.byType(TaskTile), findsOneWidget);
      expect(
        find.descendant(of: tile('midterm'), matching: find.text('08:00')),
        findsOneWidget,
      );
      expect(find.text('Không có giờ:'), findsNothing);
      // Không phải hôm nay: không có vạch giờ hiện tại.
      expect(find.byKey(const ValueKey('now-line')), findsNothing);
      expect(
        tester.getSemantics(cell(DateTime(2026, 10, 31))),
        matchesSemantics(
          label: 'Ngày 31 tháng 10, 1 việc',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('ngày đã qua: việc chưa xong hiện là quá hạn', (tester) async {
      await openCalendar(tester);

      await tapDay(tester, DateTime(2026, 10, 28));

      expect(find.text('Thứ Tư, 28/10'), findsOneWidget);
      expect(tester.widget<TaskTile>(tile('lab3')).overdue, isTrue);
      expect(tester.widget<TaskTile>(tile('running-1')).overdue, isFalse);
    });

    testWidgets('ngày trống: "Ngày này còn trống" và nút thêm việc', (
      tester,
    ) async {
      await openCalendar(tester);

      await tapDay(tester, DateTime(2026, 10, 30));

      expect(find.text('Thứ Sáu, 30/10'), findsOneWidget);
      expect(find.text('Ngày này còn trống'), findsOneWidget);
      expect(find.byType(TaskTile), findsNothing);
      expect(find.text('Thêm việc vào ngày này'), findsOneWidget);
    });

    testWidgets('thêm việc vào ngày trống: form điền sẵn ngày, lưu xong '
        'việc hiện ngay ở ngày đó', (tester) async {
      await openCalendar(tester);
      await tapDay(tester, DateTime(2026, 10, 30));

      await tester.tap(find.text('Thêm việc vào ngày này'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditScreen), findsOneWidget);
      expect(
        tester.widget<TaskEditScreen>(find.byType(TaskEditScreen)).initialDate,
        DateTime(2026, 10, 30),
      );
      expect(find.text('Th 6, 30/10/2026'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Mua quà');
      await tester.tap(find.widgetWithText(TextButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditScreen), findsNothing);
      expect(find.text('Thứ Sáu, 30/10'), findsOneWidget);
      expect(find.text('1 việc'), findsOneWidget);
      expect(find.text('Ngày này còn trống'), findsNothing);
      expect(find.text('Mua quà'), findsWidgets);
      expect(dot('2026-10-30'), findsOneWidget);
    });

    testWidgets('ngày có việc vẫn có nút thêm việc vào ngày đó', (
      tester,
    ) async {
      await openCalendar(tester);
      await tapDay(tester, DateTime(2026, 10, 31));

      await tester.tap(find.text('Thêm việc vào ngày này'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TaskEditScreen>(find.byType(TaskEditScreen)).initialDate,
        DateTime(2026, 10, 31),
      );
    });

    testWidgets('việc thêm từ nơi khác hiện ngay trên lịch', (tester) async {
      await openCalendar(tester);
      await tapDay(tester, DateTime(2026, 10, 30));
      expect(find.text('Ngày này còn trống'), findsOneWidget);

      await env.tasks.add(
        testTask('new', title: 'Đi khám', due: DateTime(2026, 10, 30)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ngày này còn trống'), findsNothing);
      expect(tile('new'), findsOneWidget);
      expect(dot('2026-10-30'), findsOneWidget);
    });
  });

  group('thao tác với việc', () {
    testWidgets('đánh dấu xong ngay trong danh sách', (tester) async {
      await openCalendar(tester);

      await tester.tap(
        find.descendant(of: tile('exe201'), matching: find.byType(Checkbox)),
      );
      await tester.pumpAndSettle();

      expect((await env.tasks.getById('exe201'))!.done, isTrue);
      // Việc đã xong xuống cuối nhóm chưa xong.
      expect(
        tester.getTopLeft(tile('pe-flutter')).dy,
        lessThan(tester.getTopLeft(tile('exe201')).dy),
      );
    });

    testWidgets('xong việc lặp lại: báo đã tạo lần kế tiếp, ngày mai có chấm', (
      tester,
    ) async {
      await openCalendar(tester);
      await env.tasks.add(
        testTask(
          'pill',
          title: 'Uống thuốc',
          due: DateTime(2026, 10, 29, 8),
          hasTime: true,
          repeat: RepeatRule.daily,
        ),
      );
      await tester.pumpAndSettle();
      expect(dot('2026-10-30'), findsNothing);

      await tester.tap(
        find.descendant(of: tile('pill'), matching: find.byType(Checkbox)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã tạo việc lặp kế tiếp'), findsOneWidget);
      expect(dot('2026-10-30'), findsOneWidget);
    });

    testWidgets('bấm việc trong danh sách mở Chi tiết việc', (tester) async {
      await openCalendar(tester);

      await tester.tap(
        find.descendant(
          of: tile('pe-flutter'),
          matching: find.text('Ôn tập PE Flutter (form validate)'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailScreen), findsOneWidget);
      expect(
        tester.widget<TaskDetailScreen>(find.byType(TaskDetailScreen)).taskId,
        'pe-flutter',
      );
    });

    testWidgets('bấm khối trên dải giờ mở Chi tiết việc', (tester) async {
      await openCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('block-exe201')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TaskDetailScreen>(find.byType(TaskDetailScreen)).taskId,
        'exe201',
      );
    });

    testWidgets('bấm việc cả ngày mở Chi tiết việc', (tester) async {
      await openCalendar(tester);

      await tester.tap(find.byKey(const ValueKey('allday-groceries')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TaskDetailScreen>(find.byType(TaskDetailScreen)).taskId,
        'groceries',
      );
    });

    testWidgets('nút đồng hồ chọn sẵn việc và mở tab Hẹn giờ', (tester) async {
      await openCalendar(tester);

      await tester.tap(find.byTooltip('Bấm giờ tập trung: Họp nhóm EXE201'));
      await tester.pumpAndSettle();

      expect(env.shell.tab, HomeTab.timer);
      expect(env.timer.preparedTaskId, 'exe201');
    });
  });

  group('chuyển tháng, tuần', () {
    testWidgets('◀ ▶ đổi tháng; về tháng này thì chọn lại hôm nay', (
      tester,
    ) async {
      await openCalendar(tester);

      await tapTooltip(tester, 'Tháng sau');
      expect(find.text('Tháng 11, 2026'), findsOneWidget);
      expect(find.text('Chủ Nhật, 1/11'), findsOneWidget);
      expect(dot('2026-11-03'), findsOneWidget);

      await tapTooltip(tester, 'Tháng trước');
      expect(find.text('Tháng 10, 2026'), findsOneWidget);
      expect(find.text('Hôm nay · Thứ Năm, 29/10'), findsOneWidget);

      await tapTooltip(tester, 'Tháng trước');
      expect(find.text('Tháng 9, 2026'), findsOneWidget);
      expect(find.text('Thứ Ba, 1/9'), findsOneWidget);
      expect(find.text('Ngày này còn trống'), findsOneWidget);
    });

    testWidgets('nút Hôm nay quay về hôm nay', (tester) async {
      await openCalendar(tester);
      await tapTooltip(tester, 'Tháng sau');
      await tapTooltip(tester, 'Tháng sau');
      expect(find.text('Tháng 12, 2026'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Hôm nay'));
      await tester.pumpAndSettle();

      expect(find.text('Tháng 10, 2026'), findsOneWidget);
      expect(find.text('Hôm nay · Thứ Năm, 29/10'), findsOneWidget);
      expect(find.text('4 việc'), findsOneWidget);
    });

    testWidgets('bấm ngày mờ của tháng sau thì sang tháng đó', (tester) async {
      await openCalendar(tester);

      await tapDay(tester, DateTime(2026, 11, 1));

      expect(find.text('Tháng 11, 2026'), findsOneWidget);
      expect(find.text('Chủ Nhật, 1/11'), findsOneWidget);
      // Lưới tháng 11 bắt đầu từ Thứ Hai 26/10.
      expect(cell(DateTime(2026, 10, 26)), findsOneWidget);
      expect(cell(DateTime(2026, 10, 25)), findsNothing);
    });

    testWidgets('xem Tuần: một hàng 7 ngày, ◀ ▶ lùi tiến 7 ngày', (
      tester,
    ) async {
      await openCalendar(tester);

      await tapMode(tester, 'Tuần');

      for (var d = 26; d <= 31; d++) {
        expect(cell(DateTime(2026, 10, d)), findsOneWidget, reason: '$d/10');
      }
      expect(cell(DateTime(2026, 11, 1)), findsOneWidget);
      expect(cell(DateTime(2026, 10, 25)), findsNothing);
      expect(cell(DateTime(2026, 11, 2)), findsNothing);
      expect(find.text('Hôm nay · Thứ Năm, 29/10'), findsOneWidget);
      expect(find.byTooltip('Tháng sau'), findsNothing);

      await tapTooltip(tester, 'Tuần sau');
      expect(find.text('Tháng 11, 2026'), findsOneWidget);
      expect(find.text('Thứ Năm, 5/11'), findsOneWidget);
      expect(cell(DateTime(2026, 11, 2)), findsOneWidget);
      expect(cell(DateTime(2026, 11, 8)), findsOneWidget);

      await tapTooltip(tester, 'Tuần trước');
      await tapTooltip(tester, 'Tuần trước');
      expect(find.text('Thứ Năm, 22/10'), findsOneWidget);
    });

    testWidgets('đổi Tuần ↔ Tháng giữ nguyên ngày đang chọn', (tester) async {
      await openCalendar(tester);
      await tapDay(tester, DateTime(2026, 10, 12));

      await tapMode(tester, 'Tuần');
      expect(find.text('Thứ Hai, 12/10'), findsOneWidget);
      expect(cell(DateTime(2026, 10, 18)), findsOneWidget);
      expect(cell(DateTime(2026, 10, 19)), findsNothing);

      await tapMode(tester, 'Tháng');
      expect(find.text('Thứ Hai, 12/10'), findsOneWidget);
      expect(cell(DateTime(2026, 10, 1)), findsOneWidget);
    });
  });

  group('cỡ điện thoại', () {
    testWidgets('vẽ được ở 390x844 mà không tràn, cả khi xem Tuần', (
      tester,
    ) async {
      await openCalendar(tester, size: const Size(1170, 2532));
      expect(tester.takeException(), isNull);

      await tapMode(tester, 'Tuần');
      expect(tester.takeException(), isNull);

      // Kéo xuống tới danh sách việc.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(find.text('Việc trong ngày'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chưa có việc nào: lịch trống vẫn vẽ được', (tester) async {
      await openCalendar(tester, sample: false, size: const Size(1170, 2532));

      expect(find.text('Ngày này còn trống'), findsOneWidget);
      expect(find.byKey(const ValueKey('now-line')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
