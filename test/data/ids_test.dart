import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/ids.dart';
import 'package:personal_app/data/tag_name.dart';

void main() {
  test('newId không trùng khi tạo liên tục', () {
    final ids = {for (var i = 0; i < 10000; i++) newId()};
    expect(ids.length, 10000);
  });

  test('stableIntId cố định, không âm và vừa 31 bit', () {
    // FNV-1a 32 bit của "a" là 0xe40c292c; bỏ bit dấu còn 0x640c292c.
    expect(stableIntId('a'), 0x640c292c);

    final id = newId();
    expect(stableIntId(id), stableIntId(id));
    for (final s in ['', 'lab3', 'pe-flutter', newId()]) {
      expect(stableIntId(s), inInclusiveRange(0, 0x7fffffff));
    }
  });

  test('tagNameKey không phân biệt hoa thường, kể cả chữ có dấu', () {
    expect(tagNameKey('  HỌC TẬP '), tagNameKey('Học tập'));
    expect(tagNameKey('Đi chơi'), 'đi chơi');
  });
}
