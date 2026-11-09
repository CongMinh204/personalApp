import 'dart:io';

import 'package:flutter/material.dart' show Color, DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/default_tags.dart';
import 'package:personal_app/data/models/focus_session.dart';
import 'package:personal_app/data/models/habit.dart';
import 'package:personal_app/data/models/subtask.dart';
import 'package:personal_app/data/models/tag.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/data/sqlite/app_database.dart';
import 'package:personal_app/data/sqlite/sqlite_focus_repository.dart';
import 'package:personal_app/data/sqlite/sqlite_habit_repository.dart';
import 'package:personal_app/data/sqlite/sqlite_tag_repository.dart';
import 'package:personal_app/data/sqlite/sqlite_task_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'repository_contract.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  Future<(AppDatabase, RepositorySet)> open(
    DateTime Function() clock, {
    String? path,
  }) async {
    final app = await AppDatabase.open(
      path: path ?? inMemoryDatabasePath,
      factory: factory,
      clock: clock,
    );
    return (
      app,
      RepositorySet(
        tasks: SqliteTaskRepository(app),
        tags: SqliteTagRepository(app),
        focus: SqliteFocusRepository(app),
        habits: SqliteHabitRepository(app),
        close: app.close,
      ),
    );
  }

  runRepositoryContract('SQLite', (clock) async => (await open(clock)).$2);

  group('Database SQLite', () {
    late DateTime now;
    late AppDatabase app;
    late RepositorySet repos;

    setUp(() async {
      now = DateTime(2026, 11, 9, 10);
      final opened = await open(() => now);
      app = opened.$1;
      repos = opened.$2;
    });

    tearDown(() => app.close());

    Task task(String id, {String? tagId}) => Task(
      id: id,
      title: 'Việc $id',
      tagId: tagId,
      due: DateTime(2026, 11, 9, 9),
      createdAt: now,
    );

    Habit habit(String id) => Habit(
      id: id,
      name: 'Uống nước',
      icon: 'drop',
      color: const Color(0xFF1E6FD9),
      startDate: DateTime(2026, 11, 1),
    );

    test('bật khóa ngoại', () async {
      final rows = await app.db.rawQuery('PRAGMA foreign_keys');
      expect(rows.first.values.first, 1);
    });

    test('có 4 nhãn mặc định ngay khi tạo database', () async {
      final tags = await repos.tags.getAll();
      expect([for (final t in tags) t.id], [for (final t in defaultTags) t.id]);
    });

    test('có đủ 6 bảng và các index', () async {
      final rows = await app.db.query(
        'sqlite_master',
        columns: ['type', 'name'],
        where: "name NOT LIKE 'sqlite_%'",
      );
      final names = {for (final r in rows) r['name'] as String};
      expect(
        names,
        containsAll([
          'tags',
          'tasks',
          'subtasks',
          'focus_sessions',
          'habits',
          'habit_logs',
          'idx_tasks_due_at',
          'idx_tasks_tag_id',
          'idx_tasks_completed_at',
          'idx_subtasks_task_id',
          'idx_focus_sessions_started_at',
          'idx_focus_sessions_task_id',
        ]),
      );
    });

    test(
      'xóa việc: việc con bị xóa theo, phiên tập trung thành không gắn việc',
      () async {
        await repos.tasks.add(
          task('a'),
          subtasks: const [Subtask(id: 's1', taskId: 'a', title: 'Con')],
        );
        await repos.focus.add(
          FocusSession(
            id: 'f1',
            taskId: 'a',
            type: FocusType.pomodoro,
            startedAt: now,
            durationSec: 1500,
            completed: true,
          ),
        );

        await repos.tasks.delete('a');

        expect(await repos.tasks.getSubtasks('a'), isEmpty);
        final sessions = await repos.focus.sessionsByRange(
          DateTimeRange(
            start: DateTime(2026, 11, 9),
            end: DateTime(2026, 11, 10),
          ),
        );
        expect(sessions, hasLength(1));
        expect(sessions.single.taskId, isNull);
      },
    );

    test('xóa nhãn: việc dùng nhãn về không nhãn', () async {
      await repos.tasks.add(task('a', tagId: DefaultTagIds.work));
      await repos.tags.delete(DefaultTagIds.work);
      expect((await repos.tasks.getById('a'))!.tagId, isNull);
    });

    test('xóa thói quen: nhật ký bị xóa theo', () async {
      await repos.habits.add(habit('h'));
      await repos.habits.setCount('h', now, 2);

      await repos.habits.delete('h');

      final rows = await app.db.query('habit_logs');
      expect(rows, isEmpty);
    });

    test('add có việc con lỗi thì không lưu gì (transaction)', () async {
      await expectLater(
        repos.tasks.add(
          task('a'),
          subtasks: const [
            Subtask(id: 's1', taskId: 'a', title: 'Hợp lệ'),
            Subtask(id: 's2', taskId: 'a', title: '   '),
          ],
        ),
        throwsArgumentError,
      );
      expect(await repos.tasks.getById('a'), isNull);
      expect(await app.db.query('subtasks'), isEmpty);
    });

    test('tìm kiếm không phân biệt hoa thường với chữ có dấu', () async {
      await repos.tasks.add(
        Task(id: 'a', title: 'Ôn tập PE Flutter', createdAt: now),
      );
      expect([for (final t in await repos.tasks.search('ÔN TẬP')) t.id], ['a']);
    });

    test(
      'watch phát lại khi ghi, kể cả ghi gián tiếp qua khóa ngoại',
      () async {
        await repos.tasks.add(task('a', tagId: DefaultTagIds.study));
        final counts = <Map<String, int>>[];
        final sub = repos.tags.watchTaskCounts().listen(counts.add);
        // SQLite đọc ở luồng nền: chờ theo điều kiện, không chờ số vòng cố định
        // (nếu không sẽ chập chờn khi máy bận).
        await eventually(() => counts.isNotEmpty);
        expect(counts.last, {DefaultTagIds.study: 1});

        await repos.tags.delete(DefaultTagIds.study);
        await eventually(() => counts.last.isEmpty);
        expect(counts.last, isEmpty);

        await sub.cancel();
      },
    );

    test('watch của việc con phát lại khi xóa việc cha', () async {
      await repos.tasks.add(
        task('a'),
        subtasks: const [Subtask(id: 's1', taskId: 'a', title: 'Con')],
      );
      final emitted = <int>[];
      final sub = repos.tasks
          .watchSubtasks('a')
          .listen((list) => emitted.add(list.length));
      await eventually(() => emitted.isNotEmpty);
      await repos.tasks.delete('a');
      await eventually(() => emitted.length >= 2);

      expect(emitted, [1, 0]);
      await sub.cancel();
    });
  });

  group('File database thật', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('personal_app_db'));

    tearDown(() async {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test(
      'đóng rồi mở lại vẫn còn dữ liệu, 4 nhãn mặc định không bị nhân đôi',
      () async {
        final path = '${dir.path}/personal_app.db';
        final now = DateTime(2026, 11, 9, 10);

        var opened = await open(() => now, path: path);
        await opened.$2.tags.add(
          const Tag(id: 'tag-moi', name: 'Dự án', color: TagColor.green),
        );
        await opened.$2.tasks.add(
          Task(id: 'a', title: 'Còn mãi', tagId: 'tag-moi', createdAt: now),
          subtasks: const [Subtask(id: 's1', taskId: 'a', title: 'Con')],
        );
        await opened.$2.tasks.setDone('a', true);
        await opened.$1.close();

        opened = await open(() => now, path: path);
        final tasks = opened.$2.tasks;
        final saved = (await tasks.getById('a'))!;
        expect(saved.title, 'Còn mãi');
        expect(saved.tagId, 'tag-moi');
        expect(saved.done, isTrue);
        expect(saved.completedAt, now);
        expect((saved.subtaskDone, saved.subtaskTotal), (0, 1));
        expect(
          await opened.$2.tags.getAll(),
          hasLength(defaultTags.length + 1),
        );
        await opened.$1.close();
      },
    );
  });
}
