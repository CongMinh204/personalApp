import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/app/app_info.dart';
import 'package:personal_app/app/settings_controller.dart';
import 'package:personal_app/data/models/tag.dart';
import 'package:personal_app/features/settings/settings_screen.dart';
import 'package:personal_app/features/settings/tag_manager_screen.dart';
import 'package:personal_app/features/settings/widgets/settings_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_test_helpers.dart';

void main() {
  late SettingsTestEnv env;

  Future<void> pumpScreen(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    bool withCompletedTasks = false,
  }) async {
    env = await SettingsTestEnv.create(
      prefs: prefs,
      tasks: [
        testTask('a'),
        if (withCompletedTasks) ...[
          testTask('b', done: true, completedAt: DateTime(2026, 11, 8)),
          testTask('c', done: true, completedAt: DateTime(2026, 11, 9)),
        ],
      ],
    );
    // Màn Cài đặt dài hơn một trang điện thoại, dùng màn hình cao để mọi dòng
    // đều được dựng.
    await env.pump(
      tester,
      const SettingsScreen(),
      size: const Size(1170, 4500),
    );
  }

  Finder inDialog(Finder finder) =>
      find.descendant(of: find.byType(Dialog), matching: finder);

  Finder row(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(InkWell));

  Brightness brightness(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness;

  group('hiển thị', () {
    testWidgets('có đủ 4 nhóm và các dòng như mockup', (tester) async {
      await pumpScreen(tester);

      for (final text in [
        'Giao diện',
        'Chủ đề',
        'Màu nhấn',
        'Tuần bắt đầu từ',
        'Thông báo',
        'Nhắc việc',
        'Thông báo trước giờ hẹn',
        'Nhắc trước mặc định',
        'Âm báo',
        'Tóm tắt buổi sáng',
        'Hẹn giờ',
        'Phiên Pomodoro',
        'Nghỉ ngắn / nghỉ dài',
        'Tự chạy phiên tiếp theo',
        'Dữ liệu',
        'Quản lý nhãn',
        'Xóa các việc đã hoàn thành',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      for (final text in ['Sáng', 'Tối', 'Hệ thống']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('không có đồng bộ, sao lưu, xuất dữ liệu hay tài khoản', (
      tester,
    ) async {
      await pumpScreen(tester);

      for (final text in ['Đồng bộ', 'Sao lưu', 'Xuất', 'Tài khoản']) {
        expect(find.textContaining(text), findsNothing, reason: text);
      }
    });

    testWidgets('app mới cài hiện giá trị mặc định', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Thứ Hai'), findsOneWidget);
      expect(find.text('15 phút'), findsOneWidget);
      expect(find.text('Mặc định'), findsOneWidget);
      expect(find.text('07:00 · danh sách việc trong ngày'), findsOneWidget);
      expect(find.text('25 phút'), findsOneWidget);
      expect(find.text('5 / 15 phút'), findsOneWidget);
      expect(find.text('4 nhãn'), findsOneWidget);
    });

    testWidgets('hiện giá trị đã lưu từ lần trước', (tester) async {
      await pumpScreen(
        tester,
        prefs: {'week_start': 7, 'pomodoro_minutes': 50, 'theme_mode': 'dark'},
      );

      expect(find.text('Chủ Nhật'), findsOneWidget);
      expect(find.text('50 phút'), findsOneWidget);
      expect(brightness(tester), Brightness.dark);
    });

    testWidgets('dòng phiên bản khớp pubspec.yaml', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Phiên bản $appVersion'), findsOneWidget);
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(
        r'^version:\s*(\d+\.\d+\.\d+)',
        multiLine: true,
      ).firstMatch(pubspec)!.group(1);
      expect(appVersion, version);
    });

    testWidgets('Âm báo chỉ để xem, không bấm được', (tester) async {
      await pumpScreen(tester);

      final inkWell = tester.widget<InkWell>(row('Âm báo'));
      expect(inkWell.onTap, isNull);
    });
  });

  group('giao diện', () {
    testWidgets('chọn Tối rồi Sáng thì giao diện đổi ngay và được lưu', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Tối'));
      await tester.pumpAndSettle();
      expect(env.settings.themeMode, ThemeMode.dark);
      expect(brightness(tester), Brightness.dark);
      expect(
        (await SharedPreferences.getInstance()).getString('theme_mode'),
        'dark',
      );

      await tester.tap(find.text('Sáng'));
      await tester.pumpAndSettle();
      expect(env.settings.themeMode, ThemeMode.light);
      expect(brightness(tester), Brightness.light);
    });

    testWidgets('chọn màu nhấn thì theme đổi màu chính', (tester) async {
      await pumpScreen(tester);
      Color primary() =>
          Theme.of(tester.element(find.byType(SettingsScreen)))
              .colorScheme
              .primary;
      final before = primary();

      final swatches = find.descendant(
        of: find.byType(AccentPicker),
        matching: find.byType(InkResponse),
      );
      expect(swatches, findsNWidgets(5));
      await tester.tap(swatches.at(3));
      await tester.pumpAndSettle();

      expect(env.settings.accent, accentOptions[3].color);
      expect(primary(), isNot(before));
    });

    testWidgets('chọn ngày đầu tuần', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Tuần bắt đầu từ'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.text('Chủ Nhật')));
      await tester.pumpAndSettle();

      expect(env.settings.weekStart, 7);
      expect(find.text('Chủ Nhật'), findsOneWidget);
    });
  });

  group('thông báo', () {
    testWidgets('chọn nhắc trước mặc định trong các mức của màn Sửa việc', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Nhắc trước mặc định'));
      await tester.pumpAndSettle();
      for (final text in [
        'Đúng giờ',
        '5 phút',
        '15 phút',
        '30 phút',
        '1 giờ',
        '1 ngày',
      ]) {
        expect(inDialog(find.text(text)), findsOneWidget, reason: text);
      }
      await tester.tap(inDialog(find.text('1 giờ')));
      await tester.pumpAndSettle();

      expect(env.settings.defaultReminderMinutes, 60);
      expect(find.text('1 giờ'), findsOneWidget);
    });

    testWidgets('công tắc Nhắc việc bật tắt và được lưu', (tester) async {
      await pumpScreen(tester);
      expect(env.settings.remindersEnabled, isTrue);

      await tester.tap(find.text('Nhắc việc'));
      await tester.pumpAndSettle();

      expect(env.settings.remindersEnabled, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getBool('reminders_enabled'),
        isFalse,
      );
    });

    testWidgets('bấm công tắc Tóm tắt buổi sáng thì tắt, bấm lại thì bật', (
      tester,
    ) async {
      await pumpScreen(tester);
      final morningSwitch = find.descendant(
        of: row('Tóm tắt buổi sáng'),
        matching: find.byType(Switch),
      );

      await tester.tap(morningSwitch);
      await tester.pumpAndSettle();
      expect(env.settings.morningSummaryEnabled, isFalse);

      await tester.tap(morningSwitch);
      await tester.pumpAndSettle();
      expect(env.settings.morningSummaryEnabled, isTrue);
    });

    testWidgets('khi đang bật, bấm vào chữ mở bộ chọn giờ', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Tóm tắt buổi sáng'));
      await tester.pumpAndSettle();

      expect(find.text('Giờ gửi tóm tắt buổi sáng'), findsOneWidget);
      // Đóng bộ chọn mà không chọn: giờ giữ nguyên.
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(env.settings.morningSummaryMinutes, 420);
    });

    testWidgets('khi đang tắt, bấm vào chữ thì bật lại, không mở bộ chọn giờ', (
      tester,
    ) async {
      await pumpScreen(tester, prefs: {'morning_summary_enabled': false});

      await tester.tap(find.text('Tóm tắt buổi sáng'));
      await tester.pumpAndSettle();

      expect(env.settings.morningSummaryEnabled, isTrue);
      expect(find.text('Giờ gửi tóm tắt buổi sáng'), findsNothing);
    });
  });

  group('hẹn giờ', () {
    Finder plus(String label) => find.byTooltip('Tăng $label');
    Finder minus(String label) => find.byTooltip('Giảm $label');
    // byTooltip trả về Tooltip; lấy IconButton bao quanh để đọc onPressed.
    IconButton buttonOf(WidgetTester tester, Finder tooltip) =>
        tester.widget<IconButton>(
          find.ancestor(of: tooltip, matching: find.byType(IconButton)),
        );

    testWidgets('đổi Pomodoro bằng nút + và Lưu', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Phiên Pomodoro'));
      await tester.pumpAndSettle();
      await tester.tap(plus('Thời lượng'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(env.settings.pomodoroMinutes, 30);
      expect(find.text('30 phút'), findsOneWidget);
    });

    testWidgets('Pomodoro không vượt quá 60 hay dưới 5 phút', (tester) async {
      await pumpScreen(tester, prefs: {'pomodoro_minutes': 60});

      await tester.tap(find.text('Phiên Pomodoro'));
      await tester.pumpAndSettle();
      expect(buttonOf(tester, plus('Thời lượng')).onPressed, isNull);

      for (var i = 0; i < 11; i++) {
        await tester.tap(minus('Thời lượng'));
        await tester.pump();
      }
      expect(inDialog(find.text('5 phút')), findsOneWidget);
      expect(buttonOf(tester, minus('Thời lượng')).onPressed, isNull);
    });

    testWidgets('bấm Hủy thì không đổi', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Phiên Pomodoro'));
      await tester.pumpAndSettle();
      await tester.tap(plus('Thời lượng'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();

      expect(env.settings.pomodoroMinutes, 25);
    });

    testWidgets('đổi nghỉ ngắn và nghỉ dài cùng lúc', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Nghỉ ngắn / nghỉ dài'));
      await tester.pumpAndSettle();
      await tester.tap(minus('Nghỉ ngắn'));
      await tester.pump();
      await tester.tap(plus('Nghỉ dài'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(env.settings.shortBreakMinutes, 4);
      expect(env.settings.longBreakMinutes, 20);
      expect(find.text('4 / 20 phút'), findsOneWidget);
    });

    testWidgets('công tắc Tự chạy phiên tiếp theo', (tester) async {
      await pumpScreen(tester);
      expect(env.settings.autoNextSession, isFalse);

      await tester.tap(find.text('Tự chạy phiên tiếp theo'));
      await tester.pumpAndSettle();

      expect(env.settings.autoNextSession, isTrue);
    });
  });

  group('dữ liệu', () {
    testWidgets('Quản lý nhãn mở màn nhãn và quay lại được', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Quản lý nhãn'));
      await tester.pumpAndSettle();
      expect(find.byType(TagManagerScreen), findsOneWidget);
      expect(find.text('4 nhãn'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(TagManagerScreen), findsNothing);
    });

    testWidgets('số nhãn cập nhật khi thêm nhãn', (tester) async {
      await pumpScreen(tester);
      expect(find.text('4 nhãn'), findsOneWidget);

      await env.tags.add(const Tag(id: 'moi', name: 'Gia đình'));
      await tester.pumpAndSettle();

      expect(find.text('5 nhãn'), findsOneWidget);
    });

    testWidgets('không có việc nào xong thì chỉ báo, không hỏi', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Xóa các việc đã hoàn thành'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Không có việc nào đã hoàn thành'), findsOneWidget);
    });

    testWidgets('hộp xác nhận nói rõ số việc và việc mất cả thống kê', (
      tester,
    ) async {
      await pumpScreen(tester, withCompletedTasks: true);

      await tester.tap(find.text('Xóa các việc đã hoàn thành'));
      await tester.pumpAndSettle();

      expect(find.text('Xóa 2 việc đã hoàn thành?'), findsOneWidget);
      expect(
        find.textContaining('Thống kê các ngày trước cũng mất'),
        findsOneWidget,
      );
    });

    testWidgets('bấm Hủy thì giữ nguyên mọi việc', (tester) async {
      await pumpScreen(tester, withCompletedTasks: true);

      await tester.tap(find.text('Xóa các việc đã hoàn thành'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();

      expect(await env.tasks.getAll(), hasLength(3));
      expect(find.textContaining('Đã xóa'), findsNothing);
    });

    testWidgets('bấm Xóa thì chỉ xóa việc đã xong và báo đúng số', (
      tester,
    ) async {
      await pumpScreen(tester, withCompletedTasks: true);

      await tester.tap(find.text('Xóa các việc đã hoàn thành'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();

      final left = await env.tasks.getAll();
      expect([for (final t in left) t.id], ['a']);
      expect(find.text('Đã xóa 2 việc'), findsOneWidget);
    });
  });
}
