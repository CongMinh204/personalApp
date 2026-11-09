import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/default_tags.dart';
import 'package:personal_app/data/models/tag.dart';
import 'package:personal_app/features/settings/settings_labels.dart';
import 'package:personal_app/features/settings/tag_validation.dart';

void main() {
  group('validateTagName', () {
    test('tên hợp lệ thì không có lỗi', () {
      expect(validateTagName('Gia đình', defaultTags), isNull);
    });

    test('tên rỗng hoặc chỉ khoảng trắng là lỗi', () {
      expect(validateTagName('', defaultTags), 'Nhập tên nhãn');
      expect(validateTagName('   ', defaultTags), 'Nhập tên nhãn');
    });

    test('trùng nhãn có sẵn là lỗi, không phân biệt hoa thường', () {
      expect(validateTagName('công việc', defaultTags), isNotNull);
      expect(validateTagName('CÔNG VIỆC', defaultTags), isNotNull);
    });

    test('trùng cả khi chữ có dấu khác hoa thường, bỏ khoảng trắng hai đầu', () {
      expect(validateTagName('  HỌC TẬP  ', defaultTags), contains('Học tập'));
    });

    test('chữ có dấu và không dấu là hai tên khác nhau', () {
      expect(validateTagName('Hoc tap', defaultTags), isNull);
    });

    test('khi sửa, giữ nguyên tên của chính nhãn đó là hợp lệ', () {
      expect(
        validateTagName('Học tập', defaultTags, editingId: DefaultTagIds.study),
        isNull,
      );
    });

    test('khi sửa, đổi sang tên của nhãn khác vẫn là lỗi', () {
      expect(
        validateTagName(
          'Công việc',
          defaultTags,
          editingId: DefaultTagIds.study,
        ),
        isNotNull,
      );
    });

    test('danh sách rỗng thì mọi tên không rỗng đều hợp lệ', () {
      expect(validateTagName('A', const <Tag>[]), isNull);
    });
  });

  group('nhãn hiển thị của cài đặt', () {
    test('nhắc trước', () {
      expect(reminderLabel(0), 'Đúng giờ');
      expect(reminderLabel(5), '5 phút');
      expect(reminderLabel(15), '15 phút');
      expect(reminderLabel(60), '1 giờ');
      expect(reminderLabel(1440), '1 ngày');
    });

    test('giờ tóm tắt buổi sáng', () {
      expect(clockLabel(420), '07:00');
      expect(clockLabel(0), '00:00');
      expect(clockLabel(8 * 60 + 5), '08:05');
      expect(clockLabel(1439), '23:59');
    });

    test('tuần bắt đầu và phút', () {
      expect(weekStartLabel(1), 'Thứ Hai');
      expect(weekStartLabel(7), 'Chủ Nhật');
      expect(minutesLabel(25), '25 phút');
    });
  });
}
