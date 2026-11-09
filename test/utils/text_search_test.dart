import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/utils/text_search.dart';

void main() {
  group('foldVietnamese', () {
    test('bỏ dấu và chuyển chữ thường', () {
      expect(foldVietnamese('Học tập'), 'hoc tap');
      expect(foldVietnamese('HỌC TẬP'), 'hoc tap');
      expect(foldVietnamese('Nguyễn Văn Ấn'), 'nguyen van an');
    });

    test('chữ đ và Đ thành d', () {
      expect(foldVietnamese('Đường đi'), 'duong di');
    });

    test('đủ 12 nguyên âm và 5 dấu thanh', () {
      expect(foldVietnamese('àáạảãâầấậẩẫăằắặẳẵ'), 'a' * 17);
      expect(foldVietnamese('èéẹẻẽêềếệểễ'), 'e' * 11);
      expect(foldVietnamese('ìíịỉĩ'), 'i' * 5);
      expect(foldVietnamese('òóọỏõôồốộổỗơờớợởỡ'), 'o' * 17);
      expect(foldVietnamese('ùúụủũưừứựửữ'), 'u' * 11);
      expect(foldVietnamese('ỳýỵỷỹ'), 'y' * 5);
    });

    test('bỏ cả dấu rời (chữ ở dạng tách dấu)', () {
      // "o" + dấu mũ + dấu nặng = ộ ở dạng tách.
      expect(foldVietnamese('ộ'), 'o');
      expect(foldVietnamese('Học tạp'), 'hoc tap');
    });

    test('giữ nguyên chữ không dấu, số và ký tự khác', () {
      expect(
        foldVietnamese('Flutter 3.47 - PRM393!'),
        'flutter 3.47 - prm393!',
      );
      expect(foldVietnamese(''), '');
    });
  });

  group('containsFolded', () {
    test('khớp bất kể hoa thường và dấu', () {
      final needle = foldVietnamese('hoc tap');
      expect(containsFolded('Ôn Học Tập chăm chỉ', needle), isTrue);
      expect(containsFolded('Học bài', needle), isFalse);
    });

    test('từ khóa có dấu cũng khớp bản không dấu', () {
      expect(containsFolded('hoc tap', foldVietnamese('học tập')), isTrue);
    });
  });
}
