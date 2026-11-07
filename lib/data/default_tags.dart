import 'models/tag.dart';

/// Id cố định của 4 nhãn mặc định.
abstract final class DefaultTagIds {
  static const study = 'tag-study';
  static const work = 'tag-work';
  static const personal = 'tag-personal';
  static const health = 'tag-health';
}

/// 4 nhãn có sẵn khi cài app: bản SQLite tạo lúc tạo database, bản Fake có
/// sẵn trong `FakeStore`.
const defaultTags = [
  Tag(id: DefaultTagIds.study, name: 'Học tập', color: TagColor.violet),
  Tag(id: DefaultTagIds.work, name: 'Công việc', color: TagColor.orange),
  Tag(id: DefaultTagIds.personal, name: 'Cá nhân', color: TagColor.green),
  Tag(id: DefaultTagIds.health, name: 'Sức khỏe', color: TagColor.red),
];
