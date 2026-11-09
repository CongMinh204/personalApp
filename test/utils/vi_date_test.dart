import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/utils/vi_date.dart';

void main() {
  group('fullDate', () {
    test('gọi đúng thứ tiếng Việt: Thứ Hai là Th 2, Thứ Năm là Th 5', () {
      expect(fullDate(DateTime(2026, 10, 26)), 'Th 2, 26/10/2026'); // Thứ Hai
      expect(fullDate(DateTime(2026, 10, 27)), 'Th 3, 27/10/2026');
      expect(fullDate(DateTime(2026, 10, 28)), 'Th 4, 28/10/2026');
      expect(fullDate(DateTime(2026, 10, 29)), 'Th 5, 29/10/2026'); // Thứ Năm
      expect(fullDate(DateTime(2026, 10, 30)), 'Th 6, 30/10/2026');
      expect(fullDate(DateTime(2026, 10, 31)), 'Th 7, 31/10/2026');
    });

    test('Chủ Nhật là CN', () {
      expect(fullDate(DateTime(2026, 11, 1)), 'CN, 01/11/2026');
    });

    test('ngày và tháng một chữ số được thêm số 0', () {
      expect(fullDate(DateTime(2026, 3, 5)), 'Th 5, 05/03/2026');
    });
  });

  group('weekdayName', () {
    test('theo DateTime.weekday', () {
      expect(weekdayName(1), 'Thứ Hai');
      expect(weekdayName(4), 'Thứ Năm');
      expect(weekdayName(7), 'Chủ Nhật');
    });
  });

  group('headerDate và hourMinute', () {
    test('định dạng tiếng Việt', () {
      expect(headerDate(DateTime(2026, 10, 29)), 'Thứ Năm, 29 tháng 10');
      expect(hourMinute(DateTime(2026, 1, 1, 7, 5)), '07:05');
    });
  });
}
