import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/features/search/recent_searches.dart';
import 'package:personal_app/features/search/search_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RecentSearches', () {
    test('thêm từ khóa mới lên đầu', () {
      final r = const RecentSearches().add('PRM393').add('Họp nhóm');
      expect(r.items, ['Họp nhóm', 'PRM393']);
    });

    test('cắt khoảng trắng hai đầu và bỏ từ khóa rỗng', () {
      final r = const RecentSearches().add('  PRM393  ').add('').add('   ');
      expect(r.items, ['PRM393']);
    });

    test('từ khóa trùng (không phân biệt hoa thường, kể cả chữ có dấu) chuyển '
        'lên đầu, không nhân đôi', () {
      final r = const RecentSearches()
          .add('Họp nhóm')
          .add('mua sữa')
          .add('HỌP NHÓM');
      expect(r.items, ['HỌP NHÓM', 'mua sữa']);
    });

    test('chữ có dấu và không dấu là hai từ khóa khác nhau', () {
      final r = const RecentSearches().add('hop').add('họp');
      expect(r.items, ['họp', 'hop']);
    });

    test('giữ tối đa ${RecentSearches.maxItems} từ khóa, bỏ cái cũ nhất', () {
      var r = const RecentSearches();
      for (var i = 1; i <= 7; i++) {
        r = r.add('từ $i');
      }
      expect(r.items, ['từ 7', 'từ 6', 'từ 5', 'từ 4', 'từ 3']);
    });

    test('add không làm đổi danh sách cũ (bất biến)', () {
      const before = RecentSearches(['a']);
      final after = before.add('b');
      expect(before.items, ['a']);
      expect(after.items, ['b', 'a']);
    });

    test('clear xóa hết', () {
      expect(const RecentSearches(['a', 'b']).clear().isEmpty, isTrue);
    });
  });

  group('RecentSearchesStore', () {
    Future<RecentSearchesStore> store([
      Map<String, Object> prefs = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(prefs);
      return RecentSearchesStore(await SharedPreferences.getInstance());
    }

    test('key bắt đầu bằng search_ theo hợp đồng', () {
      expect(RecentSearchesStore.key, startsWith('search_'));
    });

    test('chưa lưu gì thì rỗng', () async {
      expect((await store()).load().isEmpty, isTrue);
    });

    test('lưu rồi đọc lại giữ nguyên thứ tự', () async {
      final s = await store();
      await s.save(const RecentSearches().add('a').add('b').add('c'));

      expect(s.load().items, ['c', 'b', 'a']);
    });

    test('lưu danh sách rỗng thì xóa khóa', () async {
      final s = await store({
        'search_recent': ['a'],
      });
      await s.save(const RecentSearches());

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('search_recent'), isFalse);
    });

    test('đọc dữ liệu lưu hỏng thì làm sạch (trùng, rỗng, quá dài)', () async {
      final s = await store({
        'search_recent': ['x', 'X', '  ', 'y', 'z', 'w', 'v', 'u', 't'],
      });

      expect(s.load().items, ['x', 'y', 'z', 'w', 'v']);
    });
  });

  group('SearchFilter', () {
    Task task(String id, {bool done = false, String? tagId}) => Task(
      id: id,
      title: id,
      done: done,
      tagId: tagId,
      createdAt: DateTime(2026, 10, 1),
    );
    final tasks = [
      task('a', tagId: 'study'),
      task('b', done: true, tagId: 'study'),
      task('c', tagId: 'work'),
      task('d', done: true),
    ];
    List<String> ids(SearchFilter f) => [for (final t in f.apply(tasks)) t.id];

    test(
      'Tất cả giữ mọi việc',
      () => expect(ids(SearchFilter.all), ['a', 'b', 'c', 'd']),
    );

    test('Chưa xong và Đã xong', () {
      expect(ids(SearchFilter.pending), ['a', 'c']);
      expect(ids(SearchFilter.done), ['b', 'd']);
    });

    test('theo nhãn', () {
      expect(ids(SearchFilter.tag('study')), ['a', 'b']);
      expect(ids(SearchFilter.tag('work')), ['c']);
      expect(ids(SearchFilter.tag('khong-co')), isEmpty);
    });

    test('so sánh bằng: cùng loại và cùng nhãn thì bằng nhau', () {
      expect(SearchFilter.tag('x'), SearchFilter.tag('x'));
      expect(SearchFilter.tag('x'), isNot(SearchFilter.tag('y')));
      expect(SearchFilter.all, isNot(SearchFilter.pending));
    });
  });
}
