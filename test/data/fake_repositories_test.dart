import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/fake/fake_focus_repository.dart';
import 'package:personal_app/data/fake/fake_habit_repository.dart';
import 'package:personal_app/data/fake/fake_store.dart';
import 'package:personal_app/data/fake/fake_tag_repository.dart';
import 'package:personal_app/data/fake/fake_task_repository.dart';
import 'package:personal_app/utils/dates.dart';

import 'repository_contract.dart';

void main() {
  runRepositoryContract('Fake', (clock) async {
    final store = FakeStore(clock: clock);
    return RepositorySet(
      tasks: FakeTaskRepository(store),
      tags: FakeTagRepository(store),
      focus: FakeFocusRepository(store),
      habits: FakeHabitRepository(store),
    );
  });

  test('FakeStore.sample có dữ liệu mẫu cho các màn', () async {
    final now = DateTime(2026, 10, 29, 13, 40);
    final store = FakeStore.sample(clock: () => now);
    final tasks = FakeTaskRepository(store);
    final focus = FakeFocusRepository(store);
    final habits = FakeHabitRepository(store);

    final pe = (await tasks.getById('pe-flutter'))!;
    expect((pe.subtaskDone, pe.subtaskTotal), (1, 3));

    final total = await focus.totalForTask('pe-flutter');
    expect((total.seconds, total.sessions), (75 * 60, 3));

    expect(await habits.streakOf('habit-water'), 12);
    expect(await habits.bestStreakOf('habit-water'), 15);
    expect(
      [for (final h in await habits.watchArchived().first) h.id],
      ['habit-meditation', 'habit-vocab', 'habit-snack'],
    );

    final week = await tasks.countDoneByDay(
      daysRange(DateTime(2026, 10, 23), 7),
    );
    expect(week.values.reduce((a, b) => a + b), greaterThan(0));
  });
}
