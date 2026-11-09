import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/app/dependencies.dart';
import 'package:personal_app/data/default_tags.dart';
import 'package:personal_app/data/repositories/tag_repository.dart';
import 'package:personal_app/data/sqlite/app_database.dart';
import 'package:personal_app/main.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'AppDependencies.fake có dữ liệu mẫu, sample: false thì chỉ 4 nhãn',
    () async {
      final sample = AppDependencies.fake();
      expect(await sample.tasks.getAll(), isNotEmpty);

      final empty = AppDependencies.fake(sample: false);
      expect(await empty.tasks.getAll(), isEmpty);
      expect(await empty.tags.getAll(), hasLength(defaultTags.length));
    },
  );

  test(
    'AppDependencies.sqlite dùng database truyền vào và đóng được',
    () async {
      final app = await AppDatabase.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      final deps = await AppDependencies.sqlite(app: app);

      expect(await deps.tags.getAll(), hasLength(defaultTags.length));
      await deps.close!();
      expect(app.db.isOpen, isFalse);
    },
  );

  testWidgets('PersonalApp đưa repository xuống cây widget bằng Provider', (
    tester,
  ) async {
    final deps = AppDependencies.fake();
    await tester.pumpWidget(PersonalApp(dependencies: deps));

    final context = tester.element(find.byType(Scaffold).first);
    expect(context.read<TagRepository>(), same(deps.tags));
  });
}
