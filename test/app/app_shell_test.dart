import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/app/dependencies.dart';
import 'package:personal_app/app/settings_controller.dart';
import 'package:personal_app/app/shell_controller.dart';
import 'package:personal_app/features/timer/countdown_controller.dart';
import 'package:personal_app/features/timer/timer_controller.dart';
import 'package:personal_app/main.dart';
import 'package:personal_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsController settings;

  Future<void> pumpApp(WidgetTester tester) async {
    // Màn hình cỡ điện thoại (390x844).
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    settings = SettingsController.fromPrefs(
      await SharedPreferences.getInstance(),
    );
    await tester.pumpWidget(
      PersonalApp(dependencies: AppDependencies.fake(), settings: settings),
    );
    await tester.pumpAndSettle();
  }

  BuildContext shellContext(WidgetTester tester) =>
      tester.element(find.byType(NavigationBar));

  Finder navLabel(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

  group('Khung 5 tab', () {
    testWidgets('thanh dưới có Hôm nay, Lịch, Hẹn giờ, Thống kê, Thói quen', (
      tester,
    ) async {
      await pumpApp(tester);

      for (final label in [
        'Hôm nay',
        'Lịch',
        'Hẹn giờ',
        'Thống kê',
        'Thói quen',
      ]) {
        expect(navLabel(label), findsOneWidget, reason: label);
      }
      expect(find.byType(NavigationDestination), findsNWidgets(5));
    });

    testWidgets('Cài đặt không phải tab', (tester) async {
      await pumpApp(tester);
      expect(navLabel('Cài đặt'), findsNothing);
    });

    testWidgets('bấm tab thì đổi tab đang mở', (tester) async {
      await pumpApp(tester);
      final shell = shellContext(tester).read<ShellController>();
      expect(shell.tab, HomeTab.today);

      await tester.tap(navLabel('Thói quen'));
      await tester.pumpAndSettle();
      expect(shell.tab, HomeTab.habits);

      await tester.tap(navLabel('Lịch'));
      await tester.pumpAndSettle();
      expect(shell.tab, HomeTab.calendar);
    });

    testWidgets('TimerController.prepare chuyển sang tab Hẹn giờ', (
      tester,
    ) async {
      await pumpApp(tester);
      final context = shellContext(tester);

      context.read<TimerController>().prepare('pe-flutter');
      await tester.pumpAndSettle();

      expect(context.read<ShellController>().tab, HomeTab.timer);
      // Màn Hẹn giờ nhận việc được chọn sẵn rồi xóa khỏi hàng chờ.
      expect(context.read<TimerController>().preparedTaskId, isNull);
      expect(context.read<CountdownController>().taskId, 'pe-flutter');
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, HomeTab.timer.index);
    });
  });

  group('Header màn Hôm nay', () {
    testWidgets('không còn nút đổi sáng/tối và avatar', (tester) async {
      await pumpApp(tester);

      expect(find.byTooltip('Chế độ tối'), findsNothing);
      expect(find.byTooltip('Chế độ sáng'), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
    });

    testWidgets('có nút Tìm kiếm và Cài đặt', (tester) async {
      await pumpApp(tester);

      expect(find.byTooltip('Tìm kiếm'), findsOneWidget);
      expect(find.byTooltip('Cài đặt'), findsOneWidget);
    });

    testWidgets('bấm Cài đặt mở trang Cài đặt có nút quay lại', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Cài đặt'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Cài đặt'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Cài đặt'), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('Chủ đề và màu nhấn theo Cài đặt', () {
    testWidgets('đổi chủ đề thì giao diện đổi ngay', (tester) async {
      await pumpApp(tester);
      Brightness brightness() =>
          Theme.of(tester.element(find.byType(NavigationBar))).brightness;

      await settings.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);

      await settings.setThemeMode(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
    });

    testWidgets('đổi màu nhấn thì màu chính của theme đổi theo', (
      tester,
    ) async {
      await pumpApp(tester);
      Color primary() =>
          Theme.of(tester.element(find.byType(NavigationBar)))
              .colorScheme
              .primary;

      final before = primary();
      expect(before, AppTheme.light().colorScheme.primary);

      final orange = accentOptions[3].color;
      await settings.setAccent(orange);
      await tester.pumpAndSettle();

      expect(primary(), AppTheme.light(accent: orange).colorScheme.primary);
      expect(primary(), isNot(before));
    });
  });
}
