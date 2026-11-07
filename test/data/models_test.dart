import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/models/focus_session.dart';
import 'package:personal_app/data/models/habit.dart';
import 'package:personal_app/data/models/habit_log.dart';
import 'package:personal_app/data/models/subtask.dart';
import 'package:personal_app/data/models/tag.dart';
import 'package:personal_app/data/models/task.dart';

void main() {
  final created = DateTime(2026, 10, 20, 9);

  group('mã lưu của enum (đã chốt, không được đổi)', () {
    test('Priority', () {
      expect([for (final p in Priority.values) p.code], [0, 1, 2]);
    });

    test('RepeatRule', () {
      expect(
        [for (final r in RepeatRule.values) r.code],
        ['none', 'day', 'week', 'month'],
      );
    });

    test('FocusType', () {
      expect(
        [for (final t in FocusType.values) t.code],
        ['pomodoro', 'short', 'long', 'custom'],
      );
      expect(
        [for (final t in FocusType.values) t.isFocus],
        [true, false, false, true],
      );
    });

    test('TagColor', () {
      expect(
        [for (final c in TagColor.values) c.code],
        ['violet', 'orange', 'green', 'red', 'grey'],
      );
    });

    test('mã lạ đọc ra giá trị mặc định', () {
      expect(Priority.fromCode(9), Priority.medium);
      expect(RepeatRule.fromCode('year'), RepeatRule.none);
      expect(FocusType.fromCode(null), FocusType.custom);
      expect(TagColor.fromCode('blue'), TagColor.grey);
    });
  });

  group('Task', () {
    final full = Task(
      id: 't1',
      title: 'Họp nhóm',
      note: 'Phòng 304',
      tagId: 'tag-work',
      due: DateTime(2026, 10, 29, 14),
      end: DateTime(2026, 10, 29, 15),
      hasTime: true,
      priority: Priority.high,
      done: true,
      completedAt: DateTime(2026, 10, 29, 15, 5),
      reminderMinutes: 15,
      repeatRule: RepeatRule.weekly,
      createdAt: created,
    );

    test('toMap/fromMap giữ nguyên dữ liệu', () {
      expect(Task.fromMap(full.toMap()).toMap(), full.toMap());

      final minimal = Task(id: 't2', title: 'Không ngày', createdAt: created);
      final read = Task.fromMap(minimal.toMap());
      expect(read.toMap(), minimal.toMap());
      expect(read.tagId, isNull);
      expect(read.due, isNull);
      expect(read.reminderMinutes, isNull);
      expect(read.priority, Priority.medium);
    });

    test('toMap dùng tên cột snake_case, không có số việc con', () {
      final map = full.toMap();
      expect(
        map.keys,
        containsAll([
          'tag_id',
          'due_at',
          'end_at',
          'has_time',
          'completed_at',
          'reminder_minutes',
          'repeat_rule',
          'created_at',
        ]),
      );
      expect(map.containsKey('subtask_done'), isFalse);
    });

    test('fromMap đọc số việc con nếu truy vấn có kèm', () {
      final task = Task.fromMap({
        ...full.toMap(),
        'subtask_done': 1,
        'subtask_total': 3,
      });
      expect((task.subtaskDone, task.subtaskTotal), (1, 3));
    });

    test('copyWith: bỏ tham số thì giữ nguyên, truyền () => null thì xóa', () {
      final renamed = full.copyWith(title: 'Họp nhóm EXE201');
      expect(renamed.title, 'Họp nhóm EXE201');
      expect(renamed.tagId, 'tag-work');

      final cleared = full.copyWith(
        tagId: () => null,
        due: () => null,
        reminderMinutes: () => null,
      );
      expect(cleared.tagId, isNull);
      expect(cleared.due, isNull);
      expect(cleared.reminderMinutes, isNull);
      expect(cleared.id, full.id);
    });
  });

  test('Subtask toMap/fromMap', () {
    const subtask = Subtask(
      id: 's1',
      taskId: 't1',
      title: 'Viết validator',
      done: true,
    );
    expect(Subtask.fromMap(subtask.toMap()).toMap(), subtask.toMap());
  });

  test('Tag toMap/fromMap', () {
    const tag = Tag(id: 'g1', name: 'Gia đình', color: TagColor.red);
    expect(tag.toMap(), {'id': 'g1', 'name': 'Gia đình', 'color': 'red'});
    expect(Tag.fromMap(tag.toMap()).toMap(), tag.toMap());
  });

  test('FocusSession toMap/fromMap và endedAt', () {
    final session = FocusSession(
      id: 'f1',
      taskId: 't1',
      type: FocusType.pomodoro,
      startedAt: DateTime(2026, 10, 29, 9, 5),
      durationSec: 1500,
      completed: true,
    );
    expect(FocusSession.fromMap(session.toMap()).toMap(), session.toMap());
    expect(session.endedAt, DateTime(2026, 10, 29, 9, 30));
    expect(session.copyWith(taskId: () => null).taskId, isNull);
  });

  group('Habit', () {
    final habit = Habit(
      id: 'h1',
      name: 'Tập gym',
      icon: 'heart',
      color: const Color(0xFFBE185D),
      repeatDays: const {5, 1, 3},
      goalPerDay: 2,
      unit: 'buổi',
      reminderTime: const TimeOfDay(hour: 20, minute: 0),
      startDate: DateTime(2026, 10, 1),
      archivedAt: DateTime(2026, 10, 20, 8),
    );

    test('toMap/fromMap giữ nguyên dữ liệu', () {
      expect(Habit.fromMap(habit.toMap()).toMap(), habit.toMap());
    });

    test(
      'repeatDays lưu "1,3,5", reminderTime lưu số phút, ngày lưu yyyy-MM-dd',
      () {
        final map = habit.toMap();
        expect(map['repeat_days'], '1,3,5');
        expect(map['reminder_time'], 1200);
        expect(map['start_date'], '2026-10-01');
        expect(map['color'], 0xFFBE185D);
      },
    );

    test('archived suy ra từ archivedAt', () {
      expect(habit.archived, isTrue);
      expect(habit.copyWith(archivedAt: () => null).archived, isFalse);
    });
  });

  test('HabitLog lưu ngày dạng yyyy-MM-dd', () {
    final log = HabitLog(habitId: 'h1', date: DateTime(2026, 10, 29), count: 5);
    expect(log.toMap(), {'habit_id': 'h1', 'date': '2026-10-29', 'count': 5});
    expect(HabitLog.fromMap(log.toMap()).date, DateTime(2026, 10, 29));
  });
}
