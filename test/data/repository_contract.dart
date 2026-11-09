import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/default_tags.dart';
import 'package:personal_app/data/models/focus_session.dart';
import 'package:personal_app/data/models/habit.dart';
import 'package:personal_app/data/models/subtask.dart';
import 'package:personal_app/data/models/tag.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/data/repositories/focus_repository.dart';
import 'package:personal_app/data/repositories/habit_repository.dart';
import 'package:personal_app/data/repositories/tag_repository.dart';
import 'package:personal_app/data/repositories/task_repository.dart';
import 'package:personal_app/utils/dates.dart';

/// Bộ repository mà một bản cài đặt (Fake, SQLite) đưa vào bộ test.
class RepositorySet {
  const RepositorySet({
    required this.tasks,
    required this.tags,
    required this.focus,
    required this.habits,
    this.close,
  });

  final TaskRepository tasks;
  final TagRepository tags;
  final FocusRepository focus;
  final HabitRepository habits;
  final Future<void> Function()? close;
}

/// Cùng một bộ test cho mọi bản cài đặt repository, để chúng cư xử giống nhau.
/// [create] tạo dữ liệu như app mới cài (chỉ có 4 nhãn mặc định) và dùng
/// [clock] làm giờ hiện tại.
void runRepositoryContract(
  String name,
  Future<RepositorySet> Function(DateTime Function() clock) create,
) {
  group('Hợp đồng repository ($name)', () {
    late RepositorySet repos;
    late DateTime now;

    setUp(() async {
      now = DateTime(2026, 10, 29, 13, 40);
      repos = await create(() => now);
    });

    tearDown(() async => repos.close?.call());

    Task task(
      String id, {
      String title = 'Việc',
      String note = '',
      String? tagId,
      DateTime? due,
      bool hasTime = false,
    }) => Task(
      id: id,
      title: title,
      note: note,
      tagId: tagId,
      due: due,
      hasTime: hasTime,
      createdAt: now,
    );

    group('TaskRepository', () {
      test('add rồi getById đọc lại đúng dữ liệu', () async {
        final added = task(
          'a',
          title: 'Họp nhóm',
          note: 'Phòng 304',
          tagId: DefaultTagIds.work,
          due: DateTime(2026, 10, 29, 14),
          hasTime: true,
        );
        await repos.tasks.add(added);
        expect((await repos.tasks.getById('a'))?.toMap(), added.toMap());
        expect(await repos.tasks.getById('khong-co'), isNull);
      });

      test('watchAll phát danh sách hiện tại rồi phát lại khi thêm', () async {
        final emitted = <List<String>>[];
        final sub = repos.tasks.watchAll().listen(
          (list) => emitted.add([for (final t in list) t.id]),
        );
        await eventually(() => emitted.isNotEmpty);
        expect(emitted.first, isEmpty);

        await repos.tasks.add(task('a'));
        await eventually(() => emitted.last.contains('a'));
        await sub.cancel();
      });

      test(
        'luồng watch nghe lại được sau khi hủy (widget bị tạo lại)',
        () async {
          // Widget trong danh sách cuộn bị hủy rồi tạo lại khi cuộn ra và vào
          // màn hình, và nghe lại đúng luồng cũ.
          final stream = repos.tasks.watchAll();
          final first = await stream.first; // nghe rồi hủy sau giá trị đầu
          await repos.tasks.add(task('a'));
          final second = await stream.first; // nghe lại cùng luồng

          expect(first, isEmpty);
          expect([for (final t in second) t.id], ['a']);
        },
      );

      test('luồng nhãn và thói quen cũng nghe lại được sau khi hủy', () async {
        final tags = repos.tags.watchAll();
        expect(await tags.first, hasLength(4));
        expect(await tags.first, hasLength(4));

        final habits = repos.habits.watchActive();
        expect(await habits.first, isEmpty);
        expect(await habits.first, isEmpty);
      });

      test('setDone đặt completedAt theo đồng hồ, bỏ xong thì xóa', () async {
        await repos.tasks.add(task('a'));
        await repos.tasks.setDone('a', true);
        var read = (await repos.tasks.getById('a'))!;
        expect(read.done, isTrue);
        expect(read.completedAt, now);

        await repos.tasks.setDone('a', false);
        read = (await repos.tasks.getById('a'))!;
        expect(read.done, isFalse);
        expect(read.completedAt, isNull);
      });

      test('update không đổi done/completedAt', () async {
        await repos.tasks.add(task('a'));
        await repos.tasks.setDone('a', true);
        final read = (await repos.tasks.getById('a'))!;
        await repos.tasks.update(
          read.copyWith(title: 'Đổi tên', done: false, completedAt: () => null),
        );
        final after = (await repos.tasks.getById('a'))!;
        expect(after.title, 'Đổi tên');
        expect(after.done, isTrue);
        expect(after.completedAt, now);
      });

      test(
        'việc con: thêm kèm việc, update thay toàn bộ, Task có số đếm',
        () async {
          await repos.tasks.add(
            task('a'),
            subtasks: const [
              Subtask(id: 's1', taskId: 'a', title: 'Một', done: true),
              Subtask(id: 's2', taskId: 'a', title: 'Hai'),
            ],
          );
          var read = (await repos.tasks.getById('a'))!;
          expect((read.subtaskDone, read.subtaskTotal), (1, 2));
          expect(
            [for (final s in await repos.tasks.getSubtasks('a')) s.title],
            ['Một', 'Hai'],
          );

          await repos.tasks.update(
            read,
            subtasks: const [Subtask(id: 's3', taskId: 'a', title: 'Ba')],
          );
          expect(
            [for (final s in await repos.tasks.getSubtasks('a')) s.id],
            ['s3'],
          );

          await repos.tasks.setSubtaskDone('s3', true);
          read = (await repos.tasks.getById('a'))!;
          expect((read.subtaskDone, read.subtaskTotal), (1, 1));
        },
      );

      test(
        'delete xóa việc con, phiên tập trung thành không gắn việc',
        () async {
          await repos.tasks.add(
            task('a'),
            subtasks: const [Subtask(id: 's1', taskId: 'a', title: 'Một')],
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
          expect(await repos.tasks.getById('a'), isNull);
          expect(await repos.tasks.getSubtasks('a'), isEmpty);
          final sessions = await repos.focus.sessionsByRange(dayRange(now));
          expect(sessions.single.taskId, isNull);
        },
      );

      test('hoàn tác xóa: add lại đúng việc cũ với id cũ', () async {
        final original = task('a', title: 'Họp nhóm');
        await repos.tasks.add(original);
        await repos.tasks.delete('a');
        await repos.tasks.add(original);
        expect((await repos.tasks.getById('a'))?.title, 'Họp nhóm');
      });

      test('deleteCompleted trả về số việc đã xóa', () async {
        for (final id in ['a', 'b', 'c']) {
          await repos.tasks.add(task(id));
        }
        await repos.tasks.setDone('a', true);
        await repos.tasks.setDone('c', true);
        expect(await repos.tasks.deleteCompleted(), 2);
        expect([for (final t in await repos.tasks.getAll()) t.id], ['b']);
      });

      test('watchByDay chỉ gồm việc trong ngày, sắp theo due', () async {
        await repos.tasks.add(
          task('late', due: DateTime(2026, 10, 29, 19), hasTime: true),
        );
        await repos.tasks.add(
          task('early', due: DateTime(2026, 10, 29, 8), hasTime: true),
        );
        await repos.tasks.add(
          task('tomorrow', due: DateTime(2026, 10, 30, 8), hasTime: true),
        );
        await repos.tasks.add(task('no-date'));
        final list = await repos.tasks.watchByDay(DateTime(2026, 10, 29)).first;
        expect([for (final t in list) t.id], ['early', 'late']);
      });

      test('getUnfinished sắp theo due, việc không có ngày ở cuối', () async {
        await repos.tasks.add(task('no-date'));
        await repos.tasks.add(task('later', due: DateTime(2026, 11, 2)));
        await repos.tasks.add(task('sooner', due: DateTime(2026, 10, 30)));
        await repos.tasks.add(task('done', due: DateTime(2026, 10, 29)));
        await repos.tasks.setDone('done', true);
        expect(
          [for (final t in await repos.tasks.getUnfinished()) t.id],
          ['sooner', 'later', 'no-date'],
        );
      });

      test(
        'search tìm cả ghi chú và tên nhãn, không phân biệt hoa thường',
        () async {
          await repos.tasks.add(task('a', title: 'Họp nhóm EXE201'));
          await repos.tasks.add(
            task('b', title: 'Đọc sách', note: 'Chương họp mặt'),
          );
          await repos.tasks.add(
            task('c', title: 'Bài tập', tagId: DefaultTagIds.study),
          );
          await repos.tasks.add(task('d', title: 'Mua sữa'));

          Future<List<String>> ids(String query) async => [
            for (final t in await repos.tasks.search(query)) t.id,
          ];
          expect(await ids('HỌP'), unorderedEquals(['a', 'b']));
          expect(await ids('học tập'), ['c']);
          expect(await ids('   '), isEmpty);
        },
      );

      test('countDoneByDay đủ các ngày, tính theo completedAt', () async {
        await repos.tasks.add(task('a'));
        await repos.tasks.add(task('b'));
        await repos.tasks.setDone('a', true);
        now = DateTime(2026, 10, 30, 9);
        await repos.tasks.setDone('b', true);

        final counts = await repos.tasks.countDoneByDay(
          daysRange(DateTime(2026, 10, 28), 3),
        );
        expect(counts, {
          DateTime(2026, 10, 28): 0,
          DateTime(2026, 10, 29): 1,
          DateTime(2026, 10, 30): 1,
        });

        final completed = await repos.tasks.getCompletedInRange(
          dayRange(DateTime(2026, 10, 30)),
        );
        expect([for (final t in completed) t.id], ['b']);
      });

      test('báo lỗi khi tiêu đề trống, nhãn không tồn tại, id đã có', () async {
        await expectLater(
          repos.tasks.add(task('a', title: '  ')),
          throwsArgumentError,
        );
        await expectLater(
          repos.tasks.add(task('a', tagId: 'khong-co')),
          throwsArgumentError,
        );
        await repos.tasks.add(task('a'));
        await expectLater(repos.tasks.add(task('a')), throwsStateError);
      });
    });

    group('TagRepository', () {
      test('có sẵn 4 nhãn mặc định, theo thứ tự tạo', () async {
        expect(
          [for (final t in await repos.tags.getAll()) t.name],
          ['Học tập', 'Công việc', 'Cá nhân', 'Sức khỏe'],
        );
      });

      test('add cắt khoảng trắng; tên trống hoặc trùng thì báo lỗi', () async {
        await repos.tags.add(
          const Tag(id: 'g1', name: '  Gia đình  ', color: TagColor.red),
        );
        expect((await repos.tags.getById('g1'))?.name, 'Gia đình');
        await expectLater(
          repos.tags.add(const Tag(id: 'g2', name: '   ')),
          throwsArgumentError,
        );
        await expectLater(
          repos.tags.add(const Tag(id: 'g3', name: 'HỌC TẬP')),
          throwsA(isA<DuplicateTagNameException>()),
        );
        // Trùng tên với chính nó thì được.
        await repos.tags.update(const Tag(id: 'g1', name: 'gia ĐÌNH'));
        expect((await repos.tags.getById('g1'))?.name, 'gia ĐÌNH');
      });

      test(
        'delete chuyển việc thành không nhãn, đếm số việc cập nhật',
        () async {
          await repos.tasks.add(task('a', tagId: DefaultTagIds.work));
          await repos.tasks.add(task('b', tagId: DefaultTagIds.work));
          await repos.tasks.add(task('c', tagId: DefaultTagIds.study));

          final counts = <Map<String, int>>[];
          final sub = repos.tags.watchTaskCounts().listen(counts.add);
          await eventually(() => counts.isNotEmpty);
          expect(counts.last, {DefaultTagIds.work: 2, DefaultTagIds.study: 1});

          await repos.tags.delete(DefaultTagIds.work);
          await eventually(() => !counts.last.containsKey(DefaultTagIds.work));
          expect(counts.last, {DefaultTagIds.study: 1});
          expect((await repos.tasks.getById('a'))?.tagId, isNull);
          expect(await repos.tags.getById(DefaultTagIds.work), isNull);
          await sub.cancel();
        },
      );
    });

    group('FocusRepository', () {
      FocusSession session(
        String id, {
        String? taskId,
        FocusType type = FocusType.pomodoro,
        required DateTime startedAt,
        int minutes = 25,
        bool completed = true,
      }) => FocusSession(
        id: id,
        taskId: taskId,
        type: type,
        startedAt: startedAt,
        durationSec: minutes * 60,
        completed: completed,
      );

      test('sessionsByRange theo startedAt, mới nhất trước', () async {
        await repos.focus.add(
          session('f1', startedAt: DateTime(2026, 10, 29, 9)),
        );
        await repos.focus.add(
          session('f2', startedAt: DateTime(2026, 10, 29, 10)),
        );
        await repos.focus.add(
          session('f3', startedAt: DateTime(2026, 10, 28, 20)),
        );
        final today = await repos.focus.sessionsByRange(dayRange(now));
        expect([for (final s in today) s.id], ['f2', 'f1']);
      });

      test(
        'totalForTask chỉ cộng phiên tập trung của việc, kể cả bỏ dở',
        () async {
          await repos.tasks.add(task('a'));
          await repos.focus.add(session('f1', taskId: 'a', startedAt: now));
          await repos.focus.add(
            session(
              'f2',
              taskId: 'a',
              startedAt: now,
              minutes: 12,
              completed: false,
            ),
          );
          await repos.focus.add(
            session(
              'f3',
              taskId: 'a',
              type: FocusType.shortBreak,
              startedAt: now,
              minutes: 5,
            ),
          );
          await repos.focus.add(session('f4', startedAt: now));
          final total = await repos.focus.totalForTask('a');
          expect((total.seconds, total.sessions), (37 * 60, 2));
        },
      );

      test('add với taskId không tồn tại báo lỗi', () async {
        await expectLater(
          repos.focus.add(session('f1', taskId: 'khong-co', startedAt: now)),
          throwsArgumentError,
        );
      });
    });

    group('HabitRepository', () {
      Habit habit(
        String id, {
        int goal = 1,
        Set<int> days = const {1, 2, 3, 4, 5, 6, 7},
      }) => Habit(
        id: id,
        name: 'Uống nước',
        goalPerDay: goal,
        repeatDays: days,
        startDate: DateTime(2026, 10, 1),
      );

      test(
        'setArchived đặt archivedAt; danh sách đang dùng/lưu trữ tách đúng',
        () async {
          await repos.habits.add(habit('h1'));
          await repos.habits.add(habit('h2'));
          await repos.habits.setArchived('h2', true);
          expect((await repos.habits.getById('h2'))?.archivedAt, now);
          expect(
            [for (final h in await repos.habits.watchActive().first) h.id],
            ['h1'],
          );
          expect(
            [for (final h in await repos.habits.watchArchived().first) h.id],
            ['h2'],
          );

          await repos.habits.setArchived('h2', false);
          expect((await repos.habits.getById('h2'))?.archived, isFalse);
        },
      );

      test('increment, setCount và watchCountsOn', () async {
        await repos.habits.add(habit('h1', goal: 8));
        expect(await repos.habits.increment('h1', now), 1);
        expect(await repos.habits.increment('h1', now), 2);
        expect(await repos.habits.watchCountsOn(now).first, {'h1': 2});

        await repos.habits.setCount('h1', now, 0);
        expect(await repos.habits.watchCountsOn(now).first, isEmpty);
        expect(await repos.habits.logsByRange('h1', dayRange(now)), isEmpty);
      });

      test('streakOf và bestStreakOf theo quy tắc chuỗi ngày', () async {
        await repos.habits.add(habit('h1'));
        for (final day in [21, 22, 23, 25, 26, 27, 28]) {
          await repos.habits.setCount('h1', DateTime(2026, 10, day), 1);
        }
        // 24/10 bỏ lỡ; 25–28 đã làm; hôm nay (29) chưa làm nên chưa đứt chuỗi.
        expect(await repos.habits.streakOf('h1'), 4);
        expect(await repos.habits.bestStreakOf('h1'), 4);
      });

      test('delete xóa cả nhật ký', () async {
        await repos.habits.add(habit('h1'));
        await repos.habits.setCount('h1', now, 1);
        await repos.habits.delete('h1');
        expect(await repos.habits.getById('h1'), isNull);
        expect(await repos.habits.logsByRange('h1', dayRange(now)), isEmpty);
      });

      test('báo lỗi khi tên trống, mục tiêu < 1, không có ngày lặp', () async {
        await expectLater(
          repos.habits.add(Habit(id: 'x', name: ' ', startDate: now)),
          throwsArgumentError,
        );
        await expectLater(
          repos.habits.add(habit('y', goal: 0)),
          throwsArgumentError,
        );
        await expectLater(
          repos.habits.add(habit('z', days: const {})),
          throwsArgumentError,
        );
        await expectLater(
          repos.habits.setCount('khong-co', now, 1),
          throwsArgumentError,
        );
      });
    });
  });
}

/// Chờ tới khi [condition] đúng (stream có thể phát bất đồng bộ).
Future<void> eventually(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'Hết thời gian chờ stream phát');
}
