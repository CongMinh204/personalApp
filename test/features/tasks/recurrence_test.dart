import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/models/subtask.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/features/tasks/recurrence.dart';

void main() {
  group('nextDue', () {
    test('không lặp thì giữ nguyên', () {
      final due = DateTime(2026, 11, 9, 8);
      expect(nextDue(due, RepeatRule.none), due);
    });

    test('lặp ngày: cộng 1 ngày, giữ giờ, qua cuối tháng và cuối năm', () {
      expect(
        nextDue(DateTime(2026, 11, 9, 7, 30), RepeatRule.daily),
        DateTime(2026, 11, 10, 7, 30),
      );
      expect(
        nextDue(DateTime(2026, 11, 30), RepeatRule.daily),
        DateTime(2026, 12, 1),
      );
      expect(
        nextDue(DateTime(2026, 12, 31, 23, 59), RepeatRule.daily),
        DateTime(2027, 1, 1, 23, 59),
      );
    });

    test('lặp tuần: cộng 7 ngày, cùng thứ', () {
      final due = DateTime(2026, 10, 29, 19, 30); // Thứ Năm
      final next = nextDue(due, RepeatRule.weekly);
      expect(next, DateTime(2026, 11, 5, 19, 30));
      expect(next.weekday, due.weekday);
      expect(
        nextDue(DateTime(2026, 12, 28), RepeatRule.weekly),
        DateTime(2027, 1, 4),
      );
    });

    test('lặp tháng: cùng ngày trong tháng kế tiếp', () {
      expect(
        nextDue(DateTime(2026, 10, 29, 8), RepeatRule.monthly),
        DateTime(2026, 11, 29, 8),
      );
      expect(
        nextDue(DateTime(2026, 12, 15), RepeatRule.monthly),
        DateTime(2027, 1, 15),
      );
    });

    test('lặp tháng: tháng ngắn hơn thì lấy ngày cuối tháng', () {
      expect(
        nextDue(DateTime(2026, 1, 31), RepeatRule.monthly),
        DateTime(2026, 2, 28),
      );
      expect(
        nextDue(DateTime(2026, 3, 31), RepeatRule.monthly),
        DateTime(2026, 4, 30),
      );
      expect(
        nextDue(DateTime(2026, 8, 31), RepeatRule.monthly),
        DateTime(2026, 9, 30),
      );
    });

    test('lặp tháng: năm nhuận có 29/2', () {
      expect(
        nextDue(DateTime(2028, 1, 31), RepeatRule.monthly),
        DateTime(2028, 2, 29),
      );
      expect(
        nextDue(DateTime(2028, 1, 29), RepeatRule.monthly),
        DateTime(2028, 2, 29),
      );
      expect(
        nextDue(DateTime(2028, 2, 29), RepeatRule.monthly),
        DateTime(2028, 3, 29),
      );
    });

    test('lặp tháng từ tháng 12 sang tháng 1 năm sau', () {
      expect(
        nextDue(DateTime(2026, 12, 31), RepeatRule.monthly),
        DateTime(2027, 1, 31),
      );
    });
  });

  group('nextOccurrence', () {
    final now = DateTime(2026, 11, 9, 10);

    Task task({
      DateTime? due,
      DateTime? end,
      bool hasTime = false,
      RepeatRule rule = RepeatRule.daily,
    }) => Task(
      id: 'cu',
      title: 'Chạy bộ',
      note: 'Công viên',
      tagId: 'tag-health',
      due: due,
      end: end,
      hasTime: hasTime,
      priority: Priority.high,
      done: true,
      completedAt: DateTime(2026, 11, 9, 7),
      reminderMinutes: 15,
      repeatRule: rule,
      createdAt: DateTime(2026, 10, 1),
    );

    test('không lặp hoặc không có ngày thì không có lần kế tiếp', () {
      expect(
        nextOccurrence(
          task(due: DateTime(2026, 11, 9), rule: RepeatRule.none),
          now,
          id: 'moi',
        ),
        isNull,
      );
      expect(nextOccurrence(task(), now, id: 'moi'), isNull);
    });

    test('lần kế tiếp là việc mới chưa xong, giữ các trường còn lại', () {
      final next = nextOccurrence(
        task(due: DateTime(2026, 11, 9, 6), hasTime: true),
        now,
        id: 'moi',
      )!;

      expect(next.id, 'moi');
      expect(next.due, DateTime(2026, 11, 10, 6));
      expect(next.hasTime, isTrue);
      expect(next.done, isFalse);
      expect(next.completedAt, isNull);
      expect(next.createdAt, now);
      expect(
        (next.title, next.note, next.tagId, next.priority),
        ('Chạy bộ', 'Công viên', 'tag-health', Priority.high),
      );
      expect((next.reminderMinutes, next.repeatRule), (15, RepeatRule.daily));
    });

    test('giờ kết thúc dời theo cùng ngày', () {
      final next = nextOccurrence(
        task(
          due: DateTime(2026, 11, 9, 19, 30),
          end: DateTime(2026, 11, 9, 21),
          hasTime: true,
          rule: RepeatRule.weekly,
        ),
        now,
        id: 'moi',
      )!;
      expect(next.due, DateTime(2026, 11, 16, 19, 30));
      expect(next.end, DateTime(2026, 11, 16, 21));
    });

    test('việc cả ngày không có giờ kết thúc', () {
      final next = nextOccurrence(
        task(due: DateTime(2026, 11, 9)),
        now,
        id: 'moi',
      )!;
      expect(next.hasTime, isFalse);
      expect(next.end, isNull);
    });

    test('hoàn thành trễ: nhảy tới lần lặp đầu tiên từ hôm nay', () {
      // Lặp ngày, hạn 5 ngày trước: lần kế tiếp là hôm nay.
      final daily = nextOccurrence(
        task(due: DateTime(2026, 11, 4, 8), hasTime: true),
        now,
        id: 'moi',
      )!;
      expect(daily.due, DateTime(2026, 11, 9, 8));

      // Lặp tuần, hạn 10 ngày trước (Thứ Năm 30/10): lần kế tiếp là 13/11.
      final weekly = nextOccurrence(
        task(due: DateTime(2026, 10, 30), rule: RepeatRule.weekly),
        now,
        id: 'moi',
      )!;
      expect(weekly.due, DateTime(2026, 11, 13));
    });

    test('hoàn thành đúng hạn hôm nay thì lần kế tiếp là ngày mai', () {
      final next = nextOccurrence(
        task(due: DateTime(2026, 11, 9)),
        now,
        id: 'moi',
      )!;
      expect(next.due, DateTime(2026, 11, 10));
    });
  });

  test('nextSubtasks: cùng tên, chưa xong, id mới thuộc việc mới', () {
    var n = 0;
    final copies = nextSubtasks('moi', const [
      Subtask(id: 's1', taskId: 'cu', title: 'Khởi động', done: true),
      Subtask(id: 's2', taskId: 'cu', title: 'Chạy'),
    ], makeId: () => 'id${n++}');

    expect([for (final s in copies) s.id], ['id0', 'id1']);
    expect([for (final s in copies) s.title], ['Khởi động', 'Chạy']);
    expect(copies.every((s) => s.taskId == 'moi' && !s.done), isTrue);
  });
}
