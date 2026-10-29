import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/sample_tasks.dart';
import 'package:personal_app/logic/task_groups.dart';
import 'package:personal_app/models/task.dart';
import 'package:personal_app/utils/vi_date.dart';

void main() {
  // Thứ Năm, 29/10/2026 13:40
  final now = DateTime(2026, 10, 29, 13, 40);
  final tasks = sampleTasks(now);

  Task byTitle(String title) => tasks.firstWhere((t) => t.title == title);
  List<String> titles(List<Task> list) => [for (final t in list) t.title];

  group('groupTasks', () {
    test('việc ngày đã qua, chưa xong vào Quá hạn', () {
      final groups = groupTasks(tasks, now);
      expect(titles(groups.overdue), [
        'Gia hạn thẻ thư viện',
        'Nộp báo cáo Lab 3 PRM393',
      ]);
    });

    test('việc quá hạn đã xong bị ẩn', () {
      final doneYesterday = Task(
        id: 'x',
        title: 'Đã xong hôm qua',
        tag: TaskTag.work,
        due: DateTime(2026, 10, 28, 9),
        hasTime: true,
        done: true,
      );
      final groups = groupTasks([...tasks, doneYesterday], now);
      expect(titles(groups.overdue), isNot(contains('Đã xong hôm qua')));
      expect(titles(groups.today), isNot(contains('Đã xong hôm qua')));
      expect(titles(groups.upcoming), isNot(contains('Đã xong hôm qua')));
    });

    test('Hôm nay: chưa xong lên trước, rồi theo giờ', () {
      final groups = groupTasks(tasks, now);
      expect(titles(groups.today), [
        'Họp nhóm EXE201',
        'Ôn tập PE Flutter (form validate)',
        'Chạy bộ 30 phút',
        'Mua sữa và trứng',
      ]);
      expect(groups.todayDone, 2);
      expect(groups.isTodayEmpty, isFalse);
      expect(groups.isAllDone, isFalse);
    });

    test('việc không có ngày thuộc Hôm nay', () {
      const noDate = Task(id: 'n', title: 'Không ngày', tag: TaskTag.personal);
      final groups = groupTasks([noDate], now);
      expect(titles(groups.today), ['Không ngày']);
    });

    test('Sắp tới sắp xếp theo thời gian', () {
      final groups = groupTasks(tasks, now);
      expect(titles(groups.upcoming), ['Thi giữa kỳ PRM393', 'Sinh nhật mẹ']);
    });

    test('isAllDone và isTodayEmpty', () {
      final allDone = groupTasks([
        for (final t in tasks) t.copyWith(done: true),
      ], now);
      expect(allDone.isAllDone, isTrue);

      final empty = groupTasks(const [], now);
      expect(empty.isTodayEmpty, isTrue);
      expect(empty.isAllDone, isFalse);
    });
  });

  group('nextTask', () {
    test('việc có giờ, chưa xong, gần nhất sau now', () {
      final today = groupTasks(tasks, now).today;
      expect(nextTask(today, now)?.title, 'Họp nhóm EXE201');
      expect(
        nextTask(today, DateTime(2026, 10, 29, 16))?.title,
        'Ôn tập PE Flutter (form validate)',
      );
    });

    test('trả về null khi không còn việc có giờ phía trước', () {
      final today = groupTasks(tasks, now).today;
      expect(nextTask(today, DateTime(2026, 10, 29, 22)), isNull);
    });
  });

  group('vi_date', () {
    test('headerDate và hourMinute', () {
      expect(headerDate(now), 'Thứ Năm, 29 tháng 10');
      expect(hourMinute(DateTime(2026, 10, 29, 14, 5)), '14:05');
    });

    test('taskTimeLabel', () {
      expect(taskTimeLabel(byTitle('Họp nhóm EXE201'), now), '14:00 – 15:00');
      expect(taskTimeLabel(byTitle('Mua sữa và trứng'), now), 'Trong ngày');
      expect(
        taskTimeLabel(byTitle('Nộp báo cáo Lab 3 PRM393'), now),
        'Hôm qua, 23:59',
      );
      expect(
        taskTimeLabel(byTitle('Thi giữa kỳ PRM393'), now),
        'T7, 31/10 · 08:00',
      );
      expect(taskTimeLabel(byTitle('Sinh nhật mẹ'), now), '03/11');

      final tomorrow = Task(
        id: 't',
        title: 'Ngày mai',
        tag: TaskTag.study,
        due: DateTime(2026, 10, 30, 8),
        hasTime: true,
      );
      expect(taskTimeLabel(tomorrow, now), 'Ngày mai · 08:00');
    });
  });
}
