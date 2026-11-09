import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/default_tags.dart';
import 'package:personal_app/data/fake/fake_store.dart';
import 'package:personal_app/data/fake/fake_tag_repository.dart';
import 'package:personal_app/data/fake/fake_task_repository.dart';
import 'package:personal_app/data/models/subtask.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/features/tasks/task_actions.dart';

void main() {
  final now = DateTime(2026, 11, 9, 10);
  late FakeStore store;
  late FakeTaskRepository tasks;
  late FakeTagRepository tags;
  late TaskActions actions;

  setUp(() {
    store = FakeStore(clock: () => now);
    tasks = FakeTaskRepository(store);
    tags = FakeTagRepository(store);
    actions = TaskActions(tasks, clock: () => now);
  });

  Task task(
    String id, {
    RepeatRule rule = RepeatRule.none,
    String? tagId,
    DateTime? due,
  }) => Task(
    id: id,
    title: 'Việc $id',
    tagId: tagId,
    due: due ?? DateTime(2026, 11, 9),
    repeatRule: rule,
    createdAt: DateTime(2026, 11, 1),
  );

  group('toggleDone', () {
    test('đánh dấu xong rồi bỏ xong', () async {
      await tasks.add(task('a'));

      expect(await actions.toggleDone((await tasks.getById('a'))!), isNull);
      var saved = (await tasks.getById('a'))!;
      expect(saved.done, isTrue);
      expect(saved.completedAt, now);

      expect(await actions.toggleDone(saved), isNull);
      saved = (await tasks.getById('a'))!;
      expect(saved.done, isFalse);
      expect(saved.completedAt, isNull);
    });

    test('việc không lặp: không tạo việc mới', () async {
      await tasks.add(task('a'));
      await actions.toggleDone((await tasks.getById('a'))!);
      expect(await tasks.getAll(), hasLength(1));
    });

    test(
      'việc lặp: giữ việc đã xong và tạo lần kế tiếp kèm việc con',
      () async {
        await tasks.add(
          task('a', rule: RepeatRule.daily, tagId: DefaultTagIds.health),
          subtasks: const [
            Subtask(id: 's1', taskId: 'a', title: 'Khởi động', done: true),
            Subtask(id: 's2', taskId: 'a', title: 'Chạy'),
          ],
        );

        final next = await actions.toggleDone((await tasks.getById('a'))!);

        expect(next, isNotNull);
        final all = await tasks.getAll();
        expect(all, hasLength(2));
        final old = (await tasks.getById('a'))!;
        expect(old.done, isTrue);
        expect(old.due, DateTime(2026, 11, 9));

        final saved = (await tasks.getById(next!.id))!;
        expect(saved.id, isNot('a'));
        expect(saved.due, DateTime(2026, 11, 10));
        expect(saved.done, isFalse);
        expect(saved.tagId, DefaultTagIds.health);
        final subs = await tasks.getSubtasks(saved.id);
        expect([for (final s in subs) s.title], ['Khởi động', 'Chạy']);
        expect(subs.every((s) => !s.done && s.taskId == saved.id), isTrue);
      },
    );

    test('bỏ xong một việc lặp không tạo thêm việc', () async {
      await tasks.add(task('a', rule: RepeatRule.daily));
      await actions.toggleDone(
        (await tasks.getById('a'))!,
      ); // xong, tạo lần sau
      expect(await tasks.getAll(), hasLength(2));

      await actions.toggleDone((await tasks.getById('a'))!); // bỏ xong
      expect(await tasks.getAll(), hasLength(2));
    });
  });

  group('delete và undoDelete', () {
    test('delete trả về bản chụp gồm việc con, việc bị xóa', () async {
      await tasks.add(
        task('a'),
        subtasks: const [Subtask(id: 's1', taskId: 'a', title: 'Con')],
      );

      final deleted = await actions.delete((await tasks.getById('a'))!);

      expect(await tasks.getById('a'), isNull);
      expect(deleted.task.id, 'a');
      expect([for (final s in deleted.subtasks) s.id], ['s1']);
    });

    test(
      'undoDelete khôi phục đúng việc, việc con và trạng thái xong',
      () async {
        await tasks.add(
          task('a', tagId: DefaultTagIds.work),
          subtasks: const [
            Subtask(id: 's1', taskId: 'a', title: 'Con 1', done: true),
            Subtask(id: 's2', taskId: 'a', title: 'Con 2'),
          ],
        );
        await tasks.setDone('a', true);
        final before = (await tasks.getById('a'))!;

        final deleted = await actions.delete(before);
        await actions.undoDelete(deleted);

        final after = (await tasks.getById('a'))!;
        expect(after.title, before.title);
        expect(after.tagId, DefaultTagIds.work);
        expect(after.done, isTrue);
        expect(after.completedAt, now);
        expect((after.subtaskDone, after.subtaskTotal), (1, 2));
        final subs = await tasks.getSubtasks('a');
        expect([for (final s in subs) s.title], ['Con 1', 'Con 2']);
      },
    );

    test(
      'nhãn đã bị xóa trong lúc đó thì khôi phục ở trạng thái không nhãn',
      () async {
        await tasks.add(task('a', tagId: DefaultTagIds.work));
        final deleted = await actions.delete((await tasks.getById('a'))!);
        await tags.delete(DefaultTagIds.work);

        await actions.undoDelete(deleted);

        expect(await tasks.getById('a'), isNotNull);
        expect((await tasks.getById('a'))!.tagId, isNull);
      },
    );
  });
}
