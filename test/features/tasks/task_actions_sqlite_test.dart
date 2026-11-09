import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/default_tags.dart';
import 'package:personal_app/data/models/focus_session.dart';
import 'package:personal_app/data/models/subtask.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/data/sqlite/app_database.dart';
import 'package:personal_app/data/sqlite/sqlite_focus_repository.dart';
import 'package:personal_app/data/sqlite/sqlite_tag_repository.dart';
import 'package:personal_app/data/sqlite/sqlite_task_repository.dart';
import 'package:personal_app/features/tasks/task_actions.dart';
import 'package:personal_app/utils/dates.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Chạy `TaskActions` trên SQLite thật (database trong bộ nhớ), nơi khóa ngoại
/// và transaction có tác dụng.
void main() {
  sqfliteFfiInit();
  final now = DateTime(2026, 11, 9, 10);

  late AppDatabase app;
  late SqliteTaskRepository tasks;
  late SqliteTagRepository tags;
  late SqliteFocusRepository focus;
  late TaskActions actions;

  setUp(() async {
    app = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
      clock: () => now,
    );
    tasks = SqliteTaskRepository(app);
    tags = SqliteTagRepository(app);
    focus = SqliteFocusRepository(app);
    actions = TaskActions(tasks, clock: () => now);
  });

  tearDown(() => app.close());

  Task task(String id, {RepeatRule rule = RepeatRule.none, String? tagId}) =>
      Task(
        id: id,
        title: 'Việc $id',
        tagId: tagId,
        due: DateTime(2026, 11, 9, 8),
        hasTime: true,
        end: DateTime(2026, 11, 9, 9),
        reminderMinutes: 15,
        repeatRule: rule,
        createdAt: DateTime(2026, 11, 1),
      );

  test(
    'xong việc lặp: tạo lần kế tiếp kèm việc con, giữ nhãn và giờ',
    () async {
      await tasks.add(
        task('a', rule: RepeatRule.daily, tagId: DefaultTagIds.health),
        subtasks: const [
          Subtask(id: 's1', taskId: 'a', title: 'Khởi động', done: true),
          Subtask(id: 's2', taskId: 'a', title: 'Chạy'),
        ],
      );

      final next = await actions.toggleDone((await tasks.getById('a'))!);

      final old = (await tasks.getById('a'))!;
      expect(old.done, isTrue);
      expect(old.completedAt, now);
      final saved = (await tasks.getById(next!.id))!;
      expect(saved.due, DateTime(2026, 11, 10, 8));
      expect(saved.end, DateTime(2026, 11, 10, 9));
      expect(saved.tagId, DefaultTagIds.health);
      expect((saved.subtaskDone, saved.subtaskTotal), (0, 2));
      expect(await tasks.getAll(), hasLength(2));
    },
  );

  test(
    'xóa rồi hoàn tác: khôi phục việc, việc con và trạng thái xong',
    () async {
      await tasks.add(
        task('a', tagId: DefaultTagIds.work),
        subtasks: const [
          Subtask(id: 's1', taskId: 'a', title: 'Con 1', done: true),
          Subtask(id: 's2', taskId: 'a', title: 'Con 2'),
        ],
      );
      await tasks.setDone('a', true);

      final deleted = await actions.delete((await tasks.getById('a'))!);
      expect(await tasks.getById('a'), isNull);
      expect(await tasks.getSubtasks('a'), isEmpty);

      await actions.undoDelete(deleted);

      final back = (await tasks.getById('a'))!;
      expect(back.done, isTrue);
      expect(back.completedAt, now);
      expect(back.tagId, DefaultTagIds.work);
      expect((back.subtaskDone, back.subtaskTotal), (1, 2));
    },
  );

  test('xóa việc: phiên tập trung của việc đó thành không gắn việc', () async {
    await tasks.add(task('a'));
    await focus.add(
      FocusSession(
        id: 'f1',
        taskId: 'a',
        type: FocusType.pomodoro,
        startedAt: now,
        durationSec: 1500,
        completed: true,
      ),
    );

    await actions.delete((await tasks.getById('a'))!);

    final total = await focus.totalForTask('a');
    expect(total.sessions, 0);
    final sessions = await focus.sessionsByRange(
      dayRange(DateTime(2026, 11, 9)),
    );
    expect(sessions.single.taskId, isNull);
  });

  test(
    'hoàn tác khi nhãn đã bị xóa: khôi phục không nhãn, không lỗi',
    () async {
      await tasks.add(task('a', tagId: DefaultTagIds.work));
      final deleted = await actions.delete((await tasks.getById('a'))!);
      await tags.delete(DefaultTagIds.work);

      await actions.undoDelete(deleted);

      expect((await tasks.getById('a'))!.tagId, isNull);
    },
  );
}
