import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/data/repositories/focus_repository.dart';
import 'package:personal_app/features/tasks/task_labels.dart';

void main() {
  Task task({
    DateTime? due,
    DateTime? end,
    bool hasTime = false,
    int? reminder,
    Priority priority = Priority.medium,
  }) => Task(
    id: 'a',
    title: 'Việc',
    due: due,
    end: end,
    hasTime: hasTime,
    reminderMinutes: reminder,
    priority: priority,
    createdAt: DateTime(2026, 10, 1),
  );

  test('priorityLabel', () {
    expect(priorityLabel(Priority.high), 'Ưu tiên cao');
    expect(priorityLabel(Priority.medium), 'Ưu tiên trung bình');
    expect(priorityLabel(Priority.low), 'Ưu tiên thấp');
  });

  test('dueDateLabel', () {
    expect(dueDateLabel(task(due: DateTime(2026, 10, 29))), 'Th 5, 29/10/2026');
    expect(dueDateLabel(task()), 'Không có ngày');
  });

  test('dueTimeLabel: cả ngày, chỉ giờ bắt đầu, có giờ kết thúc', () {
    expect(dueTimeLabel(task(due: DateTime(2026, 10, 29))), 'Cả ngày');
    expect(
      dueTimeLabel(task(due: DateTime(2026, 10, 29, 9, 5), hasTime: true)),
      '09:05',
    );
    expect(
      dueTimeLabel(
        task(
          due: DateTime(2026, 10, 29, 19, 30),
          end: DateTime(2026, 10, 29, 21),
          hasTime: true,
        ),
      ),
      '19:30 → 21:00',
    );
  });

  test('reminderValueLabel', () {
    expect(reminderValueLabel(task()), 'Không nhắc');
    expect(reminderValueLabel(task(reminder: 0)), 'Đúng giờ');
    expect(reminderValueLabel(task(reminder: 15)), '15 phút');
    expect(reminderValueLabel(task(reminder: 1440)), '1 ngày');
  });

  test('focusTotalLabel', () {
    expect(
      focusTotalLabel(const FocusTotal(seconds: 0, sessions: 0)),
      'Chưa tập trung',
    );
    expect(
      focusTotalLabel(const FocusTotal(seconds: 3000, sessions: 2)),
      '50 phút · 2 phiên',
    );
    expect(
      focusTotalLabel(const FocusTotal(seconds: 20, sessions: 1)),
      'dưới 1 phút · 1 phiên',
    );
    // Làm tròn tới phút gần nhất: 89 giây ≈ 1 phút.
    expect(
      focusTotalLabel(const FocusTotal(seconds: 89, sessions: 1)),
      '1 phút · 1 phiên',
    );
  });
}
