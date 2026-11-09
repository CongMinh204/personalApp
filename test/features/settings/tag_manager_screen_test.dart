import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/default_tags.dart';
import 'package:personal_app/data/models/tag.dart';
import 'package:personal_app/features/settings/tag_manager_screen.dart';
import 'package:personal_app/features/settings/widgets/tag_color_picker.dart';

import 'settings_test_helpers.dart';

void main() {
  late SettingsTestEnv env;

  Future<void> pumpScreen(WidgetTester tester) async {
    env = await SettingsTestEnv.create(
      tasks: [
        testTask('a', tagId: DefaultTagIds.work),
        testTask('b', tagId: DefaultTagIds.work, done: true),
        testTask('c', tagId: DefaultTagIds.study),
        testTask('d'),
      ],
    );
    await env.pump(tester, const TagManagerScreen());
  }

  Finder swatches(Finder scope) => find.descendant(
    of: scope,
    matching: find.descendant(
      of: find.byType(TagColorPicker),
      matching: find.byType(InkResponse),
    ),
  );

  Future<void> addTag(WidgetTester tester, String name, {int? swatch}) async {
    await tester.enterText(find.byType(TextField).first, name);
    if (swatch != null) {
      await tester.tap(swatches(find.byType(Card).first).at(swatch));
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
    await tester.pumpAndSettle();
  }

  group('danh sách', () {
    testWidgets('hiện 4 nhãn mặc định kèm số việc và chú thích', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('4 nhãn'), findsOneWidget);
      for (final tag in defaultTags) {
        expect(find.text(tag.name), findsOneWidget, reason: tag.name);
      }
      // Công việc: 2 việc (tính cả việc đã xong), Học tập: 1, còn lại 0.
      expect(find.text('2 việc'), findsOneWidget);
      expect(find.text('1 việc'), findsOneWidget);
      expect(find.text('0 việc'), findsNWidgets(2));
      expect(find.textContaining('Xóa nhãn không xóa việc'), findsOneWidget);
    });

    testWidgets('mỗi nhãn có nút Sửa và Xóa', (tester) async {
      await pumpScreen(tester);

      for (final tag in defaultTags) {
        expect(find.byTooltip('Sửa nhãn ${tag.name}'), findsOneWidget);
        expect(find.byTooltip('Xóa nhãn ${tag.name}'), findsOneWidget);
      }
    });
  });

  group('thêm nhãn', () {
    testWidgets('thêm nhãn hợp lệ với màu đã chọn, ô nhập được xóa', (
      tester,
    ) async {
      await pumpScreen(tester);

      await addTag(tester, 'Gia đình', swatch: 1);

      expect(find.text('5 nhãn'), findsOneWidget);
      expect(find.text('Gia đình'), findsOneWidget);
      final saved = (await env.tags.getAll()).last;
      expect(saved.name, 'Gia đình');
      expect(saved.color, TagColor.orange);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '',
      );
    });

    testWidgets('cắt khoảng trắng hai đầu của tên', (tester) async {
      await pumpScreen(tester);

      await addTag(tester, '   Gia đình  ');

      expect((await env.tags.getAll()).last.name, 'Gia đình');
    });

    testWidgets('tên trống thì báo lỗi và không thêm', (tester) async {
      await pumpScreen(tester);

      await addTag(tester, '   ');

      expect(find.text('Nhập tên nhãn'), findsOneWidget);
      expect(find.text('4 nhãn'), findsOneWidget);
    });

    testWidgets('tên trùng (khác hoa thường) thì báo lỗi và không thêm', (
      tester,
    ) async {
      await pumpScreen(tester);

      await addTag(tester, 'CÔNG VIỆC');

      expect(find.textContaining('đã tồn tại'), findsOneWidget);
      expect(find.text('4 nhãn'), findsOneWidget);
    });

    testWidgets('gõ lại thì lỗi biến mất', (tester) async {
      await pumpScreen(tester);
      await addTag(tester, '');
      expect(find.text('Nhập tên nhãn'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'M');
      await tester.pump();

      expect(find.text('Nhập tên nhãn'), findsNothing);
    });

    testWidgets('giới hạn độ dài tên khi nhập', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField).first, 'a' * 40);
      await tester.pump();

      final text = tester
          .widget<TextField>(find.byType(TextField).first)
          .controller!
          .text;
      expect(text.length, 24);
    });
  });

  group('sửa nhãn', () {
    testWidgets('đổi tên và màu', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Sửa nhãn Cá nhân'));
      await tester.pumpAndSettle();
      expect(find.text('Sửa nhãn'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Riêng tư',
      );
      await tester.tap(swatches(find.byType(AlertDialog)).at(3));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Riêng tư'), findsOneWidget);
      expect(find.text('Cá nhân'), findsNothing);
      final saved = (await env.tags.getById(DefaultTagIds.personal))!;
      expect(saved.name, 'Riêng tư');
      expect(saved.color, TagColor.red);
    });

    testWidgets('đổi sang tên của nhãn khác thì báo lỗi và giữ hộp thoại', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Sửa nhãn Cá nhân'));
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
      expect((await env.tags.getById(DefaultTagIds.personal))!.name, 'Cá nhân');
    });

    testWidgets('giữ nguyên tên và chỉ đổi màu thì hợp lệ', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Sửa nhãn Cá nhân'));
      await tester.pumpAndSettle();
      await tester.tap(swatches(find.byType(AlertDialog)).at(4));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final saved = (await env.tags.getById(DefaultTagIds.personal))!;
      expect((saved.name, saved.color), ('Cá nhân', TagColor.grey));
    });

    testWidgets('bấm Hủy thì không đổi gì', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Sửa nhãn Cá nhân'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Khác',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();

      expect((await env.tags.getById(DefaultTagIds.personal))!.name, 'Cá nhân');
    });
  });

  group('xóa nhãn', () {
    testWidgets('hộp xác nhận nói rõ số việc sẽ thành Không nhãn', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Xóa nhãn Công việc'));
      await tester.pumpAndSettle();

      expect(find.text('Xóa nhãn "Công việc"?'), findsOneWidget);
      expect(
        find.textContaining('2 việc đang dùng nhãn này sẽ chuyển thành'),
        findsOneWidget,
      );
    });

    testWidgets('bấm Hủy thì giữ nhãn', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Xóa nhãn Công việc'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();

      expect(find.text('4 nhãn'), findsOneWidget);
      expect(await env.tags.getById(DefaultTagIds.work), isNotNull);
    });

    testWidgets('bấm Xóa thì xóa nhãn, việc chuyển thành không nhãn', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Xóa nhãn Công việc'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(find.text('3 nhãn'), findsOneWidget);
      expect(find.text('Đã xóa nhãn "Công việc"'), findsOneWidget);
      expect(await env.tags.getById(DefaultTagIds.work), isNull);
      expect((await env.tasks.getById('a'))!.tagId, isNull);
      expect((await env.tasks.getById('b'))!.tagId, isNull);
      expect(await env.tasks.getById('a'), isNotNull);
    });

    testWidgets('nhãn chưa có việc nào thì xác nhận ngắn gọn', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Xóa nhãn Sức khỏe'));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có việc nào dùng nhãn này.'), findsOneWidget);
    });
  });
}
