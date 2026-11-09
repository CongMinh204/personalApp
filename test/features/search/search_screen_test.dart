import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/app/routes.dart';
import 'package:personal_app/data/default_tags.dart';
import 'package:personal_app/data/models/tag.dart';
import 'package:personal_app/features/search/search_screen.dart';
import 'package:personal_app/features/tasks/task_detail_screen.dart';
import 'package:personal_app/features/today/widgets/task_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tasks/tasks_test_env.dart';

void main() {
  late TasksEnv env;

  Future<void> openSearch(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    env = await TasksEnv.create(prefs: prefs);
    await env.tasks.add(
      testTask(
        'a',
        title: 'Nộp báo cáo Lab 3 PRM393',
        tagId: DefaultTagIds.study,
        due: DateTime(2026, 10, 28),
      ),
    );
    await env.tasks.add(
      testTask(
        'b',
        title: 'Họp nhóm EXE201',
        note: 'Phòng 304 tòa Alpha',
        tagId: DefaultTagIds.work,
      ),
    );
    await env.tasks.add(
      testTask(
        'c',
        title: 'Ôn tập PE Flutter',
        tagId: DefaultTagIds.study,
        done: true,
      ),
    );
    await env.tasks.add(
      testTask(
        'd',
        title: 'Mua sữa và trứng',
        tagId: DefaultTagIds.personal,
        done: true,
      ),
    );
    await env.open(tester, AppRoutes.search);
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

  /// Hàng chip lọc cuộn ngang nên chip ở xa chưa được dựng; cuộn tới khi thấy.
  Future<Finder> reveal(WidgetTester tester, String label) async {
    final target = chip(label);
    // Kéo vào chính hàng chip (cuộn ngang), không vào một chip có thể đã lệch.
    final chipRow = find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.horizontal,
    );
    for (var i = 0; i < 8 && target.evaluate().isEmpty; i++) {
      await tester.drag(chipRow, const Offset(-250, 0));
      await tester.pumpAndSettle();
    }
    for (var i = 0; i < 8 && target.evaluate().isEmpty; i++) {
      await tester.drag(chipRow, const Offset(250, 0));
      await tester.pumpAndSettle();
    }
    // Chip có thể đã được dựng nhưng còn nằm lệch ngoài màn hình: đưa vào vùng
    // nhìn thấy để chạm trúng.
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
    }
    return target;
  }

  int tileCount() => find.byType(TaskTile).evaluate().length;

  Future<List<String>?> savedRecent() async =>
      (await SharedPreferences.getInstance()).getStringList('search_recent');

  group('khi chưa nhập gì', () {
    testWidgets('hiện gợi ý nhập từ khóa, chưa có bộ lọc và kết quả', (
      tester,
    ) async {
      await openSearch(tester);

      expect(find.text('Nhập từ khóa để tìm việc'), findsOneWidget);
      expect(find.text('Tìm gần đây'), findsNothing);
      expect(chip('Chưa xong'), findsNothing);
      expect(find.byType(TaskTile), findsNothing);
    });

    testWidgets('con trỏ ở ô tìm kiếm ngay khi mở', (tester) async {
      await openSearch(tester);

      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isTrue);
    });

    testWidgets('nút quay lại đóng màn tìm kiếm', (tester) async {
      await openSearch(tester);

      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsNothing);
    });
  });

  group('tìm kiếm', () {
    testWidgets('theo tiêu đề, hiện số kết quả', (tester) async {
      await openSearch(tester);

      await type(tester, 'PRM393');

      expect(find.text('1 kết quả'), findsOneWidget);
      expect(find.text('Nộp báo cáo Lab 3 PRM393'), findsOneWidget);
      expect(tileCount(), 1);
    });

    testWidgets('không phân biệt hoa thường, kể cả chữ có dấu', (tester) async {
      await openSearch(tester);

      await type(tester, 'ÔN TẬP');

      expect(find.text('Ôn tập PE Flutter'), findsOneWidget);
    });

    testWidgets('gõ không dấu vẫn tìm ra: "hoc tap" ra các việc nhãn Học tập', (
      tester,
    ) async {
      await openSearch(tester);

      await type(tester, 'hoc tap');

      expect(find.text('2 kết quả'), findsOneWidget);
      expect(find.text('Nộp báo cáo Lab 3 PRM393'), findsOneWidget);
      expect(find.text('Ôn tập PE Flutter'), findsOneWidget);
    });

    testWidgets('gõ không dấu cũng tìm ra tiêu đề có dấu', (tester) async {
      await openSearch(tester);

      await type(tester, 'on tap');

      expect(find.text('Ôn tập PE Flutter'), findsOneWidget);
    });

    testWidgets('tìm cả trong ghi chú', (tester) async {
      await openSearch(tester);

      await type(tester, 'tòa alpha');

      expect(find.text('Họp nhóm EXE201'), findsOneWidget);
    });

    testWidgets('tìm cả theo tên nhãn', (tester) async {
      await openSearch(tester);

      await type(tester, 'học tập');

      expect(find.text('2 kết quả'), findsOneWidget);
      expect(find.text('Nộp báo cáo Lab 3 PRM393'), findsOneWidget);
      expect(find.text('Ôn tập PE Flutter'), findsOneWidget);
    });

    testWidgets('không có kết quả thì báo như mockup', (tester) async {
      await openSearch(tester);

      await type(tester, 'khôngcótừnày');

      expect(find.text('Không tìm thấy việc nào'), findsOneWidget);
      expect(find.text('Thử từ khóa khác hoặc bỏ bớt bộ lọc.'), findsOneWidget);
      expect(find.byType(TaskTile), findsNothing);
    });

    testWidgets('xóa từ khóa bằng nút × thì về màn gợi ý', (tester) async {
      await openSearch(tester);
      await type(tester, 'PRM393');

      await tester.tap(find.byTooltip('Xóa từ khóa'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskTile), findsNothing);
      expect(find.text('Nhập từ khóa để tìm việc'), findsOneWidget);
      expect(find.byTooltip('Xóa từ khóa'), findsNothing);
    });

    testWidgets('việc thêm mới khớp từ khóa hiện ra ngay khi đang mở', (
      tester,
    ) async {
      await openSearch(tester);
      await type(tester, 'sữa');
      expect(find.text('1 kết quả'), findsOneWidget);

      await env.tasks.add(testTask('e', title: 'Mua sữa chua'));
      await tester.pumpAndSettle();

      expect(find.text('2 kết quả'), findsOneWidget);
    });
  });

  group('bộ lọc', () {
    testWidgets('Chưa xong và Đã xong', (tester) async {
      await openSearch(tester);
      await type(tester, 'học tập');
      expect(tileCount(), 2);

      await tester.tap(chip('Chưa xong'));
      await tester.pumpAndSettle();
      expect(find.text('1 kết quả'), findsOneWidget);
      expect(find.text('Nộp báo cáo Lab 3 PRM393'), findsOneWidget);

      await tester.tap(chip('Đã xong'));
      await tester.pumpAndSettle();
      expect(find.text('1 kết quả'), findsOneWidget);
      expect(find.text('Ôn tập PE Flutter'), findsOneWidget);

      await tester.tap(chip('Tất cả'));
      await tester.pumpAndSettle();
      expect(tileCount(), 2);
    });

    testWidgets('lọc theo nhãn, lấy nhãn từ repository', (tester) async {
      await openSearch(tester);
      await type(tester, 'p'); // khớp Nộp, Họp, tập: nhiều việc

      await tester.tap(await reveal(tester, 'Công việc'));
      await tester.pumpAndSettle();

      expect(find.text('Họp nhóm EXE201'), findsOneWidget);
      expect(find.text('1 kết quả'), findsOneWidget);
    });

    testWidgets('lọc ra rỗng thì hiện trạng thái không tìm thấy', (
      tester,
    ) async {
      await openSearch(tester);
      await type(tester, 'PRM393');

      await tester.tap(chip('Đã xong'));
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy việc nào'), findsOneWidget);
    });

    testWidgets('nhãn mới thêm cũng thành một chip lọc', (tester) async {
      await openSearch(tester);
      await type(tester, 'a');
      await env.tags.add(const Tag(id: 'gd', name: 'Gia đình'));
      await tester.pumpAndSettle();
      expect(await reveal(tester, 'Gia đình'), findsOneWidget);
    });

    testWidgets('xóa nhãn đang lọc thì quay về Tất cả', (tester) async {
      await openSearch(tester);
      await type(tester, 'học tập');
      await tester.tap(await reveal(tester, 'Học tập'));
      await tester.pumpAndSettle();

      await env.tags.delete(DefaultTagIds.study);
      await tester.pumpAndSettle();

      final all = await reveal(tester, 'Tất cả');
      expect(tester.widget<ChoiceChip>(all).selected, isTrue);
    });
  });

  group('thao tác trên kết quả', () {
    testWidgets('tick xong một việc thì lưu và cập nhật theo bộ lọc', (
      tester,
    ) async {
      await openSearch(tester);
      await type(tester, 'học tập');
      await tester.tap(chip('Chưa xong'));
      await tester.pumpAndSettle();
      expect(find.text('Nộp báo cáo Lab 3 PRM393'), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect((await env.tasks.getById('a'))!.done, isTrue);
      expect(find.text('Nộp báo cáo Lab 3 PRM393'), findsNothing);
    });

    testWidgets('bấm vào kết quả mở Chi tiết việc', (tester) async {
      await openSearch(tester);
      await type(tester, 'PRM393');

      await tester.tap(find.text('Nộp báo cáo Lab 3 PRM393'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailScreen), findsOneWidget);
    });
  });

  group('tìm gần đây', () {
    testWidgets('nhấn Enter lưu từ khóa và hiện lại khi xóa ô tìm kiếm', (
      tester,
    ) async {
      await openSearch(tester);
      await type(tester, 'PRM393');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(await savedRecent(), ['PRM393']);

      await tester.tap(find.byTooltip('Xóa từ khóa'));
      await tester.pumpAndSettle();

      expect(find.text('Tìm gần đây'), findsOneWidget);
      expect(find.text('PRM393'), findsOneWidget);
    });

    testWidgets('bấm vào kết quả cũng ghi nhớ từ khóa', (tester) async {
      await openSearch(tester);
      await type(tester, 'họp nhóm');

      await tester.tap(find.text('Họp nhóm EXE201'));
      await tester.pumpAndSettle();

      expect(await savedRecent(), ['họp nhóm']);
    });

    testWidgets('bấm một mục gần đây thì điền vào ô và tìm ngay', (
      tester,
    ) async {
      await openSearch(
        tester,
        prefs: {
          'search_recent': ['PRM393', 'sữa'],
        },
      );

      expect(find.text('Tìm gần đây'), findsOneWidget);
      await tester.tap(find.text('PRM393'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'PRM393',
      );
      expect(find.text('1 kết quả'), findsOneWidget);
    });

    testWidgets('nút Xóa xóa hết danh sách và dữ liệu đã lưu', (tester) async {
      await openSearch(
        tester,
        prefs: {
          'search_recent': ['PRM393', 'sữa'],
        },
      );

      await tester.tap(find.widgetWithText(TextButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(find.text('Tìm gần đây'), findsNothing);
      expect(find.text('Nhập từ khóa để tìm việc'), findsOneWidget);
      expect(await savedRecent(), isNull);
    });

    testWidgets('từ khóa trùng không bị nhân đôi, chỉ giữ 5 từ khóa', (
      tester,
    ) async {
      await openSearch(
        tester,
        prefs: {
          'search_recent': ['a1', 'a2', 'a3', 'a4', 'a5'],
        },
      );

      await type(tester, 'PRM393');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await type(tester, 'a3');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(await savedRecent(), ['a3', 'PRM393', 'a1', 'a2', 'a4']);
    });
  });
}
