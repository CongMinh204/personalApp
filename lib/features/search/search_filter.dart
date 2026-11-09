import '../../data/models/task.dart';

enum SearchFilterKind { all, pending, done, tag }

/// Bộ lọc kết quả tìm kiếm: Tất cả, Chưa xong, Đã xong hoặc một nhãn.
class SearchFilter {
  const SearchFilter._(this.kind, this.tagId);

  static const all = SearchFilter._(SearchFilterKind.all, null);
  static const pending = SearchFilter._(SearchFilterKind.pending, null);
  static const done = SearchFilter._(SearchFilterKind.done, null);

  factory SearchFilter.tag(String tagId) =>
      SearchFilter._(SearchFilterKind.tag, tagId);

  final SearchFilterKind kind;

  /// Id nhãn khi [kind] là [SearchFilterKind.tag].
  final String? tagId;

  @override
  bool operator ==(Object other) =>
      other is SearchFilter && other.kind == kind && other.tagId == tagId;

  @override
  int get hashCode => Object.hash(kind, tagId);

  bool matches(Task task) => switch (kind) {
    SearchFilterKind.all => true,
    SearchFilterKind.pending => !task.done,
    SearchFilterKind.done => task.done,
    SearchFilterKind.tag => task.tagId == tagId,
  };

  /// Các việc thỏa bộ lọc, giữ nguyên thứ tự.
  List<Task> apply(List<Task> tasks) => [
    for (final task in tasks)
      if (matches(task)) task,
  ];
}
