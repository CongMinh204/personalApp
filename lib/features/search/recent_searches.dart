import 'package:shared_preferences/shared_preferences.dart';

/// Danh sách "Tìm gần đây": mới nhất trước, không trùng (không phân biệt hoa
/// thường), tối đa [maxItems] từ khóa. Bất biến: mỗi thao tác trả về bản mới.
class RecentSearches {
  const RecentSearches([this.items = const []]);

  static const maxItems = 5;

  final List<String> items;

  bool get isEmpty => items.isEmpty;

  /// Thêm [query] lên đầu. Cắt khoảng trắng hai đầu, bỏ qua từ khóa rỗng, và
  /// nếu đã có từ khóa giống (không phân biệt hoa thường, kể cả chữ có dấu) thì
  /// chuyển nó lên đầu thay vì thêm bản trùng. Quá [maxItems] thì bỏ từ khóa cũ
  /// nhất.
  RecentSearches add(String query) {
    final text = query.trim();
    if (text.isEmpty) return this;
    final key = text.toLowerCase();
    final next = [
      text,
      for (final item in items)
        if (item.toLowerCase() != key) item,
    ];
    return RecentSearches(next.take(maxItems).toList());
  }

  RecentSearches clear() => const RecentSearches();
}

/// Lưu [RecentSearches] bằng shared_preferences. Key bắt đầu bằng `search_`
/// theo docs/DATA_CONTRACT.md, mục 6.
class RecentSearchesStore {
  RecentSearchesStore(this._prefs);

  static const key = 'search_recent';

  final SharedPreferences _prefs;

  /// Đọc danh sách đã lưu. Đọc lại qua [RecentSearches.add] để dữ liệu lưu
  /// hỏng (trùng, quá dài, có khoảng trắng thừa) được làm sạch.
  RecentSearches load() {
    var recent = const RecentSearches();
    final stored = _prefs.getStringList(key) ?? const <String>[];
    // Lưu theo thứ tự mới nhất trước, nên thêm từ cũ nhất lên trước.
    for (final item in stored.reversed) {
      recent = recent.add(item);
    }
    return recent;
  }

  Future<void> save(RecentSearches recent) async {
    if (recent.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setStringList(key, recent.items);
    }
  }
}
