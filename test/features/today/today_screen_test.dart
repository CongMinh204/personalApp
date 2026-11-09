import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/app/shell_controller.dart';
import 'package:personal_app/data/default_tags.dart';
import 'package:personal_app/data/models/tag.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/features/tasks/task_detail_screen.dart';
import 'package:personal_app/features/tasks/task_edit_screen.dart';
import 'package:personal_app/features/today/today_screen.dart';
import 'package:personal_app/features/today/widgets/task_tile.dart';

import '../tasks/tasks_test_env.dart';

void main() {
  late TasksEnv env;

  Future<void> pumpToday(WidgetTester tester, {bool sample = true}) async {
    env = await TasksEnv.create(sample: sample);
    await env.pump(tester, TodayScreen(clock: () => testNow));
  }

  Finder checkboxOf(String title) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(TaskTile)),
    matching: find.byType(Checkbox),
  );

  group('đọc từ repository', () {
    testWidgets('hiển thị việc của repository, chia nhóm Quá hạn / Hôm nay', (
      tester,
    ) async {
      await pumpToday(tester);

      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('Quá hạn · 2'), findsOneWidget);
      expect(find.text('2/4'), findsOneWidget);
      expect(find.text('Họp nhóm EXE201'), findsOneWidget);
    });

    testWidgets('chưa có việc nào thì hiện trạng thái trống, không có nút +', (
      tester,
    ) async {
      await pumpToday(tester, sample: false);

      expect(find.text('Hôm nay chưa có việc nào'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('việc thêm vào repository sau đó cũng hiện ra', (tester) async {
      await pumpToday(tester, sample: false);

      await env.tasks.add(testTask('moi', title: 'Việc mới thêm'));
      await tester.pumpAndSettle();

      expect(find.text('Việc mới thêm'), findsOneWidget);
      expect(find.text('Hôm nay chưa có việc nào'), findsNothing);
    });

    testWidgets('tick checkbox thì lưu vào repository và tiến độ đổi', (
      tester,
    ) async {
      await pumpToday(tester);

      await tester.tap(checkboxOf('Họp nhóm EXE201'));
      await tester.pumpAndSettle();

      expect(find.text('3/4'), findsOneWidget);
      expect((await env.tasks.getById('exe201'))!.done, isTrue);
    });
  });

  group('xóa và hoàn tác', () {
    testWidgets('vuốt trái để xóa khỏi repository, "Hoàn tác" khôi phục', (
      tester,
    ) async {
      await pumpToday(tester);

      await tester.drag(
        find.byKey(const ValueKey('exe201')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Họp nhóm EXE201'), findsNothing);
      expect(find.text('2/3'), findsOneWidget);
      expect(await env.tasks.getById('exe201'), isNull);

      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();
      expect(find.text('Họp nhóm EXE201'), findsOneWidget);
      expect(find.text('2/4'), findsOneWidget);
      expect(await env.tasks.getById('exe201'), isNotNull);
    });

    testWidgets('hoàn tác khôi phục cả việc con và trạng thái của chúng', (
      tester,
    ) async {
      await pumpToday(tester);
      final before = await env.tasks.getSubtasks('pe-flutter');
      expect(before, hasLength(3));

      await tester.drag(
        find.byKey(const ValueKey('pe-flutter')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(await env.tasks.getSubtasks('pe-flutter'), isEmpty);

      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();

      final after = await env.tasks.getSubtasks('pe-flutter');
      expect(
        [for (final s in after) (s.title, s.done)],
        [for (final s in before) (s.title, s.done)],
      );
    });
  });

  group('lọc theo nhãn lấy từ repository', () {
    testWidgets('nhãn mới thêm ở Quản lý nhãn hiện ra ở thanh lọc', (
      tester,
    ) async {
      await pumpToday(tester, sample: false);
      expect(find.widgetWithText(ChoiceChip, 'Gia đình'), findsNothing);

      await env.tags.add(const Tag(id: 'gd', name: 'Gia đình'));
      await tester.pumpAndSettle();
      // Thanh lọc cuộn ngang: cuộn tới chip cuối để nó được dựng.
      await tester.drag(find.byType(ChoiceChip).first, const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'Gia đình'), findsOneWidget);
    });

    testWidgets('chọn nhãn thì chỉ hiện việc của nhãn đó', (tester) async {
      await pumpToday(tester);
      expect(find.text('Họp nhóm EXE201'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Học tập'));
      await tester.pumpAndSettle();

      expect(find.text('Họp nhóm EXE201'), findsNothing);
      expect(find.textContaining('Ôn tập PE Flutter'), findsOneWidget);
    });

    testWidgets('xóa nhãn đang lọc thì quay về Tất cả', (tester) async {
      await pumpToday(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Học tập'));
      await tester.pumpAndSettle();

      await env.tags.delete(DefaultTagIds.study);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'Học tập'), findsNothing);
      expect(find.text('Họp nhóm EXE201'), findsOneWidget);
    });
  });

  group('điều hướng', () {
    testWidgets('nút + mở form Thêm việc đầy đủ (không có hộp thêm nhanh)', (
      tester,
    ) async {
      await pumpToday(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Thêm việc'), findsOneWidget);
      expect(find.text('Thêm việc nhanh'), findsNothing);
    });

    testWidgets('nút "Thêm việc" ở màn trống cũng mở form Thêm việc', (
      tester,
    ) async {
      await pumpToday(tester, sample: false);

      await tester.tap(find.widgetWithText(FilledButton, 'Thêm việc'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditScreen), findsOneWidget);
    });

    testWidgets('bấm vào việc mở Chi tiết việc', (tester) async {
      await pumpToday(tester);

      await tester.tap(find.text('Họp nhóm EXE201'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Chi tiết việc'), findsOneWidget);
    });

    testWidgets('nút Tìm kiếm mở trang Tìm kiếm', (tester) async {
      await pumpToday(tester);

      await tester.tap(find.byTooltip('Tìm kiếm'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Tìm kiếm'), findsOneWidget);
    });

    testWidgets('nút đồng hồ chọn sẵn việc và chuyển sang tab Hẹn giờ', (
      tester,
    ) async {
      await pumpToday(tester);

      await tester.tap(find.byTooltip('Bấm giờ tập trung: Họp nhóm EXE201'));
      await tester.pumpAndSettle();

      expect(env.timer.preparedTaskId, 'exe201');
      expect(env.shell.tab, HomeTab.timer);
    });

    testWidgets('việc đã xong không có nút đồng hồ', (tester) async {
      await pumpToday(tester);

      expect(
        find.byTooltip('Bấm giờ tập trung: Chạy bộ 30 phút'),
        findsNothing,
      );
    });
  });

  group('việc lặp lại', () {
    testWidgets('tick xong việc lặp thì tạo việc cho lần kế tiếp', (
      tester,
    ) async {
      await pumpToday(tester, sample: false);
      await env.tasks.add(
        testTask('uong-nuoc', title: 'Uống thuốc', repeat: RepeatRule.daily),
      );
      await tester.pumpAndSettle();

      await tester.tap(checkboxOf('Uống thuốc'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã tạo việc lặp kế tiếp'), findsOneWidget);
      final all = await env.tasks.getAll();
      expect(all, hasLength(2));
      final next = all.firstWhere((t) => t.id != 'uong-nuoc');
      expect(next.due, DateTime(2026, 10, 30));
      expect(next.done, isFalse);
    });
  });
}
