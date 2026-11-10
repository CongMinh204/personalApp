import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/models/focus_session.dart';
import 'package:personal_app/features/stats/stats_logic.dart';
import 'package:personal_app/features/stats/stats_screen.dart';
import 'package:personal_app/theme/app_theme.dart';

import '../tasks/tasks_test_env.dart';

// Số liệu mẫu theo testNow (Thứ Năm 29/10/2026 13:40), kỳ 7 ngày:
// 8 việc xong (7 ngày trước đó: 0), đúng hạn 4/8 = 50%, 2 việc quá hạn,
// chuỗi 4 ngày (26–29/10), kỷ lục 4; tập trung 25+25+12+25+25 phút = 1g 52p,
// 5 phiên (phiên nghỉ ngắn không tính).
void main() {
  late TasksEnv env;

  const tall = Size(1170, 6000);

  Future<void> openStats(
    WidgetTester tester, {
    bool sample = true,
    Size size = tall,
    bool dark = false,
  }) async {
    env = await TasksEnv.create(sample: sample);
    final screen = StatsScreen(clock: () => testNow);
    await env.pump(
      tester,
      dark ? Theme(data: AppTheme.dark(), child: screen) : screen,
      size: size,
    );
  }

  Finder inTile(String tile, String text) => find.descendant(
    of: find.byKey(ValueKey('tile-$tile')),
    matching: find.text(text),
  );

  Finder inShare(String tagId, String text) => find.descendant(
    of: find.byKey(ValueKey('tag-share-$tagId')),
    matching: find.text(text),
  );

  Finder inChart(String text) => find.descendant(
    of: find.byKey(const ValueKey('chart')),
    matching: find.text(text),
  );

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<StatsPeriod>),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('7 ngày (mặc định)', () {
    testWidgets('tiêu đề và công tắc kỳ', (tester) async {
      await openStats(tester);

      expect(find.text('Thống kê'), findsOneWidget);
      final segmented = tester.widget<SegmentedButton<StatsPeriod>>(
        find.byType(SegmentedButton<StatsPeriod>),
      );
      expect(segmented.selected, {StatsPeriod.week});
      for (final label in ['7 ngày', 'Tháng', 'Năm']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('4 ô tóm tắt', (tester) async {
      await openStats(tester);

      expect(inTile('done', '8'), findsOneWidget);
      expect(inTile('done', 'việc hoàn thành'), findsOneWidget);
      expect(inTile('done', '+8 so với tuần trước'), findsOneWidget);

      expect(inTile('on-time', '50%'), findsOneWidget);
      expect(inTile('on-time', 'đúng hạn'), findsOneWidget);
      expect(inTile('on-time', '2 việc đang quá hạn'), findsOneWidget);

      expect(inTile('streak', '4'), findsOneWidget);
      expect(inTile('streak', 'ngày liên tiếp'), findsOneWidget);
      expect(inTile('streak', 'Kỷ lục: 4 ngày'), findsOneWidget);

      expect(inTile('focus', '1g 52p'), findsOneWidget);
      expect(inTile('focus', 'thời gian tập trung'), findsOneWidget);
      expect(inTile('focus', '5 phiên tập trung'), findsOneWidget);
    });

    testWidgets('mỗi ô được đọc thành một mục', (tester) async {
      await openStats(tester);

      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byKey(const ValueKey('tile-done')),
            matching: find.byType(MergeSemantics),
          ),
        ),
        isSemantics(label: '8\nviệc hoàn thành\n+8 so với tuần trước'),
      );
    });

    testWidgets('biểu đồ 7 cột, cột cuối là hôm nay', (tester) async {
      await openStats(tester);

      expect(find.text('Việc hoàn thành mỗi ngày'), findsOneWidget);
      expect(find.text('TB 1,1/ngày'), findsOneWidget);
      for (final label in ['T6', 'T7', 'CN', 'T2', 'T3', 'T4', 'Nay']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (var i = 0; i < 7; i++) {
        expect(find.byKey(ValueKey('bar-$i')), findsOneWidget, reason: '$i');
      }
      // Cột có 2 việc cao hơn cột có 1 việc; ngày không có việc chỉ là vạch.
      double height(int i) =>
          tester.getSize(find.byKey(ValueKey('bar-$i'))).height;
      expect(height(4), greaterThan(height(0)));
      expect(height(2), lessThan(height(0)));
      expect(
        find.bySemanticsLabel(
          'Biểu đồ cột: Thứ Sáu 1, Thứ Bảy 1, Chủ Nhật 0, Thứ Hai 1, '
          'Thứ Ba 2, Thứ Tư 1, hôm nay 2 việc',
        ),
        findsOneWidget,
      );
    });

    testWidgets('theo nhãn: nhiều việc trước, có phần trăm', (tester) async {
      await openStats(tester);

      expect(find.text('Theo nhãn'), findsOneWidget);
      expect(inShare('tag-health', '3 việc · 38%'), findsOneWidget);
      expect(inShare('tag-personal', '2 việc · 25%'), findsOneWidget);
      expect(inShare('tag-study', '2 việc · 25%'), findsOneWidget);
      expect(inShare('tag-work', '1 việc · 13%'), findsOneWidget);
      double y(String id) =>
          tester.getTopLeft(find.byKey(ValueKey('tag-share-$id'))).dy;
      expect(y('tag-health'), lessThan(y('tag-personal')));
      expect(y('tag-personal'), lessThan(y('tag-study')));
      expect(y('tag-study'), lessThan(y('tag-work')));
    });
  });

  group('đổi kỳ', () {
    testWidgets('Tháng: so với cùng kỳ tháng trước, mỗi ngày một cột', (
      tester,
    ) async {
      await openStats(tester);

      await choose(tester, 'Tháng');

      expect(inTile('done', '8'), findsOneWidget);
      expect(inTile('done', '+8 so với cùng kỳ tháng trước'), findsOneWidget);
      expect(find.text('TB 0,3/ngày'), findsOneWidget);
      // 29 ngày đã qua có cột, 30 và 31/10 chưa tới.
      expect(find.byKey(const ValueKey('bar-28')), findsOneWidget);
      expect(find.byKey(const ValueKey('bar-29')), findsNothing);
      for (final label in ['1', '8', '15', '22', '29']) {
        expect(inChart(label), findsOneWidget, reason: label);
      }
      expect(inChart('2'), findsNothing);
      // Chuỗi ngày liên tiếp không đổi theo kỳ.
      expect(inTile('streak', 'Kỷ lục: 4 ngày'), findsOneWidget);
    });

    testWidgets('Năm: 12 cột theo tháng', (tester) async {
      await openStats(tester);

      await choose(tester, 'Năm');

      expect(inTile('done', '+8 so với cùng kỳ năm trước'), findsOneWidget);
      expect(find.text('Việc hoàn thành mỗi tháng'), findsOneWidget);
      expect(find.text('TB 0,8/tháng'), findsOneWidget);
      expect(find.byKey(const ValueKey('bar-9')), findsOneWidget); // tháng 10
      expect(find.byKey(const ValueKey('bar-10')), findsNothing);
      expect(inTile('focus', '1g 52p'), findsOneWidget);
    });

    testWidgets('quay lại 7 ngày thì thời gian tập trung không cộng nhầm', (
      tester,
    ) async {
      await openStats(tester);
      await env.focus.add(
        FocusSession(
          id: 'old',
          type: FocusType.pomodoro,
          startedAt: DateTime(2026, 10, 5, 9),
          durationSec: 25 * 60,
          completed: true,
        ),
      );
      await tester.pumpAndSettle();

      await choose(tester, 'Tháng');
      expect(inTile('focus', '2g 17p'), findsOneWidget);
      expect(inTile('focus', '6 phiên tập trung'), findsOneWidget);

      await choose(tester, '7 ngày');
      expect(inTile('focus', '1g 52p'), findsOneWidget);
      expect(inTile('focus', '5 phiên tập trung'), findsOneWidget);
    });
  });

  group('tự cập nhật', () {
    testWidgets('xong một việc ở nơi khác thì số liệu đổi ngay', (
      tester,
    ) async {
      await openStats(tester);

      // Họp nhóm EXE201 14:00–15:00, xong lúc 13:40: đúng hạn.
      await env.tasks.setDone('exe201', true);
      await tester.pumpAndSettle();

      expect(inTile('done', '9'), findsOneWidget);
      expect(inTile('done', '+9 so với tuần trước'), findsOneWidget);
      expect(inTile('on-time', '56%'), findsOneWidget);
      expect(find.text('TB 1,3/ngày'), findsOneWidget);
    });

    testWidgets('phiên tập trung mới được cộng ngay', (tester) async {
      await openStats(tester);

      await env.focus.add(
        FocusSession(
          id: 'new',
          type: FocusType.custom,
          startedAt: DateTime(2026, 10, 29, 12),
          durationSec: 25 * 60,
          completed: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(inTile('focus', '2g 17p'), findsOneWidget);
      expect(inTile('focus', '6 phiên tập trung'), findsOneWidget);
    });

    testWidgets('xóa hết việc quá hạn thì ghi "Không có việc quá hạn"', (
      tester,
    ) async {
      await openStats(tester);

      await env.tasks.delete('lab3');
      await env.tasks.delete('library-card');
      await tester.pumpAndSettle();

      expect(inTile('on-time', 'Không có việc quá hạn'), findsOneWidget);
    });
  });

  group('chưa có dữ liệu', () {
    testWidgets('các ô ghi 0, "–" và thẻ theo nhãn báo trống', (tester) async {
      await openStats(tester, sample: false);

      expect(inTile('done', '0'), findsOneWidget);
      expect(inTile('done', 'Bằng tuần trước'), findsOneWidget);
      expect(inTile('on-time', '–'), findsOneWidget);
      expect(inTile('on-time', 'Không có việc quá hạn'), findsOneWidget);
      expect(inTile('streak', '0'), findsOneWidget);
      expect(inTile('streak', 'Kỷ lục: 0 ngày'), findsOneWidget);
      expect(inTile('focus', '0p'), findsOneWidget);
      expect(inTile('focus', '0 phiên tập trung'), findsOneWidget);
      expect(find.text('TB 0/ngày'), findsOneWidget);
      expect(find.text('Chưa có việc hoàn thành trong kỳ này'), findsOneWidget);
    });
  });

  group('cỡ điện thoại', () {
    testWidgets('390x844: cả ba kỳ vẽ được, cuộn tới thẻ theo nhãn', (
      tester,
    ) async {
      await openStats(tester, size: const Size(1170, 2532));
      expect(tester.takeException(), isNull);

      for (final label in ['Tháng', 'Năm', '7 ngày']) {
        await choose(tester, label);
        expect(tester.takeException(), isNull, reason: label);
      }

      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(find.text('Theo nhãn').hitTestable(), findsOneWidget);
    });

    testWidgets('411 dp (cỡ máy ảo Pixel): nhãn dưới trục vẫn hiện', (
      tester,
    ) async {
      // Mỗi cột rộng hơn 48 dp ở kỳ 7 ngày.
      await openStats(tester, size: const Size(1233, 2742));

      for (final label in ['7 ngày', 'Tháng', 'Năm']) {
        await choose(tester, label);
        expect(tester.takeException(), isNull, reason: label);
      }
      await choose(tester, '7 ngày');
      expect(inChart('Nay'), findsOneWidget);
      expect(tester.getSize(inChart('Nay')).width, greaterThan(0));
    });

    testWidgets('chữ to (130%) không làm tràn ô', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await openStats(tester, size: const Size(1170, 2532));
      await choose(tester, 'Tháng');

      expect(tester.takeException(), isNull);
    });

    testWidgets('giao diện tối, cả ba kỳ', (tester) async {
      await openStats(tester, size: const Size(1170, 2532), dark: true);

      expect(inTile('done', '8'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final label in ['Tháng', 'Năm']) {
        await choose(tester, label);
        expect(tester.takeException(), isNull, reason: label);
      }
      expect(find.text('Việc hoàn thành mỗi tháng'), findsOneWidget);
    });
  });
}
