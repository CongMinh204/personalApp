import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/sample_tasks.dart';
import 'package:personal_app/models/task.dart';
import 'package:personal_app/screens/today_screen.dart';
import 'package:personal_app/theme/app_theme.dart';
import 'package:personal_app/widgets/task_tile.dart';

void main() {
  final now = DateTime(2026, 10, 29, 13, 40);

  Future<void> pumpToday(WidgetTester tester, List<Task> tasks) async {
    // Màn hình cỡ điện thoại (390x844) để mọi phần chính đều hiển thị.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: TodayScreen(initialTasks: tasks, clock: () => now),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder checkboxOf(String title) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(TaskTile)),
    matching: find.byType(Checkbox),
  );

  testWidgets('hiển thị dữ liệu mẫu', (tester) async {
    await pumpToday(tester, sampleTasks(now));

    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Quá hạn · 2'), findsOneWidget);
    expect(find.text('2/4'), findsOneWidget);
  });

  testWidgets('bấm checkbox "Họp nhóm EXE201" thì tiến độ thành 3/4', (
    tester,
  ) async {
    await pumpToday(tester, sampleTasks(now));

    await tester.tap(checkboxOf('Họp nhóm EXE201'));
    await tester.pumpAndSettle();

    expect(find.text('3/4'), findsOneWidget);
  });

  testWidgets('vuốt trái để xóa, bấm "Hoàn tác" để khôi phục', (tester) async {
    await pumpToday(tester, sampleTasks(now));

    await tester.drag(
      find.byKey(const ValueKey('exe201')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Họp nhóm EXE201'), findsNothing);
    expect(find.text('2/3'), findsOneWidget);

    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();
    expect(find.text('Họp nhóm EXE201'), findsOneWidget);
    expect(find.text('2/4'), findsOneWidget);
  });

  testWidgets('danh sách rỗng hiển thị trạng thái trống', (tester) async {
    await pumpToday(tester, const []);

    expect(find.text('Hôm nay chưa có việc nào'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
