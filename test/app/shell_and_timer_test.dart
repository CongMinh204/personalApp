import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/app/shell_controller.dart';
import 'package:personal_app/features/timer/timer_controller.dart';

void main() {
  group('ShellController', () {
    test('mở tab Hôm nay trước, có đúng 5 tab theo thứ tự', () {
      final shell = ShellController();
      expect(shell.tab, HomeTab.today);
      expect(HomeTab.values, [
        HomeTab.today,
        HomeTab.calendar,
        HomeTab.timer,
        HomeTab.stats,
        HomeTab.habits,
      ]);
    });

    test('select đổi tab và báo; chọn lại tab đang mở thì không báo', () {
      final shell = ShellController();
      var calls = 0;
      shell.addListener(() => calls++);

      shell.select(HomeTab.stats);
      expect(shell.tab, HomeTab.stats);
      expect(calls, 1);

      shell.select(HomeTab.stats);
      expect(calls, 1);
    });
  });

  group('TimerController.prepare', () {
    test('chọn sẵn việc và chuyển sang tab Hẹn giờ', () {
      final shell = ShellController();
      final timer = TimerController(shell);
      expect(timer.preparedTaskId, isNull);

      timer.prepare('task-1');

      expect(timer.preparedTaskId, 'task-1');
      expect(shell.tab, HomeTab.timer);
    });

    test(
      'prepare việc khác thay cho việc cũ, clearPrepared bỏ việc đã chọn',
      () {
        final timer = TimerController(ShellController());
        var calls = 0;
        timer.addListener(() => calls++);

        timer.prepare('a');
        timer.prepare('b');
        expect(timer.preparedTaskId, 'b');
        expect(calls, 2);

        timer.clearPrepared();
        expect(timer.preparedTaskId, isNull);
        expect(calls, 3);

        timer.clearPrepared();
        expect(calls, 3);
      },
    );
  });
}
